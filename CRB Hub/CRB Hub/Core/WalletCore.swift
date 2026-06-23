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

    /// Sign arbitrary message bytes with the private key.
    /// ⚠️ Internal use only — external callers should use domain-specific wrappers.
    static func signMessage(_ message: Data, privateKeyHex: String) throws -> String {
        guard let keyData = Data(hexString: privateKeyHex), keyData.count == 32 else {
            throw WalletError.invalidPrivateKey
        }

        let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: keyData)
        let signature = try privateKey.signature(for: message)
        return signature.hexString
    }

    /// Sign a message string (UTF-8 encoded)
    /// ⚠️ Internal use only — external callers should use domain-specific wrappers.
    static func signMessageString(_ message: String, privateKeyHex: String) throws -> String {
        let messageData = Data(message.utf8)
        return try signMessage(messageData, privateKeyHex: privateKeyHex)
    }

    // MARK: - Domain-Separated P2P Login Signing

    /// The fixed prefix for P2P login challenges.
    /// Must match the OTC API challenge msg format: "cereblix-otc-login|<nonce>".
    private static let p2pLoginPrefix = "cereblix-otc-login|"

    /// Validate a P2P nonce from the server.
    /// Must be non-empty, alphanumeric (+ hyphen/underscore), 8-128 characters.
    static func validateP2PNonce(_ nonce: String) -> Bool {
        let pattern = "^[a-zA-Z0-9_-]{8,128}$"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(nonce.startIndex..., in: nonce)
        return regex.firstMatch(in: nonce, range: range) != nil
    }

    /// Build the only message the wallet is allowed to sign for P2P login.
    static func p2pLoginMessage(nonce: String) throws -> String {
        guard validateP2PNonce(nonce) else {
            throw WalletError.invalidNonce
        }
        return p2pLoginPrefix + nonce
    }

    /// Sign a P2P login challenge using the canonical OTC login message.
    static func signP2PLogin(nonce: String, privateKeyHex: String) throws -> String {
        let message = try p2pLoginMessage(nonce: nonce)
        return try signP2PLogin(nonce: nonce, message: message, privateKeyHex: privateKeyHex)
    }

    /// Sign only the canonical P2P login message.
    /// The server-provided challenge.msg must exactly equal the canonical string.
    static func signP2PLogin(nonce: String, message: String, privateKeyHex: String) throws -> String {
        guard message == (try p2pLoginMessage(nonce: nonce)) else {
            throw WalletError.invalidLoginMessage
        }
        return try signMessageString(message, privateKeyHex: privateKeyHex)
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
        signingHeight: UInt64,
        privateKeyHex: String,
        publicKeyHex: String
    ) throws -> SignedCRBTransaction? {
        guard AddressValidator.isValidAddress(from), AddressValidator.isValidAddress(to), amount > 0 else {
            throw WalletError.invalidTransaction
        }

        guard let keyData = Data(hexString: privateKeyHex), keyData.count == 32 else {
            throw WalletError.invalidPrivateKey
        }

        guard let expectedPublicKey = Data(hexString: publicKeyHex), expectedPublicKey.count == 32 else {
            throw WalletError.invalidPublicKey
        }

        let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: keyData)
        let publicKeyData = privateKey.publicKey.rawRepresentation
        guard publicKeyData == expectedPublicKey, deriveAddress(from: publicKeyData) == from else {
            throw WalletError.invalidPublicKey
        }

        let payload: String
        if signingHeight >= 700 {
            guard let chainId, !chainId.isEmpty else {
                throw WalletError.missingChainId
            }
            payload = "cerebra-tx-v1|\(chainId)|\(publicKeyHex)|\(to)|\(amount)|\(fee)|\(nonce)"
        } else {
            payload = "cerebra-tx-v1|\(publicKeyHex)|\(to)|\(amount)|\(fee)|\(nonce)"
        }

        let signature = try privateKey.signature(for: Data(payload.utf8)).hexString
        return SignedCRBTransaction(
            from: from,
            to: to,
            amount: amount,
            fee: fee,
            nonce: nonce,
            pubkey: publicKeyHex,
            sig: signature,
            chain_id: chainId
        )
    }

    // MARK: - Errors

    enum WalletError: LocalizedError {
        case invalidPrivateKey
        case invalidPublicKey
        case invalidTransaction
        case missingChainId
        case signingFailed
        case invalidNonce
        case invalidLoginMessage

        var errorDescription: String? {
            switch self {
            case .invalidPrivateKey:
                return "Invalid private key format. Expected 64 hex characters (32 bytes)."
            case .invalidPublicKey:
                return "Invalid public key format."
            case .invalidTransaction:
                return "Invalid transaction details."
            case .missingChainId:
                return "Missing chain ID for this transaction."
            case .signingFailed:
                return "Failed to sign the message."
            case .invalidNonce:
                return "Invalid P2P login nonce. The server returned a malformed challenge."
            case .invalidLoginMessage:
                return "Invalid P2P login message. The server returned a malformed challenge."
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
