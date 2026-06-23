import SwiftUI

/// Reusable view that displays the fiat equivalent of a CRB amount
struct FiatValueView: View {
    @Environment(AppState.self) private var appState
    
    let baseUnits: UInt64?
    let crbAmount: Decimal?
    let font: Font
    let color: Color
    
    init(baseUnits: UInt64, font: Font = .system(size: 14, weight: .medium), color: Color = CRBTheme.Colors.muted) {
        self.baseUnits = baseUnits
        self.crbAmount = nil
        self.font = font
        self.color = color
    }
    
    init(crbAmount: Decimal, font: Font = .system(size: 14, weight: .medium), color: Color = CRBTheme.Colors.muted) {
        self.baseUnits = nil
        self.crbAmount = crbAmount
        self.font = font
        self.color = color
    }
    
    var body: some View {
        let price = appState.cachedCRBPriceUSDT
        let currency = appState.selectedFiatCurrency
        let rates = appState.cachedFXRates
        
        if price > 0 {
            let converted: Decimal? = {
                if let base = baseUnits {
                    return CurrencyManager.convertCRBToFiat(
                        baseUnits: base,
                        priceUSDT: price,
                        rates: rates,
                        targetCurrency: currency
                    )
                } else if let amount = crbAmount {
                    return CurrencyManager.convertCRBToFiat(
                        crbAmount: amount,
                        priceUSDT: price,
                        rates: rates,
                        targetCurrency: currency
                    )
                }
                return nil
            }()
            
            if let fiat = converted {
                Text("≈ \(CurrencyManager.formatFiat(fiat, currencyCode: currency))")
                    .font(font)
                    .foregroundColor(color)
            }
        }
    }
}
