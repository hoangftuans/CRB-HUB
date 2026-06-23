import SwiftUI

struct P2PLoginView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = P2PViewModel()
    
    var body: some View {
        ZStack {
            CRBTheme.Colors.background.ignoresSafeArea()
            
            VStack(spacing: CRBTheme.Spacing.xl) {
                Spacer()
                
                // Icon
                ZStack {
                    Circle()
                        .fill(CRBTheme.Colors.cyan.opacity(0.1))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "person.badge.key.fill")
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(CRBTheme.Gradients.primary)
                }
                
                Text("LOGIN".localized)
                    .font(CRBTheme.Typography.title())
                    .foregroundColor(CRBTheme.Colors.ink)
                
                Text("To access P2P trading, please sign the security challenge with your active wallet.".localized)
                    .font(CRBTheme.Typography.body())
                    .foregroundColor(CRBTheme.Colors.muted)
                    .multilineTextAlignment(.center)
                
                // Wallet info
                if let wallet = appState.selectedWallet {
                    VStack(spacing: CRBTheme.Spacing.sm) {
                        Text(wallet.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(CRBTheme.Colors.ink)
                        
                        Text(AddressValidator.truncatedAddress(wallet.address))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(CRBTheme.Colors.cyan)
                    }
                    .glassCard()
                }
                
                // How it works
                VStack(alignment: .leading, spacing: CRBTheme.Spacing.md) {
                    Text("How it works:".localized)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(CRBTheme.Colors.muted)
                    
                    stepRow(1, "Request a challenge nonce from the server".localized)
                    stepRow(2, "Sign the challenge with your ed25519 key".localized)
                    stepRow(3, "Send signature to get a session token".localized)
                    stepRow(4, "Token is held in memory only — no persistence".localized)
                }
                .glassCard()
                
                if let error = viewModel.loginError {
                    Text(error.localized)
                        .font(CRBTheme.Typography.caption())
                        .foregroundColor(CRBTheme.Colors.error)
                        .padding(CRBTheme.Spacing.md)
                }
                
                Spacer()
                
                GradientButton(
                    title: viewModel.isLoggingIn ? "Authenticating...".localized : "Login with Wallet".localized,
                    icon: "signature",
                    isDisabled: viewModel.isLoggingIn || appState.selectedWallet == nil
                ) {
                    Task {
                        await viewModel.login(appState: appState)
                        if appState.isP2PLoggedIn {
                            dismiss()
                        }
                    }
                }
                
                Text("Keys never leave your device".localized)
                    .font(.system(size: 11))
                    .foregroundColor(CRBTheme.Colors.muted.opacity(0.6))
                    .padding(.bottom, CRBTheme.Spacing.xl)
            }
            .padding(CRBTheme.Spacing.xl)
        }
        .navigationTitle("LOGIN".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func stepRow(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: CRBTheme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(CRBTheme.Colors.cyan.opacity(0.15))
                    .frame(width: 24, height: 24)
                
                Text("\(number)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(CRBTheme.Colors.cyan)
            }
            
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(CRBTheme.Colors.muted)
        }
    }
}

#Preview {
    NavigationStack {
        P2PLoginView()
            .environment(AppState())
    }
}
