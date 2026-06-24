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

    func minedAmountFromHistory(for address: String, poolAddress: String? = nil) -> UInt64 {
        var total: UInt64 = 0

        for transaction in transactions where transaction.isMiningPayout(for: address, poolAddress: poolAddress) {
            let result = total.addingReportingOverflow(transaction.amount)
            if result.overflow {
                return UInt64.max
            }
            total = result.partialValue
        }

        return total
    }

    func sendCRBSecure(
        wallet: WalletAccount,
        to recipient: String,
        amount: UInt64,
        fee: UInt64,
        fallbackPassword: String? = nil
    ) async {
        guard !isSending else { return }
        isSending = true
        sendError = nil
        sendResult = nil
        defer { isSending = false }

        do {
            let currentBalance = try await CereblixAPIClient.getBalance(address: wallet.address)
            let currentStatus = try await CereblixAPIClient.getStatus()
            let amountDescription = "\(CRBUnits.formatCRB(amount, maxFractionDigits: 8, minFractionDigits: 0)) CRB"
            let privateKeyHex = try await WalletSecurityStore.shared.loadPrivateKeyForTransaction(
                walletId: wallet.id,
                amountDescription: amountDescription,
                fallbackPassword: fallbackPassword
            )

            guard let signedTransaction = try WalletCore.signTransaction(
                from: wallet.address,
                to: recipient,
                amount: amount,
                fee: fee,
                nonce: currentBalance.nonce,
                chainId: currentStatus.chain_id,
                signingHeight: UInt64(currentStatus.height + 1),
                privateKeyHex: privateKeyHex,
                publicKeyHex: wallet.publicKeyHex
            ) else {
                throw WalletCore.WalletError.signingFailed
            }

            sendResult = try await CereblixAPIClient.broadcastTransaction(signedTransaction)
            await loadAll(address: wallet.address)
        } catch {
            sendError = error.localizedDescription
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
