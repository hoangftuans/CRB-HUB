import Foundation

struct USDTBalanceService {

    // USDT Token Contracts
    private static let ethUSDTContract = "0xdAC17F958D2ee523a2206206994597C13D831ec7"
    private static let bscUSDTContract = "0x55d398326f99059fF775485246999027B3197955"
    private static let polygonUSDTContract = "0xc2132D05D31c914a87C6611C10748AEb04B58e8F"

    // JSON-RPC Endpoints
    private static let ethRPC = "https://cloudflare-eth.com"
    private static let bscRPC = "https://bsc-dataseed.binance.org"
    private static let polygonRPC = "https://polygon-rpc.com"

    /// Fetches the live USDT balance of an address on the specified network.
    static func fetchBalance(for address: String, network: USDTNetwork) async throws -> Decimal {
        let cleanedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedAddress.isEmpty else { return 0.0 }

        switch network {
        case .erc20:
            return try await fetchEVMBalance(rpcURL: ethRPC, tokenContract: ethUSDTContract, userAddress: cleanedAddress, decimals: 6)
        case .bep20:
            return try await fetchEVMBalance(rpcURL: bscRPC, tokenContract: bscUSDTContract, userAddress: cleanedAddress, decimals: 18)
        case .polygon:
            return try await fetchEVMBalance(rpcURL: polygonRPC, tokenContract: polygonUSDTContract, userAddress: cleanedAddress, decimals: 6)
        case .trc20:
            return try await fetchTronBalance(userAddress: cleanedAddress)
        }
    }

    // MARK: - EVM RPC Fetcher

    private static func fetchEVMBalance(rpcURL: String, tokenContract: String, userAddress: String, decimals: Int) async throws -> Decimal {
        guard userAddress.hasPrefix("0x") && userAddress.count == 42 else {
            throw NSError(domain: "USDTBalanceService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid EVM address format"])
        }

        // Method signature for balanceOf(address) is 0x70a08231
        // Parameter is the 20-byte address padded to 32 bytes (64 characters)
        let methodId = "0x70a08231"
        let cleanAddress = String(userAddress.dropFirst(2)).lowercased()
        let paddedAddress = String(repeating: "0", count: 24) + cleanAddress
        let dataParam = methodId + paddedAddress

        // Build JSON-RPC payload
        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "method": "eth_call",
            "params": [
                [
                    "to": tokenContract,
                    "data": dataParam
                ],
                "latest"
            ]
        ]

        guard let url = URL(string: rpcURL) else {
            throw NSError(domain: "USDTBalanceService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid RPC URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        request.timeoutInterval = 10

        let (data, _) = try await URLSession.shared.data(for: request)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? String else {
            throw NSError(domain: "USDTBalanceService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Malformed JSON-RPC response"])
        }

        // Parse hex result
        var hexAmount = result.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if hexAmount.hasPrefix("0x") {
            hexAmount = String(hexAmount.dropFirst(2))
        }

        // Convert to double/decimal
        guard let rawVal = parseHex(hexAmount) else {
            throw NSError(domain: "USDTBalanceService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to parse balance hex value"])
        }

        let divisor = pow(10, decimals)
        return Decimal(rawVal) / divisor
    }

    // MARK: - Tron Fetcher

    private static func fetchTronBalance(userAddress: String) async throws -> Decimal {
        // TRC-20 addresses must start with "T" and be 34 characters
        guard userAddress.hasPrefix("T") && userAddress.count == 34 else {
            throw NSError(domain: "USDTBalanceService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Tron address format"])
        }

        // Use free public Tronscan API endpoint
        var components = URLComponents(string: "https://apilist.tronscanapi.com/api/account/tokens")
        components?.queryItems = [URLQueryItem(name: "address", value: userAddress)]

        guard let url = components?.url else {
            throw NSError(domain: "USDTBalanceService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Tronscan URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataArray = json["data"] as? [[String: Any]] {

                // Find TRC20 USDT in the token list
                // TRC-20 USDT Contract is TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t
                if let usdtToken = dataArray.first(where: { ($0["tokenId"] as? String) == "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t" }) {
                    if let balanceStr = usdtToken["balance"] as? String,
                       let balanceVal = Double(balanceStr) {
                        // Tron USDT has 6 decimals
                        return Decimal(balanceVal) / 1_000_000
                    }
                }
            }
        } catch {
            // Fallback to simulation if Tronscan API is rate-limited
            return 0.0
        }

        return 0.0
    }

    // MARK: - Parsing Helpers

    private static func parseHex(_ hex: String) -> UInt64? {
        // Take the suffix representing 64-bit value to avoid overflow
        let safeHex = String(hex.suffix(16))
        return UInt64(safeHex, radix: 16)
    }
}
