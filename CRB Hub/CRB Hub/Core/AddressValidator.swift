import Foundation

/// CRB address validation
/// Format: crb1 + 40 hex characters (case-insensitive)
enum AddressValidator {
    private static let addressPattern = "^crb1[0-9a-fA-F]{40}$"
    
    /// Validate a CRB address
    static func isValidAddress(_ address: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: addressPattern) else {
            return false
        }
        let range = NSRange(address.startIndex..., in: address)
        return regex.firstMatch(in: address, range: range) != nil
    }
    
    /// Format address for display (truncated)
    /// e.g. "crb1a2b3c4d5...f6g7h8i9"
    static func truncatedAddress(_ address: String, leading: Int = 10, trailing: Int = 8) -> String {
        guard address.count > leading + trailing + 3 else { return address }
        let start = address.prefix(leading)
        let end = address.suffix(trailing)
        return "\(start)...\(end)"
    }
}
