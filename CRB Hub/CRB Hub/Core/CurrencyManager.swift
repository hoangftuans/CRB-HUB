import Foundation

/// Currency conversion and formatting manager
enum CurrencyManager {
    
    /// Supported fiat currency codes
    static let supportedCurrencies = [
        "USD", "VND", "EUR", "CNY", "JPY", "KRW", "THB", "IDR", "RUB", "GBP"
    ]
    
    /// Predefined hardcoded fallback exchange rates (USDT -> Fiat)
    static let fallbackRates: [String: Decimal] = [
        "USD": Decimal(string: "1.0")!,
        "VND": Decimal(string: "25400.0")!,
        "EUR": Decimal(string: "0.92")!,
        "CNY": Decimal(string: "7.25")!,
        "JPY": Decimal(string: "158.0")!,
        "KRW": Decimal(string: "1380.0")!,
        "THB": Decimal(string: "36.7")!,
        "IDR": Decimal(string: "16400.0")!,
        "RUB": Decimal(string: "88.0")!,
        "GBP": Decimal(string: "0.79")!
    ]
    
    /// Detects system default currency based on system region settings
    static func defaultCurrencyForSystem() -> String {
        let region = Locale.current.region?.identifier ?? "US"
        switch region.upperCased() {
        case "VN": return "VND"
        case "CN": return "CNY"
        case "JP": return "JPY"
        case "KR": return "KRW"
        case "TH": return "THB"
        case "ID": return "IDR"
        case "RU": return "RUB"
        case "GB": return "GBP"
        // Eurozone countries
        case "AD", "AT", "BE", "CY", "EE", "FI", "FR", "DE", "GR", "IE", "IT", "LV", "LT", "LU", "MT", "NL", "PT", "SK", "SI", "ES", "MC", "SM", "VA", "ME", "XK":
            return "EUR"
        default:
            return "USD"
        }
    }
    
    /// Map currency code to formatting locale identifier
    static func localeIdentifier(for currencyCode: String) -> String {
        switch currencyCode.uppercased() {
        case "USD": return "en_US"
        case "VND": return "vi_VN"
        case "EUR": return "de_DE"
        case "CNY": return "zh_CN"
        case "JPY": return "ja_JP"
        case "KRW": return "ko_KR"
        case "THB": return "th_TH"
        case "IDR": return "id_ID"
        case "RUB": return "ru_RU"
        case "GBP": return "en_GB"
        default: return "en_US"
        }
    }
    
    /// Convert CRB base units (synapses) to target fiat currency
    /// Returns nil if price is unavailable
    static func convertCRBToFiat(
        baseUnits: UInt64,
        priceUSDT: Decimal?,
        rates: [String: Decimal],
        targetCurrency: String
    ) -> Decimal? {
        guard let price = priceUSDT, price > 0 else { return nil }
        let crbDecimal = CRBUnits.toDisplayCRB(baseUnits)
        let rate = rates[targetCurrency] ?? fallbackRates[targetCurrency] ?? 1
        return crbDecimal * price * rate
    }
    
    /// Convert CRB Decimal amount to target fiat currency
    /// Returns nil if price is unavailable
    static func convertCRBToFiat(
        crbAmount: Decimal,
        priceUSDT: Decimal?,
        rates: [String: Decimal],
        targetCurrency: String
    ) -> Decimal? {
        guard let price = priceUSDT, price > 0 else { return nil }
        let rate = rates[targetCurrency] ?? fallbackRates[targetCurrency] ?? 1
        return crbAmount * price * rate
    }
    
    /// Format fiat amount to localized currency string (e.g. "$123.45", "123.450 ₫")
    static func formatFiat(_ amount: Decimal, currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = Locale(identifier: localeIdentifier(for: currencyCode))
        
        // Adjust decimals for currencies like VND, JPY, KRW which typically don't have sub-units in common display
        if ["VND", "JPY", "KRW"].contains(currencyCode.uppercased()) {
            formatter.maximumFractionDigits = 0
            formatter.minimumFractionDigits = 0
        } else {
            formatter.maximumFractionDigits = 2
            formatter.minimumFractionDigits = 2
        }
        
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(currencyCode) \(amount)"
    }
}

private extension String {
    func upperCased() -> String {
        self.uppercased()
    }
}
