import Foundation

enum USDTProvider: String, Codable, CaseIterable, Identifiable {
    case binance = "Binance"
    case okx = "OKX"
    case bybit = "Bybit"
    case coinbase = "Coinbase"
    case metamask = "MetaMask"
    case trustWallet = "Trust Wallet"
    case native = "Native Wallet"
    
    var id: String { self.rawValue }
    
    var iconName: String {
        switch self {
        case .binance, .okx, .bybit, .coinbase: return "building.columns.fill"
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
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .erc20: return "ERC-20 (Ethereum)"
        case .trc20: return "TRC-20 (Tron)"
        case .bep20: return "BEP-20 (BNB Chain)"
        case .polygon: return "Polygon (POL)"
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
