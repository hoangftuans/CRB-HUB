import SwiftUI

struct USDTWalletManagerView: View {
    @Environment(AppState.self) private var appState
    @State private var showAddSheet = false
    @State private var showGenerateSheet = false
    @State private var selectedSendWallet: USDTWallet?
    @State private var isRefreshing = false
    @State private var isSyncingSafeTrade = false
    @State private var safeTradeSyncMessage: String?

    var body: some View {
        ZStack {
            CRBTheme.Colors.background.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: CRBTheme.Spacing.lg) {
                    // Header text
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Manage your USDT balances across exchanges and Web3 wallets.".localized)
                            .font(.system(size: 13))
                            .foregroundColor(CRBTheme.Colors.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if SafeTradeAPIService.shared.isEnabled {
                        safeTradeWalletSection
                    }

                    p2pDefaultWalletSection

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
                .frame(maxWidth: .infinity)
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
        .sheet(item: $selectedSendWallet) { wallet in
            SendUSDTSheet(wallet: wallet)
        }
        .task {
            // Load balances on load
            await appState.refreshUSDTBalances()
        }
    }

    // MARK: - Wallet Card Component

    private var safeTradeWalletSection: some View {
        VStack(alignment: .leading, spacing: CRBTheme.Spacing.md) {
            SectionHeader(title: "SafeTrade USDT Wallets".localized, icon: "server.rack")

            Text("Sync your SafeTrade USDT deposit wallets, then choose which one receives P2P CRB payments.".localized)
                .font(.system(size: 12))
                .foregroundColor(CRBTheme.Colors.muted)

            if let safeTradeSyncMessage {
                Text(safeTradeSyncMessage.localized)
                    .font(CRBTheme.Typography.caption())
                    .foregroundColor(safeTradeSyncMessage.localizedCaseInsensitiveContains("failed") ? CRBTheme.Colors.error : CRBTheme.Colors.success)
            }

            GradientButton(
                title: isSyncingSafeTrade ? "Syncing...".localized : "Sync SafeTrade USDT Wallets".localized,
                icon: "arrow.triangle.2.circlepath",
                isDisabled: isSyncingSafeTrade,
                style: .secondary
            ) {
                syncSafeTradeWallets()
            }
        }
        .glassCard()
    }

    private var p2pDefaultWalletSection: some View {
        VStack(alignment: .leading, spacing: CRBTheme.Spacing.md) {
            SectionHeader(title: "P2P Receiving Wallet".localized, icon: "arrow.down.circle.fill")

            Text("Choose where USDT should arrive when you create or take CRB P2P trades.".localized)
                .font(.system(size: 12))
                .foregroundColor(CRBTheme.Colors.muted)

            ForEach(USDTNetwork.p2pSupportedNetworks) { network in
                if let rail = network.p2pRail {
                    defaultWalletPicker(rail: rail, title: network.p2pReceiveLabel)
                }
            }
        }
        .glassCard()
    }

    private func defaultWalletPicker(rail: String, title: String) -> some View {
        let wallets = appState.linkedUSDTWallets.filter { $0.network.p2pRail == rail }
        let selected = appState.defaultP2PUSDTWallet(for: rail)

        return VStack(alignment: .leading, spacing: CRBTheme.Spacing.xs) {
            Text(title.localized)
                .font(CRBTheme.Typography.caption())
                .foregroundColor(CRBTheme.Colors.muted)

            if wallets.isEmpty {
                Text("No wallet linked for this network yet.".localized)
                    .font(.system(size: 12))
                    .foregroundColor(CRBTheme.Colors.warning)
            } else {
                Menu {
                    ForEach(wallets) { wallet in
                        Button {
                            appState.setDefaultP2PUSDTWallet(wallet, rail: rail)
                        } label: {
                            Text("\(wallet.name) • \(AddressValidator.truncatedAddress(wallet.address, leading: 8, trailing: 6))")
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "wallet.pass.fill")
                        Text(selected.map { "\($0.name) • \(AddressValidator.truncatedAddress($0.address, leading: 8, trailing: 6))" } ?? "Select receiving wallet".localized)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(CRBTheme.Colors.ink)
                    .padding(CRBTheme.Spacing.md)
                    .background(CRBTheme.Colors.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
                }
            }
        }
    }

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

            if wallet.network.p2pRail != nil {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 12))
                    Text(p2pWalletStatusText(wallet))
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(isDefaultP2PWallet(wallet) ? CRBTheme.Colors.buyGreen : CRBTheme.Colors.muted)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background((isDefaultP2PWallet(wallet) ? CRBTheme.Colors.buyGreen : CRBTheme.Colors.muted).opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))

                if !isDefaultP2PWallet(wallet), let rail = wallet.network.p2pRail {
                    Button {
                        appState.setDefaultP2PUSDTWallet(wallet, rail: rail)
                    } label: {
                        Text("Set as P2P default".localized)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(CRBTheme.Colors.cyan)
                    }
                }
            }

            HStack {
                Text("USDT Balance".localized)
                    .font(.system(size: 12))
                    .foregroundColor(CRBTheme.Colors.muted)

                Spacer()

                Text("\(CRBUnits.formatDecimal(wallet.balance, maxFractionDigits: 6, minFractionDigits: 2)) USDT")
                    .font(.system(size: 18, weight: .heavy, design: .monospaced))
                    .foregroundColor(CRBTheme.Colors.cyan)
            }

            if SafeTradeAPIService.shared.isEnabled {
                GradientButton(
                    title: "Send via SafeTrade".localized,
                    icon: "paperplane.fill",
                    style: .secondary
                ) {
                    selectedSendWallet = wallet
                }
            } else if wallet.isNative {
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 12))
                    Text("Native USDT send requires audited chain signing".localized)
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(CRBTheme.Colors.warning)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(CRBTheme.Colors.warning.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
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

    private func isDefaultP2PWallet(_ wallet: USDTWallet) -> Bool {
        guard let rail = wallet.network.p2pRail else { return false }
        return appState.defaultP2PUSDTWallet(for: rail)?.id == wallet.id
    }

    private func p2pWalletStatusText(_ wallet: USDTWallet) -> String {
        if isDefaultP2PWallet(wallet) {
            return String(format: "Default P2P receiving wallet: %@".localized, wallet.network.p2pReceiveLabel)
        }
        return String(format: "P2P receiving wallet: %@ only".localized, wallet.network.p2pReceiveLabel)
    }

    private func syncSafeTradeWallets() {
        isSyncingSafeTrade = true
        safeTradeSyncMessage = nil

        Task {
            do {
                let wallets = try await SafeTradeAPIService.shared.fetchSupportedUSDTDepositWallets()
                guard !wallets.isEmpty else {
                    safeTradeSyncMessage = "SafeTrade returned no USDT deposit wallets."
                    isSyncingSafeTrade = false
                    return
                }

                for wallet in wallets {
                    appState.upsertUSDTWallet(wallet)
                    if let rail = wallet.network.p2pRail,
                       appState.defaultP2PUSDTWallet(for: rail) == nil {
                        if let saved = appState.linkedUSDTWallets.first(where: {
                            $0.provider == wallet.provider && $0.network == wallet.network && $0.address == wallet.address
                        }) {
                            appState.setDefaultP2PUSDTWallet(saved, rail: rail)
                        }
                    }
                }

                await appState.refreshUSDTBalances()
                safeTradeSyncMessage = "SafeTrade USDT wallets synced."
            } catch {
                safeTradeSyncMessage = "SafeTrade sync failed: \(error.localizedDescription)"
            }
            isSyncingSafeTrade = false
        }
    }
}

// MARK: - Add Linked Wallet Sheet

struct AddUSDTWalletSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var name = ""
    @State private var provider: USDTProvider = .binance
    @State private var network: USDTNetwork = .polygon
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
                                ForEach(USDTProvider.allCases.filter { $0 != .native && $0 != .safeTrade }) { prov in
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
                                ForEach(USDTNetwork.p2pSupportedNetworks) { net in
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

        guard USDTNetwork.p2pSupportedNetworks.contains(network) else {
            validationError = "Only Polygon and Solana USDT wallets are supported for P2P.".localized
            return
        }

        if network == .solana {
            let allowed = CharacterSet(charactersIn: "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")
            guard cleanAddress.count >= 32,
                  cleanAddress.count <= 44,
                  cleanAddress.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
                validationError = "Solana addresses must be 32-44 base58 characters.".localized
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

// MARK: - Send USDT Sheet

struct SendUSDTSheet: View {
    @Environment(\.dismiss) private var dismiss

    let wallet: USDTWallet

    @State private var recipient = ""
    @State private var amount = ""
    @State private var password = ""
    @State private var emailCode = ""
    @State private var otpCode = ""
    @State private var phoneCode = ""
    @State private var requiresPassword = false
    @State private var isSending = false
    @State private var isGeneratingCode = false
    @State private var error: String?
    @State private var codeMessage: String?

    init(wallet: USDTWallet, prefilledRecipient: String = "") {
        self.wallet = wallet
        _recipient = State(initialValue: prefilledRecipient)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CRBTheme.Colors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: CRBTheme.Spacing.lg) {
                        VStack(alignment: .leading, spacing: CRBTheme.Spacing.sm) {
                            Text(wallet.name)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(CRBTheme.Colors.ink)
                            Text(wallet.network.displayName)
                                .font(.system(size: 12))
                                .foregroundColor(CRBTheme.Colors.muted)
                            Text(AddressValidator.truncatedAddress(wallet.address, leading: 10, trailing: 8))
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(CRBTheme.Colors.cyan)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard()

                        inputField("Recipient".localized, text: $recipient, placeholder: wallet.network == .solana ? "Solana address" : "0x...", keyboard: .default)
                        inputField("Amount USDT".localized, text: $amount, placeholder: "0.00", keyboard: .decimalPad)

                        safeTradeVerificationSection

                        if requiresPassword {
                            SecureField("Wallet Password".localized, text: $password)
                                .textFieldStyle(.plain)
                                .foregroundColor(CRBTheme.Colors.ink)
                                .padding(CRBTheme.Spacing.md)
                                .background(CRBTheme.Colors.backgroundSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
                        }

                        if let error {
                            Text(error.localized)
                                .font(CRBTheme.Typography.caption())
                                .foregroundColor(CRBTheme.Colors.error)
                        }

                        GradientButton(
                            title: isSending ? "Sending...".localized : (requiresPassword ? "Unlock & Send".localized : "Send USDT".localized),
                            icon: "paperplane.fill",
                            isDisabled: isSending || isGeneratingCode || recipient.isEmpty || amount.isEmpty || (requiresPassword && password.isEmpty)
                        ) {
                            send()
                        }

                        Text("Face ID is required before USDT transfers. Native wallets still require protected key access; SafeTrade withdrawals unlock the API secret from Keychain.".localized)
                            .font(.system(size: 11))
                            .foregroundColor(CRBTheme.Colors.muted)
                    }
                    .padding(CRBTheme.Spacing.xl)
                }
            }
            .navigationTitle("Send USDT".localized)
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

    private var safeTradeVerificationSection: some View {
        VStack(alignment: .leading, spacing: CRBTheme.Spacing.sm) {
            Text("SafeTrade Withdraw Verification".localized)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(CRBTheme.Colors.ink)

            Text("Generate an email code first, then enter any codes required by your SafeTrade account before sending.".localized)
                .font(.system(size: 11))
                .foregroundColor(CRBTheme.Colors.muted)

            Button {
                generateWithdrawCode()
            } label: {
                HStack {
                    Image(systemName: isGeneratingCode ? "hourglass" : "envelope.badge.shield.half.filled")
                    Text(isGeneratingCode ? "Generating code...".localized : "Generate Email Code".localized)
                        .font(.system(size: 12, weight: .bold))
                    Spacer()
                }
                .padding(CRBTheme.Spacing.md)
                .background(CRBTheme.Colors.cyan.opacity(0.1))
                .foregroundColor(CRBTheme.Colors.cyan)
                .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
            }
            .disabled(isGeneratingCode || recipient.isEmpty || amount.isEmpty)

            inputField("Email Code".localized, text: $emailCode, placeholder: "Optional if SafeTrade does not require it", keyboard: .numberPad)
            inputField("Authenticator Code".localized, text: $otpCode, placeholder: "Optional", keyboard: .numberPad)
            inputField("Phone Code".localized, text: $phoneCode, placeholder: "Optional", keyboard: .numberPad)

            if let codeMessage {
                Text(codeMessage.localized)
                    .font(CRBTheme.Typography.caption())
                    .foregroundColor(CRBTheme.Colors.buyGreen)
            }
        }
        .padding(CRBTheme.Spacing.md)
        .background(CRBTheme.Colors.backgroundSecondary.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
    }

    private func inputField(_ label: String, text: Binding<String>, placeholder: String, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: CRBTheme.Spacing.xs) {
            Text(label)
                .font(CRBTheme.Typography.caption())
                .foregroundColor(CRBTheme.Colors.muted)

            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(CRBTheme.Colors.ink)
                .keyboardType(keyboard)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding(CRBTheme.Spacing.md)
                .background(CRBTheme.Colors.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
        }
    }

    private func send() {
        guard let amountDecimal = parseDecimal(amount), amountDecimal > 0 else {
            error = "Invalid USDT amount"
            return
        }

        isSending = true
        error = nil

        Task {
            do {
                _ = try await USDTTransferService.sendSecure(
                    wallet: wallet,
                    to: recipient.trimmingCharacters(in: .whitespacesAndNewlines),
                    amount: amountDecimal,
                    safeTradeCodes: SafeTradeWithdrawCodes(
                        emailCode: emailCode,
                        otpCode: otpCode,
                        phoneCode: phoneCode
                    ),
                    fallbackPassword: requiresPassword ? password : nil
                )
                dismiss()
            } catch WalletSecurityStore.SecurityError.passwordRequired {
                requiresPassword = true
                error = "Face ID failed. Please enter your wallet password."
            } catch {
                self.error = error.localizedDescription
            }
            isSending = false
        }
    }

    private func generateWithdrawCode() {
        guard let amountDecimal = parseDecimal(amount), amountDecimal > 0 else {
            error = "Invalid USDT amount"
            return
        }

        isGeneratingCode = true
        error = nil
        codeMessage = nil

        Task {
            do {
                try await SafeTradeAPIService.shared.generateWithdrawCode(
                    wallet: wallet,
                    to: recipient.trimmingCharacters(in: .whitespacesAndNewlines),
                    amount: amountDecimal,
                    type: .email
                )
                codeMessage = "Email code sent by SafeTrade."
            } catch {
                self.error = error.localizedDescription
            }
            isGeneratingCode = false
        }
    }

    private func parseDecimal(_ value: String) -> Decimal? {
        let clean = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        return Decimal(string: clean)
    }
}

// MARK: - Generate Native Wallet Sheet

struct GenerateNativeUSDTSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var name = ""
    @State private var network: USDTNetwork = .polygon
    @State private var generatedWallet: (privateKey: String, address: String)?
    @State private var isCreating = false
    @State private var copiedKey = false
    @State private var error: String?

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

            HStack(spacing: CRBTheme.Spacing.md) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 24))
                    .foregroundColor(CRBTheme.Colors.warning)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Native USDT Signing Disabled".localized)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(CRBTheme.Colors.warning)

                    Text("Production USDT transfers require an audited Solana/EVM signer or wallet provider. Link an existing USDT wallet address for receiving and P2P until native signing is added.".localized)
                        .font(.system(size: 12))
                        .foregroundColor(CRBTheme.Colors.muted)
                }
            }
            .padding(CRBTheme.Spacing.md)
            .background(CRBTheme.Colors.warning.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.md))

            if let error {
                Text(error)
                    .font(CRBTheme.Typography.caption())
                    .foregroundColor(CRBTheme.Colors.error)
            }

            GradientButton(
                title: "Link Existing USDT Wallet Instead".localized,
                icon: "iphone.gen3",
                isDisabled: true
            ) {}
        }
    }

    private func generateWallet() async {
        isCreating = true
        error = nil
        defer { isCreating = false }

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
        do {
            try await KeychainStore.shared.savePrivateKeyWithBiometricSetup(
                walletData.privateKey,
                for: newWallet.id,
                reason: "Authenticate to protect this USDT wallet with Face ID"
            )
        } catch {
            self.error = error.localizedDescription
            return
        }

        appState.addUSDTWallet(newWallet)

        generatedWallet = walletData
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
