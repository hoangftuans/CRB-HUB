import Foundation
import CryptoKit

/// WalletCore handles ed25519 key generation, address derivation, and signing.
/// Private keys NEVER leave the device — all signing is local.
enum WalletCore {
    
    // MARK: - Key Generation
    
    /// Generate a new ed25519 keypair
    /// Returns (privateKeyRawHex, publicKeyHex, address)
    static func generateWallet() -> (privateKeyHex: String, publicKeyHex: String, address: String) {
        let privateKey = Curve25519.Signing.PrivateKey()
        let publicKey = privateKey.publicKey
        
        let privateKeyHex = privateKey.rawRepresentation.hexString
        let publicKeyHex = publicKey.rawRepresentation.hexString
        let address = deriveAddress(from: publicKey.rawRepresentation)
        
        return (privateKeyHex, publicKeyHex, address)
    }
    
    // MARK: - Import
    
    /// Import wallet from a raw private key hex string (64 hex chars = 32 bytes)
    static func importWallet(privateKeyHex: String) throws -> (publicKeyHex: String, address: String) {
        guard let keyData = Data(hexString: privateKeyHex), keyData.count == 32 else {
            throw WalletError.invalidPrivateKey
        }
        
        let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: keyData)
        let publicKey = privateKey.publicKey
        
        let publicKeyHex = publicKey.rawRepresentation.hexString
        let address = deriveAddress(from: publicKey.rawRepresentation)
        
        return (publicKeyHex, address)
    }
    
    // MARK: - Address Derivation
    
    /// Derive CRB address from a public key: "crb1" + SHA256(pubkey)[0..<20]
    static func deriveAddress(from publicKeyBytes: Data) -> String {
        let hash = SHA256.hash(data: publicKeyBytes)
        let addressBytes = Data(hash.prefix(20))
        return "crb1" + addressBytes.hexString
    }
    
    // MARK: - Signing
    
    /// Sign arbitrary message bytes with the private key
    /// Used for P2P login challenge
    static func signMessage(_ message: Data, privateKeyHex: String) throws -> String {
        guard let keyData = Data(hexString: privateKeyHex), keyData.count == 32 else {
            throw WalletError.invalidPrivateKey
        }
        
        let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: keyData)
        let signature = try privateKey.signature(for: message)
        return signature.hexString
    }
    
    /// Sign a message string (UTF-8 encoded)
    static func signMessageString(_ message: String, privateKeyHex: String) throws -> String {
        let messageData = Data(message.utf8)
        return try signMessage(messageData, privateKeyHex: privateKeyHex)
    }
    
    // MARK: - Transaction Signing
    
    /// Ký giao dịch CRB
    static func signTransaction(
        from: String,
        to: String,
        amount: UInt64,
        fee: UInt64,
        nonce: UInt64,
        chainId: String?,
        privateKeyHex: String,
        publicKeyHex: String
    ) throws -> SignedCRBTransaction? {
        // Cần reverse format bytes từ reference wallet để implement ký transaction
        throw WalletError.signingNotImplemented
    }
    
    // MARK: - Errors
    
    enum WalletError: LocalizedError {
        case invalidPrivateKey
        case invalidPublicKey
        case signingFailed
        case signingNotImplemented
        
        var errorDescription: String? {
            switch self {
            case .invalidPrivateKey:
                return "Invalid private key format. Expected 64 hex characters (32 bytes)."
            case .invalidPublicKey:
                return "Invalid public key format."
            case .signingFailed:
                return "Failed to sign the message."
            case .signingNotImplemented:
                return "Transaction signing is not yet implemented. The canonical byte format from the Cereblix reference wallet is required."
            }
        }
    }
}

// MARK: - Data Hex Extensions

extension Data {
    /// Initialize Data from a hex string
    init?(hexString: String) {
        let hex = hexString.lowercased()
        guard hex.count % 2 == 0 else { return nil }
        
        var data = Data(capacity: hex.count / 2)
        var index = hex.startIndex
        
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<nextIndex], radix: 16) else {
                return nil
            }
            data.append(byte)
            index = nextIndex
        }
        
        self = data
    }
    
    /// Convert Data to hex string
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
