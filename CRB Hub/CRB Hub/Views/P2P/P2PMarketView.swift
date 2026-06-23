import SwiftUI

struct P2PMarketView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = P2PViewModel()
    @State private var selectedTab = 0
    @State private var showLogin = false
    @State private var showOffers = false
    @State private var pulse = false
    @State private var searchQuery = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                CRBTheme.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: CRBTheme.Spacing.lg) {
                        // Market ticker
                        tickerSection
                        
                        // Trading status
                        tradingStatusBadge
                        
                        // Tab selector
                        tabSelector
                        
                        // Content
                        switch selectedTab {
                        case 0:
                            orderBookSection
                        case 1:
                            recentTradesSection
                        default:
                            marketInfoSection
                        }
                    }
                    .padding(CRBTheme.Spacing.lg)
                }
                .refreshable {
                    await viewModel.loadPublicData()
                }
            }
            .navigationTitle("P2P Market".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if appState.isP2PLoggedIn {
                        Button {
                            showOffers = true
                        } label: {
                            Image(systemName: "list.bullet.rectangle")
                                .foregroundColor(CRBTheme.Colors.cyan)
                        }
                    } else {
                        Button {
                            showLogin = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "person.badge.key")
                                Text("LOGIN".localized)
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(CRBTheme.Colors.cyan)
                        }
                    }
                }
            }
            .task {
                await viewModel.loadPublicData()
                viewModel.startPublicRefresh()
            }
            .onDisappear {
                viewModel.stopAutoRefresh()
            }
            .navigationDestination(isPresented: $showLogin) {
                P2PLoginView()
            }
            .navigationDestination(isPresented: $showOffers) {
                P2POffersView()
            }
        }
    }
    
    // MARK: - Ticker
    
    private var tickerSection: some View {
        VStack(spacing: CRBTheme.Spacing.md) {
            if let stats = viewModel.stats {
                // Price hero
                VStack(spacing: CRBTheme.Spacing.sm) {
                    HStack(spacing: 8) {
                        Text("CRB / USDT")
                            .font(CRBTheme.Typography.caption())
                            .foregroundColor(CRBTheme.Colors.muted)
                        
                        // Live Pulse Dot
                        HStack(spacing: 4) {
                            Circle()
                                .fill(CRBTheme.Colors.buyGreen)
                                .frame(width: 6, height: 6)
                                .scaleEffect(pulse ? 1.4 : 1.0)
                                .opacity(pulse ? 0.4 : 1.0)
                                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulse)
                            Text("Live Sync".localized)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(CRBTheme.Colors.buyGreen)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(CRBTheme.Colors.buyGreen.opacity(0.08))
                        .clipShape(Capsule())
                        .onAppear { pulse = true }
                    }
                    
                    Text(CRBUnits.formatUSDT(stats.price_usdt ?? 0))
                        .font(.system(size: 36, weight: .heavy, design: .monospaced))
                        .foregroundStyle(CRBTheme.Gradients.primary)
                    
                    FiatValueView(baseUnits: 100_000_000)
                    
                    HStack(spacing: CRBTheme.Spacing.lg) {
                        changeLabel("24h".localized, stats.change_24h_pct ?? 0)
                        changeLabel("7d".localized, stats.change_7d_pct ?? 0)
                    }
                    
                    // Price Trend Chart Widget
                    PriceTrendChartView(prices: viewModel.priceHistory)
                        .frame(height: 60)
                        .padding(.horizontal, CRBTheme.Spacing.xs)
                        .padding(.vertical, CRBTheme.Spacing.sm)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, CRBTheme.Spacing.sm)
                
                // Quick stats
                HStack(spacing: CRBTheme.Spacing.md) {
                    VStack(spacing: 2) {
                        Text("24h High".localized)
                            .font(.system(size: 10))
                            .foregroundColor(CRBTheme.Colors.muted)
                        Text(CRBUnits.formatUSDT(stats.high_24h_usdt ?? 0))
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(CRBTheme.Colors.buyGreen)
                    }
                    
                    Divider().frame(height: 30).background(CRBTheme.Colors.cardBorder)
                    
                    VStack(spacing: 2) {
                        Text("24h Low".localized)
                            .font(.system(size: 10))
                            .foregroundColor(CRBTheme.Colors.muted)
                        Text(CRBUnits.formatUSDT(stats.low_24h_usdt ?? 0))
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(CRBTheme.Colors.sellRed)
                    }
                    
                    Divider().frame(height: 30).background(CRBTheme.Colors.cardBorder)
                    
                    VStack(spacing: 2) {
                        Text("24h Vol".localized)
                            .font(.system(size: 10))
                            .foregroundColor(CRBTheme.Colors.muted)
                        Text(CRBUnits.formatUSDT(stats.volume_24h_usdt ?? 0))
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(CRBTheme.Colors.ink)
                    }
                    
                    Divider().frame(height: 30).background(CRBTheme.Colors.cardBorder)
                    
                    VStack(spacing: 2) {
                        Text("Workers".localized)
                            .font(.system(size: 10))
                            .foregroundColor(CRBTheme.Colors.muted)
                        Text("\(stats.trades_24h ?? 0)")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(CRBTheme.Colors.ink)
                    }
                }
            } else if viewModel.isLoadingPublic {
                LoadingView(message: "Loading...".localized)
                    .padding(.vertical, CRBTheme.Spacing.xl)
            }
        }
        .glassCard()
    }
    
    private func changeLabel(_ label: String, _ pct: Double) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(CRBTheme.Colors.muted)
            
            Text(String(format: "%+.1f%%", pct))
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(pct >= 0 ? CRBTheme.Colors.buyGreen : CRBTheme.Colors.sellRed)
        }
    }
    
    // MARK: - Trading Status
    
    private var tradingStatusBadge: some View {
        Group {
            if let state = viewModel.state {
                HStack(spacing: CRBTheme.Spacing.sm) {
                    Circle()
                        .fill(state.tradingOpen == true ? CRBTheme.Colors.buyGreen : CRBTheme.Colors.error)
                        .frame(width: 8, height: 8)
                    
                    Text(state.tradingOpen == true ? "Active".localized : "Idle".localized)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(state.tradingOpen == true ? CRBTheme.Colors.buyGreen : CRBTheme.Colors.error)
                    
                    Spacer()
                    
                    Text("Mode: \(state.mode ?? "—")")
                        .font(.system(size: 11))
                        .foregroundColor(CRBTheme.Colors.muted)
                    
                    Text(String(format: "%@ offers".localized, "\(state.offers ?? 0)"))
                        .font(.system(size: 11))
                        .foregroundColor(CRBTheme.Colors.muted)
                }
                .padding(CRBTheme.Spacing.md)
                .background((state.tradingOpen == true ? CRBTheme.Colors.buyGreen : CRBTheme.Colors.error).opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
            }
        }
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            tabButton("Order Book".localized, index: 0)
            tabButton("Recent".localized, index: 1)
            tabButton("Info".localized, index: 2)
        }
        .background(CRBTheme.Colors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: CRBTheme.Radius.md)
                .stroke(CRBTheme.Colors.cardBorder, lineWidth: 1)
        )
    }
    
    private func tabButton(_ title: String, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = index }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(selectedTab == index ? Color(hex: 0x06121F) : CRBTheme.Colors.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, CRBTheme.Spacing.md)
                .background(selectedTab == index ? CRBTheme.Gradients.primary : LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing))
                .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.md))
        }
    }
    
    // MARK: - Order Book
    
    // MARK: - Filtered Offers
    
    private var filteredSellOffers: [P2POffer] {
        if searchQuery.isEmpty {
            return viewModel.sellOffers
        } else {
            return viewModel.sellOffers.filter { offer in
                (offer.Rail?.localizedCaseInsensitiveContains(searchQuery) ?? false) ||
                (offer.Info?.localizedCaseInsensitiveContains(searchQuery) ?? false)
            }
        }
    }
    
    private var filteredBuyOffers: [P2POffer] {
        if searchQuery.isEmpty {
            return viewModel.buyOffers
        } else {
            return viewModel.buyOffers.filter { offer in
                (offer.Rail?.localizedCaseInsensitiveContains(searchQuery) ?? false) ||
                (offer.Info?.localizedCaseInsensitiveContains(searchQuery) ?? false)
            }
        }
    }

    private var orderBookSection: some View {
        VStack(alignment: .leading, spacing: CRBTheme.Spacing.md) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(CRBTheme.Colors.muted)
                
                TextField("Search by payment network...".localized, text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(CRBTheme.Colors.ink)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(CRBTheme.Colors.muted)
                    }
                }
            }
            .padding(CRBTheme.Spacing.sm)
            .background(CRBTheme.Colors.backgroundSecondary.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: CRBTheme.Radius.sm)
                    .stroke(CRBTheme.Colors.cardBorder, lineWidth: 1)
            )
            .padding(.bottom, 4)

            if viewModel.offers.isEmpty {
                EmptyStateView(icon: "book.closed", title: "No Offers".localized, message: "The order book is empty right now".localized)
            } else {
                // Sell offers (asks)
                if !filteredSellOffers.isEmpty {
                    SectionHeader(title: "Sell Offers".localized, icon: "arrow.down")
                    ForEach(filteredSellOffers) { offer in
                        offerRow(offer)
                    }
                }
                
                // Buy offers (bids)
                if !filteredBuyOffers.isEmpty {
                    SectionHeader(title: "Buy Offers".localized, icon: "arrow.up")
                    ForEach(filteredBuyOffers) { offer in
                        offerRow(offer)
                    }
                }
                
                if filteredSellOffers.isEmpty && filteredBuyOffers.isEmpty {
                    EmptyStateView(icon: "magnifyingglass", title: "No Results".localized, message: "No offers match your search criteria".localized)
                }
            }
        }
        .glassCard()
    }
    
    private func offerRow(_ offer: P2POffer) -> some View {
        let currency = appState.selectedFiatCurrency
        let rates = appState.cachedFXRates
        let rate = rates[currency] ?? CurrencyManager.fallbackRates[currency] ?? 1.0
        let price = offer.Price ?? 0
        let priceInFiat = price * Decimal(rate)
        
        return HStack(spacing: CRBTheme.Spacing.md) {
            // Side badge
            PillBadge(
                text: offer.isSellCRB ? "SELLOffers".localized : "BUYOffers".localized,
                color: offer.isSellCRB ? CRBTheme.Colors.sellRed : CRBTheme.Colors.buyGreen
            )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(CRBUnits.formatUSDT(price))
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(CRBTheme.Colors.ink)
                
                Text("≈ " + CurrencyManager.formatFiat(priceInFiat, currencyCode: currency))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(CRBTheme.Colors.muted)
                
                Text("\(CRBUnits.formatDecimal(offer.MinCRB ?? 0, maxFractionDigits: 2, minFractionDigits: 2)) - \(CRBUnits.formatDecimal(offer.MaxCRB ?? 0, maxFractionDigits: 2, minFractionDigits: 2)) CRB")
                    .font(.system(size: 11))
                    .foregroundColor(CRBTheme.Colors.muted.opacity(0.8))
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                PillBadge(text: offer.railLabel, color: CRBTheme.Colors.violet)
                
                if offer.Olympus == true {
                    PillBadge(text: "🏛 Olympus", color: CRBTheme.Colors.warning)
                }
            }
        }
        .padding(CRBTheme.Spacing.md)
        .background(CRBTheme.Colors.backgroundSecondary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
    }
    
    // MARK: - Recent Trades
    
    private var recentTradesSection: some View {
        VStack(alignment: .leading, spacing: CRBTheme.Spacing.md) {
            SectionHeader(title: "Recent Trades".localized, icon: "clock")
            
            if viewModel.recentTrades.isEmpty {
                EmptyStateView(icon: "clock", title: "No history found".localized, message: "Your transaction history will appear here".localized)
            } else {
                let currency = appState.selectedFiatCurrency
                let rates = appState.cachedFXRates
                let rate = rates[currency] ?? CurrencyManager.fallbackRates[currency] ?? 1.0
                
                ForEach(viewModel.recentTrades) { trade in
                    let tradePriceInFiat = (trade.Price ?? 0) * Decimal(rate)
                    let valInFiat = (trade.AmountUSDT ?? 0) * Decimal(rate)
                    
                    HStack(spacing: CRBTheme.Spacing.md) {
                        PillBadge(
                            text: trade.Side == "sell_crb" ? "SELLOffers".localized : "BUYOffers".localized,
                            color: trade.Side == "sell_crb" ? CRBTheme.Colors.sellRed : CRBTheme.Colors.buyGreen
                        )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(CRBUnits.formatDecimal(trade.AmountCRB ?? 0, maxFractionDigits: 4, minFractionDigits: 4)) CRB")
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .foregroundColor(CRBTheme.Colors.ink)
                            
                            Text("@ \(CRBUnits.formatUSDT(trade.Price ?? 0)) (≈ \(CurrencyManager.formatFiat(tradePriceInFiat, currencyCode: currency)))")
                                .font(.system(size: 11))
                                .foregroundColor(CRBTheme.Colors.muted)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(CRBUnits.formatUSDT(trade.AmountUSDT ?? 0))
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(CRBTheme.Colors.ink)
                            
                            Text("≈ " + CurrencyManager.formatFiat(valInFiat, currencyCode: currency))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(CRBTheme.Colors.muted)
                            
                            Text(trade.formattedTime)
                                .font(.system(size: 10))
                                .foregroundColor(CRBTheme.Colors.muted.opacity(0.8))
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
    
    // MARK: - Market Info
    
    private var marketInfoSection: some View {
        VStack(alignment: .leading, spacing: CRBTheme.Spacing.md) {
            if let stats = viewModel.stats {
                SectionHeader(title: "Info".localized, icon: "chart.bar.fill")
                
                let currency = appState.selectedFiatCurrency
                let rates = appState.cachedFXRates
                let rate = rates[currency] ?? CurrencyManager.fallbackRates[currency] ?? 1.0
                
                let marketCapFiat = stats.market_cap_usdt.map {
                    "≈ " + CurrencyManager.formatFiat($0 * Decimal(rate), currencyCode: currency)
                }
                let emissionUSDTFiat = stats.emission_24h_usdt.map {
                    "≈ " + CurrencyManager.formatFiat($0 * Decimal(rate), currencyCode: currency)
                }
                let totalUSDTFiat = stats.volume_total_usdt.map {
                    "≈ " + CurrencyManager.formatFiat($0 * Decimal(rate), currencyCode: currency)
                }
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: CRBTheme.Spacing.md) {
                    StatCard(icon: "chart.pie", label: "Market Cap".localized, value: CRBUnits.formatUSDT(stats.market_cap_usdt ?? 0), subtitle: marketCapFiat)
                    StatCard(icon: "coins", label: "Circulating Supply".localized, value: CRBUnits.formatLargeNumber(stats.circulating_supply_crb ?? 0) + " CRB", color: CRBTheme.Colors.violet)
                    StatCard(icon: "infinity", label: "Max Supply".localized, value: CRBUnits.formatLargeNumber(stats.max_supply_crb ?? 0) + " CRB", color: CRBTheme.Colors.info)
                    StatCard(icon: "percent", label: "Percent Mined".localized, value: String(format: "%.2f%%", stats.percent_mined ?? 0), color: CRBTheme.Colors.warning)
                    StatCard(icon: "cube.fill", label: "Block Reward".localized, value: CRBUnits.formatDecimal(stats.block_reward_crb ?? 0, maxFractionDigits: 0, minFractionDigits: 0) + " CRB", color: CRBTheme.Colors.buyGreen)
                    StatCard(icon: "clock", label: "Block Time".localized, value: "\(stats.block_time_secs ?? 60)s", color: CRBTheme.Colors.muted)
                    StatCard(icon: "flame", label: "Emission 24h".localized, value: CRBUnits.formatDecimal(stats.emission_24h_crb ?? 0, maxFractionDigits: 0, minFractionDigits: 0) + " CRB", color: CRBTheme.Colors.sellRed)
                    StatCard(icon: "dollarsign.circle", label: "Emission USDT".localized, value: CRBUnits.formatUSDT(stats.emission_24h_usdt ?? 0), color: CRBTheme.Colors.cyan, subtitle: emissionUSDTFiat)
                }
                
                // Volume stats
                SectionHeader(title: "All-Time Volume".localized, icon: "chart.line.uptrend.xyaxis")
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: CRBTheme.Spacing.md) {
                    StatCard(icon: "arrow.left.arrow.right", label: "Total CRB".localized, value: CRBUnits.formatLargeNumber(stats.volume_total_crb ?? 0) + " CRB", color: CRBTheme.Colors.cyan)
                    StatCard(icon: "dollarsign", label: "Total USDT".localized, value: CRBUnits.formatUSDT(stats.volume_total_usdt ?? 0), color: CRBTheme.Colors.buyGreen, subtitle: totalUSDTFiat)
                    StatCard(icon: "number", label: "Tx Count".localized, value: "\(stats.trades_total ?? 0)", color: CRBTheme.Colors.violet)
                }
            }
        }
        .glassCard()
    }
}

struct PriceTrendChartView: View {
    let prices: [Double]
    
    var body: some View {
        GeometryReader { geometry in
            let path = getPath(for: prices, in: geometry.size)
            let closedPath = getClosedPath(for: prices, in: geometry.size)
            
            ZStack {
                // Gradient fill
                closedPath
                    .fill(
                        LinearGradient(
                            colors: [CRBTheme.Colors.cyan.opacity(0.12), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                // Line path
                path
                    .stroke(
                        CRBTheme.Gradients.primary,
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                    )
            }
        }
    }
    
    private func getPath(for values: [Double], in size: CGSize) -> Path {
        var path = Path()
        guard values.count > 1 else { return path }
        
        let minVal = values.min() ?? 0
        let maxVal = values.max() ?? 1
        let range = maxVal - minVal == 0 ? 1 : maxVal - minVal
        
        let stepX = size.width / CGFloat(values.count - 1)
        
        for i in 0..<values.count {
            let x = CGFloat(i) * stepX
            let y = size.height - CGFloat((values[i] - minVal) / range) * size.height
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
    
    private func getClosedPath(for values: [Double], in size: CGSize) -> Path {
        var path = getPath(for: values, in: size)
        guard values.count > 1 else { return path }
        
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.addLine(to: CGPoint(x: 0, y: size.height))
        path.closeSubpath()
        return path
    }
}

#Preview {
    P2PMarketView()
        .environment(AppState())
}
