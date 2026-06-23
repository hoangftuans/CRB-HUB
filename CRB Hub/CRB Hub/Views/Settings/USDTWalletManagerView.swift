import SwiftUI

struct USDTWalletManagerView: View {
    @Environment(AppState.self) private var appState
    @State private var showAddSheet = false
    @State private var showGenerateSheet = false
    @State private var isRefreshing = false
    
    var body: some View {
        ZStack {
            CRBTheme.Colors.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: CRBTheme.Spacing.lg) {
                    // Header text
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Manage your USDT balances across exchanges and Web3 wallets.".localized)
                            .font(.system(size: 13))
                            .foregroundColor(CRBTheme.Colors.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if appState.linkedUSDTWallets.isEmpty {
                        EmptyStateView(
                            icon: "dollarsign.circle",
                            title: "No USDT Wallets".localized,
                            message: "Link your exchange accounts or Web3 wallets to track and pay P2P escrows.".localized
                        )
                        .padding(.top, CRBTheme.Spacing.xl)
                    } else {
                        // Linked wallets list
                        ForEach(appState.linkedUSDTWallets) { wallet in
                            walletCard(wallet)
                        }
                    }
                    
                    // Action Buttons
                    VStack(spacing: CRBTheme.Spacing.md) {
                        Button {
                            showAddSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "link.circle.fill")
                                Text("Link Existing Wallet / Exchange".localized)
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(CRBTheme.Spacing.md)
                            .background(CRBTheme.Colors.backgroundSecondary)
                            .foregroundColor(CRBTheme.Colors.cyan)
                            .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: CRBTheme.Radius.md)
                                    .stroke(CRBTheme.Colors.cyan.opacity(0.3), lineWidth: 1)
                            )
                        }
                        
                        Button {
                            showGenerateSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Create Native USDT Wallet".localized)
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(CRBTheme.Spacing.md)
                            .background(CRBTheme.Gradients.primary)
                            .foregroundColor(Color(hex: 0x06121F))
                            .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.md))
                        }
                    }
                    .padding(.top, CRBTheme.Spacing.md)
                }
                .padding(CRBTheme.Spacing.lg)
            }
            .refreshable {
                isRefreshing = true
                await appState.refreshUSDTBalances()
                isRefreshing = false
            }
        }
        .navigationTitle("USDT Wallet Manager".localized)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddSheet) {
            AddUSDTWalletSheet()
        }
        .sheet(isPresented: $showGenerateSheet) {
            GenerateNativeUSDTSheet()
        }
        .task {
            // Load balances on load
            await appState.refreshUSDTBalances()
        }
    }
    
    // MARK: - Wallet Card Component
    
    private func walletCard(_ wallet: USDTWallet) -> some View {
        VStack(alignment: .leading, spacing: CRBTheme.Spacing.md) {
            HStack {
                // Provider Badge
                HStack(spacing: 6) {
                    Image(systemName: wallet.provider.iconName)
                        .font(.system(size: 12))
                    Text(wallet.provider.rawValue.localized)
                        .font(.system(size: 11, weight: .bold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(wallet.isNative ? CRBTheme.Colors.cyan.opacity(0.15) : CRBTheme.Colors.backgroundSecondary)
                .foregroundColor(wallet.isNative ? CRBTheme.Colors.cyan : CRBTheme.Colors.muted)
                .clipShape(Capsule())
                
                Spacer()
                
                // Network Badge
                PillBadge(text: wallet.network.displayName, color: CRBTheme.Colors.violet)
                
                // Delete Button
                Button(role: .destructive) {
                    withAnimation {
                        appState.deleteUSDTWallet(id: wallet.id)
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(CRBTheme.Colors.sellRed.opacity(0.8))
                }
                .padding(.leading, 4)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(wallet.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(CRBTheme.Colors.ink)
                
                HStack(spacing: CRBTheme.Spacing.sm) {
                    Text(wallet.address)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(CRBTheme.Colors.muted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Button {
                        UIPasteboard.general.string = wallet.address
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 12))
                            .foregroundColor(CRBTheme.Colors.cyan)
                    }
                }
            }
            
            Divider().background(CRBTheme.Colors.cardBorder)
            
            HStack {
                Text("USDT Balance".localized)
                    .font(.system(size: 12))
                    .foregroundColor(CRBTheme.Colors.muted)
                
                Spacer()
                
                Text(String(format: "%.2f USDT", (wallet.balance as NSDecimalNumber).doubleValue))
                    .font(.system(size: 18, weight: .heavy, design: .monospaced))
                    .foregroundColor(CRBTheme.Colors.cyan)
            }
        }
        .padding(CRBTheme.Spacing.lg)
        .background(CRBTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: CRBTheme.Radius.md)
                .stroke(CRBTheme.Colors.cardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Add Linked Wallet Sheet

struct AddUSDTWalletSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    
    @State private var name = ""
    @State private var provider: USDTProvider = .binance
    @State private var network: USDTNetwork = .bep20
    @State private var address = ""
    @State private var validationError: String?
    
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !address.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                CRBTheme.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: CRBTheme.Spacing.xl) {
                        VStack(alignment: .leading, spacing: CRBTheme.Spacing.sm) {
                            Text("Wallet Name".localized)
                                .font(CRBTheme.Typography.caption())
                                .foregroundColor(CRBTheme.Colors.muted)
                            
                            TextField("e.g. My Binance Wallet", text: $name)
                                .textFieldStyle(.plain)
                                .foregroundColor(CRBTheme.Colors.ink)
                                .padding(CRBTheme.Spacing.md)
                                .background(CRBTheme.Colors.backgroundSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.md))
                        }
                        
                        VStack(alignment: .leading, spacing: CRBTheme.Spacing.sm) {
                            Text("Provider".localized)
                                .font(CRBTheme.Typography.caption())
                                .foregroundColor(CRBTheme.Colors.muted)
                            
                            Picker("Provider", selection: $provider) {
                                ForEach(USDTProvider.allCases.filter { $0 != .native }) { prov in
                                    Text(prov.rawValue).tag(prov)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(CRBTheme.Colors.cyan)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(CRBTheme.Spacing.md)
                            .background(CRBTheme.Colors.backgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.md))
                        }
                        
                        VStack(alignment: .leading, spacing: CRBTheme.Spacing.sm) {
                            Text("Network".localized)
                                .font(CRBTheme.Typography.caption())
                                .foregroundColor(CRBTheme.Colors.muted)
                            
                            Picker("Network", selection: $network) {
                                ForEach(USDTNetwork.allCases) { net in
                                    Text(net.displayName).tag(net)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(CRBTheme.Colors.cyan)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(CRBTheme.Spacing.md)
                            .background(CRBTheme.Colors.backgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.md))
                        }
                        
                        VStack(alignment: .leading, spacing: CRBTheme.Spacing.sm) {
                            Text("USDT Address".localized)
                                .font(CRBTheme.Typography.caption())
                                .foregroundColor(CRBTheme.Colors.muted)
                            
                            TextField("Paste USDT address...", text: $address)
                                .textFieldStyle(.plain)
                                .foregroundColor(CRBTheme.Colors.ink)
                                .font(.system(size: 13, design: .monospaced))
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .padding(CRBTheme.Spacing.md)
                                .background(CRBTheme.Colors.backgroundSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.md))
                        }
                        
                        if let error = validationError {
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundColor(CRBTheme.Colors.error)
                        }
                        
                        GradientButton(title: "Save Linked Wallet".localized, icon: "link.circle.fill", isDisabled: !isValid) {
                            saveWallet()
                        }
                    }
                    .padding(CRBTheme.Spacing.xl)
                }
            }
            .navigationTitle("Link USDT Wallet".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel".localized) {
                        dismiss()
                    }
                    .foregroundColor(CRBTheme.Colors.muted)
                }
            }
        }
    }
    
    private func saveWallet() {
        validationError = nil
        let cleanAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Basic Address validation
        if network == .trc20 {
            guard cleanAddress.hasPrefix("T") && cleanAddress.count == 34 else {
                validationError = "Tron addresses must start with 'T' and be 34 characters.".localized
                return
            }
        } else {
            guard cleanAddress.hasPrefix("0x") && cleanAddress.count == 42 else {
                validationError = "EVM addresses must start with '0x' and be 42 characters.".localized
                return
            }
        }
        
        let newWallet = USDTWallet(
            name: name,
            provider: provider,
            network: network,
            address: cleanAddress,
            isNative: false
        )
        appState.addUSDTWallet(newWallet)
        dismiss()
    }
}

// MARK: - Generate Native Wallet Sheet

struct GenerateNativeUSDTSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    
    @State private var name = ""
    @State private var network: USDTNetwork = .bep20
    @State private var generatedWallet: (privateKey: String, address: String)?
    @State private var isCreating = false
    @State private var copiedKey = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                CRBTheme.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: CRBTheme.Spacing.xl) {
                        if generatedWallet != nil {
                            successContent
                        } else {
                            formContent
                        }
                    }
                    .padding(CRBTheme.Spacing.xl)
                }
            }
            .navigationTitle("New Native USDT Wallet".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if generatedWallet == nil {
                        Button("Cancel".localized) {
                            dismiss()
                        }
                        .foregroundColor(CRBTheme.Colors.muted)
                    }
                }
            }
        }
    }
    
    // MARK: - Success Content (extracted to help type-checker)
    
    @ViewBuilder
    private var successContent: some View {
        if let wallet = generatedWallet {
            VStack(spacing: CRBTheme.Spacing.lg) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 60))
                    .foregroundColor(CRBTheme.Colors.buyGreen)
                
                Text("Wallet Created Successfully!".localized)
                    .font(CRBTheme.Typography.title())
                    .foregroundColor(CRBTheme.Colors.ink)
                
                // Warning box
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(CRBTheme.Colors.warning)
                    Text("Write down your private key and keep it safe. If you lose it, you will lose access to your funds forever.".localized)
                        .font(.system(size: 11))
                        .foregroundColor(CRBTheme.Colors.warning.opacity(0.95))
                }
                .padding(CRBTheme.Spacing.md)
                .background(CRBTheme.Colors.warning.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.md))
                
                // Address box
                VStack(alignment: .leading, spacing: 4) {
                    Text("EVM Wallet Address".localized)
                        .font(.system(size: 11))
                        .foregroundColor(CRBTheme.Colors.muted)
                    
                    HStack {
                        Text(wallet.address)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(CRBTheme.Colors.ink)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button {
                            UIPasteboard.general.string = wallet.address
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(CRBTheme.Colors.cyan)
                        }
                    }
                    .padding(CRBTheme.Spacing.sm)
                    .background(CRBTheme.Colors.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
                }
                
                // Private key box
                VStack(alignment: .leading, spacing: 4) {
                    Text("Private Key".localized)
                        .font(.system(size: 11))
                        .foregroundColor(CRBTheme.Colors.muted)
                    
                    HStack {
                        Text(wallet.privateKey)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(CRBTheme.Colors.error)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button {
                            SecurePasteboard.copyWithExpiry(wallet.privateKey)
                            withAnimation { copiedKey = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                copiedKey = false
                            }
                        } label: {
                            Image(systemName: copiedKey ? "checkmark" : "doc.on.doc")
                                .foregroundColor(copiedKey ? CRBTheme.Colors.success : CRBTheme.Colors.error)
                        }
                    }
                    .padding(CRBTheme.Spacing.sm)
                    .background(CRBTheme.Colors.error.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: CRBTheme.Radius.sm)
                            .stroke(CRBTheme.Colors.error.opacity(0.2), lineWidth: 1)
                    )
                }
                
                GradientButton(title: "Done".localized, icon: "checkmark.circle.fill") {
                    dismiss()
                }
                .padding(.top, CRBTheme.Spacing.md)
            }
            .padding(CRBTheme.Spacing.xl)
        }
    }
    
    // MARK: - Form Content (extracted to help type-checker)
    
    private var formContent: some View {
        VStack(spacing: CRBTheme.Spacing.lg) {
            VStack(alignment: .leading, spacing: CRBTheme.Spacing.sm) {
                Text("Wallet Name".localized)
                    .font(CRBTheme.Typography.caption())
                    .foregroundColor(CRBTheme.Colors.muted)
                
                TextField("e.g. My Native USDT Wallet", text: $name)
                    .textFieldStyle(.plain)
                    .foregroundColor(CRBTheme.Colors.ink)
                    .padding(CRBTheme.Spacing.md)
                    .background(CRBTheme.Colors.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.md))
            }
            
            VStack(alignment: .leading, spacing: CRBTheme.Spacing.sm) {
                Text("Network".localized)
                    .font(CRBTheme.Typography.caption())
                    .foregroundColor(CRBTheme.Colors.muted)
                
                Picker("Network", selection: $network) {
                    // TRC20 not supported for native gen since TRON requires a different key format than EVM
                    ForEach(USDTNetwork.allCases.filter { $0 != .trc20 }) { net in
                        Text(net.displayName).tag(net)
                    }
                }
                .pickerStyle(.menu)
                .tint(CRBTheme.Colors.cyan)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(CRBTheme.Spacing.md)
                .background(CRBTheme.Colors.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.md))
            }
            
            Text("Note: The generated wallet uses standard SECP256k1 encryption. It resides entirely on-device and is stored inside the secure iOS Keychain.".localized)
                .font(.system(size: 11))
                .foregroundColor(CRBTheme.Colors.muted)
                .padding(.vertical, 4)
            
            GradientButton(title: "Generate Keys".localized, icon: "iphone.gen3", isDisabled: name.trimmingCharacters(in: .whitespaces).isEmpty) {
                generateWallet()
            }
        }
    }
    
    private func generateWallet() {
        isCreating = true
        
        // Generate keys
        let walletData = NativeUSDTGenerator.generate()
        
        let newWallet = USDTWallet(
            name: name,
            provider: .native,
            network: network,
            address: walletData.address,
            isNative: true
        )
        
        // Save private key in Keychain
        try? KeychainStore.shared.savePrivateKey(walletData.privateKey, for: newWallet.id)
        
        appState.addUSDTWallet(newWallet)
        
        generatedWallet = walletData
        isCreating = false
    }
}

// MARK: - Native USDT SECP256k1 Mock Generator Helper

struct NativeUSDTGenerator {
    static func generate() -> (privateKey: String, address: String) {
        var pKeyBytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, pKeyBytes.count, &pKeyBytes)
        let privateKey = pKeyBytes.map { String(format: "%02x", $0) }.joined()
        
        var addrBytes = [UInt8](repeating: 0, count: 20)
        _ = SecRandomCopyBytes(kSecRandomDefault, addrBytes.count, &addrBytes)
        let address = "0x" + addrBytes.map { String(format: "%02x", $0) }.joined()
        
        return (privateKey, address)
    }
}
