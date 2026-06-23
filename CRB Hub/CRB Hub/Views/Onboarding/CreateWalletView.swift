import SwiftUI

struct CreateWalletView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    @State private var walletName = "My Wallet"
    @State private var isCreating = false
    @State private var createdWallet: WalletAccount?
    @State private var privateKeyHex: String?
    @State private var showPrivateKey = false
    @State private var hasBackedUp = false
    @State private var error: String?
    @State private var copiedKey = false
    
    var body: some View {
        ZStack {
            CRBTheme.Colors.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: CRBTheme.Spacing.xl) {
                    if createdWallet == nil {
                        setupSection
                    } else if !hasBackedUp {
                        backupSection
                    } else {
                        completeSection
                    }
                }
                .padding(CRBTheme.Spacing.xl)
            }
        }
        .navigationTitle("Create Wallet".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Setup
    
    private var setupSection: some View {
        VStack(spacing: CRBTheme.Spacing.xl) {
            // Icon
            ZStack {
                Circle()
                    .fill(CRBTheme.Colors.cyan.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "wallet.bifold.fill")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(CRBTheme.Gradients.primary)
            }
            .padding(.top, CRBTheme.Spacing.xl)
            
            Text("Create a New CRB Wallet".localized)
                .font(CRBTheme.Typography.title())
                .foregroundColor(CRBTheme.Colors.ink)
            
            Text("Generate a new ed25519 keypair. Your private key will be stored securely in the iOS Keychain.".localized)
                .font(CRBTheme.Typography.body())
                .foregroundColor(CRBTheme.Colors.muted)
                .multilineTextAlignment(.center)
            
            // Wallet name input
            VStack(alignment: .leading, spacing: CRBTheme.Spacing.sm) {
                Text("Wallet Name".localized)
                    .font(CRBTheme.Typography.caption())
                    .foregroundColor(CRBTheme.Colors.muted)
                
                TextField("My Wallet".localized, text: $walletName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(CRBTheme.Colors.ink)
                    .padding(CRBTheme.Spacing.md)
                    .background(CRBTheme.Colors.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: CRBTheme.Radius.md)
                            .stroke(CRBTheme.Colors.cardBorder, lineWidth: 1)
                    )
            }
            .glassCard()
            
            if let error = error {
                Text(error)
                    .font(CRBTheme.Typography.caption())
                    .foregroundColor(CRBTheme.Colors.error)
                    .padding(CRBTheme.Spacing.md)
            }
            
            GradientButton(
                title: isCreating ? "Creating...".localized : "Generate Wallet".localized,
                icon: "sparkles",
                isDisabled: isCreating || walletName.isEmpty
            ) {
                createWallet()
            }
        }
    }
    
    // MARK: - Backup
    
    private var backupSection: some View {
        VStack(spacing: CRBTheme.Spacing.xl) {
            // Warning banner
            HStack(spacing: CRBTheme.Spacing.md) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(CRBTheme.Colors.warning)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Backup Your Private Key!".localized)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(CRBTheme.Colors.warning)
                    
                    Text("If you lose this key, you lose access to your wallet permanently. No one can recover it.".localized)
                        .font(.system(size: 13))
                        .foregroundColor(CRBTheme.Colors.muted)
                }
            }
            .padding(CRBTheme.Spacing.lg)
            .background(CRBTheme.Colors.warning.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: CRBTheme.Radius.md)
                    .stroke(CRBTheme.Colors.warning.opacity(0.3), lineWidth: 1)
            )
            
            // Address display
            if let wallet = createdWallet {
                VStack(alignment: .leading, spacing: CRBTheme.Spacing.sm) {
                    Text("Your Address".localized)
                        .font(CRBTheme.Typography.caption())
                        .foregroundColor(CRBTheme.Colors.muted)
                    
                    Text(wallet.address)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(CRBTheme.Colors.cyan)
                        .textSelection(.enabled)
                }
                .glassCard()
            }
            
            // Private key display
            VStack(alignment: .leading, spacing: CRBTheme.Spacing.md) {
                HStack {
                    Text("Private Key".localized)
                        .font(CRBTheme.Typography.caption())
                        .foregroundColor(CRBTheme.Colors.muted)
                    
                    Spacer()
                    
                    Button {
                        showPrivateKey.toggle()
                    } label: {
                        Image(systemName: showPrivateKey ? "eye.slash" : "eye")
                            .font(.system(size: 14))
                            .foregroundColor(CRBTheme.Colors.muted)
                    }
                }
                
                if showPrivateKey, let key = privateKeyHex {
                    Text(key)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(CRBTheme.Colors.error)
                        .textSelection(.enabled)
                        .padding(CRBTheme.Spacing.md)
                        .background(CRBTheme.Colors.error.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
                } else {
                    Text("●●●●●●●●●●●●●●●●●●●●")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(CRBTheme.Colors.muted.opacity(0.5))
                }
                
                if showPrivateKey {
                    Button {
                        if let key = privateKeyHex {
                            UIPasteboard.general.string = key
                            copiedKey = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                copiedKey = false
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: copiedKey ? "checkmark" : "doc.on.doc")
                            Text(copiedKey ? "Copied!".localized : "Copy Private Key".localized)
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(copiedKey ? CRBTheme.Colors.success : CRBTheme.Colors.cyan)
                    }
                }
            }
            .glassCard()
            
            // Confirm backup
            GradientButton(
                title: "I Have Backed Up My Key".localized,
                icon: "checkmark.shield.fill"
            ) {
                withAnimation {
                    hasBackedUp = true
                    // Clear the private key from memory
                    privateKeyHex = nil
                }
            }
        }
    }
    
    // MARK: - Complete
    
    private var completeSection: some View {
        VStack(spacing: CRBTheme.Spacing.xl) {
            ZStack {
                Circle()
                    .fill(CRBTheme.Colors.success.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 52))
                    .foregroundColor(CRBTheme.Colors.success)
            }
            .padding(.top, CRBTheme.Spacing.xxl)
            
            Text("Wallet Created!".localized)
                .font(CRBTheme.Typography.title())
                .foregroundColor(CRBTheme.Colors.ink)
            
            if let wallet = createdWallet {
                Text(wallet.address)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(CRBTheme.Colors.cyan)
                    .padding(CRBTheme.Spacing.md)
                    .glassCard(padding: CRBTheme.Spacing.md)
            }
            
            Text("Your wallet is ready. The private key is securely stored in your device's Keychain.".localized)
                .font(CRBTheme.Typography.body())
                .foregroundColor(CRBTheme.Colors.muted)
                .multilineTextAlignment(.center)
            
            GradientButton(title: "Start Using CRB Hub".localized, icon: "arrow.right") {
                dismiss()
            }
        }
    }
    
    // MARK: - Actions
    
    private func createWallet() {
        isCreating = true
        error = nil
        
        do {
            // Generate wallet
            let (privKey, pubKey, address) = WalletCore.generateWallet()
            
            // Save to keychain
            let wallet = WalletAccount(
                address: address,
                publicKeyHex: pubKey,
                name: walletName.isEmpty ? "My Wallet" : walletName
            )
            
            try KeychainStore.shared.savePrivateKey(privKey, for: wallet.id)
            KeychainStore.shared.saveWalletMetadata(wallet)
            
            // Update app state
            appState.wallets.append(wallet)
            appState.selectedWallet = wallet
            appState.hasCompletedOnboarding = true
            
            // Show backup
            createdWallet = wallet
            privateKeyHex = privKey
        } catch {
            self.error = error.localizedDescription
        }
        
        isCreating = false
    }
}

#Preview {
    NavigationStack {
        CreateWalletView()
            .environment(AppState())
    }
}
