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
    
    init(prefilledAddress: String = "") {
        _recipientAddress = State(initialValue: prefilledAddress)
    }
    
    var isValidAddress: Bool {
        AddressValidator.isValidAddress(recipientAddress)
    }
    
    var parsedAmount: Decimal? {
        guard let val = Decimal(string: amountString), val > 0 else { return nil }
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
        isValidAddress && baseUnitAmount != nil && hasEnoughBalance && !isSending
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
            // Signing not ready warning
            VStack(spacing: CRBTheme.Spacing.md) {
                HStack(spacing: CRBTheme.Spacing.md) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(CRBTheme.Colors.warning)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Transaction Signing".localized)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(CRBTheme.Colors.warning)
                        
                        Text("Send functionality requires the canonical transaction byte format from the Cereblix reference wallet. This feature is currently under development.".localized)
                            .font(.system(size: 12))
                            .foregroundColor(CRBTheme.Colors.muted)
                    }
                }
            }
            .padding(CRBTheme.Spacing.lg)
            .background(CRBTheme.Colors.warning.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: CRBTheme.Radius.md)
                    .stroke(CRBTheme.Colors.warning.opacity(0.3), lineWidth: 1)
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
            
            // Send button (disabled for now — signing not implemented)
            GradientButton(
                title: "Send CRB".localized,
                icon: "paperplane.fill",
                isDisabled: true  // Disabled until signing is implemented
            ) {
                // Will implement when transaction signing is ready
            }
            
            Text("Transaction signing is under development".localized)
                .font(.system(size: 11))
                .foregroundColor(CRBTheme.Colors.muted.opacity(0.6))
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
}

#Preview {
    NavigationStack {
        SendView()
            .environment(AppState())
    }
}
