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
    private let liveRefreshSeconds: UInt64 = 10
    private let historyRefreshEveryTicks = 3
    
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
            try await validateSigningMetadata(
                wallet: wallet,
                balance: currentBalance,
                status: currentStatus
            )
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

    private func validateSigningMetadata(wallet: WalletAccount, balance: BalanceResponse, status: ChainStatus) async throws {
        guard status.height >= 0 else {
            throw SigningMetadataError.invalidHeight
        }

        let usingOfficialNode = APIConfig.baseURL.lowercased() == APIConfig.officialBaseURL.lowercased()
        guard !usingOfficialNode else { return }

        let officialStatus = try await CereblixAPIClient.getStatus(baseURL: APIConfig.officialBaseURL)
        let officialBalance = try await CereblixAPIClient.getBalance(address: wallet.address, baseURL: APIConfig.officialBaseURL)

        if let officialChainID = officialStatus.chain_id,
           let nodeChainID = status.chain_id,
           !officialChainID.isEmpty,
           !nodeChainID.isEmpty,
           officialChainID != nodeChainID {
            throw SigningMetadataError.chainIDMismatch
        }

        if abs(status.height - officialStatus.height) > 6 {
            throw SigningMetadataError.heightMismatch
        }

        if balance.nonce < officialBalance.nonce {
            throw SigningMetadataError.staleNonce
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

                await withTaskGroup(of: Void.self) { group in
                    group.addTask { await self.loadBalance(address: address) }
                    group.addTask { await self.loadChainStatus() }
                    if tick % self.historyRefreshEveryTicks == 0 {
                        group.addTask { await self.loadHistory(address: address, refresh: true) }
                    }
                }
            }
        }
    }
    
    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    enum SigningMetadataError: LocalizedError {
        case invalidHeight
        case chainIDMismatch
        case heightMismatch
        case staleNonce

        var errorDescription: String? {
            switch self {
            case .invalidHeight:
                return "Node returned an invalid signing height."
            case .chainIDMismatch:
                return "Custom node chain ID does not match the official Cereblix node. Transaction signing was blocked."
            case .heightMismatch:
                return "Custom node height is too far from the official Cereblix node. Transaction signing was blocked."
            case .staleNonce:
                return "Custom node returned an old nonce. Transaction signing was blocked."
            }
        }
    }
}
