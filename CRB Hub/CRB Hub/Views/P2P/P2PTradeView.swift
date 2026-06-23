import SwiftUI

struct P2PTradeView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = P2PViewModel()
    @State private var chatInput = ""
    @State private var actionError: String?
    
    let tradeId: String
    
    var body: some View {
        ZStack {
            CRBTheme.Colors.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: CRBTheme.Spacing.lg) {
                    if let trade = viewModel.currentTrade {
                        // Trade header
                        tradeHeader(trade)
                        
                        // State progress
                        stateProgress(trade)
                        
                        // Trade details
                        tradeDetails(trade)
                        
                        // Actions
                        tradeActions(trade)
                        
                        // Chat
                        chatSection
                    } else if viewModel.isLoadingTrade {
                        LoadingView(message: "Loading...".localized)
                            .padding(.vertical, CRBTheme.Spacing.xxl * 2)
                    }
                }
                .padding(CRBTheme.Spacing.lg)
            }
        }
        .navigationTitle("Details".localized)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let token = appState.p2pToken {
                await viewModel.loadTrade(token: token, tradeId: tradeId)
                await viewModel.loadChat(token: token, tradeId: tradeId)
                viewModel.startChatRefresh(token: token, tradeId: tradeId)
            }
        }
        .onDisappear {
            viewModel.stopAutoRefresh()
        }
    }
    
    // MARK: - Header
    
    private func tradeHeader(_ trade: P2PTrade) -> some View {
        let currency = appState.selectedFiatCurrency
        let rates = appState.cachedFXRates
        let rate = rates[currency] ?? CurrencyManager.fallbackRates[currency] ?? 1.0
        let price = trade.Price ?? 0
        let priceInFiat = price * rate
        let amountInFiat = (trade.AmountUSDT ?? 0) * rate
        
        return VStack(spacing: CRBTheme.Spacing.md) {
            HStack {
                PillBadge(text: trade.stateLabel.localized, color: stateColor(trade.State ?? ""))
                PillBadge(text: trade.Side == "sell_crb" ? "Sell Offers".localized : "Buy Offers".localized,
                        color: trade.Side == "sell_crb" ? CRBTheme.Colors.sellRed : CRBTheme.Colors.buyGreen)
                PillBadge(text: trade.Rail?.capitalized ?? "—", color: CRBTheme.Colors.violet)
            }
            
            Text("\(String(format: "%.4f", trade.AmountCRB ?? 0)) CRB")
                .font(.system(size: 28, weight: .heavy, design: .monospaced))
                .foregroundStyle(CRBTheme.Gradients.primary)
            
            FiatValueView(crbAmount: Decimal(trade.AmountCRB ?? 0))
            
            Text("@ \(CRBUnits.formatUSDT(price)) per CRB (≈ \(CurrencyManager.formatFiat(Decimal(priceInFiat), currencyCode: currency)))")
                .font(.system(size: 14))
                .foregroundColor(CRBTheme.Colors.muted)
            
            Text("= \(CRBUnits.formatUSDT(trade.AmountUSDT ?? 0)) (≈ \(CurrencyManager.formatFiat(Decimal(amountInFiat), currencyCode: currency)))")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(CRBTheme.Colors.ink)
        }
        .frame(maxWidth: .infinity)
        .glassCard()
    }
    
    // MARK: - State Progress
    
    private func stateProgress(_ trade: P2PTrade) -> some View {
        let states = ["AWAITING_READY", "AWAITING_LOCK", "LOCKED", "COMPLETED"]
        let currentIdx = states.firstIndex(of: trade.State ?? "") ?? -1
        
        return HStack(spacing: 0) {
            ForEach(Array(states.enumerated()), id: \.element) { index, state in
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(index <= currentIdx ? CRBTheme.Colors.cyan : CRBTheme.Colors.cardBorder)
                            .frame(width: 24, height: 24)
                        
                        if index < currentIdx {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(hex: 0x06121F))
                        } else if index == currentIdx {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 8, height: 8)
                        }
                    }
                    
                    Text(shortStateLabel(state))
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(index <= currentIdx ? CRBTheme.Colors.cyan : CRBTheme.Colors.muted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                
                if index < states.count - 1 {
                    Rectangle()
                        .fill(index < currentIdx ? CRBTheme.Colors.cyan : CRBTheme.Colors.cardBorder)
                        .frame(height: 2)
                        .padding(.bottom, 16)
                }
            }
        }
        .glassCard()
    }
    
    private func shortStateLabel(_ state: String) -> String {
        switch state {
        case "AWAITING_READY": return "Ready".localized
        case "AWAITING_LOCK": return "Lock".localized
        case "LOCKED": return "Awaiting Lock".localized
        case "COMPLETED": return "Done".localized
        default: return state.localized
        }
    }
    
    // MARK: - Details
    
    private func tradeDetails(_ trade: P2PTrade) -> some View {
        let currency = appState.selectedFiatCurrency
        let rates = appState.cachedFXRates
        let rate = rates[currency] ?? CurrencyManager.fallbackRates[currency] ?? 1.0
        let price = trade.Price ?? 0
        let priceInFiat = price * rate
        let amountInFiat = (trade.AmountUSDT ?? 0) * rate
        
        return VStack(alignment: .leading, spacing: CRBTheme.Spacing.md) {
            SectionHeader(title: "Details".localized, icon: "doc.text")
            
            detailRow("Trade ID".localized, trade.ID ?? "—")
            detailRow("Side".localized, trade.Side == "sell_crb" ? "Sell Offers".localized : "Buy Offers".localized)
            detailRow("Rail".localized, trade.Rail?.capitalized ?? "—")
            detailRow("Price".localized, "\(CRBUnits.formatUSDT(price)) (≈ \(CurrencyManager.formatFiat(Decimal(priceInFiat), currencyCode: currency)))")
            detailRow("Amount".localized, String(format: "%.8f", trade.AmountCRB ?? 0))
            detailRow("Amount USDT".localized, "\(CRBUnits.formatUSDT(trade.AmountUSDT ?? 0)) (≈ \(CurrencyManager.formatFiat(Decimal(amountInFiat), currencyCode: currency)))")
            
            if let created = trade.Created {
                detailRow("Time".localized, CRBUnits.formatDate(created))
            }
        }
        .glassCard()
    }
    
    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(CRBTheme.Colors.muted)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(CRBTheme.Colors.ink)
                .lineLimit(1)
        }
    }
    
    // MARK: - Actions
    
    private func tradeActions(_ trade: P2PTrade) -> some View {
        VStack(spacing: CRBTheme.Spacing.md) {
            if let error = actionError {
                Text(error)
                    .font(CRBTheme.Typography.caption())
                    .foregroundColor(CRBTheme.Colors.error)
            }
            
            if trade.State == "AWAITING_READY" {
                GradientButton(title: "Ready".localized, icon: "checkmark.circle.fill") {
                    performAction { token in
                        try await viewModel.tradeReady(token: token, tradeId: tradeId)
                    }
                }
                
                GradientButton(title: "Cancel".localized, icon: "xmark.circle", style: .destructive) {
                    performAction { token in
                        try await viewModel.tradeCancel(token: token, tradeId: tradeId)
                    }
                }
            }
            
            if trade.State == "AWAITING_LOCK" || trade.State == "LOCKED" {
                GradientButton(title: "Appeal".localized, icon: "exclamationmark.triangle", style: .secondary) {
                    performAction { token in
                        try await P2PAPIClient.tradeAppeal(token: token, tradeId: tradeId, category: "general")
                    }
                }
                
                GradientButton(title: "Call Admin".localized, icon: "person.badge.shield.checkmark", style: .secondary) {
                    performAction { token in
                        try await P2PAPIClient.tradeCallAdmin(token: token, tradeId: tradeId)
                    }
                }
            }
            
            if trade.State == "COMPLETED" {
                HStack(spacing: CRBTheme.Spacing.md) {
                    GradientButton(title: "👍 " + "Rate Up".localized, style: .secondary) {
                        performAction { token in
                            try await viewModel.tradeRate(token: token, tradeId: tradeId, up: true)
                        }
                    }
                    
                    GradientButton(title: "👎 " + "Rate Down".localized, style: .destructive) {
                        performAction { token in
                            try await viewModel.tradeRate(token: token, tradeId: tradeId, up: false)
                        }
                    }
                }
            }
        }
    }
    
    private func performAction(_ action: @escaping (String) async throws -> Void) {
        guard let token = appState.p2pToken else {
            actionError = "Not logged in"
            return
        }
        actionError = nil
        Task {
            do {
                try await action(token)
            } catch {
                actionError = error.localizedDescription
            }
        }
    }
    
    // MARK: - Chat
    
    private var chatSection: some View {
        VStack(alignment: .leading, spacing: CRBTheme.Spacing.md) {
            SectionHeader(title: "Chat".localized, icon: "bubble.left.and.bubble.right")
            
            if viewModel.chatMessages.isEmpty {
                Text("No messages yet".localized)
                    .font(CRBTheme.Typography.body())
                    .foregroundColor(CRBTheme.Colors.muted)
                    .padding(.vertical, CRBTheme.Spacing.md)
            } else {
                ForEach(viewModel.chatMessages) { msg in
                    let isMe = msg.from == appState.selectedWallet?.address
                    
                    HStack {
                        if isMe { Spacer() }
                        
                        VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
                            Text(msg.text ?? "")
                                .font(.system(size: 14))
                                .foregroundColor(CRBTheme.Colors.ink)
                                .padding(CRBTheme.Spacing.md)
                                .background(isMe ? CRBTheme.Colors.cyan.opacity(0.15) : CRBTheme.Colors.backgroundSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.md))
                            
                            Text(msg.formattedTime)
                                .font(.system(size: 10))
                                .foregroundColor(CRBTheme.Colors.muted)
                        }
                        .frame(maxWidth: 260, alignment: isMe ? .trailing : .leading)
                        
                        if !isMe { Spacer() }
                    }
                }
            }
            
            // Chat input
            HStack(spacing: CRBTheme.Spacing.sm) {
                TextField("Type message...".localized, text: $chatInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundColor(CRBTheme.Colors.ink)
                    .padding(CRBTheme.Spacing.md)
                    .background(CRBTheme.Colors.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.md))
                
                Button {
                    guard !chatInput.isEmpty, let token = appState.p2pToken else { return }
                    let text = chatInput
                    chatInput = ""
                    Task {
                        await viewModel.sendChat(token: token, tradeId: tradeId, text: text)
                    }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16))
                        .foregroundColor(chatInput.isEmpty ? CRBTheme.Colors.muted : CRBTheme.Colors.cyan)
                        .padding(CRBTheme.Spacing.md)
                        .background(CRBTheme.Colors.backgroundSecondary)
                        .clipShape(Circle())
                }
                .disabled(chatInput.isEmpty)
            }
        }
        .glassCard()
    }
    
    private func stateColor(_ state: String) -> Color {
        switch state {
        case "AWAITING_READY", "AWAITING_LOCK": return CRBTheme.Colors.warning
        case "COMPLETED": return CRBTheme.Colors.buyGreen
        case "CANCELLED", "REFUNDED", "EXPIRED": return CRBTheme.Colors.error
        default: return CRBTheme.Colors.muted
        }
    }
}

#Preview {
    NavigationStack {
        P2PTradeView(tradeId: "test-123")
            .environment(AppState())
    }
}
