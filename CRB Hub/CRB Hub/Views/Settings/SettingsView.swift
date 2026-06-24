import SwiftUI
import StoreKit

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var supportTipStore = SupportTipStore()
    @State private var showExportKey = false
    @State private var exportWalletId: UUID?
    @State private var exportedKey: String?
    @State private var showDeleteConfirm = false
    @State private var deleteWalletId: UUID?
    @State private var nodeURLInput = ""
    @State private var savedNodeURL = false
    @State private var walletPassword = ""
    @State private var walletPasswordConfirm = ""
    @State private var walletPasswordError: String?
    @State private var walletPasswordSuccess: String?
    @State private var isUpdatingWalletPassword = false
    @State private var selectedTipUSDTWallet: USDTWallet?
    @State private var selectedTipUSDTRecipient = ""
    @State private var copiedTipAddress: String?

    private var appVersionText: String {
        let infoDict = Bundle.main.localizedInfoDictionary ?? Bundle.main.infoDictionary
        let version = infoDict?["CFBundleShortVersionString"] as? String
        let build = infoDict?["CFBundleVersion"] as? String

        let cleanedVersion = version?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedBuild = build?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let finalVersion = cleanedVersion, !finalVersion.isEmpty else {
            if let finalBuild = cleanedBuild, !finalBuild.isEmpty {
                return "1.0 (\(finalBuild))"
            }
            return "1.0"
        }

        if let finalBuild = cleanedBuild, !finalBuild.isEmpty, finalBuild != finalVersion {
            return "\(finalVersion) (\(finalBuild))"
        }
        return finalVersion
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                CRBTheme.Colors.background.ignoresSafeArea()
                
                GeometryReader { geometry in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: CRBTheme.Spacing.xl) {
                            // Wallets
                            walletsSection

                            // Node configuration
                            nodeSection

                            // Security
                            securitySection

                            // Currency & Region
                            currencySection

                            // USDT Wallets
                            usdtWalletSection

                            // SafeTrade API
                            safeTradeAPISection

                            // Support Project
                            supportProjectSection

                            // About
                            aboutSection
                        }
                        .padding(CRBTheme.Spacing.lg)
                        .frame(width: geometry.size.width, alignment: .top)
                    }
                }
            }
            .navigationTitle("Settings".localized)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                nodeURLInput = appState.nodeBaseURL
            }
            .task {
                await supportTipStore.loadProducts()
            }
            .alert("Delete Wallet".localized, isPresented: $showDeleteConfirm) {
                Button("Cancel".localized, role: .cancel) {}
                Button("Delete".localized, role: .destructive) {
                    if let id = deleteWalletId,
                       let wallet = appState.wallets.first(where: { $0.id == id }) {
                        appState.deleteWallet(wallet)
                    }
                }
            } message: {
                Text("This will permanently delete this wallet from this device. Make sure you have backed up your private key.".localized)
            }
            .sheet(isPresented: $showExportKey) {
                exportKeySheet
            }
            .sheet(item: $selectedTipUSDTWallet) { wallet in
                SendUSDTSheet(wallet: wallet, prefilledRecipient: selectedTipUSDTRecipient)
            }
        }
    }
    
    // MARK: - Wallets
    
    private var walletsSection: some View {
        VStack(alignment: .leading, spacing: CRBTheme.Spacing.md) {
            SectionHeader(title: "Wallets".localized, icon: "wallet.bifold.fill")
            
            ForEach(appState.wallets) { wallet in
                HStack(spacing: CRBTheme.Spacing.md) {
                    // Selected indicator
                    ZStack {
                        Circle()
                            .fill(wallet.id == appState.selectedWallet?.id ? CRBTheme.Colors.cyan : CRBTheme.Colors.cardBorder)
                            .frame(width: 10, height: 10)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(wallet.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(CRBTheme.Colors.ink)
                            .lineLimit(1)
                        
                        Text(AddressValidator.truncatedAddress(wallet.address))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(CRBTheme.Colors.muted)
                    }
                    
                    Spacer()
                    
                    // Actions menu
                    Menu {
                        Button {
                            appState.selectWallet(wallet)
                        } label: {
                            Label("Select".localized, systemImage: "checkmark.circle")
                        }
                        
                        Button {
                            exportWalletId = wallet.id
                            showExportKey = true
                        } label: {
                            Label("Export Private Key".localized, systemImage: "key")
                        }
                        
                        Button {
                            UIPasteboard.general.string = wallet.address
                        } label: {
                            Label("Copy Address".localized, systemImage: "doc.on.doc")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            deleteWalletId = wallet.id
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete Wallet".localized, systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(CRBTheme.Colors.muted)
                            .padding(CRBTheme.Spacing.sm)
                    }
                }
                .padding(CRBTheme.Spacing.md)
                .background(wallet.id == appState.selectedWallet?.id ? CRBTheme.Colors.cyan.opacity(0.05) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
            }
            
            // Add wallet buttons
            HStack(spacing: CRBTheme.Spacing.md) {
                NavigationLink {
                    CreateWalletView()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Create".localized)
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(CRBTheme.Colors.cyan)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, CRBTheme.Spacing.md)
                    .background(CRBTheme.Colors.cyan.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
                }
                
                NavigationLink {
                    ImportWalletView()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Import".localized)
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(CRBTheme.Colors.violet)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, CRBTheme.Spacing.md)
                    .background(CRBTheme.Colors.violet.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
                }
            }
        }
        .glassCard()
    }
    
    // MARK: - Node
    
    private var nodeSection: some View {
        VStack(alignment: .leading, spacing: CRBTheme.Spacing.md) {
            SectionHeader(title: "Node Configuration".localized, icon: "server.rack")
            
            VStack(alignment: .leading, spacing: CRBTheme.Spacing.sm) {
                Text("Node URL".localized)
                    .font(CRBTheme.Typography.caption())
                    .foregroundColor(CRBTheme.Colors.muted)
                
                TextField("https://cereblix.com", text: $nodeURLInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(CRBTheme.Colors.ink)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding(CRBTheme.Spacing.md)
                    .background(CRBTheme.Colors.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: CRBTheme.Radius.md)
                            .stroke(
                                appState.nodeURLError != nil ? CRBTheme.Colors.error.opacity(0.5) :
                                    (appState.nodeURLWarning != nil ? CRBTheme.Colors.warning.opacity(0.5) : CRBTheme.Colors.cardBorder),
                                lineWidth: 1
                            )
                    )
                
                // Inline validation error
                if let error = appState.nodeURLError {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                        Text(error)
                            .font(.system(size: 11))
                    }
                    .foregroundColor(CRBTheme.Colors.error)
                }
                
                // Security warning for non-official nodes
                if let warning = appState.nodeURLWarning {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(CRBTheme.Colors.warning)
                        Text(warning)
                            .font(.system(size: 11))
                            .foregroundColor(CRBTheme.Colors.warning.opacity(0.9))
                    }
                    .padding(CRBTheme.Spacing.sm)
                    .background(CRBTheme.Colors.warning.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
                }
            }
            
            HStack(spacing: CRBTheme.Spacing.md) {
                GradientButton(
                    title: savedNodeURL ? "Success".localized : "Save".localized,
                    icon: savedNodeURL ? "checkmark" : "square.and.arrow.down"
                ) {
                    let url = nodeURLInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Validate URL before saving
                    let result = NodeURLValidator.validate(url)
                    switch result {
                    case .valid:
                        appState.nodeURLError = nil
                        appState.nodeURLWarning = nil
                        appState.nodeBaseURL = url
                        withAnimation { savedNodeURL = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { savedNodeURL = false }
                        }
                    case .validWithWarning(let warning):
                        appState.nodeURLError = nil
                        appState.nodeURLWarning = warning
                        appState.nodeBaseURL = url
                        withAnimation { savedNodeURL = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { savedNodeURL = false }
                        }
                    case .invalid(let error):
                        appState.nodeURLError = error
                        appState.nodeURLWarning = nil
                        // Do NOT save invalid URLs
                    }
                }
                
                GradientButton(title: "Reset".localized, style: .secondary) {
                    nodeURLInput = "https://cereblix.com"
                    appState.nodeBaseURL = "https://cereblix.com"
                    appState.nodeURLError = nil
                    appState.nodeURLWarning = nil
                }
            }
            
            Text("Default: https://cereblix.com\nCustom nodes must use HTTPS for security.")
                .font(.system(size: 11))
                .foregroundColor(CRBTheme.Colors.muted.opacity(0.7))
        }
        .glassCard()
    }
    
    // MARK: - Security
    
    private var securitySection: some View {
        VStack(alignment: .leading, spacing: CRBTheme.Spacing.md) {
            SectionHeader(title: "Security".localized, icon: "lock.shield.fill")
            
            HStack(spacing: CRBTheme.Spacing.md) {
                Image(systemName: "faceid")
                    .font(.system(size: 22))
                    .foregroundColor(CRBTheme.Colors.cyan)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Face ID / Touch ID".localized)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(CRBTheme.Colors.ink)
                    
                    Text(KeychainStore.shared.isBiometricsAvailable() ? "Available and protecting your keys".localized : "Not available on this device".localized)
                        .font(.system(size: 12))
                        .foregroundColor(CRBTheme.Colors.muted)
                }
                
                Spacer()
                
                Circle()
                    .fill(KeychainStore.shared.isBiometricsAvailable() ? CRBTheme.Colors.buyGreen : CRBTheme.Colors.error)
                    .frame(width: 10, height: 10)
            }
            
            Divider().background(CRBTheme.Colors.cardBorder)

            walletPasswordSection

            Divider().background(CRBTheme.Colors.cardBorder)

            VStack(alignment: .leading, spacing: CRBTheme.Spacing.sm) {
                securityItem("Private keys stored in iOS Keychain".localized)
                securityItem("Keys never leave your device".localized)
                securityItem("Transactions require Face ID, with wallet password fallback".localized)
                securityItem("Password fallback keys stay encrypted on this device".localized)
                securityItem("P2P token held in memory only".localized)
                securityItem("No analytics or tracking".localized)
            }
        }
        .glassCard()
    }

    private var walletPasswordSection: some View {
        VStack(alignment: .leading, spacing: CRBTheme.Spacing.md) {
            HStack(spacing: CRBTheme.Spacing.md) {
                Image(systemName: WalletSecurityStore.shared.isPasswordEnabled ? "key.fill" : "key")
                    .font(.system(size: 20))
                    .foregroundColor(WalletSecurityStore.shared.isPasswordEnabled ? CRBTheme.Colors.buyGreen : CRBTheme.Colors.warning)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Wallet Password".localized)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(CRBTheme.Colors.ink)
                    Text(WalletSecurityStore.shared.isPasswordEnabled ? "Enabled as Face ID fallback".localized : "Set a password for Web3-style unlock fallback".localized)
                        .font(.system(size: 12))
                        .foregroundColor(CRBTheme.Colors.muted)
                }

                Spacer()
            }

            SecureField("Password (min 8 characters)".localized, text: $walletPassword)
                .textFieldStyle(.plain)
                .foregroundColor(CRBTheme.Colors.ink)
                .padding(CRBTheme.Spacing.md)
                .background(CRBTheme.Colors.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))

            SecureField("Confirm Password".localized, text: $walletPasswordConfirm)
                .textFieldStyle(.plain)
                .foregroundColor(CRBTheme.Colors.ink)
                .padding(CRBTheme.Spacing.md)
                .background(CRBTheme.Colors.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))

            if let error = walletPasswordError {
                Text(error.localized)
                    .font(CRBTheme.Typography.caption())
                    .foregroundColor(CRBTheme.Colors.error)
            }

            if let success = walletPasswordSuccess {
                Text(success.localized)
                    .font(CRBTheme.Typography.caption())
                    .foregroundColor(CRBTheme.Colors.buyGreen)
            }

            HStack(spacing: CRBTheme.Spacing.md) {
                GradientButton(
                    title: isUpdatingWalletPassword ? "Saving...".localized : "Set Password".localized,
                    icon: "key.fill",
                    isDisabled: isUpdatingWalletPassword || walletPassword.isEmpty || walletPasswordConfirm.isEmpty
                ) {
                    setWalletPassword()
                }

                if WalletSecurityStore.shared.isPasswordEnabled {
                    GradientButton(
                        title: "Disable".localized,
                        icon: "xmark.circle",
                        isDisabled: isUpdatingWalletPassword,
                        style: .secondary
                    ) {
                        disableWalletPassword()
                    }
                }
            }

            if WalletSecurityStore.shared.isPasswordEnabled {
                Button {
                    syncWalletPassword()
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Sync Password with Wallets".localized)
                            .font(.system(size: 13, weight: .bold))
                        Spacer()
                    }
                    .foregroundColor(CRBTheme.Colors.cyan)
                    .padding(CRBTheme.Spacing.md)
                    .background(CRBTheme.Colors.cyan.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
                }
                .disabled(isUpdatingWalletPassword || walletPassword.isEmpty)
            }
        }
    }
    
    private func securityItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: CRBTheme.Spacing.sm) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 11))
                .foregroundColor(CRBTheme.Colors.buyGreen)
                .padding(.top, 2)
            
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(CRBTheme.Colors.muted)
        }
    }

    private func setWalletPassword() {
        walletPasswordError = nil
        walletPasswordSuccess = nil
        let password = walletPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        let confirm = walletPasswordConfirm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard password == confirm else {
            walletPasswordError = "Passwords do not match"
            return
        }

        isUpdatingWalletPassword = true
        Task {
            do {
                try await WalletSecurityStore.shared.setPassword(
                    password,
                    wallets: appState.wallets,
                    usdtWallets: appState.linkedUSDTWallets
                )
                walletPassword = ""
                walletPasswordConfirm = ""
                walletPasswordSuccess = "Wallet password enabled"
            } catch {
                walletPasswordError = error.localizedDescription
            }
            isUpdatingWalletPassword = false
        }
    }

    private func syncWalletPassword() {
        walletPasswordError = nil
        walletPasswordSuccess = nil
        let password = walletPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !password.isEmpty else {
            walletPasswordError = "Enter your wallet password to sync"
            return
        }

        isUpdatingWalletPassword = true
        Task {
            do {
                try await WalletSecurityStore.shared.syncFallbackKeys(
                    wallets: appState.wallets,
                    usdtWallets: appState.linkedUSDTWallets,
                    password: password
                )
                walletPassword = ""
                walletPasswordConfirm = ""
                walletPasswordSuccess = "Wallet password synced"
            } catch {
                walletPasswordError = error.localizedDescription
            }
            isUpdatingWalletPassword = false
        }
    }

    private func disableWalletPassword() {
        WalletSecurityStore.shared.disablePassword(wallets: appState.wallets, usdtWallets: appState.linkedUSDTWallets)
        walletPassword = ""
        walletPasswordConfirm = ""
        walletPasswordError = nil
        walletPasswordSuccess = "Wallet password disabled"
    }

    // MARK: - Currency & Region
    
    private var currencySection: some View {
        VStack(alignment: .leading, spacing: CRBTheme.Spacing.md) {
            SectionHeader(title: "Currency & Region".localized, icon: "dollarsign.circle.fill")
            
            Toggle("Auto Currency by Region".localized, isOn: Binding(
                get: { appState.autoCurrencyByRegion },
                set: { appState.autoCurrencyByRegion = $0 }
            ))
            .toggleStyle(SwitchToggleStyle(tint: CRBTheme.Colors.cyan))
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(CRBTheme.Colors.ink)
            
            if !appState.autoCurrencyByRegion {
                Divider().background(CRBTheme.Colors.cardBorder)
                
                HStack {
                    Text("Manual Currency Override".localized)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(CRBTheme.Colors.ink)
                    
                    Spacer()
                    
                    Picker("", selection: Binding(
                        get: { appState.manualCurrencyOverride },
                        set: { appState.manualCurrencyOverride = $0 }
                    )) {
                        ForEach(CurrencyManager.supportedCurrencies, id: \.self) { code in
                            Text(code).tag(code)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(CRBTheme.Colors.cyan)
                }
            } else {
                Divider().background(CRBTheme.Colors.cardBorder)
                
                HStack {
                    Text("Auto Currency".localized)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(CRBTheme.Colors.ink)
                    Spacer()
                    Text(appState.selectedFiatCurrency)
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(CRBTheme.Colors.cyan)
                }
            }
        }
        .glassCard()
    }
    
    // MARK: - USDT Wallets
    
    private var usdtWalletSection: some View {
        VStack(alignment: .leading, spacing: CRBTheme.Spacing.md) {
            SectionHeader(title: "USDT Wallet Manager".localized, icon: "dollarsign.circle.fill")
            
            Text("Manage, generate, and link your USDT wallets for P2P trading.".localized)
                .font(.system(size: 13))
                .foregroundColor(CRBTheme.Colors.muted)
            
            NavigationLink {
                USDTWalletManagerView()
            } label: {
                HStack {
                    Image(systemName: "wallet.pass.fill")
                    Text("Open USDT Wallet Manager".localized)
                        .fontWeight(.bold)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                }
                .frame(maxWidth: .infinity)
                .padding(CRBTheme.Spacing.md)
                .background(CRBTheme.Colors.cyan.opacity(0.08))
                .foregroundColor(CRBTheme.Colors.cyan)
                .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
            }
        }
        .glassCard()
    }

    private var safeTradeAPISection: some View {
        let settings = SafeTradeAPIService.shared.settings
        return VStack(alignment: .leading, spacing: CRBTheme.Spacing.md) {
            SectionHeader(title: "SafeTrade API".localized, icon: "link.badge.plus")

            Text("Connect SafeTrade API for USDT balances, transfer execution, and P2P payment actions.".localized)
                .font(.system(size: 13))
                .foregroundColor(CRBTheme.Colors.muted)

            HStack {
                Label(settings.isEnabled ? "Connected".localized : "Not Connected".localized, systemImage: settings.isEnabled ? "checkmark.circle.fill" : "xmark.circle")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(settings.isEnabled ? CRBTheme.Colors.success : CRBTheme.Colors.muted)
                Spacer()
                Text(settings.baseURL)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(CRBTheme.Colors.muted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            NavigationLink {
                SafeTradeAPISettingsView()
            } label: {
                HStack {
                    Image(systemName: "key.fill")
                    Text("Configure SafeTrade API".localized)
                        .fontWeight(.bold)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                }
                .frame(maxWidth: .infinity)
                .padding(CRBTheme.Spacing.md)
                .background(CRBTheme.Colors.cyan.opacity(0.08))
                .foregroundColor(CRBTheme.Colors.cyan)
                .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
            }
        }
        .glassCard()
    }

    // MARK: - Support Project

    private var supportProjectSection: some View {
        VStack(alignment: .leading, spacing: CRBTheme.Spacing.md) {
            SectionHeader(title: "Support CRB Hub".localized, icon: "heart.fill")

            Text("Optional App Store tips help support ongoing development. Tips do not unlock features or change wallet functionality.".localized)
                .font(.system(size: 13))
                .foregroundColor(CRBTheme.Colors.muted)
                .multilineTextAlignment(.leading)

            if supportTipStore.isLoading {
                HStack(spacing: CRBTheme.Spacing.sm) {
                    ProgressView()
                        .tint(CRBTheme.Colors.cyan)
                    Text("Loading support options...".localized)
                        .font(.system(size: 13))
                        .foregroundColor(CRBTheme.Colors.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(CRBTheme.Spacing.md)
                .background(CRBTheme.Colors.backgroundSecondary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
            } else if supportTipStore.products.isEmpty {
                Text("Support tips are not available yet.".localized)
                    .font(.system(size: 13))
                    .foregroundColor(CRBTheme.Colors.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(CRBTheme.Spacing.md)
                    .background(CRBTheme.Colors.backgroundSecondary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
            } else {
                VStack(spacing: CRBTheme.Spacing.sm) {
                    ForEach(supportTipStore.products) { product in
                        Button {
                            Task {
                                await supportTipStore.purchase(product)
                            }
                        } label: {
                            HStack(spacing: CRBTheme.Spacing.sm) {
                                Image(systemName: "cup.and.saucer.fill")
                                    .font(.system(size: 14, weight: .bold))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(product.displayName)
                                        .font(.system(size: 13, weight: .bold))
                                    Text(product.description)
                                        .font(.system(size: 11))
                                        .foregroundColor(CRBTheme.Colors.muted)
                                        .lineLimit(2)
                                }
                                Spacer()
                                Text(product.displayPrice)
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                            }
                            .foregroundColor(CRBTheme.Colors.ink)
                            .padding(CRBTheme.Spacing.md)
                            .background(CRBTheme.Colors.backgroundSecondary.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
                        }
                        .buttonStyle(.plain)
                        .disabled(supportTipStore.isPurchasing)
                    }
                }
            }

            if let message = supportTipStore.message {
                Text(message.localized)
                    .font(CRBTheme.Typography.caption())
                    .foregroundColor(CRBTheme.Colors.buyGreen)
            }

            if let error = supportTipStore.errorMessage {
                Text(error)
                    .font(CRBTheme.Typography.caption())
                    .foregroundColor(CRBTheme.Colors.error)
            }
        }
        .glassCard()
    }
    // MARK: - About
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: CRBTheme.Spacing.md) {
            SectionHeader(title: "About".localized, icon: "info.circle")
            
            HStack {
                Spacer()
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                Spacer()
            }
            .padding(.vertical, CRBTheme.Spacing.xs)
            
            HStack(spacing: CRBTheme.Spacing.sm) {
                Text("App Version".localized)
                    .foregroundColor(CRBTheme.Colors.muted)
                    .layoutPriority(1)
                Spacer()
                Text(appVersionText)
                    .foregroundColor(CRBTheme.Colors.ink)
                    .lineLimit(1)
            }
            .font(.system(size: 13))
            
            HStack(spacing: CRBTheme.Spacing.sm) {
                Text("Chain".localized)
                    .foregroundColor(CRBTheme.Colors.muted)
                    .layoutPriority(1)
                Spacer()
                Text("Cereblix (CRB)")
                    .foregroundColor(CRBTheme.Colors.cyan)
                    .lineLimit(1)
            }
            .font(.system(size: 13))
            
            HStack(spacing: CRBTheme.Spacing.sm) {
                Text("Algorithm".localized)
                    .foregroundColor(CRBTheme.Colors.muted)
                    .layoutPriority(1)
                Spacer()
                Text("NeuroMorph (CPU)")
                    .foregroundColor(CRBTheme.Colors.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .font(.system(size: 13))
            
            HStack(spacing: CRBTheme.Spacing.sm) {
                Text("Base Unit".localized)
                    .foregroundColor(CRBTheme.Colors.muted)
                    .layoutPriority(1)
                Spacer()
                Text("1 CRB = 100,000,000 synapses")
                    .foregroundColor(CRBTheme.Colors.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .font(.system(size: 13))
            
            Divider().background(CRBTheme.Colors.cardBorder)
            
            HStack(spacing: CRBTheme.Spacing.sm) {
                Text("Developer".localized)
                    .foregroundColor(CRBTheme.Colors.muted)
                    .layoutPriority(1)
                Spacer()
                Text("Hoang Tuan Nguyen")
                    .foregroundColor(CRBTheme.Colors.ink)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .font(.system(size: 13))
            
            HStack(spacing: CRBTheme.Spacing.sm) {
                Text("Contact".localized)
                    .foregroundColor(CRBTheme.Colors.muted)
                    .layoutPriority(1)
                Spacer()
                Text("nguyenminh044331@gmail.com")
                    .foregroundColor(CRBTheme.Colors.cyan)
                    .font(.system(size: 13, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .truncationMode(.tail)
            }
            .font(.system(size: 13))
            
            HStack(spacing: CRBTheme.Spacing.sm) {
                Text("License".localized)
                    .foregroundColor(CRBTheme.Colors.muted)
                    .layoutPriority(1)
                Spacer()
                Text("MIT License".localized)
                    .foregroundColor(CRBTheme.Colors.ink)
                    .lineLimit(1)
            }
            .font(.system(size: 13))

            Divider().background(CRBTheme.Colors.cardBorder)

            developerDonateSection
            
            Divider().background(CRBTheme.Colors.cardBorder)
            
            Text("CRB Hub is a non-custodial wallet. Your private keys are stored locally on your device and never transmitted to any server. Always backup your private keys.".localized)
                .font(.system(size: 11))
                .foregroundColor(CRBTheme.Colors.muted.opacity(0.7))
        }
        .glassCard()
    }

    private var developerDonateSection: some View {
        VStack(alignment: .leading, spacing: CRBTheme.Spacing.md) {
            HStack(spacing: CRBTheme.Spacing.sm) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(CRBTheme.Colors.buyGreen)
                Text("Donate Tips".localized)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(CRBTheme.Colors.ink)
                Spacer()
            }

            Text("If CRB Hub is useful, you can optionally send a CRB or USDT tip to support development. Tips do not unlock features or change wallet behavior.".localized)
                .font(.system(size: 12))
                .foregroundColor(CRBTheme.Colors.muted)
                .multilineTextAlignment(.leading)

            if DeveloperTipConfig.crbAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                DeveloperTipConfig.configuredUSDTRecipients.isEmpty {
                tipUnavailableView
            } else {
                let crbAddress = DeveloperTipConfig.crbAddress.trimmingCharacters(in: .whitespacesAndNewlines)
                if !crbAddress.isEmpty {
                    cryptoTipCard(
                        asset: "CRB",
                        network: "Cereblix",
                        address: crbAddress,
                        icon: "bitcoinsign.circle.fill",
                        color: CRBTheme.Colors.cyan
                    ) {
                        NavigationLink {
                            SendView(prefilledAddress: crbAddress)
                        } label: {
                            tipActionLabel("Send CRB".localized, icon: "paperplane.fill")
                        }
                        .disabled(!AddressValidator.isValidAddress(crbAddress))
                        .opacity(AddressValidator.isValidAddress(crbAddress) ? 1 : 0.45)
                    }
                }

                ForEach(DeveloperTipConfig.configuredUSDTRecipients, id: \.network) { recipient in
                    cryptoTipCard(
                        asset: "USDT",
                        network: recipient.network.p2pReceiveLabel,
                        address: recipient.address,
                        icon: "dollarsign.circle.fill",
                        color: CRBTheme.Colors.buyGreen
                    ) {
                        usdtTipMenu(network: recipient.network, recipient: recipient.address)
                    }
                }
            }

            if copiedTipAddress != nil {
                Text("Tip address copied.".localized)
                    .font(CRBTheme.Typography.caption())
                    .foregroundColor(CRBTheme.Colors.buyGreen)
            }
        }
    }

    private var tipUnavailableView: some View {
        Text("Crypto tip addresses are not configured yet.".localized)
            .font(.system(size: 12))
            .foregroundColor(CRBTheme.Colors.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(CRBTheme.Spacing.md)
            .background(CRBTheme.Colors.backgroundSecondary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
    }

    private func cryptoTipCard<Action: View>(
        asset: String,
        network: String,
        address: String,
        icon: String,
        color: Color,
        @ViewBuilder action: () -> Action
    ) -> some View {
        VStack(alignment: .leading, spacing: CRBTheme.Spacing.md) {
            HStack(spacing: CRBTheme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(asset)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(CRBTheme.Colors.ink)
                    Text(network.localized)
                        .font(.system(size: 11))
                        .foregroundColor(CRBTheme.Colors.muted)
                }
                Spacer()
                QRCodeView(data: address, size: 56)
            }

            Text(AddressValidator.truncatedAddress(address, leading: 12, trailing: 10))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(CRBTheme.Colors.cyan)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .textSelection(.enabled)

            HStack(spacing: CRBTheme.Spacing.sm) {
                Button {
                    SecurePasteboard.copy(address)
                    copiedTipAddress = address
                } label: {
                    tipActionLabel("Copy".localized, icon: "doc.on.doc")
                }
                .buttonStyle(.plain)

                action()
            }
        }
        .padding(CRBTheme.Spacing.md)
        .background(CRBTheme.Colors.backgroundSecondary.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: CRBTheme.Radius.sm)
                .stroke(CRBTheme.Colors.cardBorder, lineWidth: 1)
        )
    }

    private func tipActionLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CRBTheme.Spacing.sm)
        .padding(.horizontal, CRBTheme.Spacing.sm)
        .background(CRBTheme.Colors.cyan.opacity(0.08))
        .foregroundColor(CRBTheme.Colors.cyan)
        .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
    }

    private func usdtTipMenu(network: USDTNetwork, recipient: String) -> some View {
        let wallets = appState.linkedUSDTWallets.filter { $0.network == network }

        return Menu {
            if wallets.isEmpty {
                Button("No matching USDT wallet".localized) {}
                    .disabled(true)
            } else {
                ForEach(wallets) { wallet in
                    Button {
                        selectedTipUSDTRecipient = recipient
                        selectedTipUSDTWallet = wallet
                    } label: {
                        Text("\(wallet.name) - \(AddressValidator.truncatedAddress(wallet.address, leading: 8, trailing: 6))")
                    }
                }
            }
        } label: {
            tipActionLabel("Send USDT".localized, icon: "paperplane.fill")
        }
        .disabled(wallets.isEmpty)
        .opacity(wallets.isEmpty ? 0.45 : 1)
    }
    
    // MARK: - Export Key Sheet
    
    private var exportKeySheet: some View {
        NavigationStack {
            ZStack {
                CRBTheme.Colors.background.ignoresSafeArea()
                
                VStack(spacing: CRBTheme.Spacing.xl) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(CRBTheme.Colors.warning)
                    
                    Text("Export Private Key".localized)
                        .font(CRBTheme.Typography.title())
                        .foregroundColor(CRBTheme.Colors.ink)
                    
                    Text("Anyone with this key can access your wallet. Never share it.".localized)
                        .font(CRBTheme.Typography.body())
                        .foregroundColor(CRBTheme.Colors.error)
                        .multilineTextAlignment(.center)
                    
                    if let key = exportedKey {
                        Text(key)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(CRBTheme.Colors.error)
                            .textSelection(.enabled)
                            .padding(CRBTheme.Spacing.lg)
                            .background(CRBTheme.Colors.error.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: CRBTheme.Radius.md)
                                    .stroke(CRBTheme.Colors.error.opacity(0.3), lineWidth: 1)
                            )
                    } else {
                        GradientButton(title: "Authenticate to Show Key".localized, icon: "faceid", style: .destructive) {
                            exportKey()
                        }
                    }
                    
                    Spacer()
                }
                .padding(CRBTheme.Spacing.xl)
            }
            .navigationTitle("Export Key".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done".localized) {
                        showExportKey = false
                        exportedKey = nil
                    }
                    .foregroundColor(CRBTheme.Colors.cyan)
                }
            }
        }
    }
    
    private func exportKey() {
        guard let walletId = exportWalletId else { return }
        
        Task {
            do {
                let key = try await KeychainStore.shared.loadPrivateKeySecure(
                    for: walletId,
                    reason: "Authenticate to export your private key"
                )
                exportedKey = key
            } catch {
                // Biometrics failed or key not found
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppState())
}
