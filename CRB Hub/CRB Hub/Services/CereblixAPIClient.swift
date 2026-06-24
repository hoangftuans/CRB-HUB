import Foundation

/// Cereblix Wallet/Node API client
/// Calls the chain API: status, balance, history, tx
enum CereblixAPIClient {
    
    /// GET /api/status — chain + node status
    static func getStatus() async throws -> ChainStatus {
        try await APIClient.get("\(APIConfig.walletAPI)/status", type: ChainStatus.self)
    }

    static func getStatus(baseURL: String) async throws -> ChainStatus {
        try await APIClient.get("\(baseURL)/api/status", type: ChainStatus.self)
    }
    
    /// GET /api/balance?addr=crb1... — balance and account info
    static func getBalance(address: String) async throws -> BalanceResponse {
        let url = try APIClient.makeURL(
            base: APIConfig.walletAPI,
            path: "balance",
            queryItems: [URLQueryItem(name: "addr", value: address)]
        )
        return try await APIClient.get(url, type: BalanceResponse.self)
    }

    static func getBalance(address: String, baseURL: String) async throws -> BalanceResponse {
        let url = try APIClient.makeURL(
            base: "\(baseURL)/api",
            path: "balance",
            queryItems: [URLQueryItem(name: "addr", value: address)]
        )
        return try await APIClient.get(url, type: BalanceResponse.self)
    }
    
    /// GET /api/history?addr=crb1...&limit=50&offset=0 — transaction history
    static func getHistory(address: String, limit: Int = 50, offset: Int = 0) async throws -> [CRBTransaction] {
        let url = try APIClient.makeURL(
            base: APIConfig.walletAPI,
            path: "history",
            queryItems: [
                URLQueryItem(name: "addr", value: address),
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "offset", value: String(offset)),
            ]
        )
        return try await APIClient.get(url, type: [CRBTransaction].self)
    }
    
    /// GET /api/tx?id=<txid> — look up a transaction
    static func getTransaction(txid: String) async throws -> CRBTransaction {
        let url = try APIClient.makeURL(
            base: APIConfig.walletAPI,
            path: "tx",
            queryItems: [URLQueryItem(name: "id", value: txid)]
        )
        return try await APIClient.get(url, type: CRBTransaction.self)
    }
    
    /// POST /api/tx — broadcast a signed transaction
    static func broadcastTransaction(_ signedTx: SignedCRBTransaction) async throws -> BroadcastResult {
        try await APIClient.post("\(APIConfig.walletAPI)/tx", body: signedTx, type: BroadcastResult.self)
    }
}
