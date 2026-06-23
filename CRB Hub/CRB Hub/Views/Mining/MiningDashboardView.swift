import SwiftUI

struct MiningDashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = MiningViewModel()
    @State private var showSetup = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                CRBTheme.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: CRBTheme.Spacing.lg) {
                        // My miner stats
                        myMinerSection
                        
                        // Workers
                        workersSection
                        
                        // Pool stats
                        poolStatsSection
                    }
                    .padding(CRBTheme.Spacing.lg)
                }
                .refreshable {
                    if let addr = appState.selectedWallet?.address {
                        await viewModel.loadAll(address: addr)
                    }
                }
            }
            .navigationTitle("Mining".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSetup = true
                    } label: {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .foregroundColor(CRBTheme.Colors.cyan)
                    }
                }
            }
            .task {
                if let addr = appState.selectedWallet?.address {
                    await viewModel.loadAll(address: addr)
                    viewModel.startAutoRefresh(address: addr)
                }
            }
            .onDisappear {
                viewModel.stopAutoRefresh()
            }
            .navigationDestination(isPresented: $showSetup) {
                MiningSetupView()
            }
        }
    }
    
    // MARK: - My Miner
    
    private var myMinerSection: some View {
        VStack(alignment: .leading, spacing: CRBTheme.Spacing.md) {
            SectionHeader(title: "My Stats".localized, icon: "hammer.fill")
            
            if viewModel.isLoadingStats && viewModel.myMiner == nil {
                LoadingView(message: "Loading...".localized)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, CRBTheme.Spacing.xl)
            } else if let miner = viewModel.myMiner {
                // Hashrate hero
                VStack(spacing: CRBTheme.Spacing.sm) {
                    Text(CRBUnits.formatHashrate(miner.hashrate))
                        .font(.system(size: 32, weight: .heavy, design: .monospaced))
                        .foregroundStyle(CRBTheme.Gradients.primary)
                    
                    Text("Hashrate".localized)
                        .font(CRBTheme.Typography.caption())
                        .foregroundColor(CRBTheme.Colors.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, CRBTheme.Spacing.md)
                
                let price = appState.cachedCRBPriceUSDT
                let currency = appState.selectedFiatCurrency
                let rates = appState.cachedFXRates
                
                let owedFiat = CurrencyManager.convertCRBToFiat(baseUnits: miner.owed, priceUSDT: price, rates: rates, targetCurrency: currency).map {
                    "≈ " + CurrencyManager.formatFiat($0, currencyCode: currency)
                }
                let paidFiat = CurrencyManager.convertCRBToFiat(baseUnits: miner.paid, priceUSDT: price, rates: rates, targetCurrency: currency).map {
                    "≈ " + CurrencyManager.formatFiat($0, currencyCode: currency)
                }
                let earnedFiat = CurrencyManager.convertCRBToFiat(baseUnits: miner.earned, priceUSDT: price, rates: rates, targetCurrency: currency).map {
                    "≈ " + CurrencyManager.formatFiat($0, currencyCode: currency)
                }
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: CRBTheme.Spacing.md) {
                    StatCard(icon: "banknote", label: "Owed".localized, value: CRBUnits.formatCRBCompact(miner.owed), color: CRBTheme.Colors.warning, subtitle: owedFiat)
                    StatCard(icon: "checkmark.circle", label: "Paid".localized, value: CRBUnits.formatCRBCompact(miner.paid), color: CRBTheme.Colors.buyGreen, subtitle: paidFiat)
                    StatCard(icon: "chart.line.uptrend.xyaxis", label: "Earned".localized, value: CRBUnits.formatCRBCompact(miner.earned), color: CRBTheme.Colors.cyan, subtitle: earnedFiat)
                    StatCard(icon: "square.stack.3d.up", label: "Shares".localized, value: String(format: "%.0f", miner.shares), color: CRBTheme.Colors.violet)
                }
            } else {
                // Not mining
                VStack(spacing: CRBTheme.Spacing.lg) {
                    Image(systemName: "hammer")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(CRBTheme.Colors.muted.opacity(0.4))
                    
                    Text("Not mining yet".localized)
                        .font(CRBTheme.Typography.headline())
                        .foregroundColor(CRBTheme.Colors.muted)
                    
                    Text("Set up a miner pointed to your wallet address to start earning CRB".localized)
                        .font(CRBTheme.Typography.body())
                        .foregroundColor(CRBTheme.Colors.muted.opacity(0.7))
                        .multilineTextAlignment(.center)
                    
                    GradientButton(title: "Setup Miner".localized, icon: "wrench.and.screwdriver") {
                        showSetup = true
                    }
                }
                .padding(.vertical, CRBTheme.Spacing.xl)
            }
        }
        .glassCard()
    }
    
    // MARK: - Workers
    
    private var workersSection: some View {
        VStack(alignment: .leading, spacing: CRBTheme.Spacing.md) {
            HStack {
                SectionHeader(title: "Workers".localized, icon: "desktopcomputer")
                Spacer()
                
                HStack(spacing: CRBTheme.Spacing.sm) {
                    PillBadge(text: "\(viewModel.activeWorkers.count) " + "Active".localized, color: CRBTheme.Colors.buyGreen)
                    if !viewModel.idleWorkers.isEmpty {
                        PillBadge(text: "\(viewModel.idleWorkers.count) " + "Idle".localized, color: CRBTheme.Colors.error)
                    }
                }
            }
            
            if viewModel.workers.isEmpty && !viewModel.isLoadingWorkers {
                Text("No workers found in the last 5 minutes".localized)
                    .font(CRBTheme.Typography.body())
                    .foregroundColor(CRBTheme.Colors.muted)
                    .padding(.vertical, CRBTheme.Spacing.md)
            } else {
                ForEach(viewModel.workers) { worker in
                    workerRow(worker)
                }
            }
        }
        .glassCard()
    }
    
    private func workerRow(_ worker: PoolWorker) -> some View {
        HStack(spacing: CRBTheme.Spacing.md) {
            // Status indicator
            Circle()
                .fill(worker.isIdle ? CRBTheme.Colors.error : CRBTheme.Colors.buyGreen)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(worker.worker)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(CRBTheme.Colors.ink)
                
                Text(worker.statusLabel)
                    .font(.system(size: 11))
                    .foregroundColor(worker.isIdle ? CRBTheme.Colors.error : CRBTheme.Colors.muted)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(CRBUnits.formatHashrate(worker.hashrate))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(CRBTheme.Colors.ink)
                
                Text(String(format: "%@ shares".localized, String(format: "%.0f", worker.shares)))
                    .font(.system(size: 11))
                    .foregroundColor(CRBTheme.Colors.muted)
            }
        }
        .padding(CRBTheme.Spacing.md)
        .background(worker.isIdle ? CRBTheme.Colors.error.opacity(0.05) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
    }
    
    // MARK: - Pool Stats
    
    private var poolStatsSection: some View {
        VStack(alignment: .leading, spacing: CRBTheme.Spacing.md) {
            SectionHeader(title: "Pool Stats".localized, icon: "server.rack")
            
            if let pool = viewModel.poolStats {
                let price = appState.cachedCRBPriceUSDT
                let currency = appState.selectedFiatCurrency
                let rates = appState.cachedFXRates
                
                let minPayoutFiat = pool.min_payout.flatMap {
                    CurrencyManager.convertCRBToFiat(baseUnits: $0, priceUSDT: price, rates: rates, targetCurrency: currency)
                }.map { "≈ " + CurrencyManager.formatFiat($0, currencyCode: currency) }
                
                let totalPaidFiat = pool.total_paid.flatMap {
                    CurrencyManager.convertCRBToFiat(baseUnits: $0, priceUSDT: price, rates: rates, targetCurrency: currency)
                }.map { "≈ " + CurrencyManager.formatFiat($0, currencyCode: currency) }
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: CRBTheme.Spacing.md) {
                    StatCard(icon: "speedometer", label: "Pool Hashrate".localized, value: CRBUnits.formatHashrate(pool.pool_hashrate ?? 0))
                    StatCard(icon: "cube.fill", label: "Blocks".localized, value: "\(pool.blocks_found ?? 0)", color: CRBTheme.Colors.warning)
                    StatCard(icon: "person.2.fill", label: "Miners".localized, value: "\(pool.active_miners ?? 0)", color: CRBTheme.Colors.violet)
                    StatCard(icon: "percent", label: "Pool Fee".localized, value: String(format: "%.1f%%", Double(pool.fee_permil ?? 10) / 10.0), color: CRBTheme.Colors.info)
                    StatCard(icon: "arrow.down.to.line", label: "Min Payout".localized, value: CRBUnits.formatCRBCompact(pool.min_payout ?? 0), color: CRBTheme.Colors.buyGreen, subtitle: minPayoutFiat)
                    StatCard(icon: "banknote", label: "Paid".localized, value: CRBUnits.formatCRBCompact(pool.total_paid ?? 0), color: CRBTheme.Colors.success, subtitle: totalPaidFiat)
                }
            }
            
            // Health
            if let health = viewModel.poolHealth {
                HStack(spacing: CRBTheme.Spacing.sm) {
                    Circle()
                        .fill(health.ok ? CRBTheme.Colors.buyGreen : CRBTheme.Colors.error)
                        .frame(width: 8, height: 8)
                    
                    Text("Pool \(health.ok ? "Online" : "Offline")")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(health.ok ? CRBTheme.Colors.buyGreen : CRBTheme.Colors.error)
                    
                    if let role = health.role {
                        Text("(\(role))")
                            .font(.system(size: 11))
                            .foregroundColor(CRBTheme.Colors.muted)
                    }
                    
                    Spacer()
                    
                    if let height = health.height {
                        Text("Height: \(height)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(CRBTheme.Colors.muted)
                    }
                }
                .padding(CRBTheme.Spacing.md)
                .background(health.ok ? CRBTheme.Colors.buyGreen.opacity(0.05) : CRBTheme.Colors.error.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
            }
        }
        .glassCard()
    }
}

#Preview {
    MiningDashboardView()
        .environment(AppState())
}
