import Foundation

/// CRB unit conversion utilities
/// 1 CRB = 100,000,000 synapses (base units)
/// NEVER use Double for balance/fee/amount — always Decimal or UInt64
enum CRBUnits {
    static let synapsesPerCRB: Decimal = 100_000_000
    static let synapsesPerCRBInt: UInt64 = 100_000_000
    
    /// Convert base units (synapses) to display CRB as Decimal
    static func toDisplayCRB(_ baseUnits: UInt64) -> Decimal {
        Decimal(baseUnits) / synapsesPerCRB
    }
    
    /// Convert CRB input (Decimal) to base units
    static func toBaseUnits(_ crb: Decimal) -> UInt64 {
        let result = crb * synapsesPerCRB
        return UInt64(truncating: result as NSDecimalNumber)
    }
    
    /// Format base units as a human-readable CRB string
    /// e.g. 66530000000000 → "665,300.00000000"
    static func formatCRB(_ baseUnits: UInt64, maxFractionDigits: Int = 8, minFractionDigits: Int = 2) -> String {
        let crb = toDisplayCRB(baseUnits)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = maxFractionDigits
        formatter.minimumFractionDigits = minFractionDigits
        formatter.groupingSeparator = ","
        formatter.decimalSeparator = "."
        return formatter.string(from: crb as NSDecimalNumber) ?? "0.00"
    }
    
    /// Format base units as compact string (e.g. "665.30 CRB")
    static func formatCRBCompact(_ baseUnits: UInt64) -> String {
        let crb = toDisplayCRB(baseUnits)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: crb as NSDecimalNumber) ?? "0.00"
    }
    
    /// Format hashrate to human-readable (H/s, KH/s, MH/s, GH/s)
    static func formatHashrate(_ hashrate: Double) -> String {
        if hashrate >= 1_000_000_000 {
            return String(format: "%.2f GH/s", hashrate / 1_000_000_000)
        } else if hashrate >= 1_000_000 {
            return String(format: "%.2f MH/s", hashrate / 1_000_000)
        } else if hashrate >= 1_000 {
            return String(format: "%.2f KH/s", hashrate / 1_000)
        } else {
            return String(format: "%.0f H/s", hashrate)
        }
    }
    
    /// Format a Double USDT value
    static func formatUSDT(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return "$\(formatter.string(from: NSNumber(value: value)) ?? "0.00")"
    }
    
    /// Format large numbers compactly (e.g. supply)
    static func formatLargeNumber(_ value: Double) -> String {
        if value >= 1_000_000 {
            return String(format: "%.2fM", value / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.2fK", value / 1_000)
        } else {
            return String(format: "%.2f", value)
        }
    }
    
    /// Format unix timestamp to relative time
    static func formatRelativeTime(_ timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    /// Format unix timestamp to date string
    static func formatDate(_ timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
