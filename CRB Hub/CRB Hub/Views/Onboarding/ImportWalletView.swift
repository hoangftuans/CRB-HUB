import SwiftUI

struct ImportWalletView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    @State private var walletName = "Imported Wallet"
    @State private var privateKeyInput = ""
    @State private var isImporting = false
    @State private var error: String?
    @State private var previewAddress: String?
    
    var body: some View {
        ZStack {
            CRBTheme.Colors.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: CRBTheme.Spacing.xl) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(CRBTheme.Colors.violet.opacity(0.1))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "square.and.arrow.down.fill")
                            .font(.system(size: 36, weight: .light))
                            .foregroundStyle(CRBTheme.Gradients.primary)
                    }
                    .padding(.top, CRBTheme.Spacing.xl)
                    
                    Text("Import Wallet".localized)
                        .font(CRBTheme.Typography.title())
                        .foregroundColor(CRBTheme.Colors.ink)
                    
                    Text("Enter your ed25519 private key (64 hex characters / 32 bytes)".localized)
                        .font(CRBTheme.Typography.body())
                        .foregroundColor(CRBTheme.Colors.muted)
                        .multilineTextAlignment(.center)
                    
                    // Wallet name
                    VStack(alignment: .leading, spacing: CRBTheme.Spacing.sm) {
                        Text("Wallet Name".localized)
                            .font(CRBTheme.Typography.caption())
                            .foregroundColor(CRBTheme.Colors.muted)
                        
                        TextField("Imported Wallet".localized, text: $walletName)
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
                    
                    // Private key input
                    VStack(alignment: .leading, spacing: CRBTheme.Spacing.sm) {
                        HStack {
                            Text("Private Key (hex)".localized)
                                .font(CRBTheme.Typography.caption())
                                .foregroundColor(CRBTheme.Colors.muted)
                            
                            Spacer()
                            
                            Button {
                                if let pasted = UIPasteboard.general.string {
                                    privateKeyInput = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
                                    validateKey()
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "doc.on.clipboard")
                                    Text("Paste".localized)
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(CRBTheme.Colors.cyan)
                            }
                        }
                        
                        TextField("64 hex characters...".localized, text: $privateKeyInput, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(CRBTheme.Colors.ink)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .lineLimit(3...5)
                            .padding(CRBTheme.Spacing.md)
                            .background(CRBTheme.Colors.backgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: CRBTheme.Radius.md)
                                    .stroke(
                                        privateKeyInput.isEmpty ? CRBTheme.Colors.cardBorder :
                                            (previewAddress != nil ? CRBTheme.Colors.success.opacity(0.5) : CRBTheme.Colors.error.opacity(0.5)),
                                        lineWidth: 1
                                    )
                            )
                            .onChange(of: privateKeyInput) { _, _ in
                                validateKey()
                            }
                        
                        // Character count
                        Text(String(format: "%1$d/64 characters".localized, privateKeyInput.count))
                            .font(.system(size: 11))
                            .foregroundColor(privateKeyInput.count == 64 ? CRBTheme.Colors.success : CRBTheme.Colors.muted)
                    }
                    .glassCard()
                    
                    // Preview address
                    if let address = previewAddress {
                        VStack(alignment: .leading, spacing: CRBTheme.Spacing.sm) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(CRBTheme.Colors.success)
                                Text("Derived Address".localized)
                                    .font(CRBTheme.Typography.caption())
                                    .foregroundColor(CRBTheme.Colors.success)
                            }
                            
                            Text(address)
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundColor(CRBTheme.Colors.cyan)
                                .textSelection(.enabled)
                        }
                        .glassCard()
                    }
                    
                    if let error = error {
                        Text(error)
                            .font(CRBTheme.Typography.caption())
                            .foregroundColor(CRBTheme.Colors.error)
                            .padding(CRBTheme.Spacing.md)
                    }
                    
                    GradientButton(
                        title: isImporting ? "Importing...".localized : "Import Wallet".localized,
                        icon: "checkmark.circle.fill",
                        isDisabled: isImporting || previewAddress == nil || walletName.isEmpty
                    ) {
                        importWallet()
                    }
                    
                    // Security note
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11))
                        Text("Your key is stored locally and never sent to any server".localized)
                            .font(.system(size: 11))
                    }
                    .foregroundColor(CRBTheme.Colors.muted.opacity(0.6))
                }
                .padding(CRBTheme.Spacing.xl)
            }
        }
        .navigationTitle("Import Wallet".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func validateKey() {
        let clean = privateKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        error = nil
        previewAddress = nil
        
        guard clean.count == 64 else { return }
        
        do {
            let (_, address) = try WalletCore.importWallet(privateKeyHex: clean)
            previewAddress = address
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    private func importWallet() {
        isImporting = true
        error = nil
        
        do {
            try appState.importWallet(
                name: walletName.isEmpty ? "Imported Wallet" : walletName,
                privateKeyHex: privateKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            )
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        
        isImporting = false
    }
}

#Preview {
    NavigationStack {
        ImportWalletView()
            .environment(AppState())
    }
}
