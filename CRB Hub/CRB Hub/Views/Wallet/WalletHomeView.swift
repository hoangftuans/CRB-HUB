import SwiftUI

struct WalletHomeView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = WalletViewModel()
    @State private var showReceive = false
    @State private var showSend = false
    @State private var showHistory = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                CRBTheme.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: CRBTheme.Spacing.lg) {
                        // Balance card
                        balanceCard
                        
                        // Action buttons
                        actionButtons
                        
                        // Stats grid
                        if let balance = viewModel.balance {
                            statsGrid(balance)
                        }
                        
                        // Chain status
                        if let status = viewModel.chainStatus {
                            chainStatusSection(status)
                        }
                        
                        // Recent transactions
                        recentTransactionsSection
                    }
                    .padding(CRBTheme.Spacing.lg)
                }
                .refreshable {
                    if let addr = appState.selectedWallet?.address {
                        await viewModel.loadAll(address: addr)
                    }
                }
            }
            .navigationTitle("Wallet".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if appState.wallets.count > 1 {
                        Menu {
                            ForEach(appState.wallets) { wallet in
                                Button {
                                    appState.selectWallet(wallet)
                                } label: {
                                    Label(wallet.name, systemImage: wallet.id == appState.selectedWallet?.id ? "checkmark.circle.fill" : "circle")
                                }
                            }
                        } label: {
                            Image(systemName: "person.2.fill")
                                .foregroundColor(CRBTheme.Colors.cyan)
                        }
                    }
                }
            }
            .task {
                if let addr = appState.selectedWallet?.address {
                    await viewModel.loadAll(address: addr)
                    viewModel.startAutoRefresh(address: addr)
                }
            }
            .onChange(of: appState.selectedWallet?.id) { _, _ in
                if let addr = appState.selectedWallet?.address {
                    Task {
                        await viewModel.loadAll(address: addr)
                        viewModel.startAutoRefresh(address: addr)
                    }
                }
            }
            .onDisappear {
                viewModel.stopAutoRefresh()
            }
            .navigationDestination(isPresented: $showReceive) {
                ReceiveView()
            }
            .navigationDestination(isPresented: $showSend) {
                SendView()
            }
            .navigationDestination(isPresented: $showHistory) {
                HistoryView()
            }
        }
    }
    
    // MARK: - Balance Card
    
    private var balanceCard: some View {
        VStack(spacing: CRBTheme.Spacing.md) {
            // Wallet name and address
            if let wallet = appState.selectedWallet {
                Text(wallet.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(CRBTheme.Colors.muted)
                
                Text(AddressValidator.truncatedAddress(wallet.address))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(CRBTheme.Colors.cyan.opacity(0.8))
            }
            
            // Balance
            if viewModel.isLoadingBalance && viewModel.balance == nil {
                LoadingView(message: "Loading balance...".localized)
                    .padding(.vertical, CRBTheme.Spacing.xl)
            } else if let balance = viewModel.balance {
                VStack(spacing: 4) {
                    CRBAmountView(baseUnits: balance.balance, style: .large)
                    FiatValueView(baseUnits: balance.balance)
                }
                .padding(.vertical, CRBTheme.Spacing.md)
            } else if let error = viewModel.balanceError {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(CRBTheme.Colors.warning)
                    Text(error.localized)
                        .font(CRBTheme.Typography.caption())
                        .foregroundColor(CRBTheme.Colors.muted)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, CRBTheme.Spacing.xl)
            }
        }
        .frame(maxWidth: .infinity)
        .glassCard()
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: CRBTheme.Spacing.md) {
            actionButton(icon: "arrow.down.left", title: "Receive".localized, color: CRBTheme.Colors.buyGreen) {
                showReceive = true
            }
            
            actionButton(icon: "arrow.up.right", title: "Send".localized, color: CRBTheme.Colors.cyan) {
                showSend = true
            }
            
            actionButton(icon: "clock.arrow.circlepath", title: "History".localized, color: CRBTheme.Colors.violet) {
                showHistory = true
            }
        }
    }
    
    private func actionButton(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: CRBTheme.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(CRBTheme.Colors.ink)
            }
            .frame(maxWidth: .infinity)
            .glassCard(padding: CRBTheme.Spacing.lg)
        }
    }
    
    // MARK: - Stats Grid
    
    private func statsGrid(_ balance: BalanceResponse) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
        ], spacing: CRBTheme.Spacing.md) {
            StatCard(icon: "lock.open.fill", label: "Spendable".localized, value: CRBUnits.formatCRBCompact(balance.spendable), color: CRBTheme.Colors.buyGreen)
            StatCard(icon: "hammer.fill", label: "Mined".localized, value: CRBUnits.formatCRBCompact(balance.mined ?? 0), color: CRBTheme.Colors.warning)
            StatCard(icon: "arrow.down.left", label: "Received".localized, value: CRBUnits.formatCRBCompact(balance.received ?? 0), color: CRBTheme.Colors.cyan)
            StatCard(icon: "arrow.up.right", label: "Sent".localized, value: CRBUnits.formatCRBCompact(balance.sent ?? 0), color: CRBTheme.Colors.sellRed)
            StatCard(icon: "number", label: "Tx Count".localized, value: "\(balance.txns ?? 0)", color: CRBTheme.Colors.violet)
            StatCard(icon: "arrow.counterclockwise", label: "Nonce".localized, value: "\(balance.nonce)", color: CRBTheme.Colors.info)
        }
    }
    
    // MARK: - Chain Status
    
    private func chainStatusSection(_ status: ChainStatus) -> some View {
        VStack(alignment: .leading, spacing: CRBTheme.Spacing.md) {
            SectionHeader(title: "Chain Status".localized, icon: "link")
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
            ], spacing: CRBTheme.Spacing.sm) {
                miniStat("Height".localized, "\(status.height)")
                miniStat("Peers".localized, "\(status.peers)")
                miniStat("Mempool".localized, "\(status.mempool)")
                miniStat("Hashrate".localized, CRBUnits.formatHashrate(status.hashrate))
                miniStat("Fee".localized, CRBUnits.formatCRBCompact(status.fee_suggested))
                miniStat("Epoch".localized, "\(status.epoch)")
            }
        }
        .glassCard()
    }
    
    private func miniStat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(CRBTheme.Colors.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(CRBTheme.Colors.muted)
        }
    }
    
    // MARK: - Recent Transactions
    
    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: CRBTheme.Spacing.md) {
            HStack {
                SectionHeader(title: "Recent Transactions".localized, icon: "list.bullet")
                Spacer()
                if !viewModel.transactions.isEmpty {
                    Button("View All".localized) {
                        showHistory = true
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(CRBTheme.Colors.cyan)
                }
            }
            
            if viewModel.transactions.isEmpty && !viewModel.isLoadingHistory {
                EmptyStateView(
                    icon: "tray",
                    title: "No Transactions".localized,
                    message: "Your transaction history will appear here".localized
                )
            } else {
                ForEach(viewModel.transactions.prefix(5)) { tx in
                    transactionRow(tx)
                }
            }
        }
        .glassCard()
    }
    
    private func transactionRow(_ tx: CRBTransaction) -> some View {
        let type = tx.transactionType(for: appState.selectedWallet?.address ?? "")
        
        return HStack(spacing: CRBTheme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(typeColor(type).opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: type.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(typeColor(type))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(type.label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(CRBTheme.Colors.ink)
                
                if let time = tx.time {
                    Text(CRBUnits.formatRelativeTime(time))
                        .font(.system(size: 11))
                        .foregroundColor(CRBTheme.Colors.muted)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(type == .sent ? "-" : "+")\(CRBUnits.formatCRBCompact(tx.amount)) CRB")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(type == .sent ? CRBTheme.Colors.sellRed : CRBTheme.Colors.buyGreen)
                
                FiatValueView(baseUnits: tx.amount, font: .system(size: 11))
            }
        }
        .padding(.vertical, CRBTheme.Spacing.xs)
    }
    
    private func typeColor(_ type: CRBTransaction.TransactionType) -> Color {
        switch type {
        case .sent: return CRBTheme.Colors.sellRed
        case .received: return CRBTheme.Colors.buyGreen
        case .mined: return CRBTheme.Colors.warning
        case .unknown: return CRBTheme.Colors.muted
        }
    }
}

#Preview {
    WalletHomeView()
        .environment(AppState())
}
