import Foundation

/// Cereblix P2P Exchange (OTC) API client
/// Public endpoints + authenticated trading endpoints
/// All user inputs are sanitized before being sent to the server.
enum P2PAPIClient {
    
    // MARK: - Input Sanitization
    
    /// Maximum chat message length
    private static let maxChatLength = 1000
    
    /// Sanitize a chat message: trim, strip control characters, limit length
    private static func sanitizeChat(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = trimmed.unicodeScalars.filter { !$0.properties.isDefaultIgnorableCodePoint && ($0.value >= 0x20 || $0 == "\n") }
        let sanitized = String(String.UnicodeScalarView(cleaned))
        return String(sanitized.prefix(maxChatLength))
    }
    
    /// Validate an ID parameter (trade ID, offer ID, etc.)
    /// Must be non-empty and contain only safe characters (alphanumeric, hyphen, underscore)
    private static func validateId(_ id: String) -> Bool {
        let pattern = "^[a-zA-Z0-9_-]{1,128}$"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(id.startIndex..., in: id)
        return regex.firstMatch(in: id, range: range) != nil
    }
    
    // MARK: - Public Endpoints (no auth)
    
    /// GET /otc/stats — market ticker
    static func getStats() async throws -> P2PStats {
        try await APIClient.get("\(APIConfig.p2pAPI)/stats", type: P2PStats.self)
    }
    
    /// GET /otc/recent — recent completed trades
    static func getRecentTrades() async throws -> [P2PRecentTrade] {
        try await APIClient.get("\(APIConfig.p2pAPI)/recent", type: [P2PRecentTrade].self)
    }
    
    /// GET /otc/offers — public order book
    static func getOffers() async throws -> [P2POffer] {
        try await APIClient.get("\(APIConfig.p2pAPI)/offers", type: [P2POffer].self)
    }
    
    /// GET /otc/state — desk status / trading window
    static func getState() async throws -> P2PState {
        try await APIClient.get("\(APIConfig.p2pAPI)/state", type: P2PState.self)
    }
    
    // MARK: - Authentication
    
    /// GET /otc/challenge — get login challenge
    static func getChallenge() async throws -> P2PChallenge {
        try await APIClient.get("\(APIConfig.p2pAPI)/challenge", type: P2PChallenge.self)
    }
    
    /// POST /otc/login — login with wallet signature
    static func login(pub: String, nonce: String, sig: String) async throws -> P2PSession {
        struct LoginRequest: Codable {
            let pub: String
            let nonce: String
            let sig: String
        }
        let body = LoginRequest(pub: pub, nonce: nonce, sig: sig)
        return try await APIClient.post("\(APIConfig.p2pAPI)/login", body: body, type: P2PSession.self)
    }
    
    /// POST /otc/logout
    static func logout(token: String) async throws {
        struct Empty: Codable {}
        try await APIClient.postAuthSimple("\(APIConfig.p2pAPI)/logout", token: token, body: Empty())
    }
    
    // MARK: - Trading Endpoints (Bearer token required)
    
    /// POST /otc/offers — create an offer
    static func createOffer(token: String, offer: CreateOfferRequest) async throws -> P2POffer {
        try await APIClient.postAuth("\(APIConfig.p2pAPI)/offers", token: token, body: offer, type: P2POffer.self)
    }
    
    /// POST /otc/offers/cancel — cancel own offer
    static func cancelOffer(token: String, offerId: String) async throws {
        guard validateId(offerId) else { throw CRBAPIError.badRequest("Invalid offer ID") }
        struct CancelRequest: Codable { let id: String }
        try await APIClient.postAuthSimple("\(APIConfig.p2pAPI)/offers/cancel", token: token, body: CancelRequest(id: offerId))
    }
    
    /// GET /otc/myoffers — my offers
    static func getMyOffers(token: String) async throws -> [P2POffer] {
        try await APIClient.getAuth("\(APIConfig.p2pAPI)/myoffers", token: token, type: [P2POffer].self)
    }
    
    /// POST /otc/take — take an offer
    static func takeOffer(token: String, request: TakeOfferRequest) async throws -> P2PTrade {
        try await APIClient.postAuth("\(APIConfig.p2pAPI)/take", token: token, body: request, type: P2PTrade.self)
    }
    
    /// GET /otc/trade?id= — trade detail
    static func getTrade(token: String, tradeId: String) async throws -> P2PTrade {
        guard validateId(tradeId) else { throw CRBAPIError.badRequest("Invalid trade ID") }
        let url = try APIClient.makeURL(
            base: APIConfig.p2pAPI,
            path: "trade",
            queryItems: [URLQueryItem(name: "id", value: tradeId)]
        )
        return try await APIClient.getAuth(url, token: token, type: P2PTrade.self)
    }
    
    /// GET /otc/mytrades — all my trades
    static func getMyTrades(token: String) async throws -> [P2PTrade] {
        try await APIClient.getAuth("\(APIConfig.p2pAPI)/mytrades", token: token, type: [P2PTrade].self)
    }
    
    /// POST /otc/trade/ready
    static func tradeReady(token: String, tradeId: String) async throws {
        struct ReadyRequest: Codable { let id: String }
        try await APIClient.postAuthSimple("\(APIConfig.p2pAPI)/trade/ready", token: token, body: ReadyRequest(id: tradeId))
    }
    
    /// POST /otc/trade/cancel
    static func tradeCancel(token: String, tradeId: String) async throws {
        struct CancelRequest: Codable { let id: String }
        try await APIClient.postAuthSimple("\(APIConfig.p2pAPI)/trade/cancel", token: token, body: CancelRequest(id: tradeId))
    }
    
    /// POST /otc/trade/appeal
    static func tradeAppeal(token: String, tradeId: String, category: String) async throws {
        struct AppealRequest: Codable { let id: String; let category: String }
        try await APIClient.postAuthSimple("\(APIConfig.p2pAPI)/trade/appeal", token: token, body: AppealRequest(id: tradeId, category: category))
    }
    
    /// POST /otc/trade/call-admin
    static func tradeCallAdmin(token: String, tradeId: String) async throws {
        struct CallAdminRequest: Codable { let id: String }
        try await APIClient.postAuthSimple("\(APIConfig.p2pAPI)/trade/call-admin", token: token, body: CallAdminRequest(id: tradeId))
    }
    
    /// POST /otc/trade/rate
    static func tradeRate(token: String, tradeId: String, up: Bool) async throws {
        struct RateRequest: Codable { let id: String; let up: Bool }
        try await APIClient.postAuthSimple("\(APIConfig.p2pAPI)/trade/rate", token: token, body: RateRequest(id: tradeId, up: up))
    }
    
    /// GET /otc/chat?id= — read trade chat
    static func getChat(token: String, tradeId: String) async throws -> [P2PChatMessage] {
        let url = try APIClient.makeURL(
            base: APIConfig.p2pAPI,
            path: "chat",
            queryItems: [URLQueryItem(name: "id", value: tradeId)]
        )
        return try await APIClient.getAuth(url, token: token, type: [P2PChatMessage].self)
    }
    
    /// POST /otc/chat — send chat message
    static func sendChat(token: String, tradeId: String, text: String) async throws {
        guard validateId(tradeId) else { throw CRBAPIError.badRequest("Invalid trade ID") }
        let sanitizedText = sanitizeChat(text)
        guard !sanitizedText.isEmpty else { throw CRBAPIError.badRequest("Chat message cannot be empty") }
        struct ChatRequest: Codable { let id: String; let text: String }
        try await APIClient.postAuthSimple("\(APIConfig.p2pAPI)/chat", token: token, body: ChatRequest(id: tradeId, text: sanitizedText))
    }
    
    /// POST /otc/block
    static func blockUser(token: String, id: String) async throws {
        struct BlockRequest: Codable { let id: String }
        try await APIClient.postAuthSimple("\(APIConfig.p2pAPI)/block", token: token, body: BlockRequest(id: id))
    }
    
    /// POST /otc/unblock
    static func unblockUser(token: String, id: String) async throws {
        struct UnblockRequest: Codable { let id: String }
        try await APIClient.postAuthSimple("\(APIConfig.p2pAPI)/unblock", token: token, body: UnblockRequest(id: id))
    }
}
