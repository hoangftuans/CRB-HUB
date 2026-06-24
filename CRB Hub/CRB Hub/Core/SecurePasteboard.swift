import UIKit

/// Secure clipboard utility for sensitive data.
/// Private keys and secrets are copied with an expiration date —
/// the clipboard automatically clears after the specified interval.
enum SecurePasteboard {
    
    /// Default expiry for sensitive data: 60 seconds
    static let defaultExpiry: TimeInterval = 60
    
    /// Copy a sensitive string to the clipboard with automatic expiry.
    /// After `expirySeconds`, the pasteboard item is automatically removed by iOS.
    ///
    /// - Parameters:
    ///   - string: The sensitive string to copy (e.g., a private key)
    ///   - expirySeconds: Time in seconds before the clipboard auto-clears (default: 60)
    @MainActor
    static func copyWithExpiry(_ string: String, expirySeconds: TimeInterval = 60) {
        let expirationDate = Date().addingTimeInterval(expirySeconds)
        
        UIPasteboard.general.setItems(
            [[UIPasteboard.typeAutomatic: string]],
            options: [
                .expirationDate: expirationDate,
                .localOnly: true  // Don't sync to other devices via Handoff
            ]
        )
    }
    
    /// Copy a non-sensitive string to the clipboard (no expiry).
    /// Use this for public data like wallet addresses.
    @MainActor
    static func copy(_ string: String) {
        UIPasteboard.general.string = string
    }
}
