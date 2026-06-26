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
                    await viewModel.loadMyData(token: token, appState: appState)
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
                await viewModel.loadMyData(token: token, appState: appState)
                viewModel.startAuthenticatedRefresh(token: token, appState: appState)
            }
            await refreshLiveRates(includeFiat: true)
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }
                await refreshLiveRates(includeFiat: false)
            }
        }
        .onDisappear {
            viewModel.stopAutoRefresh()
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
                                text: offer.sideLabel.localized,
                                color: offer.isSellCRB ? CRBTheme.Colors.sellRed : CRBTheme.Colors.buyGreen
                            )
                            if appState.p2pBinding(kind: .offer, p2pId: offer.ID, role: .maker) != nil {
                                PillBadge(text: "Bound".localized, color: CRBTheme.Colors.buyGreen)
                            }

                            let currency = appState.selectedFiatCurrency
                        let rates = appState.cachedFXRates
                        let rate = rates[currency] ?? CurrencyManager.fallbackRates[currency] ?? 1
                        let offerPriceFiat = (offer.Price ?? 0) * rate
                        
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
                        let rate = rates[currency] ?? CurrencyManager.fallbackRates[currency] ?? 1
                        
                        HStack(spacing: CRBTheme.Spacing.md) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    PillBadge(text: trade.stateLabel.localized, color: stateColor(trade.State ?? ""))
                                    PillBadge(text: (trade.Side == "sell_crb" ? "SELL" : "BUY").localized,
                                            color: trade.Side == "sell_crb" ? CRBTheme.Colors.sellRed : CRBTheme.Colors.buyGreen)
                                }
                                
                                Text("\(CRBUnits.formatDecimal(trade.AmountCRB ?? 0, maxFractionDigits: 4, minFractionDigits: 4)) CRB @ \(CRBUnits.formatUSDT(trade.Price ?? 0))")
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundColor(CRBTheme.Colors.ink)
                                
                                Text("≈ " + CurrencyManager.formatFiat((trade.AmountUSDT ?? 0) * rate, currencyCode: currency))
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
    @State private var selectedMakerUSDTWalletId: UUID?
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
                            ForEach(USDTNetwork.p2pSupportedNetworks) { network in
                                if let rail = network.p2pRail {
                                    railButton(network.p2pReceiveLabel, value: rail)
                                }
                            }
                        }

                        liveRateCard

                        // Price
                        inputField("Price (USDT)".localized, text: $offerPrice, placeholder: "0.00", keyboard: .decimalPad)
                        
                        // Min/Max CRB
                        HStack(spacing: CRBTheme.Spacing.md) {
                            inputField("Min CRB".localized, text: $offerMinCRB, placeholder: "0", keyboard: .decimalPad)
                            inputField("Max CRB".localized, text: $offerMaxCRB, placeholder: "0", keyboard: .decimalPad)
                        }
                        
                        // USDT address
                        makerUSDTWalletPicker
                        inputField(String(format: "Maker %@ Receiving Address".localized, railReceiveLabel(offerRail)), text: $offerMakerUSDT, placeholder: railPlaceholder(offerRail), keyboard: .default)
                            .onChange(of: offerMakerUSDT) { _, newValue in
                                syncMakerWalletSelection(address: newValue, rail: offerRail)
                            }
                        
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
            .onAppear {
                if offerMakerUSDT.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    selectDefaultMakerWallet(for: offerRail)
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
            withAnimation {
                offerRail = value
                selectDefaultMakerWallet(for: value)
            }
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

    private var makerUSDTWalletPicker: some View {
        let wallets = matchingUSDTWallets(for: offerRail)

        return VStack(alignment: .leading, spacing: CRBTheme.Spacing.xs) {
            Text("Use Existing USDT Wallet".localized)
                .font(CRBTheme.Typography.caption())
                .foregroundColor(CRBTheme.Colors.muted)

            if wallets.isEmpty {
                Text(String(format: "No linked %@ wallet yet. Add one in Settings or paste a matching address manually.".localized, railReceiveLabel(offerRail)))
                    .font(.system(size: 12))
                    .foregroundColor(CRBTheme.Colors.warning)
                    .padding(CRBTheme.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(CRBTheme.Colors.warning.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
            } else {
                Menu {
                    ForEach(wallets) { wallet in
                        Button {
                            selectedMakerUSDTWalletId = wallet.id
                            offerMakerUSDT = wallet.address
                        } label: {
                            Text("\(wallet.name) • \(AddressValidator.truncatedAddress(wallet.address, leading: 8, trailing: 6))")
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "wallet.pass.fill")
                        Text(selectedMakerUSDTWalletLabel ?? "Select linked wallet".localized)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(CRBTheme.Colors.ink)
                    .padding(CRBTheme.Spacing.md)
                    .background(CRBTheme.Colors.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: CRBTheme.Radius.sm)
                            .stroke(CRBTheme.Colors.cardBorder, lineWidth: 1)
                    )
                }
            }
        }
    }

    private var selectedMakerUSDTWalletLabel: String? {
        guard let id = selectedMakerUSDTWalletId,
              let wallet = appState.linkedUSDTWallets.first(where: { $0.id == id }) else {
            return nil
        }
        return "\(wallet.name) • \(wallet.network.displayName)"
    }

    private func matchingUSDTWallets(for rail: String) -> [USDTWallet] {
        appState.linkedUSDTWallets.filter { $0.network.p2pRail == rail.lowercased() }
    }

    private func selectDefaultMakerWallet(for rail: String) {
        if let wallet = appState.defaultP2PUSDTWallet(for: rail) ?? matchingUSDTWallets(for: rail).first {
            selectedMakerUSDTWalletId = wallet.id
            offerMakerUSDT = wallet.address
        } else {
            selectedMakerUSDTWalletId = nil
            offerMakerUSDT = ""
        }
    }

    private func linkedUSDTWallet(address: String, rail: String) -> USDTWallet? {
        let cleanAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanAddress.isEmpty else { return nil }
        return appState.linkedUSDTWallets.first {
            $0.address.caseInsensitiveCompare(cleanAddress) == .orderedSame &&
            $0.network.p2pRail == rail.lowercased()
        }
    }

    private func syncMakerWalletSelection(address: String, rail: String) {
        if let wallet = linkedUSDTWallet(address: address, rail: rail) {
            selectedMakerUSDTWalletId = wallet.id
        } else if selectedMakerUSDTWalletId != nil {
            selectedMakerUSDTWalletId = nil
        }
    }

    private func railReceiveLabel(_ rail: String) -> String {
        rail.lowercased() == "solana" ? "Solana USDT" : "Polygon USDT"
    }

    private func railPlaceholder(_ rail: String) -> String {
        rail.lowercased() == "solana" ? "Solana address" : "0x..."
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

    private var liveRateCard: some View {
        let currency = appState.selectedFiatCurrency
        let marketPrice = liveMarketPrice ?? 0
        let marketFiat = marketPrice * selectedFiatRate
        let enteredPrice = Decimal(string: offerPrice) ?? marketPrice
        let maxCRB = Decimal(string: offerMaxCRB) ?? 0
        let estimatedUSDT = enteredPrice * maxCRB
        let estimatedFiat = estimatedUSDT * selectedFiatRate

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

                Button {
                    offerPrice = CRBUnits.formatDecimal(marketPrice, maxFractionDigits: 8, minFractionDigits: 0)
                } label: {
                    Image(systemName: "arrow.down.to.line.compact")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(CRBTheme.Colors.cyan)
                        .padding(8)
                        .background(CRBTheme.Colors.cyan.opacity(0.1))
                        .clipShape(Circle())
                }
                .disabled(liveMarketPrice == nil)
            }

            HStack(spacing: CRBTheme.Spacing.md) {
                ratePill("24h".localized, appState.p2pStats?.change_24h_pct ?? 0)
                ratePill("7d".localized, appState.p2pStats?.change_7d_pct ?? 0)
                Spacer()
            }

            if maxCRB > 0 {
                Text(String(format: "Max order value: %@ ≈ %@".localized, CRBUnits.formatUSDT(estimatedUSDT), CurrencyManager.formatFiat(estimatedFiat, currencyCode: currency)))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(CRBTheme.Colors.muted)
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
        let cleanMakerUSDT = offerMakerUSDT.trimmingCharacters(in: .whitespacesAndNewlines)
        let linkedWallet = linkedUSDTWallet(address: cleanMakerUSDT, rail: offerRail)
        guard !cleanMakerUSDT.isEmpty else {
            createOfferError = "Please select or enter a USDT wallet address"
            return
        }
        guard USDTNetwork.isValidP2PAddress(cleanMakerUSDT, rail: offerRail) else {
            createOfferError = String(format: "USDT wallet address must be a %@ address".localized, railReceiveLabel(offerRail))
            return
        }

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
                        makerUSDT: cleanMakerUSDT,
                        info: offerInfo.isEmpty ? nil : offerInfo,
                        readySecs: nil,
                        olympus: nil
                    )
                    let createdOffer = try await viewModel.createOffer(token: token, offer: request, appState: appState)
                    appState.bindP2PWallet(
                        kind: .offer,
                        p2pId: createdOffer.ID,
                        role: .maker,
                        usdtAddress: cleanMakerUSDT,
                        usdtNetwork: linkedWallet?.network ?? selectedMakerUSDTNetwork(for: offerRail, address: cleanMakerUSDT),
                        usdtWalletId: linkedWallet?.id ?? selectedMakerUSDTWalletId(for: cleanMakerUSDT)
                    )
                    showCreateOffer = false
                }
            } catch {
                createOfferError = error.localizedDescription
            }
            isCreatingOffer = false
        }
    }

    private func selectedMakerUSDTNetwork(for rail: String, address: String) -> USDTNetwork {
        if let id = selectedMakerUSDTWalletId,
           let wallet = appState.linkedUSDTWallets.first(where: {
               $0.id == id &&
               $0.address.caseInsensitiveCompare(address) == .orderedSame
           }) {
            return wallet.network
        }
        if let wallet = linkedUSDTWallet(address: address, rail: rail) {
            return wallet.network
        }
        return rail.lowercased() == "solana" ? .solana : .polygon
    }

    private func selectedMakerUSDTWalletId(for address: String) -> UUID? {
        linkedUSDTWallet(address: address, rail: offerRail)?.id
    }
}

#Preview {
    NavigationStack {
        P2POffersView()
            .environment(AppState())
    }
}
