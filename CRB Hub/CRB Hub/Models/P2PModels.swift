import Foundation

// MARK: - Public Endpoints

/// Response from GET /otc/stats
struct P2PStats: Codable {
    let pair: String?
    let price_usdt: Double?
    let change_24h_pct: Double?
    let change_7d_pct: Double?
    let high_24h_usdt: Double?
    let low_24h_usdt: Double?
    let volume_24h_crb: Double?
    let volume_24h_usdt: Double?
    let trades_24h: Int?
    let volume_total_crb: Double?
    let volume_total_usdt: Double?
    let trades_total: Int?
    let market_cap_usdt: Double?
    let circulating_supply_crb: Double?
    let max_supply_crb: Double?
    let percent_mined: Double?
    let block_reward_crb: Double?
    let block_time_secs: Int?
    let emission_24h_crb: Double?
    let emission_24h_usdt: Double?
    let updated: Int?
}

/// Recent completed trade from GET /otc/recent
struct P2PRecentTrade: Codable, Identifiable {
    var id: String { "\(Time ?? 0)-\(AmountCRB ?? 0)" }
    
    let Side: String?
    let Rail: String?
    let AmountCRB: Double?
    let AmountUSDT: Double?
    let Price: Double?
    let Olympus: Bool?
    let Time: Int?
    
    var formattedTime: String {
        guard let time = Time else { return "—" }
        let date = Date(timeIntervalSince1970: TimeInterval(time))
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

/// Public offer from GET /otc/offers
struct P2POffer: Codable, Identifiable {
    let ID: String
    let Side: String?
    let Rail: String?
    let Price: Double?
    let MinCRB: Double?
    let MaxCRB: Double?
    let Info: String?
    let Olympus: Bool?
    
    var id: String { self.ID }
    
    var isSellCRB: Bool {
        Side == "sell_crb"
    }
    
    var sideLabel: String {
        isSellCRB ? "SELL" : "BUY"
    }
    
    var railLabel: String {
        Rail?.capitalized ?? "—"
    }
}

/// Desk state from GET /otc/state
struct P2PState: Codable {
    let mode: String?
    let offers: Int?
    let trades: Int?
    let crbConf: Int?
    let tradingOpen: Bool?
    let openAt: Int?
    let closeAt: Int?
    let publicOrders: Bool?
}

// MARK: - Authentication

/// Challenge from GET /otc/challenge
struct P2PChallenge: Codable {
    let nonce: String
    let msg: String
}

/// Session from POST /otc/login
struct P2PSession: Codable {
    let token: String
    let addr: String?
    let admin: Bool?
    let adminPass: Bool?
    let tg: Bool?
}

// MARK: - Trading

/// Trade detail from GET /otc/trade?id= or POST /otc/take
struct P2PTrade: Codable, Identifiable {
    let ID: String?
    let Side: String?
    let Rail: String?
    let Price: Double?
    let AmountCRB: Double?
    let AmountUSDT: Double?
    let State: String?
    let MakerAddr: String?
    let TakerAddr: String?
    let Info: String?
    let Created: Int?
    let Updated: Int?
    
    // Escrow & details
    let Maker: String?
    let Taker: String?
    let EscrowCRB: String?
    let EscrowUSDT: String?
    let CRBLocked: Bool?
    let USDTFunded: Bool?
    let CRBSeen: Bool?
    let USDTSeen: Bool?
    let CRBConfs: Int?
    let MakerReady: Bool?
    let TakerReady: Bool?
    let ReadyDeadline: Int?
    let LockDeadline: Int?
    
    var id: String { self.ID ?? UUID().uuidString }
    
    var stateLabel: String {
        guard let state = State else { return "Unknown" }
        switch state {
        case "AWAITING_READY": return "Awaiting Ready"
        case "AWAITING_LOCK": return "Awaiting Lock"
        case "COMPLETED": return "Completed"
        case "CANCELLED": return "Cancelled"
        case "REFUNDED": return "Refunded"
        case "EXPIRED": return "Expired"
        default: return state
        }
    }
    
    var stateColor: String {
        guard let state = State else { return "gray" }
        switch state {
        case "AWAITING_READY", "AWAITING_LOCK": return "yellow"
        case "COMPLETED": return "green"
        case "CANCELLED", "REFUNDED", "EXPIRED": return "red"
        default: return "gray"
        }
    }
}

/// Chat message from GET /otc/chat?id=
struct P2PChatMessage: Codable, Identifiable {
    var id: String { "\(time ?? 0)-\(from ?? "")" }
    
    let from: String?
    let text: String?
    let time: Int?
    let translation: String?
    
    var formattedTime: String {
        guard let time = time else { return "—" }
        let date = Date(timeIntervalSince1970: TimeInterval(time))
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Create Offer Request
struct CreateOfferRequest: Codable {
    let side: String
    let rail: String
    let price: Double
    let minCRB: Double
    let maxCRB: Double
    let makerUSDT: String?
    let info: String?
    let readySecs: Int?
    let olympus: Bool?
}

// MARK: - Take Offer Request
struct TakeOfferRequest: Codable {
    let offerID: String
    let amount: Double
    let takerUSDT: String?
    let info: String?
}
