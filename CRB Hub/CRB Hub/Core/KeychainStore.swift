import Foundation
import Security
import LocalAuthentication

/// Keychain storage for CRB wallet private keys.
/// Keys are protected with SecAccessControl requiring biometry (.biometryCurrentSet)
/// and kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly.
/// Private keys NEVER leave the device.
@MainActor
final class KeychainStore {
    
    static let shared = KeychainStore()
    
    private let service = "com.crbhub.wallet"
    private let accountListKey = "wallet_accounts"
    /// Legacy service tag used before the biometric migration
    private let legacyService = "com.crbhub.wallet"
    
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
    
    // MARK: - Biometric Access Control
    
    /// Create SecAccessControl flags requiring biometry + passcode.
    /// .biometryCurrentSet means re-enrollment invalidates the key.
    private func createAccessControl() throws -> SecAccessControl {
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            .biometryCurrentSet,
            &error
        ) else {
            throw KeychainError.accessControlCreationFailed
        }
        return access
    }
    
    // MARK: - Private Key Storage (Keychain with Biometric Protection)
    
    /// Save private key to Keychain with biometric protection.
    /// The key is protected by SecAccessControl with .biometryCurrentSet,
    /// meaning Face ID / Touch ID is required to read it.
    func savePrivateKey(_ privateKeyHex: String, for walletId: UUID) throws {
        let keyData = Data(privateKeyHex.utf8)
        
        // Delete any existing key first (both legacy and new)
        deletePrivateKeyRaw(for: walletId)
        
        // Create biometric access control
        let accessControl = try createAccessControl()
        
        // Add new key with biometric protection
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: walletId.uuidString,
            kSecValueData as String: keyData,
            kSecAttrAccessControl as String: accessControl,
        ]
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }
    
    /// Load private key from Keychain with biometric authentication enforced at the Keychain level.
    /// There is NO unprotected path to read a private key — Face ID is enforced by SecAccessControl.
    func loadPrivateKeySecure(for walletId: UUID, reason: String = "Authenticate to access your wallet") async throws -> String {
        // Try migration from legacy (unprotected) storage first
        try await migrateKeyIfNeeded(for: walletId)
        
        // Create an LAContext for the biometric prompt
        let context = LAContext()
        context.localizedReason = reason
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: walletId.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context,
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let privateKeyHex = String(data: data, encoding: .utf8) else {
                throw KeychainError.invalidData
            }
            return privateKeyHex
            
        case errSecUserCanceled, errSecAuthFailed:
            throw KeychainError.biometricAuthFailed
            
        case errSecItemNotFound:
            throw KeychainError.loadFailed(status)
            
        default:
            throw KeychainError.loadFailed(status)
        }
    }
    
    /// Migrate a legacy key (stored without biometric protection) to the new biometric-protected format.
    /// This runs once per key — old entry is read, re-saved with SecAccessControl, and the old entry is deleted.
    ///
    /// Two-phase approach to avoid triggering Face ID during the check:
    /// 1. Query ATTRIBUTES ONLY (no data) — does NOT trigger biometrics
    /// 2. If key has no access control (legacy), THEN read data and migrate
    private func migrateKeyIfNeeded(for walletId: UUID) async throws {
        // Phase 1: Check attributes only — no kSecReturnData to avoid triggering Face ID
        let attrQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: walletId.uuidString,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        
        var attrResult: AnyObject?
        let attrStatus = SecItemCopyMatching(attrQuery as CFDictionary, &attrResult)
        
        guard attrStatus == errSecSuccess,
              let dict = attrResult as? [String: Any] else {
            // No key found at all — nothing to migrate
            return
        }
        
        // If item already has access control, it's already migrated — skip
        if dict[kSecAttrAccessControl as String] != nil {
            return
        }
        
        // Phase 2: Key exists WITHOUT access control (legacy) — read the actual data
        // This won't trigger Face ID because the key is unprotected
        let dataQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: walletId.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        
        var dataResult: AnyObject?
        let dataStatus = SecItemCopyMatching(dataQuery as CFDictionary, &dataResult)
        
        guard dataStatus == errSecSuccess,
              let data = dataResult as? Data,
              let privateKeyHex = String(data: data, encoding: .utf8) else {
            return
        }
        
        // Phase 3: Delete the old unprotected key and re-save with biometric protection
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: walletId.uuidString,
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Re-save with biometric protection
        try savePrivateKey(privateKeyHex, for: walletId)
    }
    
    /// Delete private key from Keychain (raw, no auth required for deletion)
    private func deletePrivateKeyRaw(for walletId: UUID) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: walletId.uuidString,
        ]
        SecItemDelete(query as CFDictionary)
    }
    
    /// Delete private key from Keychain (public API)
    func deletePrivateKey(for walletId: UUID) {
        deletePrivateKeyRaw(for: walletId)
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
        case biometricAuthFailed
        case accessControlCreationFailed
        
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
            case .biometricAuthFailed:
                return "Biometric authentication was cancelled or failed"
            case .accessControlCreationFailed:
                return "Failed to create biometric access control"
            }
        }
    }
}
