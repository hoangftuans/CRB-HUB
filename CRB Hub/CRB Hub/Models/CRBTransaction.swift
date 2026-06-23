import Foundation

/// Transaction model from /api/history and /api/tx
struct CRBTransaction: Codable, Identifiable {
    var id: String { txid }
    
    let from: String?
    let to: String?
    let amount: UInt64
    let fee: UInt64
    let nonce: UInt64?
    let height: Int?
    let txid: String
    let time: Int?
    
    /// Determine transaction type relative to a given address
    func transactionType(for address: String) -> TransactionType {
        if from == nil && to == address {
            return .mined
        } else if to == address {
            if from == "crb1b1a90fe0fdd522368cc784973c768cf3ca46c9d6" {
                return .mined
            }
            return .received
        } else if from == address {
            return .sent
        }
        return .unknown
    }
    
    enum TransactionType {
        case sent, received, mined, unknown
        
        var label: String {
            switch self {
            case .sent: return "Sent Transaction".localized
            case .received: return "Received Transaction".localized
            case .mined: return "Mined Transaction".localized
            case .unknown: return "Unknown".localized
            }
        }
        
        var icon: String {
            switch self {
            case .sent: return "arrow.up.right"
            case .received: return "arrow.down.left"
            case .mined: return "hammer.fill"
            case .unknown: return "questionmark.circle"
            }
        }
    }
}

/// Signed transaction to broadcast via POST /api/tx
struct SignedCRBTransaction: Codable {
    let from: String
    let to: String
    let amount: UInt64
    let fee: UInt64
    let nonce: UInt64
    let pubkey: String
    let sig: String
    let chain_id: String?

    enum CodingKeys: String, CodingKey {
        case from
        case to
        case amount
        case fee
        case nonce
        case pubkey = "from_pub"
        case sig
        case chain_id
    }
}

/// Response from POST /api/tx
struct BroadcastResult: Codable {
    let result: String?
    let txid: String?
    let error: String?
}

/// Wallet account model stored locally
struct WalletAccount: Codable, Identifiable {
    let id: UUID
    let address: String
    let publicKeyHex: String
    let name: String
    let createdAt: Date
    
    init(id: UUID = UUID(), address: String, publicKeyHex: String, name: String, createdAt: Date = Date()) {
        self.id = id
        self.address = address
        self.publicKeyHex = publicKeyHex
        self.name = name
        self.createdAt = createdAt
    }
}
