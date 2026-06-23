import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var showCreateWallet = false
    @State private var showImportWallet = false
    @State private var pulseAnimation = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                CRBTheme.Colors.background.ignoresSafeArea()
                
                // Background glow effects
                Circle()
                    .fill(CRBTheme.Colors.cyan.opacity(0.08))
                    .frame(width: 400, height: 400)
                    .blur(radius: 80)
                    .offset(x: 120, y: -200)
                
                Circle()
                    .fill(CRBTheme.Colors.violet.opacity(0.08))
                    .frame(width: 350, height: 350)
                    .blur(radius: 70)
                    .offset(x: -100, y: 100)
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Logo area
                    ZStack {
                        Circle()
                            .fill(CRBTheme.Colors.cyan.opacity(0.1))
                            .frame(width: 140, height: 140)
                            .scaleEffect(pulseAnimation ? 1.15 : 1.0)
                            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: pulseAnimation)
                        
                        Circle()
                            .fill(CRBTheme.Colors.violet.opacity(0.08))
                            .frame(width: 110, height: 110)
                        
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 52, weight: .light))
                            .foregroundStyle(CRBTheme.Gradients.primary)
                    }
                    .onAppear { pulseAnimation = true }
                    
                    Spacer().frame(height: 32)
                    
                    // Title
                    Text("CRB Hub")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .gradientText()
                    
                    Text("Cereblix Wallet")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(CRBTheme.Colors.muted)
                        .padding(.top, 4)
                    
                    Spacer().frame(height: 16)
                    
                    // Description
                    Text("Non-custodial CRB wallet.\nYour keys, your crypto.".localized)
                        .font(.system(size: 15))
                        .foregroundColor(CRBTheme.Colors.muted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                    
                    Spacer()
                    
                    // Action buttons
                    VStack(spacing: CRBTheme.Spacing.md) {
                        GradientButton(
                            title: "Create New Wallet".localized,
                            icon: "plus.circle.fill"
                        ) {
                            showCreateWallet = true
                        }
                        
                        GradientButton(
                            title: "Import Wallet".localized,
                            icon: "square.and.arrow.down",
                            style: .secondary
                        ) {
                            showImportWallet = true
                        }
                    }
                    .padding(.horizontal, CRBTheme.Spacing.xl)
                    
                    Spacer().frame(height: 20)
                    
                    // Security note
                    HStack(spacing: 6) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 12))
                        Text("Private keys stored in iOS Keychain".localized)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(CRBTheme.Colors.muted.opacity(0.7))
                    .padding(.bottom, CRBTheme.Spacing.xxl)
                }
            }
            .navigationDestination(isPresented: $showCreateWallet) {
                CreateWalletView()
            }
            .navigationDestination(isPresented: $showImportWallet) {
                ImportWalletView()
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environment(AppState())
}
