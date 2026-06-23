import Foundation

/// Response from GET /api/status
/// Chain + node status (also powers market/economics figures)
struct ChainStatus: Codable {
    let height: Int
    let tip: String?
    let difficulty: String?
    let hashrate: Double
    let reward: UInt64
    let supply: UInt64
    let epoch: Int
    let mempool: Int
    let peers: Int
    let fee_floor: UInt64
    let fee_suggested: UInt64
    let consensus_version: Int?
    let node_version: String?
    let chain_id: String?
    let block_age: Int?
    let now: Int?
}
