import SwiftUI

// MARK: - Node URL Validator

/// Validates custom node URLs for security.
/// Only HTTPS is allowed.
/// Warns if the domain is not cereblix.com.
enum NodeURLValidator {

    enum ValidationResult {
        case valid
        case validWithWarning(String)
        case invalid(String)
    }

    /// Official domains that don't trigger a warning
    private static let officialDomains = ["cereblix.com", "www.cereblix.com"]

    /// Validate a node URL string
    static func validate(_ urlString: String) -> ValidationResult {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return .invalid("URL cannot be empty")
        }

        guard let components = URLComponents(string: trimmed) else {
            return .invalid("Invalid URL format")
        }

        guard let scheme = components.scheme?.lowercased() else {
            return .invalid("URL must include a scheme (https://)")
        }

        guard let host = components.host, !host.isEmpty else {
            return .invalid("URL must include a valid host")
        }

        if scheme != "https" {
            return .invalid("Only HTTPS connections are allowed. HTTP is insecure and can expose your wallet data.")
        }

        // Warn about non-official domains
        let isOfficial = officialDomains.contains(host.lowercased()) ||
                          host.lowercased().hasSuffix(".cereblix.com")

        if !isOfficial {
            return .validWithWarning("⚠️ This is not an official Cereblix node. Only use nodes you trust. Wallet and mining API requests will be sent to this server. P2P login remains pinned to the official Cereblix host.")
        }

        return .valid
    }
}

/// Global app state — selected wallet, onboarding, node config, currency preferences
@Observable
@MainActor
final class AppState {

    // MARK: - Wallet
    var wallets: [WalletAccount] = []
    var selectedWallet: WalletAccount?
    var hasCompletedOnboarding: Bool = false
    var isAppLocked: Bool = false
    var appLockError: String?
    private var backgroundedAt: Date?
    private let appLockGracePeriod: TimeInterval = 30

    // MARK: - Node Config
    var nodeBaseURL: String = "https://cereblix.com" {
        didSet {
            APIConfig.baseURL = nodeBaseURL
            UserDefaults.standard.set(nodeBaseURL, forKey: "node_base_url")
        }
    }

    /// Validation error for nodeBaseURL, shown in UI
    var nodeURLError: String?

    /// Warning for non-official node, shown in UI
    var nodeURLWarning: String?

    // MARK: - P2P Session (memory only — never persisted)
    var p2pToken: String?
    var p2pAddress: String?
    var isP2PLoggedIn: Bool { p2pToken != nil }

    // MARK: - Chain Status & Price Cache
    var chainStatus: ChainStatus?
    var p2pStats: P2PStats?

    // MARK: - Currency Settings
    var autoCurrencyByRegion: Bool = true {
        didSet {
            UserDefaults.standard.set(autoCurrencyByRegion, forKey: "auto_currency_by_region")
        }
    }

    var manualCurrencyOverride: String = "USD" {
        didSet {
            UserDefaults.standard.set(manualCurrencyOverride, forKey: "manual_currency_override")
        }
    }

    var selectedFiatCurrency: String {
        if autoCurrencyByRegion {
            return CurrencyManager.defaultCurrencyForSystem()
        } else {
            return manualCurrencyOverride
        }
    }

    var cachedFXRates: [String: Decimal] = CurrencyManager.fallbackRates {
        didSet {
            if let data = try? JSONEncoder().encode(cachedFXRates) {
                UserDefaults.standard.set(data, forKey: "cached_fx_rates")
            }
        }
    }

    var cachedCRBPriceUSDT: Decimal = 0 {
        didSet {
            UserDefaults.standard.set(NSDecimalNumber(decimal: cachedCRBPriceUSDT).stringValue, forKey: "cached_crb_price_usdt")
        }
    }

    // MARK: - Linked USDT Wallets
    var linkedUSDTWallets: [USDTWallet] = [] {
        didSet {
            saveUSDTWallets()
        }
    }

    var p2pWalletBindings: [P2PWalletBinding] = [] {
        didSet {
            saveP2PWalletBindings()
        }
    }

    var defaultP2PUSDTWalletIdsByRail: [String: UUID] = [:] {
        didSet {
            saveDefaultP2PUSDTWallets()
        }
    }

    init() {
        loadState()

        // Start background initial fetching
        Task {
            await refreshFiatRates()
            await refreshP2PStats()
        }
    }

    private func loadState() {
        // Load wallets
        wallets = KeychainStore.shared.loadWalletList()
        hasCompletedOnboarding = !wallets.isEmpty
        selectedWallet = wallets.first

        // Load node URL
        if let savedURL = UserDefaults.standard.string(forKey: "node_base_url"), !savedURL.isEmpty {
            nodeBaseURL = savedURL
            APIConfig.baseURL = savedURL
        }

        // Load currency settings
        if UserDefaults.standard.object(forKey: "auto_currency_by_region") != nil {
            autoCurrencyByRegion = UserDefaults.standard.bool(forKey: "auto_currency_by_region")
        }
        if let manualOverride = UserDefaults.standard.string(forKey: "manual_currency_override") {
            manualCurrencyOverride = manualOverride
        }
        if let ratesData = UserDefaults.standard.data(forKey: "cached_fx_rates") {
            if let rates = try? JSONDecoder().decode([String: Decimal].self, from: ratesData) {
                cachedFXRates = rates
            } else if let legacyRates = try? JSONDecoder().decode([String: Double].self, from: ratesData) {
                cachedFXRates = legacyRates.compactMapValues { Decimal(string: String($0)) }
            }
        }
        if let savedPriceString = UserDefaults.standard.string(forKey: "cached_crb_price_usdt"),
           let savedPrice = Decimal(string: savedPriceString),
           savedPrice > 0 {
            cachedCRBPriceUSDT = savedPrice
        } else {
            let legacySavedPrice = UserDefaults.standard.double(forKey: "cached_crb_price_usdt")
            if legacySavedPrice > 0,
               let migratedPrice = Decimal(string: String(legacySavedPrice)) {
                cachedCRBPriceUSDT = migratedPrice
            }
        }

        // Load linked USDT wallets
        if let usdtData = UserDefaults.standard.data(forKey: "linked_usdt_wallets"),
           let loaded = try? JSONDecoder().decode([USDTWallet].self, from: usdtData) {
            linkedUSDTWallets = loaded
        }

        if let bindingData = UserDefaults.standard.data(forKey: "p2p_wallet_bindings"),
           let loaded = try? JSONDecoder().decode([P2PWalletBinding].self, from: bindingData) {
            p2pWalletBindings = loaded
        }

        if let defaultsData = UserDefaults.standard.data(forKey: "default_p2p_usdt_wallets"),
           let loaded = try? JSONDecoder().decode([String: UUID].self, from: defaultsData) {
            defaultP2PUSDTWalletIdsByRail = loaded
        }
    }

    // MARK: - Wallet Management

    func lockApp() {
        guard hasCompletedOnboarding else { return }
        isAppLocked = true
    }

    func markBackgrounded() {
        backgroundedAt = Date()
        lockApp()
    }

    func handleAppActive() {
        guard hasCompletedOnboarding else {
            isAppLocked = false
            return
        }
        guard let backgroundedAt else { return }
        if Date().timeIntervalSince(backgroundedAt) >= appLockGracePeriod {
            lockApp()
        }
    }

    func unlockAppWithBiometrics() async {
        appLockError = nil
        do {
            try await KeychainStore.shared.authenticateBiometrics(reason: "Authenticate to unlock CRB Hub")
            isAppLocked = false
            backgroundedAt = nil
        } catch {
            appLockError = error.localizedDescription
        }
    }

    func unlockApp(password: String) {
        appLockError = nil
        do {
            try WalletSecurityStore.shared.verifyPassword(password)
            isAppLocked = false
            backgroundedAt = nil
        } catch {
            appLockError = error.localizedDescription
        }
    }

    func createWallet(name: String) throws {
        let wallet = try KeychainStore.shared.createWallet(name: name)
        wallets.append(wallet)
        selectedWallet = wallet
        hasCompletedOnboarding = true
        isAppLocked = false
    }

    func createWalletWithBiometricSetup(name: String) async throws {
        let wallet = try await KeychainStore.shared.createWalletWithBiometricSetup(name: name)
        wallets.append(wallet)
        selectedWallet = wallet
        hasCompletedOnboarding = true
        isAppLocked = false
    }

    func importWallet(name: String, privateKeyHex: String) throws {
        let wallet = try KeychainStore.shared.importWallet(name: name, privateKeyHex: privateKeyHex)
        wallets.append(wallet)
        selectedWallet = wallet
        hasCompletedOnboarding = true
    }

    func importWalletWithBiometricSetup(name: String, privateKeyHex: String) async throws {
        let wallet = try await KeychainStore.shared.importWalletWithBiometricSetup(name: name, privateKeyHex: privateKeyHex)
        wallets.append(wallet)
        selectedWallet = wallet
        hasCompletedOnboarding = true
    }

    func deleteWallet(_ wallet: WalletAccount) {
        KeychainStore.shared.deleteWallet(id: wallet.id)
        wallets.removeAll { $0.id == wallet.id }
        if selectedWallet?.id == wallet.id {
            selectedWallet = wallets.first
        }
        if wallets.isEmpty {
            hasCompletedOnboarding = false
        }
    }

    func selectWallet(_ wallet: WalletAccount) {
        selectedWallet = wallet
    }

    // MARK: - P2P Session

    func setP2PSession(token: String, address: String) {
        p2pToken = token
        p2pAddress = address
    }

    func clearP2PSession() {
        p2pToken = nil
        p2pAddress = nil
    }

    // MARK: - USDT Wallet Management

    func addUSDTWallet(_ wallet: USDTWallet) {
        linkedUSDTWallets.append(wallet)
    }

    func upsertUSDTWallet(_ wallet: USDTWallet) {
        if let index = linkedUSDTWallets.firstIndex(where: {
            $0.provider == wallet.provider &&
            $0.network == wallet.network &&
            $0.address == wallet.address
        }) {
            var updated = wallet
            updated.id = linkedUSDTWallets[index].id
            updated.balance = linkedUSDTWallets[index].balance
            linkedUSDTWallets[index] = updated
        } else {
            linkedUSDTWallets.append(wallet)
        }
    }

    func deleteUSDTWallet(id: UUID) {
        linkedUSDTWallets.removeAll { $0.id == id }
        p2pWalletBindings.removeAll { $0.usdtWalletId == id }
        defaultP2PUSDTWalletIdsByRail = defaultP2PUSDTWalletIdsByRail.filter { $0.value != id }
    }

    func setDefaultP2PUSDTWallet(_ wallet: USDTWallet, rail: String) {
        defaultP2PUSDTWalletIdsByRail[rail.lowercased()] = wallet.id
    }

    func defaultP2PUSDTWallet(for rail: String) -> USDTWallet? {
        let cleanRail = rail.lowercased()
        if let id = defaultP2PUSDTWalletIdsByRail[cleanRail],
           let wallet = linkedUSDTWallets.first(where: { $0.id == id && $0.network.p2pRail == cleanRail }) {
            return wallet
        }
        return linkedUSDTWallets.first { $0.network.p2pRail == cleanRail }
    }

    func bindP2PWallet(
        kind: P2PWalletBinding.BindingKind,
        p2pId: String,
        role: P2PWalletBinding.Role,
        usdtAddress: String,
        usdtNetwork: USDTNetwork,
        usdtWalletId: UUID?
    ) {
        guard let wallet = selectedWallet else { return }
        let cleanId = p2pId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanUSDTAddress = usdtAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanId.isEmpty, !cleanUSDTAddress.isEmpty else { return }

        let binding = P2PWalletBinding(
            kind: kind,
            p2pId: cleanId,
            role: role,
            crbWalletId: wallet.id,
            crbAddress: wallet.address,
            usdtWalletId: usdtWalletId,
            usdtAddress: cleanUSDTAddress,
            usdtNetwork: usdtNetwork,
            rail: usdtNetwork.p2pRail ?? "",
            createdAt: Date()
        )

        p2pWalletBindings.removeAll { $0.kind == kind && $0.p2pId == cleanId && $0.role == role }
        p2pWalletBindings.append(binding)
    }

    func p2pBinding(kind: P2PWalletBinding.BindingKind, p2pId: String, role: P2PWalletBinding.Role? = nil) -> P2PWalletBinding? {
        p2pWalletBindings.last {
            $0.kind == kind &&
            $0.p2pId == p2pId &&
            (role == nil || $0.role == role)
        }
    }

    func p2pBoundUSDTWallet(kind: P2PWalletBinding.BindingKind, p2pId: String, role: P2PWalletBinding.Role? = nil) -> USDTWallet? {
        guard let binding = p2pBinding(kind: kind, p2pId: p2pId, role: role) else {
            return nil
        }
        if let walletId = binding.usdtWalletId,
           let wallet = linkedUSDTWallets.first(where: { $0.id == walletId }) {
            return wallet
        }
        return linkedUSDTWallets.first {
            $0.address.caseInsensitiveCompare(binding.usdtAddress) == .orderedSame &&
            $0.network == binding.usdtNetwork
        }
    }

    func hydrateP2PWalletBindings(offers: [P2POffer] = [], trades: [P2PTrade] = []) {
        for offer in offers {
            guard let makerUSDT = offer.MakerUSDT else { continue }
            hydrateP2PWalletBinding(
                kind: .offer,
                p2pId: offer.ID,
                role: .maker,
                usdtAddress: makerUSDT,
                rail: offer.Rail
            )
        }

        for trade in trades {
            guard let tradeId = trade.ID else { continue }
            if trade.MakerAddr == selectedWallet?.address, let makerUSDT = trade.MakerUSDT {
                hydrateP2PWalletBinding(
                    kind: .trade,
                    p2pId: tradeId,
                    role: .maker,
                    usdtAddress: makerUSDT,
                    rail: trade.Rail
                )
            }
            if trade.TakerAddr == selectedWallet?.address, let takerUSDT = trade.TakerUSDT {
                hydrateP2PWalletBinding(
                    kind: .trade,
                    p2pId: tradeId,
                    role: .taker,
                    usdtAddress: takerUSDT,
                    rail: trade.Rail
                )
            }
        }
    }

    private func hydrateP2PWalletBinding(
        kind: P2PWalletBinding.BindingKind,
        p2pId: String,
        role: P2PWalletBinding.Role,
        usdtAddress: String,
        rail: String?
    ) {
        guard p2pBinding(kind: kind, p2pId: p2pId, role: role) == nil else { return }
        let cleanRail = rail?.lowercased() ?? ""
        let cleanAddress = usdtAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanAddress.isEmpty else { return }

        let linkedWallet = linkedUSDTWallets.first {
            $0.address.caseInsensitiveCompare(cleanAddress) == .orderedSame &&
            $0.network.p2pRail == cleanRail
        }
        let network = linkedWallet?.network ?? (cleanRail == "solana" ? USDTNetwork.solana : USDTNetwork.polygon)
        guard USDTNetwork.isValidP2PAddress(cleanAddress, rail: cleanRail) else { return }

        bindP2PWallet(
            kind: kind,
            p2pId: p2pId,
            role: role,
            usdtAddress: cleanAddress,
            usdtNetwork: network,
            usdtWalletId: linkedWallet?.id
        )
    }

    func refreshUSDTBalances() async {
        for index in 0..<linkedUSDTWallets.count {
            let wallet = linkedUSDTWallets[index]
            do {
                let bal = try await USDTBalanceService.fetchBalance(for: wallet.address, network: wallet.network)
                linkedUSDTWallets[index].balance = bal
            } catch {
                linkedUSDTWallets[index].balance = 0
            }
        }
    }

    private func saveUSDTWallets() {
        if let data = try? JSONEncoder().encode(linkedUSDTWallets) {
            UserDefaults.standard.set(data, forKey: "linked_usdt_wallets")
        }
    }

    private func saveP2PWalletBindings() {
        if let data = try? JSONEncoder().encode(p2pWalletBindings) {
            UserDefaults.standard.set(data, forKey: "p2p_wallet_bindings")
        }
    }

    private func saveDefaultP2PUSDTWallets() {
        if let data = try? JSONEncoder().encode(defaultP2PUSDTWalletIdsByRail) {
            UserDefaults.standard.set(data, forKey: "default_p2p_usdt_wallets")
        }
    }

    // MARK: - Background Refresh

    func refreshChainStatus() async {
        do {
            chainStatus = try await CereblixAPIClient.getStatus()
        } catch {
            chainStatus = nil
        }
    }

    func refreshP2PStats() async {
        do {
            let stats = try await P2PAPIClient.getStats()
            p2pStats = stats
            if let price = stats.price_usdt, price > 0 {
                cachedCRBPriceUSDT = price
            }
        } catch {
            return
        }
    }

    func refreshFiatRates() async {
        do {
            let rates = try await FiatExchangeService.fetchRates()
            cachedFXRates = rates
        } catch {
            return
        }
    }
}
