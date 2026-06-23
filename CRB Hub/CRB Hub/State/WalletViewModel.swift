import SwiftUI

/// ViewModel for wallet balance, history, and send
@Observable
@MainActor
final class WalletViewModel {
    
    // MARK: - Balance
    var balance: BalanceResponse?
    var isLoadingBalance = false
    var balanceError: String?
    
    // MARK: - History
    var transactions: [CRBTransaction] = []
    var isLoadingHistory = false
    var historyError: String?
    var historyOffset = 0
    var hasMoreHistory = true
    private let historyLimit = 50
    
    // MARK: - Send
    var isSending = false
    var sendError: String?
    var sendResult: BroadcastResult?
    
    // MARK: - Chain Status
    var chainStatus: ChainStatus?
    var isLoadingStatus = false
    
    // MARK: - Auto Refresh
    private var refreshTask: Task<Void, Never>?
    
    // MARK: - Actions
    
    func loadBalance(address: String) async {
        isLoadingBalance = true
        balanceError = nil
        
        do {
            balance = try await CereblixAPIClient.getBalance(address: address)
        } catch {
            balanceError = error.localizedDescription
        }
        
        isLoadingBalance = false
    }
    
    func loadChainStatus() async {
        isLoadingStatus = true
        do {
            chainStatus = try await CereblixAPIClient.getStatus()
        } catch {
            // Silent fail for status
        }
        isLoadingStatus = false
    }
    
    func loadHistory(address: String, refresh: Bool = false) async {
        if refresh {
            historyOffset = 0
            hasMoreHistory = true
            transactions = []
        }
        
        guard hasMoreHistory else { return }
        
        isLoadingHistory = true
        historyError = nil
        
        do {
            let newTxs = try await CereblixAPIClient.getHistory(
                address: address,
                limit: historyLimit,
                offset: historyOffset
            )
            
            if refresh {
                transactions = newTxs
            } else {
                transactions.append(contentsOf: newTxs)
            }
            
            historyOffset += newTxs.count
            hasMoreHistory = newTxs.count >= historyLimit
        } catch {
            historyError = error.localizedDescription
        }
        
        isLoadingHistory = false
    }
    
    func loadAll(address: String) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadBalance(address: address) }
            group.addTask { await self.loadChainStatus() }
            group.addTask { await self.loadHistory(address: address, refresh: true) }
        }
    }
    
    func startAutoRefresh(address: String) {
        stopAutoRefresh()
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { return }
                await loadBalance(address: address)
                await loadChainStatus()
            }
        }
    }
    
    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }
}
