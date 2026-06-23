import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var showExportKey = false
    @State private var exportWalletId: UUID?
    @State private var exportedKey: String?
    @State private var showDeleteConfirm = false
    @State private var deleteWalletId: UUID?
    @State private var nodeURLInput = ""
    @State private var savedNodeURL = false
    @State private var copiedDonationAddress = false
    
    // Địa chỉ ví nhận donate
    private let donationAddress = "crb1bcf10b1d12f028f8a3583010c1be8f228360727b"
    
    var body: some View {
        NavigationStack {
            ZStack {
                CRBTheme.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: CRBTheme.Spacing.xl) {
                        // Wallets
                        walletsSection
                        
                        // Node configuration
                        nodeSection
                        
                        // Security
                        securitySection
                        
                        // Currency & Region
                        currencySection
                        
                        // Support Developer
                        donateSection
                        
                        // About
                        aboutSection
                    }
                    .padding(CRBTheme.Spacing.lg)
                }
            }
            .navigationTitle("Settings".localized)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                nodeURLInput = appState.nodeBaseURL
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
                            .stroke(CRBTheme.Colors.cardBorder, lineWidth: 1)
                    )
            }
            
            HStack(spacing: CRBTheme.Spacing.md) {
                GradientButton(
                    title: savedNodeURL ? "Success".localized : "Save".localized,
                    icon: savedNodeURL ? "checkmark" : "square.and.arrow.down"
                ) {
                    let url = nodeURLInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !url.isEmpty {
                        appState.nodeBaseURL = url
                        withAnimation { savedNodeURL = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { savedNodeURL = false }
                        }
                    }
                }
                
                GradientButton(title: "Reset".localized, style: .secondary) {
                    nodeURLInput = "https://cereblix.com"
                    appState.nodeBaseURL = "https://cereblix.com"
                }
            }
            
            Text("Default: https://cereblix.com\nYou can run your own node at http://NODE_IP:18751")
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
            
            VStack(alignment: .leading, spacing: CRBTheme.Spacing.sm) {
                securityItem("Private keys stored in iOS Keychain".localized)
                securityItem("Keys never leave your device".localized)
                securityItem("kSecAttrAccessibleWhenUnlockedThisDeviceOnly".localized)
                securityItem("P2P token held in memory only".localized)
                securityItem("No analytics or tracking".localized)
            }
        }
        .glassCard()
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
    
    // MARK: - Support Developer
    
    private var donateSection: some View {
        VStack(alignment: .leading, spacing: CRBTheme.Spacing.md) {
            SectionHeader(title: "Support Developer".localized, icon: "heart.fill")
            
            Text("If you find CRB Hub helpful, please consider supporting the developer by donating some CRB.".localized)
                .font(.system(size: 13))
                .foregroundColor(CRBTheme.Colors.muted)
                .multilineTextAlignment(.leading)
            
            HStack(spacing: CRBTheme.Spacing.md) {
                Text(AddressValidator.truncatedAddress(donationAddress))
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(CRBTheme.Colors.cyan)
                
                Spacer()
                
                Button {
                    UIPasteboard.general.string = donationAddress
                    withAnimation { copiedDonationAddress = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { copiedDonationAddress = false }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copiedDonationAddress ? "checkmark" : "doc.on.doc")
                        Text(copiedDonationAddress ? "Copied!".localized : "Copy".localized)
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(copiedDonationAddress ? CRBTheme.Colors.success : CRBTheme.Colors.cyan)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(copiedDonationAddress ? CRBTheme.Colors.success.opacity(0.1) : CRBTheme.Colors.cyan.opacity(0.1))
                    .clipShape(Capsule())
                }
                
                NavigationLink {
                    SendView(prefilledAddress: donationAddress)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "paperplane.fill")
                        Text("Send".localized)
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: 0x06121F))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(CRBTheme.Colors.cyan)
                    .clipShape(Capsule())
                }
            }
            .padding(CRBTheme.Spacing.sm)
            .background(CRBTheme.Colors.backgroundSecondary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
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
            
            HStack {
                Text("App Version".localized)
                    .foregroundColor(CRBTheme.Colors.muted)
                Spacer()
                Text("1.0.0")
                    .foregroundColor(CRBTheme.Colors.ink)
            }
            .font(.system(size: 13))
            
            HStack {
                Text("Chain".localized)
                    .foregroundColor(CRBTheme.Colors.muted)
                Spacer()
                Text("Cereblix (CRB)")
                    .foregroundColor(CRBTheme.Colors.cyan)
            }
            .font(.system(size: 13))
            
            HStack {
                Text("Algorithm".localized)
                    .foregroundColor(CRBTheme.Colors.muted)
                Spacer()
                Text("NeuroMorph (CPU)")
                    .foregroundColor(CRBTheme.Colors.ink)
            }
            .font(.system(size: 13))
            
            HStack {
                Text("Base Unit".localized)
                    .foregroundColor(CRBTheme.Colors.muted)
                Spacer()
                Text("1 CRB = 100,000,000 synapses")
                    .foregroundColor(CRBTheme.Colors.ink)
            }
            .font(.system(size: 13))
            
            Divider().background(CRBTheme.Colors.cardBorder)
            
            HStack {
                Text("Developer".localized)
                    .foregroundColor(CRBTheme.Colors.muted)
                Spacer()
                Text("Hoang Tuan Nguyen")
                    .foregroundColor(CRBTheme.Colors.ink)
                    .fontWeight(.semibold)
            }
            .font(.system(size: 13))
            
            HStack {
                Text("Contact".localized)
                    .foregroundColor(CRBTheme.Colors.muted)
                Spacer()
                Text("nguyenminh044331@gmail.com")
                    .foregroundColor(CRBTheme.Colors.cyan)
                    .font(.system(size: 13, design: .monospaced))
            }
            .font(.system(size: 13))
            
            HStack {
                Text("License".localized)
                    .foregroundColor(CRBTheme.Colors.muted)
                Spacer()
                Text("MIT License".localized)
                    .foregroundColor(CRBTheme.Colors.ink)
            }
            .font(.system(size: 13))
            
            Divider().background(CRBTheme.Colors.cardBorder)
            
            Text("CRB Hub is a non-custodial wallet. Your private keys are stored locally on your device and never transmitted to any server. Always backup your private keys.".localized)
                .font(.system(size: 11))
                .foregroundColor(CRBTheme.Colors.muted.opacity(0.7))
        }
        .glassCard()
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
                let key = try await KeychainStore.shared.loadPrivateKeyWithBiometrics(for: walletId)
                exportedKey = key
            } catch {
                // Biometrics failed
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppState())
}
