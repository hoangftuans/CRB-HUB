import Foundation

/// Response from open.er-api.com
struct ExchangeRatesResponse: Decodable {
    let result: String
    let base_code: String
    let rates: [String: Decimal]
}

private extension ExchangeRatesResponse {
    struct DecimalValue: Decodable {
        let value: Decimal

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let decimal = try? container.decode(Decimal.self) {
                value = decimal
            } else if let string = try? container.decode(String.self),
                      let decimal = Decimal(string: string) {
                value = decimal
            } else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Exchange rate must be a decimal number"
                )
            }
        }

    }

    enum CodingKeys: String, CodingKey {
        case result
        case base_code
        case rates
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        result = try container.decode(String.self, forKey: .result)
        base_code = try container.decode(String.self, forKey: .base_code)
        let decodedRates = try container.decode([String: DecimalValue].self, forKey: .rates)
        rates = decodedRates.mapValues(\.value)
    }
}

enum FiatExchangeService {
    /// Fetch exchange rates from USD (reference for USDT) to local fiat currencies
    static func fetchRates() async throws -> [String: Decimal] {
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
