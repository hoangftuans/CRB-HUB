import SwiftUI

struct SendView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    @State private var recipientAddress = ""
    @State private var amountString = ""
    @State private var balance: BalanceResponse?
    @State private var chainStatus: ChainStatus?
    @State private var isLoading = true
    @State private var isSending = false
    @State private var error: String?
    @State private var sendResult: BroadcastResult?
    @State private var fallbackPassword = ""
    @State private var requiresPassword = false
    @State private var showFinalConfirmation = false
    @State private var walletViewModel = WalletViewModel()
    
    init(prefilledAddress: String = "", prefilledAmount: String? = nil) {
        _recipientAddress = State(initialValue: prefilledAddress)
        if let amount = prefilledAmount {
            _amountString = State(initialValue: amount)
        }
    }
    
    var isValidAddress: Bool {
        AddressValidator.isValidAddress(recipientAddress)
    }
    
    var parsedAmount: Decimal? {
        let clean = amountString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let val = Decimal(string: clean), val > 0 else { return nil }
        return val
    }
    
    var baseUnitAmount: UInt64? {
        guard let amount = parsedAmount else { return nil }
        return CRBUnits.toBaseUnits(amount)
    }
    
    var feeSuggested: UInt64 {
        chainStatus?.fee_suggested ?? 1000
    }
    
    var totalCost: UInt64 {
        (baseUnitAmount ?? 0) + feeSuggested
    }
    
    var hasEnoughBalance: Bool {
        guard let spendable = balance?.spendable else { return false }
        return totalCost <= spendable
    }
    
    var canSend: Bool {
        isValidAddress && baseUnitAmount != nil && hasEnoughBalance && !isSending && (!requiresPassword || !fallbackPassword.isEmpty)
    }
    
    var body: some View {
        ZStack {
            CRBTheme.Colors.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: CRBTheme.Spacing.xl) {
                    if sendResult != nil {
                        successView
                    } else {
                        sendForm
                    }
                }
                .padding(CRBTheme.Spacing.xl)
            }
        }
        .navigationTitle("Send CRB".localized)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
    }
    
    // MARK: - Send Form
    
    private var sendForm: some View {
        VStack(spacing: CRBTheme.Spacing.xl) {
            VStack(spacing: CRBTheme.Spacing.md) {
                HStack(spacing: CRBTheme.Spacing.md) {
                    Image(systemName: "faceid")
                        .font(.system(size: 24))
                        .foregroundColor(CRBTheme.Colors.cyan)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Secure Transfer".localized)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(CRBTheme.Colors.ink)
                        
                        Text("Face ID is required before this wallet signs and broadcasts the transaction. If Face ID fails, enter your wallet password.".localized)
                            .font(.system(size: 12))
                            .foregroundColor(CRBTheme.Colors.muted)
                    }
                }
            }
            .padding(CRBTheme.Spacing.lg)
            .background(CRBTheme.Colors.cyan.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: CRBTheme.Radius.md)
                    .stroke(CRBTheme.Colors.cyan.opacity(0.3), lineWidth: 1)
            )
            
            if let bal = balance {
                HStack {
                    Text("Spendable:".localized)
                        .font(CRBTheme.Typography.caption())
                        .foregroundColor(CRBTheme.Colors.muted)
                    Spacer()
                    CRBAmountView(baseUnits: bal.spendable, style: .small)
                }
                .glassCard(padding: CRBTheme.Spacing.md)
            }
            
            // Recipient
            VStack(alignment: .leading, spacing: CRBTheme.Spacing.sm) {
                Text("Recipient Address".localized)
                    .font(CRBTheme.Typography.caption())
                    .foregroundColor(CRBTheme.Colors.muted)
                
                TextField("crb1...", text: $recipientAddress)
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
                            .stroke(
                                recipientAddress.isEmpty ? CRBTheme.Colors.cardBorder :
                                    (isValidAddress ? CRBTheme.Colors.success.opacity(0.5) : CRBTheme.Colors.error.opacity(0.5)),
                                lineWidth: 1
                            )
                    )
                
                if !recipientAddress.isEmpty && !isValidAddress {
                    Text("Invalid Address".localized)
                        .font(.system(size: 11))
                        .foregroundColor(CRBTheme.Colors.error)
                }
            }
            .glassCard()
            
            // Amount
            VStack(alignment: .leading, spacing: CRBTheme.Spacing.sm) {
                HStack {
                    Text("CRB Amount".localized)
                        .font(CRBTheme.Typography.caption())
                        .foregroundColor(CRBTheme.Colors.muted)
                    
                    Spacer()
                    
                    if let bal = balance {
                        Button("Max".localized) {
                            let maxAmount = bal.spendable > feeSuggested ? bal.spendable - feeSuggested : 0
                            let decimalAmount = CRBUnits.toDisplayCRB(maxAmount)
                            amountString = "\(decimalAmount)"
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(CRBTheme.Colors.cyan)
                    }
                }
                
                TextField("0.00", text: $amountString)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(CRBTheme.Colors.ink)
                    .keyboardType(.decimalPad)
                    .padding(CRBTheme.Spacing.md)
                    .background(CRBTheme.Colors.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: CRBTheme.Radius.md)
                            .stroke(CRBTheme.Colors.cardBorder, lineWidth: 1)
                    )
                
                if let units = baseUnitAmount {
                    HStack {
                        Text("\(units) synapses")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(CRBTheme.Colors.muted)
                        Spacer()
                        FiatValueView(baseUnits: units, font: .system(size: 11))
                    }
                }
            }
            .glassCard()
            
            VStack(spacing: CRBTheme.Spacing.sm) {
                HStack {
                    Text("Fee:".localized)
                        .font(CRBTheme.Typography.caption())
                        .foregroundColor(CRBTheme.Colors.muted)
                    Spacer()
                    Text(CRBUnits.formatCRB(feeSuggested, maxFractionDigits: 8, minFractionDigits: 8) + " CRB")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(CRBTheme.Colors.ink)
                }
                
                if baseUnitAmount != nil {
                    Divider().background(CRBTheme.Colors.cardBorder)
                    
                    HStack {
                        Text("Total".localized)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(CRBTheme.Colors.ink)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(CRBUnits.formatCRB(totalCost, maxFractionDigits: 8, minFractionDigits: 2) + " CRB")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(hasEnoughBalance ? CRBTheme.Colors.ink : CRBTheme.Colors.error)
                            FiatValueView(baseUnits: totalCost, font: .system(size: 12))
                        }
                    }
                    
                    if !hasEnoughBalance {
                        Text("Insufficient balance".localized)
                            .font(.system(size: 11))
                            .foregroundColor(CRBTheme.Colors.error)
                    }
                }
            }
            .glassCard()
            
            if let error = error {
                Text(error)
                    .font(CRBTheme.Typography.caption())
                    .foregroundColor(CRBTheme.Colors.error)
            }

            if requiresPassword {
                VStack(alignment: .leading, spacing: CRBTheme.Spacing.sm) {
                    Text("Wallet Password".localized)
                        .font(CRBTheme.Typography.caption())
                        .foregroundColor(CRBTheme.Colors.muted)

                    SecureField("Enter wallet password".localized, text: $fallbackPassword)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, weight: .medium))
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
            }
            
            GradientButton(
                title: isSending ? "Sending...".localized : "Review & Send CRB".localized,
                icon: "paperplane.fill",
                isDisabled: !canSend
            ) {
                showFinalConfirmation = true
            }
        }
        .confirmationDialog(
            "Confirm CRB Transfer".localized,
            isPresented: $showFinalConfirmation,
            titleVisibility: .visible
        ) {
            Button("Confirm & Authenticate".localized) {
                Task {
                    await sendCRB()
                }
            }
            Button("Cancel".localized, role: .cancel) {}
        } message: {
            Text(finalConfirmationMessage)
        }
    }
    
    // MARK: - Success
    
    private var successView: some View {
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
            
            Text("Transaction Broadcasted".localized)
                .font(CRBTheme.Typography.title())
                .foregroundColor(CRBTheme.Colors.ink)
            
            if let txid = sendResult?.txid {
                VStack(spacing: CRBTheme.Spacing.sm) {
                    Text("TxID".localized)
                        .font(CRBTheme.Typography.caption())
                        .foregroundColor(CRBTheme.Colors.muted)
                    
                    Text(txid)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(CRBTheme.Colors.cyan)
                        .textSelection(.enabled)
                }
                .glassCard()
            }
            
            GradientButton(title: "Done".localized, icon: "checkmark") {
                dismiss()
            }
        }
    }
    
    // MARK: - Actions

    private var finalConfirmationMessage: String {
        let source = appState.selectedWallet?.address ?? ""
        let recipient = recipientAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let amount = baseUnitAmount.map { CRBUnits.formatCRB($0, maxFractionDigits: 8, minFractionDigits: 0) } ?? amountString
        let fee = CRBUnits.formatCRB(feeSuggested, maxFractionDigits: 8, minFractionDigits: 8)
        let total = CRBUnits.formatCRB(totalCost, maxFractionDigits: 8, minFractionDigits: 2)
        let node = APIConfig.baseURL == APIConfig.officialBaseURL ? "Official Cereblix node" : "Custom node: \(APIConfig.baseURL)"
        return """
        From: \(AddressValidator.truncatedAddress(source, leading: 10, trailing: 8))
        To: \(AddressValidator.truncatedAddress(recipient, leading: 10, trailing: 8))
        Amount: \(amount) CRB
        Fee: \(fee) CRB
        Total: \(total) CRB
        Network: \(node)
        """
    }
    
    private func loadData() async {
        isLoading = true
        if let addr = appState.selectedWallet?.address {
            do {
                async let b = CereblixAPIClient.getBalance(address: addr)
                async let s = CereblixAPIClient.getStatus()
                balance = try await b
                chainStatus = try await s
            } catch {
                self.error = error.localizedDescription
            }
        }
        isLoading = false
    }

    private func sendCRB() async {
        guard let wallet = appState.selectedWallet else {
            error = "No active wallet selected.".localized
            return
        }
        guard let amount = baseUnitAmount else {
            error = "Invalid Amount".localized
            return
        }

        isSending = true
        error = nil
        await walletViewModel.sendCRBSecure(
            wallet: wallet,
            to: recipientAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: amount,
            fee: feeSuggested,
            fallbackPassword: requiresPassword ? fallbackPassword : nil
        )
        isSending = false

        if let result = walletViewModel.sendResult {
            sendResult = result
            requiresPassword = false
            fallbackPassword = ""
            await loadData()
            return
        }

        let message = walletViewModel.sendError ?? "Transaction failed.".localized
        if message.localizedCaseInsensitiveContains("Face ID failed") {
            requiresPassword = true
        }
        error = message
    }
}

#Preview {
    NavigationStack {
        SendView()
            .environment(AppState())
    }
}
