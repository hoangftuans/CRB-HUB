import SwiftUI

struct ReceiveView: View {
    @Environment(AppState.self) private var appState
    @State private var copied = false
    
    var address: String {
        appState.selectedWallet?.address ?? ""
    }
    
    var body: some View {
        ZStack {
            CRBTheme.Colors.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: CRBTheme.Spacing.xl) {
                    Spacer().frame(height: CRBTheme.Spacing.lg)
                    
                    // QR Code
                    QRCodeView(data: address, size: 220)
                    
                    // Current rate
                    HStack(spacing: 4) {
                        Text("Price:".localized)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(CRBTheme.Colors.muted)
                        Text("1 CRB")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(CRBTheme.Colors.ink)
                        FiatValueView(baseUnits: 100_000_000, font: .system(size: 14, weight: .bold), color: CRBTheme.Colors.cyan)
                    }
                    
                    // Address
                    VStack(spacing: CRBTheme.Spacing.md) {
                        Text("Receive CRB".localized)
                            .font(CRBTheme.Typography.caption())
                            .foregroundColor(CRBTheme.Colors.muted)
                        
                        Text(address)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(CRBTheme.Colors.cyan)
                            .multilineTextAlignment(.center)
                            .textSelection(.enabled)
                            .padding(CRBTheme.Spacing.lg)
                            .background(CRBTheme.Colors.backgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: CRBTheme.Radius.md)
                                    .stroke(CRBTheme.Colors.cyan.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .glassCard()
                    
                    // Action buttons
                    HStack(spacing: CRBTheme.Spacing.md) {
                        GradientButton(
                            title: copied ? "Copied!".localized : "Copy Address".localized,
                            icon: copied ? "checkmark" : "doc.on.doc"
                        ) {
                            UIPasteboard.general.string = address
                            withAnimation {
                                copied = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation {
                                    copied = false
                                }
                            }
                        }
                        
                        ShareLink(item: address) {
                            HStack(spacing: CRBTheme.Spacing.sm) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 15, weight: .semibold))
                                Text("Share".localized)
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, CRBTheme.Spacing.md)
                            .background(Color.white.opacity(0.08))
                            .foregroundColor(CRBTheme.Colors.ink)
                            .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: CRBTheme.Radius.md)
                                    .stroke(CRBTheme.Colors.cardBorder, lineWidth: 1)
                            )
                        }
                    }
                    
                    // Mining hint
                    HStack(spacing: CRBTheme.Spacing.md) {
                        Image(systemName: "hammer.fill")
                            .font(.system(size: 18))
                            .foregroundColor(CRBTheme.Colors.warning)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Setup Miner".localized)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(CRBTheme.Colors.ink)
                            
                            Text("Use this same address for mining payouts. Go to the Mining tab for setup instructions.".localized)
                                .font(.system(size: 12))
                                .foregroundColor(CRBTheme.Colors.muted)
                        }
                    }
                    .glassCard()
                }
                .padding(CRBTheme.Spacing.xl)
            }
        }
        .navigationTitle("Receive CRB".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ReceiveView()
            .environment(AppState())
    }
}
