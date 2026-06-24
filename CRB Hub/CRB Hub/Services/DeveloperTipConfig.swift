import Foundation

enum DeveloperTipConfig {
    static let crbAddress = "crb1bcf10b1d12f028f8a3583010c1be8f228360727b"

    static let usdtRecipients: [USDTNetwork: String] = [
        .polygon: "0x1ba88a91736f1af18e508c878f3a22a3a25eb7d9",
        .solana: ""
    ]

    static var configuredUSDTRecipients: [(network: USDTNetwork, address: String)] {
        usdtRecipients.compactMap { network, address in
            let cleanAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanAddress.isEmpty else { return nil }
            return (network, cleanAddress)
        }
        .sorted { $0.network.displayName < $1.network.displayName }
    }
}
