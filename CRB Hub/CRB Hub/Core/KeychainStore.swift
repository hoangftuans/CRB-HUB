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
    
    /// Load private key from Keychain with biometric authentication.
    /// Approach: Check attributes first without retrieving data (non-prompting).
    /// If the key has SecAccessControl, let Keychain handle Face ID (1 prompt).
    /// If legacy, evaluate LAContext manually (1 prompt) and fetch data.
    func loadPrivateKeySecure(for walletId: UUID, reason: String = "Authenticate to access your wallet") async throws -> String {
        // Step 1: Check attributes first (to identify legacy vs new protected keys without prompting Face ID)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: walletId.uuidString,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        
        var attributesResult: AnyObject?
        let attributesStatus = SecItemCopyMatching(query as CFDictionary, &attributesResult)
        
        guard attributesStatus == errSecSuccess else {
            throw KeychainError.loadFailed(attributesStatus)
        }
        
        guard let attributes = attributesResult as? [String: Any] else {
            throw KeychainError.invalidData
        }
        
        // If kSecAttrAccessControl is present, it means the key is saved with biometric SecAccessControl protection.
        let hasAccessControl = attributes[kSecAttrAccessControl as String] != nil
        
        let context = LAContext()
        context.localizedReason = reason
        
        if hasAccessControl {
            // Key is protected by SecAccessControl.
            // We pass the context with custom prompt details, but do NOT manually call evaluatePolicy.
            // SecItemCopyMatching will trigger Face ID exactly once, using this context.
            let protectedQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: walletId.uuidString,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne,
                kSecUseAuthenticationContext as String: context,
            ]
            
            var result: AnyObject?
            let status = SecItemCopyMatching(protectedQuery as CFDictionary, &result)
            
            guard status == errSecSuccess else {
                if status == errSecUserCanceled || status == errSecAuthFailed {
                    throw KeychainError.biometricAuthFailed
                }
                throw KeychainError.loadFailed(status)
            }
            
            guard let data = result as? Data,
                  let privateKeyHex = String(data: data, encoding: .utf8) else {
                throw KeychainError.invalidData
            }
            
            return privateKeyHex
        } else {
            // Key is a legacy key (unprotected in Keychain).
            // We MUST manually enforce biometrics using LAContext to protect it.
            var authError: NSError?
            if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) {
                try await context.evaluatePolicy(
                    .deviceOwnerAuthenticationWithBiometrics,
                    localizedReason: reason
                )
            } else if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) {
                try await context.evaluatePolicy(
                    .deviceOwnerAuthentication,
                    localizedReason: reason
                )
            } else {
                throw KeychainError.biometricsUnavailable
            }
            
            // Authentication succeeded, now fetch the legacy data
            let legacyQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: walletId.uuidString,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne,
            ]
            
            var legacyResult: AnyObject?
            let legacyStatus = SecItemCopyMatching(legacyQuery as CFDictionary, &legacyResult)
            
            guard legacyStatus == errSecSuccess else {
                throw KeychainError.loadFailed(legacyStatus)
            }
            
            guard let data = legacyResult as? Data,
                  let privateKeyHex = String(data: data, encoding: .utf8) else {
                throw KeychainError.invalidData
            }
            
            return privateKeyHex
        }
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
