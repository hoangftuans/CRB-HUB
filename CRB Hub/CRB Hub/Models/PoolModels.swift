import Foundation

/// Pool-wide statistics from GET /pool/api/poolstats
struct PoolStatsResponse: Codable {
    let pool_address: String?
    let fee_permil: Int?
    let blocks_found: Int?
    let round_shares: Double?
    let min_payout: UInt64?
    let active_miners: Int?
    let pool_hashrate: Double?
    let hashes_per_share: Double?
    let total_owed: UInt64?
    let total_paid: UInt64?
    let share_window_s: Int?
    let miners: [PoolMiner]?
}

/// Individual miner in pool stats
struct PoolMiner: Codable, Identifiable {
    var id: String { address }
    
    let address: String
    let shares: Double
    let owed: UInt64
    let paid: UInt64
    let earned: UInt64
    let hashrate: Double
}

/// Workers response from GET /pool/api/workers?addr=
struct WorkersResponse: Codable {
    let address: String?
    let window_secs: Int?
    let workers: [PoolWorker]?
}

/// Individual worker stats
struct PoolWorker: Codable, Identifiable {
    var id: String { worker }
    
    let worker: String
    let hashrate: Double
    let shares: Double
    let idle_secs: Int
    
    var isIdle: Bool {
        idle_secs > 300
    }

    var isOnline: Bool {
        idle_secs <= 60
    }

    var isWarming: Bool {
        idle_secs > 60 && idle_secs <= 300
    }
    
    var statusLabel: String {
        if idle_secs <= 60 {
            return "Active".localized
        } else if idle_secs <= 300 {
            return "Idle".localized + " \(idle_secs / 60)m"
        } else {
            return "Offline".localized + " \(idle_secs / 60)m"
        }
    }

    var idleDisplay: String {
        if idle_secs <= 0 {
            return "now"
        }
        if idle_secs < 60 {
            return "\(idle_secs)s ago"
        }
        let minutes = idle_secs / 60
        if minutes < 60 {
            return "\(minutes)m ago"
        }
        return "\(minutes / 60)h \(minutes % 60)m ago"
    }
}

/// Pool health from GET /pool/api/health
struct PoolHealth: Codable {
    let ok: Bool
    let role: String?
    let instance: String?
    let height: Int?
}
