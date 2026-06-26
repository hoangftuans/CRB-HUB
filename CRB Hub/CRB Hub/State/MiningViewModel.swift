import SwiftUI

/// ViewModel for mining dashboard
@Observable
@MainActor
final class MiningViewModel {
    
    // MARK: - Pool Stats
    var poolStats: PoolStatsResponse?
    var myMiner: PoolMiner?
    var historyPayoutAmount: UInt64 = 0
    var historyPayoutCount = 0
    var historyPayoutError: String?
    var isLoadingStats = false
    var statsError: String?
    
    // MARK: - Workers
    var workers: [PoolWorker] = []
    var isLoadingWorkers = false
    var workersError: String?
    var windowSecs: Int = 300
    
    // MARK: - Health
    var poolHealth: PoolHealth?
    
    // MARK: - Auto Refresh
    private var refreshTask: Task<Void, Never>?
    private let liveRefreshSeconds: UInt64 = 10
    private let payoutHistoryRefreshEveryTicks = 6
    
    // MARK: - Actions
    
    func loadPoolStats(minerAddress: String) async {
        guard !isLoadingStats else { return }
        isLoadingStats = true
        statsError = nil
        
        do {
            let stats = try await MiningAPIClient.getPoolStats()
            poolStats = stats
            
            // Find this miner in the miners list
            myMiner = stats.miners?.first(where: {
                $0.address.lowercased() == minerAddress.lowercased()
            })
        } catch {
            statsError = error.localizedDescription
        }
        
        isLoadingStats = false
    }
    
    func loadWorkers(address: String) async {
        guard !isLoadingWorkers else { return }
        isLoadingWorkers = true
        workersError = nil
        
        do {
            let response = try await MiningAPIClient.getWorkers(address: address)
            workers = response.workers ?? []
            windowSecs = response.window_secs ?? 300
        } catch {
            workersError = error.localizedDescription
        }
        
        isLoadingWorkers = false
    }
    
    func loadHealth() async {
        do {
            poolHealth = try await MiningAPIClient.getHealth()
        } catch {
            // Silent fail for health
        }
    }

    func loadPayoutHistory(address: String) async {
        historyPayoutError = nil

        do {
            let poolAddress = poolStats?.pool_address
            let pageSize = 100
            let maxPages = 5
            var transactions: [CRBTransaction] = []

            for page in 0..<maxPages {
                let pageTransactions = try await CereblixAPIClient.getHistory(
                    address: address,
                    limit: pageSize,
                    offset: page * pageSize
                )
                transactions.append(contentsOf: pageTransactions)

                if pageTransactions.count < pageSize {
                    break
                }
            }

            let payouts = transactions.filter { $0.isMiningPayout(for: address, poolAddress: poolAddress) }

            var total: UInt64 = 0
            for payout in payouts {
                let result = total.addingReportingOverflow(payout.amount)
                if result.overflow {
                    total = UInt64.max
                    break
                }
                total = result.partialValue
            }

            historyPayoutAmount = total
            historyPayoutCount = payouts.count
        } catch {
            historyPayoutAmount = 0
            historyPayoutCount = 0
            historyPayoutError = error.localizedDescription
        }
    }
    
    func loadAll(address: String) async {
        await loadLive(address: address)
        await loadPayoutHistory(address: address)
    }

    func loadLive(address: String) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadPoolStats(minerAddress: address) }
            group.addTask { await self.loadWorkers(address: address) }
            group.addTask { await self.loadHealth() }
        }
    }
    
    func startAutoRefresh(address: String) {
        stopAutoRefresh()
        refreshTask = Task {
            var tick = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(liveRefreshSeconds))
                guard !Task.isCancelled else { return }
                tick += 1
                await loadLive(address: address)
                if tick % payoutHistoryRefreshEveryTicks == 0 {
                    await loadPayoutHistory(address: address)
                }
            }
        }
    }
    
    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }
    
    // MARK: - Computed
    
    var activeWorkers: [PoolWorker] {
        workers.filter { !$0.isIdle }
    }
    
    var idleWorkers: [PoolWorker] {
        workers.filter { $0.isIdle }
    }
    
    var totalHashrate: Double {
        workers.reduce(0) { $0 + $1.hashrate }
    }

    var totalShares: Double {
        workers.reduce(0) { $0 + $1.shares }
    }

    var displayedPaid: UInt64 {
        max(myMiner?.paid ?? 0, historyPayoutAmount)
    }

    var displayedEarned: UInt64 {
        let owed = myMiner?.owed ?? 0
        let result = displayedPaid.addingReportingOverflow(owed)
        let paidPlusOwed = result.overflow ? UInt64.max : result.partialValue
        return max(myMiner?.earned ?? 0, paidPlusOwed)
    }

    var hasMiningPayoutHistory: Bool {
        historyPayoutAmount > 0 || historyPayoutCount > 0
    }
}
