import SwiftUI

struct SafeTradeAPISettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var isEnabled = false
    @State private var baseURL = ""
    @State private var apiKey = ""
    @State private var apiSecret = ""
    @State private var statusPath = ""
    @State private var balancePath = ""
    @State private var transferPath = ""
    @State private var p2pPath = ""
    @State private var isTesting = false
    @State private var message: String?
    @State private var error: String?

    var body: some View {
        ZStack {
            CRBTheme.Colors.background.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: CRBTheme.Spacing.lg) {
                    headerCard
                    credentialCard
                    endpointCard
                    statusCard
                    actionButtons
                }
                .padding(CRBTheme.Spacing.xl)
            }
        }
        .navigationTitle("SafeTrade API".localized)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            load()
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: CRBTheme.Spacing.sm) {
            Toggle(isOn: $isEnabled) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Enable SafeTrade API".localized)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(CRBTheme.Colors.ink)
                    Text("Use SafeTrade for USDT balances, transfers, and P2P payment actions when connected.".localized)
                        .font(.system(size: 12))
                        .foregroundColor(CRBTheme.Colors.muted)
                }
            }
            .tint(CRBTheme.Colors.cyan)
        }
        .glassCard()
    }

    private var credentialCard: some View {
        VStack(alignment: .leading, spacing: CRBTheme.Spacing.md) {
            SectionHeader(title: "Credentials".localized, icon: "key.fill")
            input("Base URL".localized, text: $baseURL, placeholder: "https://safe.trade/api/v2", keyboard: .URL)
            input("API Key".localized, text: $apiKey, placeholder: "SafeTrade API key", keyboard: .default)

            VStack(alignment: .leading, spacing: CRBTheme.Spacing.xs) {
                Text("API Secret".localized)
                    .font(CRBTheme.Typography.caption())
                    .foregroundColor(CRBTheme.Colors.muted)
                SecureField("Leave blank to keep existing secret".localized, text: $apiSecret)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(CRBTheme.Colors.ink)
                    .padding(CRBTheme.Spacing.md)
                    .background(CRBTheme.Colors.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
            }
        }
        .glassCard()
    }

    private var endpointCard: some View {
        VStack(alignment: .leading, spacing: CRBTheme.Spacing.md) {
            SectionHeader(title: "Endpoints".localized, icon: "point.3.connected.trianglepath.dotted")
            input("Status Path".localized, text: $statusPath, placeholder: "status", keyboard: .URL)
            input("Balance Path".localized, text: $balancePath, placeholder: "trade/account/balances/spot", keyboard: .URL)
            input("Transfer Path".localized, text: $transferPath, placeholder: "trade/account/withdraws", keyboard: .URL)
            input("P2P Path".localized, text: $p2pPath, placeholder: "trade/market/orders", keyboard: .URL)
        }
        .glassCard()
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: CRBTheme.Spacing.sm) {
            if let message {
                Label(message, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(CRBTheme.Colors.success)
            }

            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(CRBTheme.Colors.error)
            }

            Text("SafeTrade credentials are stored in iOS Keychain. The API secret is protected by Face ID before SafeTrade requests are signed.".localized)
                .font(.system(size: 11))
                .foregroundColor(CRBTheme.Colors.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var actionButtons: some View {
        VStack(spacing: CRBTheme.Spacing.md) {
            GradientButton(
                title: isTesting ? "Testing...".localized : "Save & Test".localized,
                icon: "network",
                isDisabled: isTesting || apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ) {
                Task {
                    await saveAndTest()
                }
            }

            Button(role: .destructive) {
                SafeTradeAPIService.shared.disconnect()
                load()
                message = nil
                error = "SafeTrade API disconnected.".localized
            } label: {
                Text("Disconnect SafeTrade".localized)
                    .font(.system(size: 13, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
    }

    private func input(_ label: String, text: Binding<String>, placeholder: String, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: CRBTheme.Spacing.xs) {
            Text(label)
                .font(CRBTheme.Typography.caption())
                .foregroundColor(CRBTheme.Colors.muted)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .keyboardType(keyboard)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(CRBTheme.Colors.ink)
                .padding(CRBTheme.Spacing.md)
                .background(CRBTheme.Colors.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
        }
    }

    private func load() {
        let settings = SafeTradeAPIService.shared.settings
        isEnabled = settings.isEnabled
        baseURL = settings.baseURL
        apiKey = SafeTradeAPIService.shared.configuredAPIKey
        apiSecret = ""
        statusPath = settings.statusPath
        balancePath = settings.balancePath
        transferPath = settings.transferPath
        p2pPath = settings.p2pPath
        message = settings.lastTestStatus
        error = nil
    }

    private func saveAndTest() async {
        isTesting = true
        error = nil
        message = nil
        defer { isTesting = false }

        do {
            try SafeTradeAPIService.shared.save(
                settings: SafeTradeAPIService.Settings(
                    isEnabled: isEnabled,
                    baseURL: baseURL,
                    apiKey: apiKey,
                    statusPath: statusPath,
                    balancePath: balancePath,
                    transferPath: transferPath,
                    p2pPath: p2pPath,
                    lastTestedAt: nil,
                    lastTestStatus: nil
                ),
                apiSecret: apiSecret
            )
            message = try await SafeTradeAPIService.shared.testConnection()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
