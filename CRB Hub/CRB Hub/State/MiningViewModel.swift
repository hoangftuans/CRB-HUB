import SwiftUI

/// ViewModel for mining dashboard
@Observable
@MainActor
final class MiningViewModel {
    
    // MARK: - Pool Stats
    var poolStats: PoolStatsResponse?
    var myMiner: PoolMiner?
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
    
    // MARK: - Actions
    
    func loadPoolStats(minerAddress: String) async {
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
    
    func loadAll(address: String) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadPoolStats(minerAddress: address) }
            group.addTask { await self.loadWorkers(address: address) }
            group.addTask { await self.loadHealth() }
        }
    }
    
    func startAutoRefresh(address: String) {
        stopAutoRefresh()
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard !Task.isCancelled else { return }
                await loadAll(address: address)
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
}
