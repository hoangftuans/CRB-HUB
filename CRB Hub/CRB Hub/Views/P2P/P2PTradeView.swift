import SwiftUI

struct P2PTradeView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = P2PViewModel()
    @State private var chatInput = ""
    @State private var actionError: String?
    @State private var usdtFallbackWalletId: UUID?
    @State private var usdtFallbackPassword = ""
    @State private var pendingEscrowCopy: EscrowCopyRequest?
    @State private var pendingEscrowPayment: EscrowPaymentRequest?
    
    let tradeId: String
    
    var body: some View {
        ZStack {
            CRBTheme.Colors.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: CRBTheme.Spacing.lg) {
                    if let trade = viewModel.currentTrade {
                        // Trade header
                        tradeHeader(trade)

                        // Live rate against locked trade price
                        liveTradeRateCard(trade)

                        // State progress
                        stateProgress(trade)
                        
                        // Trade details
                        tradeDetails(trade)
                        
                        // Escrow deposit
                        escrowSection(trade)
                        
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
                if let trade = viewModel.currentTrade {
                    bindLoadedTradeWalletIfPossible(trade)
                }
                await viewModel.loadChat(token: token, tradeId: tradeId)
                await refreshLiveRates(includeFiat: true)
                viewModel.startChatRefresh(token: token, tradeId: tradeId)
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(10))
                    guard !Task.isCancelled else { return }
                    await refreshLiveRates(includeFiat: false)
                }
            }
        }
        .onDisappear {
            viewModel.stopAutoRefresh()
        }
        .confirmationDialog(
            "Verify Escrow Address".localized,
            isPresented: Binding(
                get: { pendingEscrowCopy != nil },
                set: { if !$0 { pendingEscrowCopy = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let request = pendingEscrowCopy {
                Button("Copy Confirmed Details".localized) {
                    copyEscrowPayment(address: request.address, amount: request.amount, asset: request.asset)
                    pendingEscrowCopy = nil
                }
                Button("Cancel".localized, role: .cancel) {
                    pendingEscrowCopy = nil
                }
            }
        } message: {
            if let request = pendingEscrowCopy {
                Text("Trade \(tradeId)\nNetwork: \(request.network)\nAmount: \(request.amount) \(request.asset)\nAddress: \(request.address)\n\nOnly continue if this matches the official OTC trade details.".localized)
            }
        }
        .confirmationDialog(
            "Confirm USDT Escrow Payment".localized,
            isPresented: Binding(
                get: { pendingEscrowPayment != nil },
                set: { if !$0 { pendingEscrowPayment = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let request = pendingEscrowPayment {
                Button("Pay Confirmed Escrow".localized) {
                    payNativeUSDTEscrow(
                        wallet: request.wallet,
                        escrowAddr: request.address,
                        amount: request.amount,
                        fallbackPassword: request.fallbackPassword
                    )
                    pendingEscrowPayment = nil
                }
                Button("Cancel".localized, role: .cancel) {
                    pendingEscrowPayment = nil
                }
            }
        } message: {
            if let request = pendingEscrowPayment {
                Text("Trade \(tradeId)\nNetwork: \(request.network)\nAmount: \(request.amount) USDT\nAddress: \(request.address)\n\nOnly send if this is the escrow address shown by the official OTC trade.".localized)
            }
        }
    }
    
    // MARK: - Header
    
    private func tradeHeader(_ trade: P2PTrade) -> some View {
        let currency = appState.selectedFiatCurrency
        let rates = appState.cachedFXRates
        let rate = rates[currency] ?? CurrencyManager.fallbackRates[currency] ?? 1
        let price = trade.Price ?? 0
        let priceInFiat = price * rate
        let amountInFiat = (trade.AmountUSDT ?? 0) * rate
        
        return VStack(spacing: CRBTheme.Spacing.md) {
            HStack {
                PillBadge(text: trade.stateLabel.localized, color: stateColor(trade.State ?? ""))
                PillBadge(text: (trade.Side == "sell_crb" ? "SELL" : "BUY").localized,
                        color: trade.Side == "sell_crb" ? CRBTheme.Colors.sellRed : CRBTheme.Colors.buyGreen)
                PillBadge(text: trade.Rail?.capitalized ?? "—", color: CRBTheme.Colors.violet)
            }
            
            Text("\(CRBUnits.formatDecimal(trade.AmountCRB ?? 0, maxFractionDigits: 4, minFractionDigits: 4)) CRB")
                .font(.system(size: 28, weight: .heavy, design: .monospaced))
                .foregroundStyle(CRBTheme.Gradients.primary)
            
            FiatValueView(crbAmount: trade.AmountCRB ?? 0)
            
            Text("@ \(CRBUnits.formatUSDT(price)) per CRB (≈ \(CurrencyManager.formatFiat(priceInFiat, currencyCode: currency)))")
                .font(.system(size: 14))
                .foregroundColor(CRBTheme.Colors.muted)
            
            Text("= \(CRBUnits.formatUSDT(trade.AmountUSDT ?? 0)) (≈ \(CurrencyManager.formatFiat(amountInFiat, currencyCode: currency)))")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(CRBTheme.Colors.ink)
        }
        .frame(maxWidth: .infinity)
        .glassCard()
    }

    private func liveTradeRateCard(_ trade: P2PTrade) -> some View {
        let currency = appState.selectedFiatCurrency
        let tradePrice = trade.Price ?? 0
        let marketPrice = liveMarketPrice ?? tradePrice
        let fiatRate = selectedFiatRate
        let marketFiat = marketPrice * fiatRate
        let tradeFiat = tradePrice * fiatRate
        let delta = marketPrice > 0 ? ((tradePrice - marketPrice) / marketPrice) * 100 : 0

        return VStack(alignment: .leading, spacing: CRBTheme.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Live CRB/USDT".localized)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(CRBTheme.Colors.buyGreen)
                    Text("\(CRBUnits.formatUSDT(marketPrice)) ≈ \(CurrencyManager.formatFiat(marketFiat, currencyCode: currency))")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(CRBTheme.Colors.ink)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text("Locked Trade Price".localized)
                        .font(.system(size: 11))
                        .foregroundColor(CRBTheme.Colors.muted)
                    Text("\(CRBUnits.formatUSDT(tradePrice)) ≈ \(CurrencyManager.formatFiat(tradeFiat, currencyCode: currency))")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(CRBTheme.Colors.cyan)
                }
            }

            HStack(spacing: CRBTheme.Spacing.md) {
                ratePill("vs live".localized, NSDecimalNumber(decimal: delta).doubleValue)
                ratePill("24h".localized, appState.p2pStats?.change_24h_pct ?? 0)
                ratePill("7d".localized, appState.p2pStats?.change_7d_pct ?? 0)
                Spacer()
            }
        }
        .padding(CRBTheme.Spacing.md)
        .background(CRBTheme.Colors.backgroundSecondary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: CRBTheme.Radius.sm)
                .stroke(CRBTheme.Colors.buyGreen.opacity(0.2), lineWidth: 1)
        )
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
        let rate = rates[currency] ?? CurrencyManager.fallbackRates[currency] ?? 1
        let price = trade.Price ?? 0
        let priceInFiat = price * rate
        let amountInFiat = (trade.AmountUSDT ?? 0) * rate
        
        return VStack(alignment: .leading, spacing: CRBTheme.Spacing.md) {
            SectionHeader(title: "Details".localized, icon: "doc.text")
            
            detailRow("Trade ID".localized, trade.ID ?? "—")
            detailRow("Side".localized, trade.Side == "sell_crb" ? "Sell Offers".localized : "Buy Offers".localized)
            detailRow("Rail".localized, trade.Rail?.capitalized ?? "—")
            detailRow("Price".localized, "\(CRBUnits.formatUSDT(price)) (≈ \(CurrencyManager.formatFiat(priceInFiat, currencyCode: currency)))")
            detailRow("Amount".localized, CRBUnits.formatDecimal(trade.AmountCRB ?? 0, maxFractionDigits: 8, minFractionDigits: 0))
            detailRow("Amount USDT".localized, "\(CRBUnits.formatUSDT(trade.AmountUSDT ?? 0)) (≈ \(CurrencyManager.formatFiat(amountInFiat, currencyCode: currency)))")
            
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
    
    @ViewBuilder
    private func escrowSection(_ trade: P2PTrade) -> some View {
        if trade.State == "AWAITING_LOCK" || trade.State == "LOCKED" {
            let isMaker = trade.MakerAddr == appState.selectedWallet?.address
            let isTaker = trade.TakerAddr == appState.selectedWallet?.address
            let isSeller = (trade.Side == "sell_crb" && isMaker) || (trade.Side == "buy_crb" && isTaker)
            
            let myLocked = isSeller ? (trade.CRBLocked ?? false) : (trade.USDTFunded ?? false)
            let otherLocked = isSeller ? (trade.USDTFunded ?? false) : (trade.CRBLocked ?? false)
            let escrowAddr = (isSeller ? trade.EscrowCRB : trade.EscrowUSDT) ?? ""
            let amountStr = isSeller ? CRBUnits.formatDecimal(trade.AmountCRB ?? 0, maxFractionDigits: 4, minFractionDigits: 4) : CRBUnits.formatDecimal(trade.AmountUSDT ?? 0, maxFractionDigits: 6, minFractionDigits: 6)
            let assetName = isSeller ? "CRB" : "USDT"
            
            VStack(alignment: .leading, spacing: CRBTheme.Spacing.md) {
                SectionHeader(title: "Escrow Deposit".localized, icon: "lock.fill")
                
                // My Leg Status Card
                VStack(alignment: .leading, spacing: CRBTheme.Spacing.sm) {
                    HStack {
                        PillBadge(text: "Your Deposit".localized, color: myLocked ? CRBTheme.Colors.buyGreen : CRBTheme.Colors.warning)
                        Spacer()
                        if myLocked {
                            Text("Locked ✓".localized)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(CRBTheme.Colors.buyGreen)
                        } else if isSeller && (trade.CRBSeen ?? false) {
                            Text(String(format: "Confirming (%d/10)".localized, trade.CRBConfs ?? 0))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(CRBTheme.Colors.warning)
                        } else if !isSeller && (trade.USDTSeen ?? false) {
                            Text("USDT Detected".localized)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(CRBTheme.Colors.warning)
                        } else {
                            Text("Awaiting Deposit".localized)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(CRBTheme.Colors.muted)
                        }
                    }
                    
                    if !myLocked {
                        Text(isSeller ?
                             String(format: "Deposit %@ CRB to the escrow address below:".localized, amountStr) :
                             String(format: "Deposit %@ via %@ network to the escrow address below:".localized, amountStr, railReceiveLabel(trade.Rail ?? "")))
                            .font(.system(size: 13))
                            .foregroundColor(CRBTheme.Colors.muted)
                            .lineSpacing(4)
                        
                        if !escrowAddr.isEmpty {
                            // Escrow address copy row
                            HStack {
                                Text(escrowAddr)
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundColor(CRBTheme.Colors.ink)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                
                                Spacer()
                                
                                Button {
                                    pendingEscrowCopy = EscrowCopyRequest(
                                        address: escrowAddr,
                                        amount: amountStr,
                                        asset: assetName,
                                        network: isSeller ? "CRB" : railReceiveLabel(trade.Rail ?? "")
                                    )
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 14))
                                        .foregroundColor(CRBTheme.Colors.cyan)
                                }
                            }
                            .padding(CRBTheme.Spacing.md)
                            .background(CRBTheme.Colors.backgroundSecondary.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
                            
                            // Safe deposit warning box
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(CRBTheme.Colors.warning)
                                Text(String(format: "Only send %@ on the correct network. Sending to wrong address or network will result in permanent loss.".localized, assetName))
                                    .font(.system(size: 11))
                                    .foregroundColor(CRBTheme.Colors.warning.opacity(0.85))
                            }
                             .padding(CRBTheme.Spacing.sm)
                             .background(CRBTheme.Colors.warning.opacity(0.05))
                             .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.xs))
                             
	                             if !isSeller {
	                                 let matchingWallets = matchingUSDTWallets(for: trade, role: isMaker ? .maker : .taker)

	                                 if !matchingWallets.isEmpty {
	                                     VStack(alignment: .leading, spacing: CRBTheme.Spacing.sm) {
	                                         HStack {
	                                             Text("Pay from existing USDT wallet".localized)
	                                                 .font(.system(size: 11, weight: .bold))
	                                                 .foregroundColor(CRBTheme.Colors.cyan)
	                                             Spacer()
	                                             if boundUSDTWallet(for: trade, role: isMaker ? .maker : .taker) != nil {
	                                                 PillBadge(text: "Bound".localized, color: CRBTheme.Colors.buyGreen)
	                                             }
	                                         }
	                                         .padding(.bottom, 2)

                                         ForEach(matchingWallets) { wallet in
                                             VStack(spacing: 8) {
                                                 HStack {
                                                     Image(systemName: wallet.provider.iconName)
                                                         .font(.system(size: 12))
                                                         .foregroundColor(CRBTheme.Colors.ink)
                                                     Text(wallet.name)
                                                         .font(.system(size: 13, weight: .semibold))
                                                         .foregroundColor(CRBTheme.Colors.ink)
                                                     Spacer()
                                                     Text("\(CRBUnits.formatDecimal(wallet.balance, maxFractionDigits: 6, minFractionDigits: 2)) USDT")
                                                         .font(.system(size: 13, weight: .bold, design: .monospaced))
                                                         .foregroundColor(CRBTheme.Colors.cyan)
                                                 }
                                                 .padding(8)
                                                 .background(CRBTheme.Colors.backgroundSecondary.opacity(0.4))
                                                 .clipShape(RoundedRectangle(cornerRadius: 6))

                                                 if wallet.isNative {
                                                     VStack(alignment: .leading, spacing: 6) {
                                                         Button {
                                                             pendingEscrowPayment = EscrowPaymentRequest(
                                                                wallet: wallet,
                                                                address: escrowAddr,
                                                                amount: amountStr,
                                                                network: railReceiveLabel(trade.Rail ?? ""),
                                                                fallbackPassword: nil
                                                             )
                                                         } label: {
                                                             HStack {
                                                                 Image(systemName: "faceid")
                                                                 Text("Pay Escrow with Face ID".localized)
                                                                     .font(.system(size: 12, weight: .bold))
                                                             }
                                                             .frame(maxWidth: .infinity)
                                                             .padding(8)
                                                             .background(CRBTheme.Colors.cyan.opacity(0.14))
                                                             .foregroundColor(CRBTheme.Colors.cyan)
                                                             .clipShape(RoundedRectangle(cornerRadius: 6))
                                                         }

                                                         if usdtFallbackWalletId == wallet.id {
                                                             SecureField("Wallet Password".localized, text: $usdtFallbackPassword)
                                                                 .textFieldStyle(.plain)
                                                                 .font(.system(size: 12))
                                                                 .foregroundColor(CRBTheme.Colors.ink)
                                                                 .padding(8)
                                                                 .background(CRBTheme.Colors.backgroundSecondary.opacity(0.6))
                                                                 .clipShape(RoundedRectangle(cornerRadius: 6))

                                                             Button {
                                                                 pendingEscrowPayment = EscrowPaymentRequest(
                                                                    wallet: wallet,
                                                                    address: escrowAddr,
                                                                    amount: amountStr,
                                                                    network: railReceiveLabel(trade.Rail ?? ""),
                                                                    fallbackPassword: usdtFallbackPassword
                                                                 )
                                                             } label: {
                                                                 Text("Unlock with Password".localized)
                                                                     .font(.system(size: 12, weight: .bold))
                                                                     .frame(maxWidth: .infinity)
                                                                     .padding(8)
                                                                     .background(CRBTheme.Colors.violet.opacity(0.14))
                                                                     .foregroundColor(CRBTheme.Colors.violet)
                                                                     .clipShape(RoundedRectangle(cornerRadius: 6))
                                                             }
                                                             .disabled(usdtFallbackPassword.isEmpty)
                                                         }
                                                     }
                                                     .frame(maxWidth: .infinity, alignment: .leading)
                                                     .padding(8)
                                                     .background(CRBTheme.Colors.cyan.opacity(0.06))
                                                     .clipShape(RoundedRectangle(cornerRadius: 6))
                                                 } else {
                                                     Button {
                                                         pendingEscrowCopy = EscrowCopyRequest(
                                                            address: escrowAddr,
                                                            amount: amountStr,
                                                            asset: assetName,
                                                            network: railReceiveLabel(trade.Rail ?? "")
                                                         )
                                                     } label: {
                                                         HStack {
                                                             Image(systemName: "doc.on.doc")
                                                             Text(String(format: "Copy payment for %@".localized, wallet.name))
                                                                 .font(.system(size: 12, weight: .bold))
                                                         }
                                                         .frame(maxWidth: .infinity)
                                                         .padding(8)
                                                         .background(CRBTheme.Colors.violet.opacity(0.12))
                                                         .foregroundColor(CRBTheme.Colors.violet)
                                                         .clipShape(RoundedRectangle(cornerRadius: 6))
                                                     }
                                                 }
                                             }
                                             .padding(4)
                                         }
                                     }
                                     .padding(CRBTheme.Spacing.sm)
                                     .background(CRBTheme.Colors.backgroundSecondary.opacity(0.2))
                                     .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
                                     .padding(.vertical, 4)
	                                 } else {
	                                     Text(String(format: "No linked %@ wallet matches this trade. Add one in Settings before paying or copy the escrow address to an external wallet on the same network.".localized, railReceiveLabel(trade.Rail ?? "")))
                                         .font(.system(size: 12))
                                         .foregroundColor(CRBTheme.Colors.warning)
                                         .padding(CRBTheme.Spacing.sm)
                                         .background(CRBTheme.Colors.warning.opacity(0.06))
                                         .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
                                 }
                             }

                             if isSeller {
                                if let wallet = appState.selectedWallet {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Pay from active CRB wallet".localized)
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(CRBTheme.Colors.cyan)
                                        Text("\(wallet.name) • \(AddressValidator.truncatedAddress(wallet.address))")
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundColor(CRBTheme.Colors.muted)
                                    }
                                    .padding(CRBTheme.Spacing.sm)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(CRBTheme.Colors.backgroundSecondary.opacity(0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
                                }

                                // Direct Pay Escrow button opening SendView prefilled
                                NavigationLink {
                                    SendView(prefilledAddress: escrowAddr, prefilledAmount: amountStr)
                                } label: {
                                    HStack {
                                        Image(systemName: "paperplane.fill")
                                        Text("Pay Escrow".localized)
                                            .fontWeight(.bold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(CRBTheme.Spacing.md)
                                    .background(CRBTheme.Gradients.primary)
                                    .foregroundColor(Color(hex: 0x06121F))
                                    .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.md))
                                }
                                .padding(.top, 4)
                            }
                        }
                    } else {
                        Text("Your deposit is locked in escrow ✓".localized)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(CRBTheme.Colors.buyGreen)
                    }
                }
                .padding(CRBTheme.Spacing.lg)
                .background(CRBTheme.Colors.backgroundSecondary.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: CRBTheme.Radius.md)
                        .stroke(myLocked ? CRBTheme.Colors.buyGreen.opacity(0.2) : CRBTheme.Colors.cardBorder, lineWidth: 1)
                )
                
                // Counterparty Leg Status Card
                HStack {
                    PillBadge(text: "Counterparty Deposit".localized, color: otherLocked ? CRBTheme.Colors.buyGreen : CRBTheme.Colors.muted)
                    Spacer()
                    if otherLocked {
                        Text("Locked ✓".localized)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(CRBTheme.Colors.buyGreen)
                    } else if isSeller && (trade.USDTSeen ?? false) {
                        Text("USDT Detected".localized)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(CRBTheme.Colors.warning)
                    } else if !isSeller && (trade.CRBSeen ?? false) {
                        Text(String(format: "Confirming (%d/10)".localized, trade.CRBConfs ?? 0))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(CRBTheme.Colors.warning)
                    } else {
                        Text("Awaiting Deposit".localized)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(CRBTheme.Colors.muted)
                    }
                }
                .padding(CRBTheme.Spacing.md)
                .background(CRBTheme.Colors.backgroundSecondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: CRBTheme.Radius.md)
                        .stroke(CRBTheme.Colors.cardBorder, lineWidth: 1)
                )
            }
            .glassCard()
        }
    }
    
    private func stateColor(_ state: String) -> Color {
        switch state {
        case "AWAITING_READY", "AWAITING_LOCK": return CRBTheme.Colors.warning
        case "COMPLETED": return CRBTheme.Colors.buyGreen
        case "CANCELLED", "REFUNDED", "EXPIRED": return CRBTheme.Colors.error
        default: return CRBTheme.Colors.muted
        }
    }
    
    private func matchingUSDTWallets(for trade: P2PTrade, role: P2PWalletBinding.Role) -> [USDTWallet] {
        let rail = trade.Rail ?? ""
        let railWallets = appState.linkedUSDTWallets.filter { $0.network.p2pRail == rail.lowercased() }
        guard let boundWallet = boundUSDTWallet(for: trade, role: role) else {
            return railWallets
        }
        return [boundWallet] + railWallets.filter { $0.id != boundWallet.id }
    }

    private func boundUSDTWallet(for trade: P2PTrade, role: P2PWalletBinding.Role) -> USDTWallet? {
        guard let tradeId = trade.ID else { return nil }
        if let boundWallet = appState.p2pBoundUSDTWallet(kind: .trade, p2pId: tradeId, role: role) {
            return boundWallet
        }
        guard let usdtAddress = role == .maker ? trade.MakerUSDT : trade.TakerUSDT else {
            return nil
        }
        return appState.linkedUSDTWallets.first {
            $0.address.caseInsensitiveCompare(usdtAddress) == .orderedSame &&
            $0.network.p2pRail == trade.Rail?.lowercased()
        }
    }

    private func bindLoadedTradeWalletIfPossible(_ trade: P2PTrade) {
        guard let tradeId = trade.ID else { return }
        let isMaker = trade.MakerAddr == appState.selectedWallet?.address
        let isTaker = trade.TakerAddr == appState.selectedWallet?.address
        guard isMaker || isTaker else { return }

        let role: P2PWalletBinding.Role = isMaker ? .maker : .taker
        guard appState.p2pBinding(kind: .trade, p2pId: tradeId, role: role) == nil else {
            return
        }
        guard let usdtAddress = isMaker ? trade.MakerUSDT : trade.TakerUSDT,
              let wallet = appState.linkedUSDTWallets.first(where: {
                  $0.address.caseInsensitiveCompare(usdtAddress) == .orderedSame &&
                  $0.network.p2pRail == trade.Rail?.lowercased()
              }) else {
            return
        }

        appState.bindP2PWallet(
            kind: .trade,
            p2pId: tradeId,
            role: role,
            usdtAddress: wallet.address,
            usdtNetwork: wallet.network,
            usdtWalletId: wallet.id
        )
    }

    private var liveMarketPrice: Decimal? {
        if let price = appState.p2pStats?.price_usdt, price > 0 {
            return price
        }
        if appState.cachedCRBPriceUSDT > 0 {
            return appState.cachedCRBPriceUSDT
        }
        return nil
    }

    private var selectedFiatRate: Decimal {
        let currency = appState.selectedFiatCurrency
        return appState.cachedFXRates[currency] ?? CurrencyManager.fallbackRates[currency] ?? 1
    }

    private func ratePill(_ label: String, _ value: Double) -> some View {
        let positive = value >= 0
        return Text("\(label) \(positive ? "+" : "")\(String(format: "%.2f", value))%")
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(positive ? CRBTheme.Colors.buyGreen : CRBTheme.Colors.sellRed)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background((positive ? CRBTheme.Colors.buyGreen : CRBTheme.Colors.sellRed).opacity(0.08))
            .clipShape(Capsule())
    }

    private func refreshLiveRates(includeFiat: Bool) async {
        await appState.refreshP2PStats()
        if includeFiat {
            await appState.refreshFiatRates()
        }
    }

    private func railReceiveLabel(_ rail: String) -> String {
        rail.lowercased() == "solana" ? "Solana USDT" : "Polygon USDT"
    }

    private func payNativeUSDTEscrow(wallet: USDTWallet, escrowAddr: String, amount: String, fallbackPassword: String? = nil) {
        guard let amountDecimal = Decimal(string: amount), amountDecimal > 0 else {
            actionError = "Invalid USDT amount"
            return
        }

        actionError = nil
        Task {
            do {
                _ = try await USDTTransferService.sendSecure(
                    wallet: wallet,
                    to: escrowAddr,
                    amount: amountDecimal,
                    fallbackPassword: fallbackPassword
                )
                usdtFallbackWalletId = nil
                usdtFallbackPassword = ""
            } catch WalletSecurityStore.SecurityError.passwordRequired {
                usdtFallbackWalletId = wallet.id
                usdtFallbackPassword = ""
                actionError = "Face ID failed. Please enter your wallet password."
            } catch {
                actionError = error.localizedDescription
            }
        }
    }

    private func copyEscrowPayment(address: String, amount: String, asset: String) {
        UIPasteboard.general.string = "\(asset) \(amount)\n\(address)"
    }

    private struct EscrowCopyRequest {
        let address: String
        let amount: String
        let asset: String
        let network: String
    }

    private struct EscrowPaymentRequest {
        let wallet: USDTWallet
        let address: String
        let amount: String
        let network: String
        let fallbackPassword: String?
    }
}

#Preview {
    NavigationStack {
        P2PTradeView(tradeId: "test-123")
            .environment(AppState())
    }
}
