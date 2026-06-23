import Foundation

enum USDTProvider: String, Codable, CaseIterable, Identifiable {
    case binance = "Binance"
    case okx = "OKX"
    case bybit = "Bybit"
    case coinbase = "Coinbase"
    case metamask = "MetaMask"
    case trustWallet = "Trust Wallet"
    case safeTrade = "SafeTrade"
    case native = "Native Wallet"
    
    var id: String { self.rawValue }
    
    var iconName: String {
        switch self {
        case .binance, .okx, .bybit, .coinbase: return "building.columns.fill"
        case .safeTrade: return "server.rack"
        case .metamask, .trustWallet: return "wallet.pass.fill"
        case .native: return "iphone.gen3"
        }
    }
}

enum USDTNetwork: String, Codable, CaseIterable, Identifiable {
    case erc20 = "ERC-20"
    case trc20 = "TRC-20"
    case bep20 = "BEP-20"
    case polygon = "Polygon"
    case solana = "Solana"
    
    var id: String { self.rawValue }

    static let p2pSupportedNetworks: [USDTNetwork] = [.polygon, .solana]
    
    var displayName: String {
        switch self {
        case .erc20: return "ERC-20 (Ethereum)"
        case .trc20: return "TRC-20 (Tron)"
        case .bep20: return "BEP-20 (BNB Chain)"
        case .polygon: return "Polygon (POL)"
        case .solana: return "Solana"
        }
    }

    var p2pRail: String? {
        switch self {
        case .polygon:
            return "polygon"
        case .solana:
            return "solana"
        case .erc20, .trc20, .bep20:
            return nil
        }
    }

    var p2pReceiveLabel: String {
        switch self {
        case .polygon:
            return "Polygon USDT"
        case .solana:
            return "Solana USDT"
        default:
            return displayName
        }
    }

    var isEVM: Bool {
        switch self {
        case .erc20, .bep20, .polygon:
            return true
        case .trc20, .solana:
            return false
        }
    }

    static func isValidP2PAddress(_ address: String, rail: String) -> Bool {
        let cleanAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        switch rail.lowercased() {
        case "polygon":
            let hexCharacters = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
            let body = String(cleanAddress.dropFirst(2))
            return cleanAddress.hasPrefix("0x") &&
                cleanAddress.count == 42 &&
                body.unicodeScalars.allSatisfy { hexCharacters.contains($0) }
        case "solana":
            let base58Characters = CharacterSet(charactersIn: "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")
            return cleanAddress.count >= 32 &&
                cleanAddress.count <= 44 &&
                cleanAddress.unicodeScalars.allSatisfy { base58Characters.contains($0) }
        default:
            return false
        }
    }
}

struct USDTWallet: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var provider: USDTProvider
    var network: USDTNetwork
    var address: String
    var balance: Decimal = 0.0
    var isNative: Bool = false
}

struct P2PWalletBinding: Codable, Identifiable, Hashable {
    enum BindingKind: String, Codable {
        case offer
        case trade
    }

    enum Role: String, Codable {
        case maker
        case taker
    }

    var id: String { "\(kind.rawValue):\(p2pId):\(role.rawValue)" }
    let kind: BindingKind
    let p2pId: String
    let role: Role
    let crbWalletId: UUID
    let crbAddress: String
    let usdtWalletId: UUID?
    let usdtAddress: String
    let usdtNetwork: USDTNetwork
    let rail: String
    let createdAt: Date
}
