import SwiftUI

struct BackupWarningView: View {
    @Environment(\.dismiss) private var dismiss
    let privateKeyHex: String
    let onConfirm: () -> Void
    
    @State private var showKey = false
    @State private var copiedKey = false
    @State private var confirmedBackup = false
    @State private var confirmedUnderstand = false
    
    var body: some View {
        ZStack {
            CRBTheme.Colors.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: CRBTheme.Spacing.xl) {
                    // Warning header
                    VStack(spacing: CRBTheme.Spacing.md) {
                        Image(systemName: "exclamationmark.shield.fill")
                            .font(.system(size: 56, weight: .light))
                            .foregroundColor(CRBTheme.Colors.warning)
                        
                        Text("Backup Your Key".localized)
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundColor(CRBTheme.Colors.ink)
                        
                        Text("This is the ONLY way to recover your wallet".localized)
                            .font(CRBTheme.Typography.body())
                            .foregroundColor(CRBTheme.Colors.error)
                    }
                    .padding(.top, CRBTheme.Spacing.xl)
                    
                    // Warning cards
                    warningCard(
                        icon: "xmark.octagon.fill",
                        title: "No Recovery Without Key",
                        message: "If you lose your private key, your CRB is gone forever. No one can recover it — not even us.",
                        color: CRBTheme.Colors.error
                    )
                    
                    warningCard(
                        icon: "eye.slash.fill",
                        title: "Keep It Secret",
                        message: "Never share your private key. Anyone with this key has full access to your wallet.",
                        color: CRBTheme.Colors.warning
                    )
                    
                    warningCard(
                        icon: "doc.text.fill",
                        title: "Write It Down",
                        message: "Copy it to a secure offline location. Don't screenshot it or save it in cloud storage.",
                        color: CRBTheme.Colors.info
                    )
                    
                    // Private key reveal
                    VStack(alignment: .leading, spacing: CRBTheme.Spacing.md) {
                        HStack {
                            Text("Your Private Key".localized)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(CRBTheme.Colors.ink)
                            
                            Spacer()
                            
                            Button {
                                withAnimation { showKey.toggle() }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: showKey ? "eye.slash" : "eye")
                                    Text(showKey ? "Hide".localized : "Reveal".localized)
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(CRBTheme.Colors.cyan)
                            }
                        }
                        
                        if showKey {
                            Text(privateKeyHex)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(CRBTheme.Colors.warning)
                                .textSelection(.enabled)
                                .padding(CRBTheme.Spacing.md)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(CRBTheme.Colors.warning.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
                                .overlay(
                                    RoundedRectangle(cornerRadius: CRBTheme.Radius.sm)
                                        .stroke(CRBTheme.Colors.warning.opacity(0.2), lineWidth: 1)
                                )
                            
                            Button {
                                UIPasteboard.general.string = privateKeyHex
                                withAnimation { copiedKey = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation { copiedKey = false }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: copiedKey ? "checkmark" : "doc.on.doc")
                                    Text(copiedKey ? "Copied to clipboard!".localized : "Copy Private Key".localized)
                                }
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(copiedKey ? CRBTheme.Colors.success : CRBTheme.Colors.cyan)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, CRBTheme.Spacing.sm)
                                .background(CRBTheme.Colors.cyan.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
                            }
                        } else {
                            Text("●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(CRBTheme.Colors.muted.opacity(0.3))
                                .padding(CRBTheme.Spacing.md)
                        }
                    }
                    .glassCard()
                    
                    // Confirmation checkboxes
                    VStack(alignment: .leading, spacing: CRBTheme.Spacing.md) {
                        confirmToggle(
                            isOn: $confirmedBackup,
                            text: "I have safely backed up my private key"
                        )
                        
                        confirmToggle(
                            isOn: $confirmedUnderstand,
                            text: "I understand that losing this key means losing my CRB forever"
                        )
                    }
                    .glassCard()
                    
                    // Continue button
                    GradientButton(
                        title: "Continue to Wallet".localized,
                        icon: "arrow.right.circle.fill",
                        isDisabled: !confirmedBackup || !confirmedUnderstand
                    ) {
                        onConfirm()
                    }
                }
                .padding(CRBTheme.Spacing.xl)
            }
        }
        .navigationTitle("Backup".localized)
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled()
    }
    
    private func warningCard(icon: String, title: String, message: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: CRBTheme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(color)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title.localized)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(CRBTheme.Colors.ink)
                
                Text(message.localized)
                    .font(.system(size: 13))
                    .foregroundColor(CRBTheme.Colors.muted)
            }
        }
        .padding(CRBTheme.Spacing.lg)
        .background(color.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: CRBTheme.Radius.md)
                .stroke(color.opacity(0.15), lineWidth: 1)
        )
    }
    
    private func confirmToggle(isOn: Binding<Bool>, text: String) -> some View {
        Button {
            withAnimation { isOn.wrappedValue.toggle() }
        } label: {
            HStack(alignment: .top, spacing: CRBTheme.Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isOn.wrappedValue ? CRBTheme.Colors.cyan : CRBTheme.Colors.cardBorder, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    
                    if isOn.wrappedValue {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(CRBTheme.Colors.cyan)
                            .frame(width: 22, height: 22)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(hex: 0x06121F))
                    }
                }
                
                Text(text.localized)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(CRBTheme.Colors.ink)
                    .multilineTextAlignment(.leading)
            }
        }
    }
}

#Preview {
    NavigationStack {
        BackupWarningView(privateKeyHex: "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2") {
            print("Confirmed!")
        }
    }
}
