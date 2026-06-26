import SwiftUI

/// ViewModel for P2P market data and trading
@Observable
@MainActor
final class P2PViewModel {
    
    // MARK: - Public Market Data
    var stats: P2PStats?
    var recentTrades: [P2PRecentTrade] = []
    var offers: [P2POffer] = []
    var state: P2PState?
    var isLoadingPublic = false
    var publicError: String?
    var priceHistory: [Double] = [0.102, 0.105, 0.101, 0.108, 0.112, 0.109, 0.115, 0.118, 0.120, 0.116, 0.124, 0.128]
    
    // MARK: - Auth
    var isLoggingIn = false
    var loginError: String?
    
    // MARK: - My Offers & Trades
    var myOffers: [P2POffer] = []
    var myTrades: [P2PTrade] = []
    var isLoadingMyData = false
    
    // MARK: - Trade Detail
    var currentTrade: P2PTrade?
    var chatMessages: [P2PChatMessage] = []
    var isLoadingTrade = false
    
    // MARK: - Auto Refresh
    private var refreshTask: Task<Void, Never>?
    private var chatRefreshTask: Task<Void, Never>?
    private let publicRefreshSeconds: UInt64 = 5
    private let privateRefreshSeconds: UInt64 = 5
    private let tradeRefreshSeconds: UInt64 = 3
    private var knownTradeStates: [String: String] = [:]
    private var knownChatMessageIdsByTrade: [String: Set<String>] = [:]
    
    // MARK: - Public Actions
    
    func loadPublicData() async {
        guard !isLoadingPublic else { return }
        isLoadingPublic = true
        publicError = nil
        
        do {
            async let s = P2PAPIClient.getStats()
            async let r = P2PAPIClient.getRecentTrades()
            async let o = P2PAPIClient.getOffers()
            async let st = P2PAPIClient.getState()
            
            stats = try await s
            recentTrades = try await r
            offers = try await o
            state = try await st
        } catch {
            publicError = error.localizedDescription
        }
        
        isLoadingPublic = false
    }
    
    // MARK: - Auth Actions
    
    func login(appState: AppState) async {
        guard !isLoggingIn else { return }
        guard let wallet = appState.selectedWallet else {
            loginError = "No wallet selected"
            return
        }
        
        isLoggingIn = true
        loginError = nil
        
        do {
            // Step 1: Get challenge from server
            let challenge = try await P2PAPIClient.getChallenge()
            
            // Step 2: Load private key with biometric authentication (Keychain-enforced)
            let privateKeyHex = try await KeychainStore.shared.loadPrivateKeySecure(
                for: wallet.id,
                reason: "Authenticate to sign P2P login challenge"
            )
            
            // Step 3: Sign the exact OTC challenge msg after canonical validation.
            // Expected format: "cereblix-otc-login|<nonce>".
            let signature = try WalletCore.signP2PLogin(
                nonce: challenge.nonce,
                message: challenge.msg,
                privateKeyHex: privateKeyHex
            )
            
            // Step 4: Login with pub, nonce, sig
            let session = try await P2PAPIClient.login(
                pub: wallet.publicKeyHex,
                nonce: challenge.nonce,
                sig: signature
            )
            
            // Step 5: Store token in memory only (never persisted)
            appState.setP2PSession(token: session.token, address: session.addr ?? wallet.address)
            
        } catch {
            loginError = error.localizedDescription
        }
        
        isLoggingIn = false
    }
    
    func logout(appState: AppState) async {
        if let token = appState.p2pToken {
            try? await P2PAPIClient.logout(token: token)
        }
        appState.clearP2PSession()
    }
    
    // MARK: - Trading Actions
    
    func loadMyData(token: String, appState: AppState? = nil) async {
        guard !isLoadingMyData else { return }
        isLoadingMyData = true
        
        do {
            async let o = P2PAPIClient.getMyOffers(token: token)
            async let t = P2PAPIClient.getMyTrades(token: token)
            
            let fetchedOffers = try await o
            let fetchedTrades = try await t
            processTradeStateNotifications(fetchedTrades)
            myOffers = fetchedOffers
            myTrades = fetchedTrades
            appState?.hydrateP2PWalletBindings(offers: myOffers, trades: myTrades)
        } catch {
            // Handle auth errors
            if case CRBAPIError.unauthorized(_) = error {
                // Token expired
            }
        }
        
        isLoadingMyData = false
    }
    
    func createOffer(token: String, offer: CreateOfferRequest, appState: AppState? = nil) async throws -> P2POffer {
        let created = try await P2PAPIClient.createOffer(token: token, offer: offer)
        await loadMyData(token: token, appState: appState)
        return created
    }
    
    func cancelOffer(token: String, offerId: String) async throws {
        try await P2PAPIClient.cancelOffer(token: token, offerId: offerId)
        await loadMyData(token: token)
    }
    
    func takeOffer(token: String, request: TakeOfferRequest, appState: AppState? = nil) async throws -> P2PTrade {
        let trade = try await P2PAPIClient.takeOffer(token: token, request: request)
        await loadMyData(token: token, appState: appState)
        return trade
    }
    
    func loadTrade(token: String, tradeId: String) async {
        guard !isLoadingTrade else { return }
        isLoadingTrade = true
        do {
            let trade = try await P2PAPIClient.getTrade(token: token, tradeId: tradeId)
            processTradeStateNotifications([trade])
            currentTrade = trade
        } catch {
            // Handle error
        }
        isLoadingTrade = false
    }
    
    func loadChat(token: String, tradeId: String) async {
        do {
            let messages = try await P2PAPIClient.getChat(token: token, tradeId: tradeId)
            processChatNotifications(messages, tradeId: tradeId)
            chatMessages = messages
        } catch {
            // Handle error
        }
    }
    
    func sendChat(token: String, tradeId: String, text: String) async {
        do {
            try await P2PAPIClient.sendChat(token: token, tradeId: tradeId, text: text)
            await loadChat(token: token, tradeId: tradeId)
        } catch {
            // Handle error
        }
    }
    
    func tradeReady(token: String, tradeId: String) async throws {
        try await P2PAPIClient.tradeReady(token: token, tradeId: tradeId)
        await loadTrade(token: token, tradeId: tradeId)
    }
    
    func tradeCancel(token: String, tradeId: String) async throws {
        try await P2PAPIClient.tradeCancel(token: token, tradeId: tradeId)
        await loadTrade(token: token, tradeId: tradeId)
    }
    
    func tradeRate(token: String, tradeId: String, up: Bool) async throws {
        try await P2PAPIClient.tradeRate(token: token, tradeId: tradeId, up: up)
    }
    
    // MARK: - Auto Refresh
    
    func startPublicRefresh() {
        stopAutoRefresh()
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(publicRefreshSeconds))
                guard !Task.isCancelled else { return }
                await loadPublicData()
            }
        }
    }

    func startAuthenticatedRefresh(token: String, appState: AppState? = nil) {
        stopAutoRefresh()
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(privateRefreshSeconds))
                guard !Task.isCancelled else { return }
                await loadMyData(token: token, appState: appState)
            }
        }
    }
    
    func startChatRefresh(token: String, tradeId: String) {
        chatRefreshTask?.cancel()
        chatRefreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(tradeRefreshSeconds))
                guard !Task.isCancelled else { return }
                await withTaskGroup(of: Void.self) { group in
                    group.addTask { await self.loadChat(token: token, tradeId: tradeId) }
                    group.addTask { await self.loadTrade(token: token, tradeId: tradeId) }
                }
            }
        }
    }
    
    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
        chatRefreshTask?.cancel()
        chatRefreshTask = nil
    }
    
    // MARK: - Computed
    
    var sellOffers: [P2POffer] {
        offers.filter { $0.isSellCRB }
    }
    
    var buyOffers: [P2POffer] {
        offers.filter { !$0.isSellCRB }
    }
    
    var isTradingOpen: Bool {
        state?.tradingOpen ?? false
    }

    private func processTradeStateNotifications(_ trades: [P2PTrade]) {
        for trade in trades {
            guard let id = trade.ID, let state = trade.State else { continue }
            let previous = knownTradeStates[id]
            knownTradeStates[id] = state
            guard let previous, previous != state else { continue }

            LocalNotificationService.shared.notify(
                title: "P2P trade updated",
                body: "Trade \(id) changed from \(previous) to \(trade.stateLabel).",
                key: "p2p.trade.state.\(id).\(state)",
                cooldown: 60
            )
        }
    }

    private func processChatNotifications(_ messages: [P2PChatMessage], tradeId: String) {
        let currentIds = Set(messages.map(\.id))
        defer { knownChatMessageIdsByTrade[tradeId] = currentIds }

        guard let knownIds = knownChatMessageIdsByTrade[tradeId], !knownIds.isEmpty else {
            return
        }

        let newMessages = messages.filter { !knownIds.contains($0.id) }
        guard let latest = newMessages.last else { return }
        let snippet = latest.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        LocalNotificationService.shared.notify(
            title: "New P2P chat message",
            body: snippet?.isEmpty == false ? snippet! : "Trade \(tradeId) has a new chat message.",
            key: "p2p.chat.\(tradeId)",
            cooldown: 60
        )
    }
}
