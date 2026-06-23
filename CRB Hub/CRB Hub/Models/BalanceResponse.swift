import Foundation

/// Response from GET /api/balance?addr=crb1...
struct BalanceResponse: Codable {
    let address: String
    let balance: UInt64
    let spendable: UInt64
    let nonce: UInt64
    let received: UInt64?
    let mined: UInt64?
    let sent: UInt64?
    let txns: Int?
}
