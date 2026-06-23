import Foundation
import Security
import LocalAuthentication

/// Keychain storage for CRB wallet private keys.
/// Keys are stored with kSecAttrAccessibleWhenUnlockedThisDeviceOnly
/// and never leave the device.
@MainActor
final class KeychainStore {
    
    static let shared = KeychainStore()
    
    private let service = "com.crbhub.wallet"
    private let accountListKey = "wallet_accounts"
    
    private init() {}
    
    // MARK: - Wallet List (Metadata Only)
    
    /// Save wallet metadata (no private key) to UserDefaults
    func saveWalletMetadata(_ wallet: WalletAccount) {
        var wallets = loadWalletList()
        wallets.removeAll { $0.id == wallet.id }
        wallets.append(wallet)
        
        if let data = try? JSONEncoder().encode(wallets) {
            UserDefaults.standard.set(data, forKey: accountListKey)
        }
    }
    
    /// Load all wallet metadata
    func loadWalletList() -> [WalletAccount] {
        guard let data = UserDefaults.standard.data(forKey: accountListKey),
              let wallets = try? JSONDecoder().decode([WalletAccount].self, from: data) else {
            return []
        }
        return wallets
    }
    
    /// Delete wallet metadata
    func deleteWalletMetadata(id: UUID) {
        var wallets = loadWalletList()
        wallets.removeAll { $0.id == id }
        
        if let data = try? JSONEncoder().encode(wallets) {
            UserDefaults.standard.set(data, forKey: accountListKey)
        }
    }
    
    // MARK: - Private Key Storage (Keychain)
    
    /// Save private key to Keychain
    func savePrivateKey(_ privateKeyHex: String, for walletId: UUID) throws {
        let keyData = Data(privateKeyHex.utf8)
        
        // Delete any existing key first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: walletId.uuidString,
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Add new key
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: walletId.uuidString,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }
    
    /// Load private key from Keychain (requires biometric auth in production)
    func loadPrivateKey(for walletId: UUID) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: walletId.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError.loadFailed(status)
        }
        
        guard let privateKeyHex = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        
        return privateKeyHex
    }
    
    /// Load private key with Face ID / biometric authentication
    func loadPrivateKeyWithBiometrics(for walletId: UUID) async throws -> String {
        let context = LAContext()
        context.localizedReason = "Authenticate to access your wallet"
        
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // Fallback to passcode if biometrics unavailable
            if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
                try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Authenticate to access your wallet")
                return try loadPrivateKey(for: walletId)
            }
            throw KeychainError.biometricsUnavailable
        }
        
        try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Authenticate to access your wallet")
        return try loadPrivateKey(for: walletId)
    }
    
    /// Delete private key from Keychain
    func deletePrivateKey(for walletId: UUID) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: walletId.uuidString,
        ]
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - Full Wallet Operations
    
    /// Create and save a new wallet
    func createWallet(name: String) throws -> WalletAccount {
        let (privateKeyHex, publicKeyHex, address) = WalletCore.generateWallet()
        
        let wallet = WalletAccount(
            address: address,
            publicKeyHex: publicKeyHex,
            name: name
        )
        
        try savePrivateKey(privateKeyHex, for: wallet.id)
        saveWalletMetadata(wallet)
        
        return wallet
    }
    
    /// Import wallet from private key hex
    func importWallet(name: String, privateKeyHex: String) throws -> WalletAccount {
        let cleanKey = privateKeyHex.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let (publicKeyHex, address) = try WalletCore.importWallet(privateKeyHex: cleanKey)
        
        let wallet = WalletAccount(
            address: address,
            publicKeyHex: publicKeyHex,
            name: name
        )
        
        try savePrivateKey(cleanKey, for: wallet.id)
        saveWalletMetadata(wallet)
        
        return wallet
    }
    
    /// Delete a wallet completely (metadata + private key)
    func deleteWallet(id: UUID) {
        deletePrivateKey(for: id)
        deleteWalletMetadata(id: id)
    }
    
    /// Check if biometrics are available
    func isBiometricsAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    // MARK: - Errors
    
    enum KeychainError: LocalizedError {
        case saveFailed(OSStatus)
        case loadFailed(OSStatus)
        case invalidData
        case biometricsUnavailable
        
        var errorDescription: String? {
            switch self {
            case .saveFailed(let status):
                return "Failed to save to Keychain (status: \(status))"
            case .loadFailed(let status):
                return "Failed to load from Keychain (status: \(status))"
            case .invalidData:
                return "Keychain data is corrupted"
            case .biometricsUnavailable:
                return "Face ID / Touch ID is not available"
            }
        }
    }
}
