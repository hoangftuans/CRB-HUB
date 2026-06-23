import SwiftUI

// MARK: - Node URL Validator

/// Validates custom node URLs for security.
/// Only HTTPS is allowed (except localhost/127.0.0.1 for local dev).
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
        
        // Allow http only for localhost / 127.0.0.1
        let isLocalhost = host == "localhost" || host == "127.0.0.1"
        
        if scheme == "http" && !isLocalhost {
            return .invalid("Only HTTPS connections are allowed. HTTP is insecure and can expose your wallet data.")
        }
        
        if scheme != "https" && scheme != "http" {
            return .invalid("URL scheme must be https")
        }
        
        // Warn about non-official domains
        let isOfficial = officialDomains.contains(host.lowercased()) ||
                          host.lowercased().hasSuffix(".cereblix.com")
        
        if !isOfficial && !isLocalhost {
            return .validWithWarning("⚠️ This is not an official Cereblix node. Only use nodes you trust. Your API requests (including auth tokens) will be sent to this server.")
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
    
    var cachedFXRates: [String: Double] = CurrencyManager.fallbackRates {
        didSet {
            if let data = try? JSONEncoder().encode(cachedFXRates) {
                UserDefaults.standard.set(data, forKey: "cached_fx_rates")
            }
        }
    }
    
    var cachedCRBPriceUSDT: Double = 0.0 {
        didSet {
            UserDefaults.standard.set(cachedCRBPriceUSDT, forKey: "cached_crb_price_usdt")
        }
    }
    
    // MARK: - Linked USDT Wallets
    var linkedUSDTWallets: [USDTWallet] = [] {
        didSet {
            saveUSDTWallets()
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
        if let ratesData = UserDefaults.standard.data(forKey: "cached_fx_rates"),
           let rates = try? JSONDecoder().decode([String: Double].self, from: ratesData) {
            cachedFXRates = rates
        }
        let savedPrice = UserDefaults.standard.double(forKey: "cached_crb_price_usdt")
        if savedPrice > 0 {
            cachedCRBPriceUSDT = savedPrice
        }
        
        // Load linked USDT wallets
        if let usdtData = UserDefaults.standard.data(forKey: "linked_usdt_wallets"),
           let loaded = try? JSONDecoder().decode([USDTWallet].self, from: usdtData) {
            linkedUSDTWallets = loaded
        }
    }
    
    // MARK: - Wallet Management
    
    func createWallet(name: String) throws {
        let wallet = try KeychainStore.shared.createWallet(name: name)
        wallets.append(wallet)
        selectedWallet = wallet
        hasCompletedOnboarding = true
    }
    
    func importWallet(name: String, privateKeyHex: String) throws {
        let wallet = try KeychainStore.shared.importWallet(name: name, privateKeyHex: privateKeyHex)
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
    
    func deleteUSDTWallet(id: UUID) {
        linkedUSDTWallets.removeAll { $0.id == id }
    }
    
    func refreshUSDTBalances() async {
        for index in 0..<linkedUSDTWallets.count {
            let wallet = linkedUSDTWallets[index]
            do {
                let bal = try await USDTBalanceService.fetchBalance(for: wallet.address, network: wallet.network)
                linkedUSDTWallets[index].balance = bal
            } catch {
                print("Failed to fetch balance for \(wallet.name): \(error)")
            }
        }
    }
    
    private func saveUSDTWallets() {
        if let data = try? JSONEncoder().encode(linkedUSDTWallets) {
            UserDefaults.standard.set(data, forKey: "linked_usdt_wallets")
        }
    }
    
    // MARK: - Background Refresh
    
    func refreshChainStatus() async {
        do {
            chainStatus = try await CereblixAPIClient.getStatus()
        } catch {
            print("Failed to refresh chain status: \(error)")
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
            print("Failed to refresh P2P stats: \(error)")
        }
    }
    
    func refreshFiatRates() async {
        do {
            let rates = try await FiatExchangeService.fetchRates()
            cachedFXRates = rates
        } catch {
            print("Failed to refresh fiat exchange rates: \(error)")
        }
    }
}
