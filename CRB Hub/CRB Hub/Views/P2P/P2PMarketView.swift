import SwiftUI

struct P2PMarketView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = P2PViewModel()
    @State private var selectedTab = 0
    @State private var showLogin = false
    @State private var showOffers = false
    
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
                    Text("CRB / USDT")
                        .font(CRBTheme.Typography.caption())
                        .foregroundColor(CRBTheme.Colors.muted)
                    
                    Text(CRBUnits.formatUSDT(stats.price_usdt ?? 0))
                        .font(.system(size: 36, weight: .heavy, design: .monospaced))
                        .foregroundStyle(CRBTheme.Gradients.primary)
                    
                    FiatValueView(baseUnits: 100_000_000)
                    
                    HStack(spacing: CRBTheme.Spacing.lg) {
                        changeLabel("24h".localized, stats.change_24h_pct ?? 0)
                        changeLabel("7d".localized, stats.change_7d_pct ?? 0)
                    }
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
    
    private var orderBookSection: some View {
        VStack(alignment: .leading, spacing: CRBTheme.Spacing.md) {
            if viewModel.offers.isEmpty {
                EmptyStateView(icon: "book.closed", title: "No Offers".localized, message: "The order book is empty right now".localized)
            } else {
                // Sell offers (asks)
                if !viewModel.sellOffers.isEmpty {
                    SectionHeader(title: "Sell Offers".localized, icon: "arrow.down")
                    ForEach(viewModel.sellOffers) { offer in
                        offerRow(offer)
                    }
                }
                
                // Buy offers (bids)
                if !viewModel.buyOffers.isEmpty {
                    SectionHeader(title: "Buy Offers".localized, icon: "arrow.up")
                    ForEach(viewModel.buyOffers) { offer in
                        offerRow(offer)
                    }
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
        let priceInFiat = price * rate
        
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
                
                Text("≈ " + CurrencyManager.formatFiat(Decimal(priceInFiat), currencyCode: currency))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(CRBTheme.Colors.muted)
                
                Text("\(String(format: "%.2f", offer.MinCRB ?? 0)) - \(String(format: "%.2f", offer.MaxCRB ?? 0)) CRB")
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
                    let tradePriceInFiat = (trade.Price ?? 0) * rate
                    let valInFiat = (trade.AmountUSDT ?? 0) * rate
                    
                    HStack(spacing: CRBTheme.Spacing.md) {
                        PillBadge(
                            text: trade.Side == "sell_crb" ? "SELLOffers".localized : "BUYOffers".localized,
                            color: trade.Side == "sell_crb" ? CRBTheme.Colors.sellRed : CRBTheme.Colors.buyGreen
                        )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(String(format: "%.4f", trade.AmountCRB ?? 0)) CRB")
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .foregroundColor(CRBTheme.Colors.ink)
                            
                            Text("@ \(CRBUnits.formatUSDT(trade.Price ?? 0)) (≈ \(CurrencyManager.formatFiat(Decimal(tradePriceInFiat), currencyCode: currency)))")
                                .font(.system(size: 11))
                                .foregroundColor(CRBTheme.Colors.muted)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(CRBUnits.formatUSDT(trade.AmountUSDT ?? 0))
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(CRBTheme.Colors.ink)
                            
                            Text("≈ " + CurrencyManager.formatFiat(Decimal(valInFiat), currencyCode: currency))
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
                    "≈ " + CurrencyManager.formatFiat(Decimal($0 * rate), currencyCode: currency)
                }
                let emissionUSDTFiat = stats.emission_24h_usdt.map {
                    "≈ " + CurrencyManager.formatFiat(Decimal($0 * rate), currencyCode: currency)
                }
                let totalUSDTFiat = stats.volume_total_usdt.map {
                    "≈ " + CurrencyManager.formatFiat(Decimal($0 * rate), currencyCode: currency)
                }
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: CRBTheme.Spacing.md) {
                    StatCard(icon: "chart.pie", label: "Market Cap".localized, value: CRBUnits.formatUSDT(stats.market_cap_usdt ?? 0), subtitle: marketCapFiat)
                    StatCard(icon: "coins", label: "Circulating Supply".localized, value: CRBUnits.formatLargeNumber(stats.circulating_supply_crb ?? 0) + " CRB", color: CRBTheme.Colors.violet)
                    StatCard(icon: "infinity", label: "Max Supply".localized, value: CRBUnits.formatLargeNumber(stats.max_supply_crb ?? 0) + " CRB", color: CRBTheme.Colors.info)
                    StatCard(icon: "percent", label: "Percent Mined".localized, value: String(format: "%.2f%%", stats.percent_mined ?? 0), color: CRBTheme.Colors.warning)
                    StatCard(icon: "cube.fill", label: "Block Reward".localized, value: String(format: "%.0f CRB", stats.block_reward_crb ?? 0), color: CRBTheme.Colors.buyGreen)
                    StatCard(icon: "clock", label: "Block Time".localized, value: "\(stats.block_time_secs ?? 60)s", color: CRBTheme.Colors.muted)
                    StatCard(icon: "flame", label: "Emission 24h".localized, value: String(format: "%.0f CRB", stats.emission_24h_crb ?? 0), color: CRBTheme.Colors.sellRed)
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

#Preview {
    P2PMarketView()
        .environment(AppState())
}
