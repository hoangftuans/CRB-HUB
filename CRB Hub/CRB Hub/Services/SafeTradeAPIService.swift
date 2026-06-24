import CryptoKit
import Foundation

@MainActor
final class SafeTradeAPIService {
    static let shared = SafeTradeAPIService()

    private let settingsKey = "safetrade_api_settings"
    private let secretAccount = "safetrade_api_secret"
    private let keychain = KeychainStore.shared

    private init() {}

    var settings: Settings {
        get {
            guard let data = UserDefaults.standard.data(forKey: settingsKey),
                  let settings = try? JSONDecoder().decode(Settings.self, from: data) else {
                return .default
            }
            return settings
        }
        set {
            UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: settingsKey)
        }
    }

    var isEnabled: Bool {
        guard let secret = try? loadSecret() else {
            return false
        }
        return settings.isEnabled && !secret.isEmpty
    }

    func save(settings: Settings, apiSecret: String?) throws {
        var clean = settings.normalized
        clean.lastTestedAt = nil
        clean.lastTestStatus = nil
        self.settings = clean

        if let apiSecret, !apiSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            try keychain.saveGenericSecret(Data(apiSecret.utf8), account: secretAccount)
        }
    }

    func disconnect() {
        settings = .default
        keychain.deleteGenericSecret(account: secretAccount)
    }

    func testConnection() async throws -> String {
        let result: SafeTradeMemberResponse = try await request(
            path: settings.normalized.statusPath,
            method: "GET",
            queryItems: [],
            body: Optional<EmptyBody>.none
        )
        var updated = settings
        updated.lastTestedAt = Date()
        updated.lastTestStatus = result.email.map { "Connected: \($0)" } ?? result.uid.map { "Connected: \($0)" } ?? "Connected"
        settings = updated
        return updated.lastTestStatus ?? "Connected"
    }

    func fetchUSDTBalance(address: String, network: USDTNetwork) async throws -> Decimal {
        guard isEnabled else {
            throw SafeTradeError.notConfigured
        }

        let response: [SafeTradeSpotBalanceResponse] = try await request(
            path: settings.normalized.balancePath,
            method: "GET",
            queryItems: [],
            body: Optional<EmptyBody>.none
        )

        guard let account = response.first(where: { $0.currency.lowercased() == "usdt" }) else {
            throw SafeTradeError.unexpectedResponse
        }
        return account.balance
    }

    func fetchUSDTDepositAddress(network: USDTNetwork) async throws -> SafeTradeDepositAddress {
        guard isEnabled else {
            throw SafeTradeError.notConfigured
        }

        let response: SafeTradeDepositAddress = try await request(
            path: "trade/account/deposit_address/usdt",
            method: "GET",
            queryItems: [URLQueryItem(name: "network", value: network.safeTradeBlockchainKey)],
            body: Optional<EmptyBody>.none
        )
        guard !response.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SafeTradeError.unexpectedResponse
        }
        return response
    }

    func fetchSupportedUSDTDepositWallets() async throws -> [USDTWallet] {
        if let wallets = try? await fetchUSDTDepositWalletsFromSpotBalances(), !wallets.isEmpty {
            return wallets
        }

        let networks = USDTNetwork.p2pSupportedNetworks
        var wallets: [USDTWallet] = []
        for network in networks {
            do {
                let deposit = try await fetchUSDTDepositAddress(network: network)
                wallets.append(
                    USDTWallet(
                        name: "SafeTrade \(network.p2pReceiveLabel)",
                        provider: .safeTrade,
                        network: network,
                        address: deposit.address,
                        isNative: false
                    )
                )
            } catch {
                continue
            }
        }
        return wallets
    }

    private func fetchUSDTDepositWalletsFromSpotBalances() async throws -> [USDTWallet] {
        let response: [SafeTradeSpotBalanceResponse] = try await request(
            path: settings.normalized.balancePath,
            method: "GET",
            queryItems: [],
            body: Optional<EmptyBody>.none
        )
        guard let usdtAccount = response.first(where: { $0.currency.lowercased() == "usdt" }) else {
            return []
        }

        return usdtAccount.depositAddresses.compactMap { deposit in
            guard let network = USDTNetwork.safeTradeNetwork(from: deposit.network),
                  USDTNetwork.p2pSupportedNetworks.contains(network),
                  !deposit.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            return USDTWallet(
                name: "SafeTrade \(network.p2pReceiveLabel)",
                provider: .safeTrade,
                network: network,
                address: deposit.address,
                isNative: false
            )
        }
    }

    func generateWithdrawCode(wallet: USDTWallet, to recipient: String, amount: Decimal, type: SafeTradeWithdrawCodeType = .email) async throws {
        guard isEnabled else {
            throw SafeTradeError.notConfigured
        }

        let requestBody = SafeTradeGenerateWithdrawCodeRequest(
            address: recipient,
            amount: amount,
            blockchainKey: wallet.network.safeTradeBlockchainKey,
            currency: "usdt",
            type: type.rawValue
        )

        let _: SafeTradeGenerateWithdrawCodeResponse = try await request(
            path: settings.normalized.generateWithdrawCodePath,
            method: "POST",
            queryItems: [],
            body: requestBody
        )
    }

    func transferUSDT(wallet: USDTWallet, to recipient: String, amount: Decimal, codes: SafeTradeWithdrawCodes = SafeTradeWithdrawCodes()) async throws -> String {
        guard isEnabled else {
            throw SafeTradeError.notConfigured
        }

        let requestBody = SafeTradeTransferRequest(
            address: recipient,
            amount: amount,
            beneficiaryId: nil,
            blockchainKey: wallet.network.safeTradeBlockchainKey,
            currency: "usdt",
            emailCode: codes.emailCode.nilIfBlank,
            note: "CRB Hub USDT transfer",
            otpCode: codes.otpCode.nilIfBlank,
            phoneCode: codes.phoneCode.nilIfBlank
        )

        let response: SafeTradeTransferResponse = try await request(
            path: settings.normalized.transferPath,
            method: "POST",
            queryItems: [],
            body: requestBody
        )

        guard let txid = response.displayId, !txid.isEmpty else {
            throw SafeTradeError.unexpectedResponse
        }
        return txid
    }

    func createP2PTrade(wallet: USDTWallet, tradeId: String, amount: Decimal, side: String) async throws -> String {
        guard isEnabled else {
            throw SafeTradeError.notConfigured
        }

        throw SafeTradeError.server(422, "SafeTrade P2P order execution needs market/order fields. USDT escrow payments use the withdraw endpoint.")
    }

    private func request<B: Encodable, T: Decodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem],
        body: B?
    ) async throws -> T {
        let config = settings.normalized
        guard var components = URLComponents(string: config.baseURL) else {
            throw SafeTradeError.invalidURL
        }
        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let endpoint = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = "/" + [basePath, endpoint].filter { !$0.isEmpty }.joined(separator: "/")
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw SafeTradeError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = APIConfig.timeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json;charset=utf-8", forHTTPHeaderField: "Content-Type")
        try sign(&request, apiKey: config.apiKey, secret: loadSecret())

        if let body {
            let payload = try JSONEncoder().encode(body)
            request.httpBody = payload
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SafeTradeError.unexpectedResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = try? JSONDecoder().decode(SafeTradeErrorResponse.self, from: data)
            throw SafeTradeError.server(httpResponse.statusCode, errorBody?.displayMessage)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            if T.self == SafeTradeMemberResponse.self, data.isEmpty {
                return SafeTradeMemberResponse(uid: nil, email: nil, level: nil) as! T
            }
            throw SafeTradeError.decoding(error)
        }
    }

    private func sign(_ request: inout URLRequest, apiKey: String, secret: String) throws {
        let nonce = String(Int(Date().timeIntervalSince1970) * 1000)
        let signature = HMAC<SHA256>.authenticationCode(
            for: Data("\(nonce)\(apiKey)".utf8),
            using: SymmetricKey(data: Data(secret.utf8))
        )
        request.setValue(apiKey, forHTTPHeaderField: "X-Auth-Apikey")
        request.setValue(nonce, forHTTPHeaderField: "X-Auth-Nonce")
        request.setValue(Data(signature).hexString, forHTTPHeaderField: "X-Auth-Signature")
    }

    private func loadSecret() throws -> String {
        guard let data = try keychain.loadGenericSecret(account: secretAccount),
              let secret = String(data: data, encoding: .utf8),
              !secret.isEmpty else {
            throw SafeTradeError.notConfigured
        }
        return secret
    }

    struct Settings: Codable, Equatable {
        var isEnabled: Bool
        var baseURL: String
        var apiKey: String
        var statusPath: String
        var balancePath: String
        var transferPath: String
        var generateWithdrawCodePath: String
        var p2pPath: String
        var lastTestedAt: Date?
        var lastTestStatus: String?

        init(
            isEnabled: Bool,
            baseURL: String,
            apiKey: String,
            statusPath: String,
            balancePath: String,
            transferPath: String,
            generateWithdrawCodePath: String = "trade/account/withdraws/generate_code",
            p2pPath: String,
            lastTestedAt: Date?,
            lastTestStatus: String?
        ) {
            self.isEnabled = isEnabled
            self.baseURL = baseURL
            self.apiKey = apiKey
            self.statusPath = statusPath
            self.balancePath = balancePath
            self.transferPath = transferPath
            self.generateWithdrawCodePath = generateWithdrawCodePath
            self.p2pPath = p2pPath
            self.lastTestedAt = lastTestedAt
            self.lastTestStatus = lastTestStatus
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
            baseURL = try container.decode(String.self, forKey: .baseURL)
            apiKey = try container.decode(String.self, forKey: .apiKey)
            statusPath = try container.decode(String.self, forKey: .statusPath)
            balancePath = try container.decode(String.self, forKey: .balancePath)
            transferPath = try container.decode(String.self, forKey: .transferPath)
            generateWithdrawCodePath = (try? container.decode(String.self, forKey: .generateWithdrawCodePath)) ?? "trade/account/withdraws/generate_code"
            p2pPath = try container.decode(String.self, forKey: .p2pPath)
            lastTestedAt = try? container.decodeIfPresent(Date.self, forKey: .lastTestedAt)
            lastTestStatus = try? container.decodeIfPresent(String.self, forKey: .lastTestStatus)
        }

        static let `default` = Settings(
            isEnabled: false,
            baseURL: "https://safe.trade/api/v2",
            apiKey: "",
            statusPath: "trade/account/members/me",
            balancePath: "trade/account/balances/spot",
            transferPath: "trade/account/withdraws",
            generateWithdrawCodePath: "trade/account/withdraws/generate_code",
            p2pPath: "trade/market/orders",
            lastTestedAt: nil,
            lastTestStatus: nil
        )

        var normalized: Settings {
            var copy = self
            copy.baseURL = copy.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            copy.apiKey = copy.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if copy.baseURL == "https://safetrade.com/api" {
                copy.baseURL = "https://safe.trade/api/v2"
            }
            copy.statusPath = normalizePath(copy.statusPath, fallback: "trade/account/members/me")
            copy.balancePath = normalizePath(copy.balancePath, fallback: "trade/account/balances/spot")
            copy.transferPath = normalizePath(copy.transferPath, fallback: "trade/account/withdraws")
            copy.generateWithdrawCodePath = normalizePath(copy.generateWithdrawCodePath, fallback: "trade/account/withdraws/generate_code")
            copy.p2pPath = normalizePath(copy.p2pPath, fallback: "trade/market/orders")
            if copy.statusPath == "status" {
                copy.statusPath = "trade/account/members/me"
            }
            if copy.balancePath == "wallet/balance" {
                copy.balancePath = "trade/account/balances/spot"
            }
            if copy.transferPath == "wallet/withdraw" {
                copy.transferPath = "trade/account/withdraws"
            }
            if copy.generateWithdrawCodePath == "wallet/withdraw/generate_code" {
                copy.generateWithdrawCodePath = "trade/account/withdraws/generate_code"
            }
            if copy.p2pPath == "p2p/trade" {
                copy.p2pPath = "trade/market/orders"
            }
            return copy
        }

        private func normalizePath(_ path: String, fallback: String) -> String {
            let clean = path.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return clean.isEmpty ? fallback : clean
        }
    }

    enum SafeTradeError: LocalizedError {
        case notConfigured
        case invalidURL
        case server(Int, String?)
        case decoding(Error)
        case unexpectedResponse

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "SafeTrade API is not connected."
            case .invalidURL:
                return "Invalid SafeTrade API URL."
            case .server(let code, let message):
                let cleanMessage = (message ?? "").lowercased()
                if code == 422, cleanMessage.contains("apikey") || cleanMessage.contains("api key") {
                    return "SafeTrade API key is invalid or does not have withdrawal permission. Create a new API key with withdraw access, then reconnect SafeTrade."
                }
                return "SafeTrade API error \(code): \(message ?? "Unknown error")"
            case .decoding(let error):
                return "SafeTrade response parsing failed: \(error.localizedDescription)"
            case .unexpectedResponse:
                return "SafeTrade returned an unexpected response format."
            }
        }
    }

    private struct EmptyBody: Encodable {}
}

private extension USDTNetwork {
    var safeTradeBlockchainKey: String {
        switch self {
        case .erc20: return "eth-mainnet"
        case .trc20: return "tron-mainnet"
        case .bep20: return "bsc-mainnet"
        case .polygon: return "polygon-mainnet"
        case .solana: return "sol-mainnet"
        }
    }

    static func safeTradeNetwork(from key: String?) -> USDTNetwork? {
        let clean = (key ?? "").lowercased()
        if clean.contains("polygon") || clean.contains("matic") || clean == "pol" {
            return .polygon
        }
        if clean.contains("sol") {
            return .solana
        }
        if clean.contains("bsc") || clean.contains("bep20") || clean.contains("bnb") {
            return .bep20
        }
        if clean.contains("tron") || clean.contains("trc20") {
            return .trc20
        }
        if clean.contains("eth") || clean.contains("erc20") {
            return .erc20
        }
        return nil
    }
}

private struct SafeTradeMemberResponse: Decodable {
    let uid: String?
    let email: String?
    let level: Int?
}

struct SafeTradeDepositAddress: Decodable {
    let address: String
    let currencies: [String]?
    let network: String?
}

private struct SafeTradeSpotBalanceResponse: Decodable {
    let balance: Decimal
    let currency: String
    let locked: Decimal?
    let type: String?
    let depositAddresses: [SafeTradeDepositAddress]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        balance = Self.decodeDecimal(container, .balance) ?? 0
        currency = (try? container.decodeIfPresent(String.self, forKey: .currency)) ?? ""
        locked = Self.decodeDecimal(container, .locked)
        type = try? container.decodeIfPresent(String.self, forKey: .type)
        depositAddresses = (try? container.decodeIfPresent([SafeTradeDepositAddress].self, forKey: .depositAddresses)) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case balance
        case currency
        case locked
        case type
        case depositAddresses = "deposit_addresses"
    }

    private static func decodeDecimal(_ container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Decimal? {
        if let decimal = try? container.decodeIfPresent(Decimal.self, forKey: key) {
            return decimal
        }
        if let string = try? container.decodeIfPresent(String.self, forKey: key) {
            return Decimal(string: string)
        }
        return nil
    }

}

private struct SafeTradeTransferRequest: Encodable {
    let address: String
    let amount: Decimal
    let beneficiaryId: Int?
    let blockchainKey: String
    let currency: String
    let emailCode: String?
    let note: String?
    let otpCode: String?
    let phoneCode: String?

    enum CodingKeys: String, CodingKey {
        case address
        case amount
        case beneficiaryId = "beneficiary_id"
        case blockchainKey = "blockchain_key"
        case currency
        case emailCode = "email_code"
        case note
        case otpCode = "otp_code"
        case phoneCode = "phone_code"
    }
}

private struct SafeTradeGenerateWithdrawCodeRequest: Encodable {
    let address: String
    let amount: Decimal
    let blockchainKey: String
    let currency: String
    let type: String

    enum CodingKeys: String, CodingKey {
        case address
        case amount
        case blockchainKey = "blockchain_key"
        case currency
        case type
    }
}

private struct SafeTradeGenerateWithdrawCodeResponse: Decodable {
    let status: Int?
}

private struct SafeTradeTransferResponse: Decodable {
    let txid: String?
    let id: Int?
    let tid: String?
    let status: String?

    var displayId: String? {
        txid ?? tid ?? id.map { String($0) } ?? status
    }
}

private struct SafeTradeErrorResponse: Decodable {
    let error: String?
    let message: String?
    let errors: [String]?
    let fieldErrors: [String: [String]]?
    let stringFieldErrors: [String: String]?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        error = try? container.decodeIfPresent(String.self, forKey: .error)
        message = try? container.decodeIfPresent(String.self, forKey: .message)
        errors = try? container.decodeIfPresent([String].self, forKey: .errors)
        fieldErrors = try? container.decodeIfPresent([String: [String]].self, forKey: .errors)
        stringFieldErrors = try? container.decodeIfPresent([String: String].self, forKey: .errors)
    }

    private enum CodingKeys: String, CodingKey {
        case error
        case message
        case errors
    }

    var displayMessage: String? {
        if let message { return message }
        if let error { return error }
        if let errors, !errors.isEmpty { return errors.joined(separator: ", ") }
        if let fieldErrors, !fieldErrors.isEmpty {
            return fieldErrors
                .map { "\($0.key): \($0.value.joined(separator: ", "))" }
                .sorted()
                .joined(separator: "; ")
        }
        if let stringFieldErrors, !stringFieldErrors.isEmpty {
            return stringFieldErrors
                .map { "\($0.key): \($0.value)" }
                .sorted()
                .joined(separator: "; ")
        }
        return nil
    }
}

private extension String {
    var nilIfBlank: String? {
        let clean = trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? nil : clean
    }
}
