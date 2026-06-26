import SwiftUI

struct MiningDashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = MiningViewModel()
    @State private var showSetup = false
    @State private var calculatorHashrate = ""
    @State private var calculatorUnit: MiningHashrateUnit = .mega
    @State private var calculatorPowerWatts = "120"
    @State private var calculatorElectricityPrice = "0.12"
    @State private var profitRefreshTask: Task<Void, Never>?
    @State private var selectedWorker: PoolWorker?
    
    var body: some View {
        NavigationStack {
            ZStack {
                CRBTheme.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: CRBTheme.Spacing.lg) {
                        // My miner stats
                        myMinerSection

                        // Profit calculator
                        profitCalculatorSection
                        
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
                    await refreshProfitInputs()
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
                await refreshProfitInputs()
                startProfitAutoRefresh()
            }
            .onDisappear {
                viewModel.stopAutoRefresh()
                stopProfitAutoRefresh()
            }
            .onChange(of: appState.selectedWallet?.id) { _, _ in
                if let addr = appState.selectedWallet?.address {
                    Task {
                        await viewModel.loadAll(address: addr)
                        viewModel.startAutoRefresh(address: addr)
                    }
                } else {
                    viewModel.myMiner = nil
                    viewModel.workers = []
                    viewModel.stopAutoRefresh()
                }
            }
            .navigationDestination(isPresented: $showSetup) {
                MiningSetupView()
            }
            .navigationDestination(item: $selectedWorker) { worker in
                WorkerDetailView(worker: worker, samples: viewModel.samples(for: worker))
            }
        }
    }

    private func refreshProfitInputs() async {
        await appState.refreshChainStatus()
        await appState.refreshP2PStats()
        await appState.refreshFiatRates()
    }

    private func startProfitAutoRefresh() {
        stopProfitAutoRefresh()
        profitRefreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard !Task.isCancelled else { return }
                await refreshProfitInputs()
            }
        }
    }

    private func stopProfitAutoRefresh() {
        profitRefreshTask?.cancel()
        profitRefreshTask = nil
    }
    
    // MARK: - My Miner
    
    private var myMinerSection: some View {
        VStack(alignment: .leading, spacing: CRBTheme.Spacing.md) {
            SectionHeader(title: "My Stats".localized, icon: "hammer.fill")
            
            if viewModel.isLoadingStats && viewModel.myMiner == nil && !viewModel.hasMiningPayoutHistory {
                LoadingView(message: "Loading...".localized)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, CRBTheme.Spacing.xl)
            } else if viewModel.myMiner != nil || viewModel.hasMiningPayoutHistory {
                let miner = viewModel.myMiner
                let owed = miner?.owed ?? 0
                let paid = viewModel.displayedPaid
                let earned = viewModel.displayedEarned
                let shares = miner?.shares ?? 0
                let hashrate = miner?.hashrate ?? viewModel.totalHashrate

                // Hashrate hero
                VStack(spacing: CRBTheme.Spacing.sm) {
                    Text(CRBUnits.formatHashrate(hashrate))
                        .font(.system(size: 32, weight: .heavy, design: .monospaced))
                        .foregroundStyle(CRBTheme.Gradients.primary)
                    
                    Text("Hashrate".localized)
                        .font(CRBTheme.Typography.caption())
                        .foregroundColor(CRBTheme.Colors.muted)

                    if miner == nil && viewModel.hasMiningPayoutHistory {
                        Text("Mined Transaction".localized)
                            .font(CRBTheme.Typography.caption())
                            .foregroundColor(CRBTheme.Colors.warning)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, CRBTheme.Spacing.md)
                
                let price = appState.cachedCRBPriceUSDT
                let currency = appState.selectedFiatCurrency
                let rates = appState.cachedFXRates
                
                let owedFiat = CurrencyManager.convertCRBToFiat(baseUnits: owed, priceUSDT: price, rates: rates, targetCurrency: currency).map {
                    "≈ " + CurrencyManager.formatFiat($0, currencyCode: currency)
                }
                let paidFiat = CurrencyManager.convertCRBToFiat(baseUnits: paid, priceUSDT: price, rates: rates, targetCurrency: currency).map {
                    "≈ " + CurrencyManager.formatFiat($0, currencyCode: currency)
                }
                let earnedFiat = CurrencyManager.convertCRBToFiat(baseUnits: earned, priceUSDT: price, rates: rates, targetCurrency: currency).map {
                    "≈ " + CurrencyManager.formatFiat($0, currencyCode: currency)
                }
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: CRBTheme.Spacing.md) {
                    StatCard(icon: "banknote", label: "Owed".localized, value: CRBUnits.formatCRBCompact(owed), color: CRBTheme.Colors.warning, subtitle: owedFiat)
                    StatCard(icon: "checkmark.circle", label: "Paid".localized, value: CRBUnits.formatCRBCompact(paid), color: CRBTheme.Colors.buyGreen, subtitle: paidFiat)
                    StatCard(icon: "chart.line.uptrend.xyaxis", label: "Earned".localized, value: CRBUnits.formatCRBCompact(earned), color: CRBTheme.Colors.cyan, subtitle: earnedFiat)
                    StatCard(icon: "square.stack.3d.up", label: "Shares".localized, value: String(format: "%.0f", shares), color: CRBTheme.Colors.violet)
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

    // MARK: - Profit Calculator

    private var profitCalculatorSection: some View {
        VStack(alignment: .leading, spacing: CRBTheme.Spacing.md) {
            SectionHeader(title: "Profit Calculator".localized, icon: "function")

            VStack(spacing: CRBTheme.Spacing.md) {
                HStack(spacing: CRBTheme.Spacing.md) {
                    calculatorInput(
                        "Hashrate".localized,
                        text: $calculatorHashrate,
                        placeholder: currentHashratePlaceholder,
                        keyboard: .decimalPad
                    )

                    VStack(alignment: .leading, spacing: CRBTheme.Spacing.xs) {
                        Text("Unit".localized)
                            .font(CRBTheme.Typography.caption())
                            .foregroundColor(CRBTheme.Colors.muted)

                        Picker("Unit".localized, selection: $calculatorUnit) {
                            ForEach(MiningHashrateUnit.allCases) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(CRBTheme.Colors.cyan)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(CRBTheme.Spacing.md)
                        .background(CRBTheme.Colors.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
                    }
                }

                HStack(spacing: CRBTheme.Spacing.md) {
                    calculatorInput(
                        "Power".localized,
                        text: $calculatorPowerWatts,
                        placeholder: "120 W",
                        keyboard: .decimalPad
                    )

                    calculatorInput(
                        "Electricity".localized,
                        text: $calculatorElectricityPrice,
                        placeholder: "\(appState.selectedFiatCurrency)/kWh",
                        keyboard: .decimalPad
                    )
                }
            }

            if let estimate = miningProfitEstimate {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: CRBTheme.Spacing.md) {
                    StatCard(icon: "calendar", label: "Pool CRB / Day".localized, value: "\(CRBUnits.formatDecimal(estimate.poolDailyCRB, maxFractionDigits: 8, minFractionDigits: 2)) CRB", color: CRBTheme.Colors.cyan)
                    StatCard(icon: "dice", label: "Solo Expected".localized, value: "\(CRBUnits.formatDecimal(estimate.soloDailyCRB, maxFractionDigits: 8, minFractionDigits: 2)) CRB", color: CRBTheme.Colors.violet, subtitle: "\(CRBUnits.formatDecimal(estimate.soloBlocksPerDay, maxFractionDigits: 6, minFractionDigits: 0)) " + "blocks/day".localized)
                    StatCard(
                        icon: "dollarsign.circle",
                        label: "Revenue / Day".localized,
                        value: CurrencyManager.formatFiat(estimate.dailyRevenueFiat, currencyCode: appState.selectedFiatCurrency),
                        color: CRBTheme.Colors.buyGreen
                    )
                    StatCard(icon: "bolt.fill", label: "Power / Day".localized, value: CurrencyManager.formatFiat(estimate.dailyPowerCostFiat, currencyCode: appState.selectedFiatCurrency), color: CRBTheme.Colors.warning)
                    StatCard(
                        icon: "chart.line.uptrend.xyaxis",
                        label: "Profit / Day".localized,
                        value: CurrencyManager.formatFiat(estimate.dailyProfitFiat, currencyCode: appState.selectedFiatCurrency),
                        color: estimate.dailyProfitFiat >= 0 ? CRBTheme.Colors.buyGreen : CRBTheme.Colors.sellRed,
                        subtitle: "\(CurrencyManager.formatFiat(estimate.monthlyProfitFiat, currencyCode: appState.selectedFiatCurrency)) / " + "Month".localized
                    )
                }

                HStack(spacing: CRBTheme.Spacing.sm) {
                    Image(systemName: "info.circle")
                        .foregroundColor(CRBTheme.Colors.muted)
                    Text(estimate.sourceNote.localized)
                        .font(.system(size: 11))
                        .foregroundColor(CRBTheme.Colors.muted)
                }
            } else {
                Text("Enter hashrate and wait for live chain price data to estimate mining profit.".localized)
                    .font(CRBTheme.Typography.body())
                    .foregroundColor(CRBTheme.Colors.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(CRBTheme.Spacing.md)
                    .background(CRBTheme.Colors.backgroundSecondary.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
            }
        }
        .glassCard()
    }

    private var currentHashratePlaceholder: String {
        let hashrate = viewModel.totalHashrate > 0 ? viewModel.totalHashrate : (viewModel.myMiner?.hashrate ?? 0)
        guard hashrate > 0 else { return "100" }
        return CRBUnits.formatDecimal(Decimal(string: String(hashrate / calculatorUnit.multiplier)) ?? 0, maxFractionDigits: 2, minFractionDigits: 0)
    }

    private var miningProfitEstimate: MiningProfitEstimate? {
        let fallbackHashrate = viewModel.totalHashrate > 0 ? viewModel.totalHashrate : (viewModel.myMiner?.hashrate ?? 0)
        let enteredHashrate = parseMiningDecimal(calculatorHashrate)
        let fallbackInputHashrate: Decimal? = fallbackHashrate > 0
            ? Decimal(string: String(fallbackHashrate / calculatorUnit.multiplier))
            : Decimal(100)
        let hashrateDecimal = enteredHashrate ?? fallbackInputHashrate
        guard let hashrateDecimal, hashrateDecimal > 0 else { return nil }

        let networkHashrate = appState.chainStatus?.hashrate ?? viewModel.poolStats?.pool_hashrate ?? 0
        guard networkHashrate > 0 else { return nil }
        let networkHashrateDecimal = Decimal(string: String(networkHashrate)) ?? 0
        guard networkHashrateDecimal > 0 else { return nil }

        let minerHashrate = hashrateDecimal * (Decimal(string: String(calculatorUnit.multiplier)) ?? 1)
        let blockReward = appState.p2pStats?.block_reward_crb ?? appState.chainStatus.map { CRBUnits.toDisplayCRB($0.reward) } ?? 50
        let blockTime = Decimal(appState.p2pStats?.block_time_secs ?? 60)
        let priceUSDT = appState.cachedCRBPriceUSDT
        let fiatRate = appState.cachedFXRates[appState.selectedFiatCurrency] ?? CurrencyManager.fallbackRates[appState.selectedFiatCurrency] ?? 1
        let powerWatts = parseMiningDecimal(calculatorPowerWatts) ?? 0
        let electricityPrice = parseMiningDecimal(calculatorElectricityPrice) ?? 0

        guard blockReward > 0, blockTime > 0 else { return nil }

        let poolFeePermil = Decimal(viewModel.poolStats?.fee_permil ?? 0)
        let poolFeeRate = max(0, min(poolFeePermil / 1000, 1))
        let blocksPerDay = Decimal(86_400) / blockTime
        let soloBlocksPerDay = (minerHashrate / networkHashrateDecimal) * blocksPerDay
        let soloDailyCRB = soloBlocksPerDay * blockReward
        let poolDailyCRB = soloDailyCRB * (1 - poolFeeRate)
        let dailyRevenueFiat = poolDailyCRB * priceUSDT * fiatRate
        let dailyPowerCostFiat = (powerWatts * 24 / 1000) * electricityPrice
        let dailyProfitFiat = dailyRevenueFiat - dailyPowerCostFiat
        let monthlyProfitFiat = dailyProfitFiat * 30

        return MiningProfitEstimate(
            poolDailyCRB: max(poolDailyCRB, 0),
            soloDailyCRB: max(soloDailyCRB, 0),
            soloBlocksPerDay: max(soloBlocksPerDay, 0),
            dailyRevenueFiat: dailyRevenueFiat,
            dailyPowerCostFiat: dailyPowerCostFiat,
            dailyProfitFiat: dailyProfitFiat,
            monthlyProfitFiat: monthlyProfitFiat,
            sourceNote: "Estimate follows the pool calculator: your hashrate divided by live network hashrate, multiplied by blocks per day and block reward. Pool revenue subtracts pool fee; solo is expected value."
        )
    }

    private func parseMiningDecimal(_ value: String) -> Decimal? {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty else { return nil }
        return Decimal(string: normalized)
    }

    private func calculatorInput(_ label: String, text: Binding<String>, placeholder: String, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: CRBTheme.Spacing.xs) {
            Text(label)
                .font(CRBTheme.Typography.caption())
                .foregroundColor(CRBTheme.Colors.muted)

            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .keyboardType(keyboard)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(CRBTheme.Colors.ink)
                .padding(CRBTheme.Spacing.md)
                .background(CRBTheme.Colors.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
        }
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

            workerSummaryStrip
            
            if viewModel.workers.isEmpty && !viewModel.isLoadingWorkers {
                Text("No workers found in the last 5 minutes".localized)
                    .font(CRBTheme.Typography.body())
                    .foregroundColor(CRBTheme.Colors.muted)
                    .padding(.vertical, CRBTheme.Spacing.md)
            } else {
                ForEach(viewModel.workers) { worker in
                    Button {
                        selectedWorker = worker
                    } label: {
                        workerRow(worker)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .glassCard()
    }

    private var workerSummaryStrip: some View {
        HStack(spacing: CRBTheme.Spacing.sm) {
            workerMetric("Total Hashrate".localized, CRBUnits.formatHashrate(viewModel.totalHashrate), icon: "speedometer")
            workerMetric("Shares".localized, String(format: "%.0f", viewModel.totalShares), icon: "square.stack.3d.up")
            workerMetric("Window".localized, "\(viewModel.windowSecs / 60)m", icon: "clock.arrow.circlepath")
        }
    }

    private func workerMetric(_ title: String, _ value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundColor(CRBTheme.Colors.muted)

            Text(value)
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundColor(CRBTheme.Colors.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CRBTheme.Spacing.sm)
        .background(CRBTheme.Colors.backgroundSecondary.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
    }
    
    private func workerRow(_ worker: PoolWorker) -> some View {
        let statusColor = workerStatusColor(worker)

        return VStack(alignment: .leading, spacing: CRBTheme.Spacing.sm) {
            HStack(spacing: CRBTheme.Spacing.sm) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 9, height: 9)

                VStack(alignment: .leading, spacing: 2) {
                    Text(worker.worker)
                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                        .foregroundColor(CRBTheme.Colors.ink)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text("Last share: \(worker.idleDisplay)".localized)
                        .font(.system(size: 11))
                        .foregroundColor(CRBTheme.Colors.muted)
                }

                Spacer()

                PillBadge(text: worker.statusLabel, color: statusColor)
            }

            HStack(spacing: CRBTheme.Spacing.sm) {
                workerRowMetric("Hashrate".localized, CRBUnits.formatHashrate(worker.hashrate), color: CRBTheme.Colors.cyan)
                workerRowMetric("Shares".localized, String(format: "%.0f", worker.shares), color: CRBTheme.Colors.violet)
                workerRowMetric("Idle".localized, worker.idleDisplay, color: statusColor)
            }
        }
        .padding(CRBTheme.Spacing.md)
        .background(statusColor.opacity(worker.isOnline ? 0.055 : 0.075))
        .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: CRBTheme.Radius.sm)
                .stroke(statusColor.opacity(0.16), lineWidth: 1)
        )
    }

    private func workerRowMetric(_ title: String, _ value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(CRBTheme.Colors.muted)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func workerStatusColor(_ worker: PoolWorker) -> Color {
        if worker.isOnline {
            return CRBTheme.Colors.buyGreen
        }
        if worker.isWarming {
            return CRBTheme.Colors.warning
        }
        return CRBTheme.Colors.error
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
                    StatCard(icon: "banknote", label: "Total Paid".localized, value: CRBUnits.formatCRBCompact(pool.total_paid ?? 0), color: CRBTheme.Colors.success, subtitle: totalPaidFiat)
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

struct WorkerDetailView: View {
    let worker: PoolWorker
    let samples: [WorkerHashrateSample]

    var body: some View {
        ZStack {
            CRBTheme.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: CRBTheme.Spacing.lg) {
                    headerCard
                    chartCard
                    sampleHistoryCard
                }
                .padding(CRBTheme.Spacing.lg)
            }
        }
        .navigationTitle(worker.worker)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: CRBTheme.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(worker.worker)
                        .font(.system(size: 20, weight: .heavy, design: .monospaced))
                        .foregroundColor(CRBTheme.Colors.ink)
                    Text("Last share: \(worker.idleDisplay)".localized)
                        .font(.system(size: 12))
                        .foregroundColor(CRBTheme.Colors.muted)
                }

                Spacer()

                PillBadge(text: worker.statusLabel, color: statusColor)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: CRBTheme.Spacing.md) {
                StatCard(icon: "speedometer", label: "Hashrate".localized, value: CRBUnits.formatHashrate(worker.hashrate), color: CRBTheme.Colors.cyan)
                StatCard(icon: "square.stack.3d.up", label: "Shares".localized, value: String(format: "%.0f", worker.shares), color: CRBTheme.Colors.violet)
                StatCard(icon: "clock", label: "Idle".localized, value: worker.idleDisplay, color: statusColor)
                StatCard(icon: "waveform.path.ecg", label: "Samples".localized, value: "\(samples.count)", color: CRBTheme.Colors.info)
            }
        }
        .glassCard()
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: CRBTheme.Spacing.md) {
            SectionHeader(title: "Hashrate History".localized, icon: "chart.xyaxis.line")

            if samples.count < 2 {
                Text("Waiting for more live samples...".localized)
                    .font(CRBTheme.Typography.body())
                    .foregroundColor(CRBTheme.Colors.muted)
                    .frame(maxWidth: .infinity, minHeight: 160)
            } else {
                WorkerHashrateChart(samples: samples, color: statusColor)
                    .frame(height: 180)

                HStack {
                    Text("Min \(CRBUnits.formatHashrate(minHashrate))")
                    Spacer()
                    Text("Avg \(CRBUnits.formatHashrate(avgHashrate))")
                    Spacer()
                    Text("Max \(CRBUnits.formatHashrate(maxHashrate))")
                }
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(CRBTheme.Colors.muted)
            }
        }
        .glassCard()
    }

    private var sampleHistoryCard: some View {
        VStack(alignment: .leading, spacing: CRBTheme.Spacing.md) {
            SectionHeader(title: "Recent Samples".localized, icon: "list.bullet.rectangle")

            ForEach(samples.suffix(8).reversed()) { sample in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(sample.timestamp.formatted(date: .omitted, time: .standard))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(CRBTheme.Colors.ink)
                        Text("\(sample.idleSeconds)s idle")
                            .font(.system(size: 11))
                            .foregroundColor(CRBTheme.Colors.muted)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(CRBUnits.formatHashrate(sample.hashrate))
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(CRBTheme.Colors.cyan)
                        Text(String(format: "%.0f shares", sample.shares))
                            .font(.system(size: 11))
                            .foregroundColor(CRBTheme.Colors.muted)
                    }
                }
                .padding(CRBTheme.Spacing.sm)
                .background(CRBTheme.Colors.backgroundSecondary.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
            }
        }
        .glassCard()
    }

    private var statusColor: Color {
        if worker.isOnline {
            return CRBTheme.Colors.buyGreen
        }
        if worker.isWarming {
            return CRBTheme.Colors.warning
        }
        return CRBTheme.Colors.error
    }

    private var minHashrate: Double {
        samples.map(\.hashrate).min() ?? worker.hashrate
    }

    private var maxHashrate: Double {
        samples.map(\.hashrate).max() ?? worker.hashrate
    }

    private var avgHashrate: Double {
        guard !samples.isEmpty else { return worker.hashrate }
        return samples.reduce(0) { $0 + $1.hashrate } / Double(samples.count)
    }
}

struct WorkerHashrateChart: View {
    let samples: [WorkerHashrateSample]
    let color: Color

    var body: some View {
        Canvas { context, size in
            let values = samples.map(\.hashrate)
            guard values.count > 1 else { return }

            let minValue = values.min() ?? 0
            let maxValue = values.max() ?? 1
            let range = max(maxValue - minValue, 1)
            let stepX = size.width / CGFloat(values.count - 1)
            let topPadding: CGFloat = 12
            let bottomPadding: CGFloat = 18
            let chartHeight = max(size.height - topPadding - bottomPadding, 1)

            var gridPath = Path()
            for index in 0...3 {
                let y = topPadding + (chartHeight * CGFloat(index) / 3)
                gridPath.move(to: CGPoint(x: 0, y: y))
                gridPath.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(gridPath, with: .color(CRBTheme.Colors.cardBorder.opacity(0.55)), lineWidth: 1)

            var linePath = Path()
            for (index, value) in values.enumerated() {
                let x = CGFloat(index) * stepX
                let normalized = (value - minValue) / range
                let y = topPadding + chartHeight - (chartHeight * CGFloat(normalized))
                let point = CGPoint(x: x, y: y)
                if index == 0 {
                    linePath.move(to: point)
                } else {
                    linePath.addLine(to: point)
                }
            }

            context.stroke(linePath, with: .color(color), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

            if let last = values.last {
                let normalized = (last - minValue) / range
                let point = CGPoint(x: size.width, y: topPadding + chartHeight - (chartHeight * CGFloat(normalized)))
                context.fill(Path(ellipseIn: CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)), with: .color(color))
            }
        }
        .padding(.vertical, CRBTheme.Spacing.sm)
        .background(CRBTheme.Colors.backgroundSecondary.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.md))
    }
}

enum MiningHashrateUnit: String, CaseIterable, Identifiable {
    case hash = "H/s"
    case kilo = "kH/s"
    case mega = "MH/s"
    case giga = "GH/s"

    var id: String { rawValue }

    var multiplier: Double {
        switch self {
        case .hash:
            return 1
        case .kilo:
            return 1_000
        case .mega:
            return 1_000_000
        case .giga:
            return 1_000_000_000
        }
    }
}

struct MiningProfitEstimate {
    let poolDailyCRB: Decimal
    let soloDailyCRB: Decimal
    let soloBlocksPerDay: Decimal
    let dailyRevenueFiat: Decimal
    let dailyPowerCostFiat: Decimal
    let dailyProfitFiat: Decimal
    let monthlyProfitFiat: Decimal
    let sourceNote: String
}

#Preview {
    MiningDashboardView()
        .environment(AppState())
}
