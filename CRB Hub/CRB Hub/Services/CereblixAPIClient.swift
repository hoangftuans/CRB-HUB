import Foundation

/// Cereblix Wallet/Node API client
/// Calls the chain API: status, balance, history, tx
enum CereblixAPIClient {
    
    /// GET /api/status — chain + node status
    static func getStatus() async throws -> ChainStatus {
        try await APIClient.get("\(APIConfig.walletAPI)/status", type: ChainStatus.self)
    }
    
    /// GET /api/balance?addr=crb1... — balance and account info
    static func getBalance(address: String) async throws -> BalanceResponse {
        try await APIClient.get("\(APIConfig.walletAPI)/balance?addr=\(address)", type: BalanceResponse.self)
    }
    
    /// GET /api/history?addr=crb1...&limit=50&offset=0 — transaction history
    static func getHistory(address: String, limit: Int = 50, offset: Int = 0) async throws -> [CRBTransaction] {
        try await APIClient.get(
            "\(APIConfig.walletAPI)/history?addr=\(address)&limit=\(limit)&offset=\(offset)",
            type: [CRBTransaction].self
        )
    }
    
    /// GET /api/tx?id=<txid> — look up a transaction
    static func getTransaction(txid: String) async throws -> CRBTransaction {
        try await APIClient.get("\(APIConfig.walletAPI)/tx?id=\(txid)", type: CRBTransaction.self)
    }
    
    /// POST /api/tx — broadcast a signed transaction
    static func broadcastTransaction(_ signedTx: SignedCRBTransaction) async throws -> BroadcastResult {
        try await APIClient.post("\(APIConfig.walletAPI)/tx", body: signedTx, type: BroadcastResult.self)
    }
}
