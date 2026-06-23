import Foundation

/// Response from open.er-api.com
struct ExchangeRatesResponse: Codable {
    let result: String
    let base_code: String
    let rates: [String: Double]
}

enum FiatExchangeService {
    /// Fetch exchange rates from USD (reference for USDT) to local fiat currencies
    static func fetchRates() async throws -> [String: Double] {
        let url = "https://open.er-api.com/v6/latest/USD"
        let response = try await APIClient.get(url, type: ExchangeRatesResponse.self)
        
        if response.result.lowercased() == "success" {
            return response.rates
        } else {
            throw NSError(
                domain: "FiatExchangeService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Exchange rate API returned non-success status"]
            )
        }
    }
}
