import Foundation

/// CRB address validation and input sanitization
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
    
    // MARK: - Input Sanitization
    
    /// Sanitize user input: strip control characters, normalize unicode, trim whitespace.
    /// Use this for any user-provided string before processing.
    static func sanitizeInput(_ input: String) -> String {
        // 1. Trim whitespace and newlines
        var sanitized = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 2. Remove control characters (except newline for multi-line inputs)
        sanitized = String(sanitized.unicodeScalars.filter {
            !$0.properties.isDefaultIgnorableCodePoint && ($0.value >= 0x20 || $0 == "\n")
        })
        
        // 3. Normalize unicode to NFC form (prevents homoglyph attacks)
        sanitized = sanitized.precomposedStringWithCanonicalMapping
        
        return sanitized
    }
    
    /// Sanitize a single-line input (strips all newlines too)
    static func sanitizeSingleLine(_ input: String) -> String {
        let cleaned = sanitizeInput(input)
        return cleaned.replacingOccurrences(of: "\n", with: "")
    }
}

