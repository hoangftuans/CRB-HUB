import SwiftUI

struct P2POffersView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = P2PViewModel()
    @State private var showCreateOffer = false
    @State private var selectedTradeId: String?
    
    var body: some View {
        ZStack {
            CRBTheme.Colors.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: CRBTheme.Spacing.xl) {
                    // My offers
                    myOffersSection
                    
                    // My trades
                    myTradesSection
                }
                .padding(CRBTheme.Spacing.lg)
            }
            .refreshable {
                if let token = appState.p2pToken {
                    await viewModel.loadMyData(token: token)
                }
            }
        }
        .navigationTitle("P2P Offers".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateOffer = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(CRBTheme.Colors.cyan)
                }
            }
        }
        .task {
            if let token = appState.p2pToken {
                await viewModel.loadMyData(token: token)
            }
        }
        .sheet(isPresented: $showCreateOffer) {
            createOfferSheet
        }
        .navigationDestination(item: $selectedTradeId) { tradeId in
            P2PTradeView(tradeId: tradeId)
        }
    }
    
    // MARK: - My Offers
    
    private var myOffersSection: some View {
        VStack(alignment: .leading, spacing: CRBTheme.Spacing.md) {
            SectionHeader(title: "My Offers".localized, icon: "tag.fill")
            
            if viewModel.myOffers.isEmpty {
                EmptyStateView(icon: "tag", title: "No Offers".localized, message: "Create an offer to start trading".localized)
            } else {
                ForEach(viewModel.myOffers) { offer in
                    HStack(spacing: CRBTheme.Spacing.md) {
                        PillBadge(
                            text: offer.sideLabel,
                            color: offer.isSellCRB ? CRBTheme.Colors.sellRed : CRBTheme.Colors.buyGreen
                        )
                        
                        let currency = appState.selectedFiatCurrency
                        let rates = appState.cachedFXRates
                        let rate = rates[currency] ?? CurrencyManager.fallbackRates[currency] ?? 1.0
                        let offerPriceFiat = (offer.Price ?? 0) * Decimal(rate)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(CRBUnits.formatUSDT(offer.Price ?? 0))
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(CRBTheme.Colors.ink)
                            
                            Text("≈ " + CurrencyManager.formatFiat(offerPriceFiat, currencyCode: currency))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(CRBTheme.Colors.muted)
                            
                            Text("\(CRBUnits.formatDecimal(offer.MinCRB ?? 0, maxFractionDigits: 2, minFractionDigits: 2)) - \(CRBUnits.formatDecimal(offer.MaxCRB ?? 0, maxFractionDigits: 2, minFractionDigits: 2)) CRB")
                                .font(.system(size: 11))
                                .foregroundColor(CRBTheme.Colors.muted.opacity(0.8))
                        }
                        
                        Spacer()
                        
                        // Cancel button
                        Button {
                            Task {
                                if let token = appState.p2pToken {
                                    try? await viewModel.cancelOffer(token: token, offerId: offer.ID)
                                }
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(CRBTheme.Colors.error.opacity(0.7))
                        }
                    }
                    .padding(CRBTheme.Spacing.md)
                    .background(CRBTheme.Colors.backgroundSecondary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
                }
            }
        }
        .glassCard()
    }
    
    // MARK: - My Trades
    
    private var myTradesSection: some View {
        VStack(alignment: .leading, spacing: CRBTheme.Spacing.md) {
            SectionHeader(title: "My Trades".localized, icon: "arrow.left.arrow.right")
            
            if viewModel.myTrades.isEmpty {
                EmptyStateView(icon: "arrow.left.arrow.right", title: "No Trades".localized, message: "Take an offer from the order book to start a trade".localized)
            } else {
                ForEach(viewModel.myTrades) { trade in
                    Button {
                        selectedTradeId = trade.ID
                    } label: {
                        let currency = appState.selectedFiatCurrency
                        let rates = appState.cachedFXRates
                        let rate = rates[currency] ?? CurrencyManager.fallbackRates[currency] ?? 1.0
                        
                        HStack(spacing: CRBTheme.Spacing.md) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    PillBadge(text: trade.stateLabel.localized, color: stateColor(trade.State ?? ""))
                                    PillBadge(text: trade.Side == "sell_crb" ? "SELLOffers".localized : "BUYOffers".localized,
                                            color: trade.Side == "sell_crb" ? CRBTheme.Colors.sellRed : CRBTheme.Colors.buyGreen)
                                }
                                
                                Text("\(CRBUnits.formatDecimal(trade.AmountCRB ?? 0, maxFractionDigits: 4, minFractionDigits: 4)) CRB @ \(CRBUnits.formatUSDT(trade.Price ?? 0))")
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundColor(CRBTheme.Colors.ink)
                                
                                Text("≈ " + CurrencyManager.formatFiat((trade.AmountUSDT ?? 0) * Decimal(rate), currencyCode: currency))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(CRBTheme.Colors.muted)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(CRBTheme.Colors.muted)
                        }
                        .padding(CRBTheme.Spacing.md)
                        .background(CRBTheme.Colors.backgroundSecondary.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
                    }
                }
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
    
    // MARK: - Create Offer Sheet
    
    @State private var offerSide = "sell_crb"
    @State private var offerRail = "polygon"
    @State private var offerPrice = ""
    @State private var offerMinCRB = ""
    @State private var offerMaxCRB = ""
    @State private var offerMakerUSDT = ""
    @State private var offerInfo = ""
    @State private var isCreatingOffer = false
    @State private var createOfferError: String?
    
    private var createOfferSheet: some View {
        NavigationStack {
            ZStack {
                CRBTheme.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: CRBTheme.Spacing.lg) {
                        // Side picker
                        HStack(spacing: CRBTheme.Spacing.md) {
                            sideButton("Sell Offers".localized, value: "sell_crb", color: CRBTheme.Colors.sellRed)
                            sideButton("Buy Offers".localized, value: "buy_crb", color: CRBTheme.Colors.buyGreen)
                        }
                        
                        // Rail picker
                        HStack(spacing: CRBTheme.Spacing.md) {
                            railButton("Polygon", value: "polygon")
                            railButton("Solana", value: "solana")
                        }
                        
                        // Price
                        inputField("Price (USDT)".localized, text: $offerPrice, placeholder: "0.00", keyboard: .decimalPad)
                        
                        // Min/Max CRB
                        HStack(spacing: CRBTheme.Spacing.md) {
                            inputField("Min CRB".localized, text: $offerMinCRB, placeholder: "0", keyboard: .decimalPad)
                            inputField("Max CRB".localized, text: $offerMaxCRB, placeholder: "0", keyboard: .decimalPad)
                        }
                        
                        // USDT address
                        inputField("Maker USDT Address".localized, text: $offerMakerUSDT, placeholder: "0x... or ...", keyboard: .default)
                        
                        // Info
                        inputField("Note (optional)".localized, text: $offerInfo, placeholder: "Any message for takers", keyboard: .default)
                        
                        if let error = createOfferError {
                            Text(error.localized)
                                .font(CRBTheme.Typography.caption())
                                .foregroundColor(CRBTheme.Colors.error)
                        }
                        
                        GradientButton(
                            title: isCreatingOffer ? "Loading...".localized : "Create Offer".localized,
                            icon: "plus.circle",
                            isDisabled: isCreatingOffer || offerPrice.isEmpty || offerMaxCRB.isEmpty
                        ) {
                            createOffer()
                        }
                    }
                    .padding(CRBTheme.Spacing.xl)
                }
            }
            .navigationTitle("Create Offer".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel".localized) { showCreateOffer = false }
                        .foregroundColor(CRBTheme.Colors.muted)
                }
            }
        }
    }
    
    private func sideButton(_ title: String, value: String, color: Color) -> some View {
        Button {
            withAnimation { offerSide = value }
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(offerSide == value ? .white : color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, CRBTheme.Spacing.md)
                .background(offerSide == value ? color : color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.md))
        }
    }
    
    private func railButton(_ title: String, value: String) -> some View {
        Button {
            withAnimation { offerRail = value }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(offerRail == value ? CRBTheme.Colors.ink : CRBTheme.Colors.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, CRBTheme.Spacing.sm)
                .background(offerRail == value ? CRBTheme.Colors.violet.opacity(0.15) : CRBTheme.Colors.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: CRBTheme.Radius.sm)
                        .stroke(offerRail == value ? CRBTheme.Colors.violet.opacity(0.3) : CRBTheme.Colors.cardBorder, lineWidth: 1)
                )
        }
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
                .padding(CRBTheme.Spacing.md)
                .background(CRBTheme.Colors.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: CRBTheme.Radius.sm)
                        .stroke(CRBTheme.Colors.cardBorder, lineWidth: 1)
                )
        }
    }
    
    private func createOffer() {
        guard let price = Decimal(string: offerPrice),
              let maxCRB = Decimal(string: offerMaxCRB),
              price > 0,
              maxCRB > 0 else {
            createOfferError = "Invalid price or amount"
            return
        }
        let minCRB = Decimal(string: offerMinCRB) ?? 0
        
        isCreatingOffer = true
        createOfferError = nil
        
        Task {
            do {
                if let token = appState.p2pToken {
                    let request = CreateOfferRequest(
                        side: offerSide,
                        rail: offerRail,
                        price: price,
                        minCRB: minCRB,
                        maxCRB: maxCRB,
                        makerUSDT: offerMakerUSDT.isEmpty ? nil : offerMakerUSDT,
                        info: offerInfo.isEmpty ? nil : offerInfo,
                        readySecs: nil,
                        olympus: nil
                    )
                    let _ = try await viewModel.createOffer(token: token, offer: request)
                    showCreateOffer = false
                }
            } catch {
                createOfferError = error.localizedDescription
            }
            isCreatingOffer = false
        }
    }
}

#Preview {
    NavigationStack {
        P2POffersView()
            .environment(AppState())
    }
}
