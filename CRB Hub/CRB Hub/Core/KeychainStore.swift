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
    private let securityService = "com.crbhub.wallet.security"
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

        // Mark as migrated since it's saved with biometric access control
        let migrationKey = "migrated_to_biometrics_\(walletId.uuidString)"
        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    /// Confirm biometric access before creating a new protected Keychain item.
    /// Saving with SecAccessControl does not always prompt by itself, so this
    /// catches unavailable or denied Face ID / Touch ID during wallet setup.
    func authenticateBiometrics(reason: String) async throws {
        let context = LAContext()
        context.localizedReason = reason

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw KeychainError.biometricsUnavailable
        }

        let authenticated: Bool = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
                if error != nil {
                    continuation.resume(throwing: KeychainError.biometricAuthFailed)
                } else {
                    continuation.resume(returning: success)
                }
            }
        }

        guard authenticated else {
            throw KeychainError.biometricAuthFailed
        }
    }

    /// Authenticate with biometrics before saving the private key into Keychain.
    func savePrivateKeyWithBiometricSetup(_ privateKeyHex: String, for walletId: UUID, reason: String) async throws {
        try await authenticateBiometrics(reason: reason)
        try savePrivateKey(privateKeyHex, for: walletId)
    }

    /// Migrate a legacy key (stored without biometric protection) to the new biometric-protected format.
    /// This runs silently (no Face ID prompt) because the legacy key is not protected by SecAccessControl.
    private func migrateKeyIfNeeded(for walletId: UUID) {
        let migrationKey = "migrated_to_biometrics_\(walletId.uuidString)"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else {
            return
        }

        // Try reading legacy key data without allowing the Keychain to show an
        // authentication sheet. If this is already a protected item, the query
        // should fail silently and the normal secure load below will prompt once.
        let context = LAContext()
        context.interactionNotAllowed = true

        let legacyQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: walletId.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(legacyQuery as CFDictionary, &result)

        if status == errSecSuccess,
           let data = result as? Data,
           let privateKeyHex = String(data: data, encoding: .utf8) {
            // Found legacy key! Migrate it silently to new format
            do {
                try savePrivateKey(privateKeyHex, for: walletId)
                UserDefaults.standard.set(true, forKey: migrationKey)
            } catch {
                // If migration fails, we'll retry on next access
            }
        } else if status == errSecItemNotFound {
            // No legacy key exists — might be new or deleted.
            UserDefaults.standard.set(true, forKey: migrationKey)
        } else {
            // Any other error means it's likely already protected or inaccessible.
            // Mark as migrated so we don't query it again.
            UserDefaults.standard.set(true, forKey: migrationKey)
        }
    }

    /// Load private key from Keychain with biometric authentication.
    /// Since legacy keys are migrated silently, all keys are guaranteed to be protected by SecAccessControl.
    /// This triggers the native Face ID dialog exactly once via SecItemCopyMatching.
    func loadPrivateKeySecure(for walletId: UUID, reason: String = "Authenticate to access your wallet") async throws -> String {
        // Step 1: Migrate legacy key silently if needed (no biometrics triggered)
        migrateKeyIfNeeded(for: walletId)

        // Step 2: Query the keychain item with SecAccessControl protection.
        // We pass the context to configure the reason, and the Keychain itself prompts Face ID once.
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
    }

    /// Load a private key for a transaction-signing path.
    /// All coin transfers must use this method so Face ID / Touch ID is enforced
    /// by the Keychain before any signing or broadcast attempt.
    func loadPrivateKeyForTransaction(for walletId: UUID, amountDescription: String) async throws -> String {
        try await loadPrivateKeySecure(
            for: walletId,
            reason: "Authenticate to send \(amountDescription)"
        )
    }

    func saveGenericSecret(_ data: Data, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: securityService,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: securityService,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            kSecValueData as String: data,
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    func saveGenericSecretWithBiometrics(_ data: Data, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: securityService,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)

        let accessControl = try createAccessControl()
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: securityService,
            kSecAttrAccount as String: account,
            kSecAttrAccessControl as String: accessControl,
            kSecValueData as String: data,
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    func loadGenericSecret(account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: securityService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainError.loadFailed(status)
        }
        guard let data = result as? Data else {
            throw KeychainError.invalidData
        }
        return data
    }

    func loadGenericSecretWithBiometrics(account: String, reason: String) async throws -> Data? {
        let context = LAContext()
        context.localizedReason = reason

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: securityService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            if status == errSecUserCanceled || status == errSecAuthFailed {
                throw KeychainError.biometricAuthFailed
            }
            throw KeychainError.loadFailed(status)
        }
        guard let data = result as? Data else {
            throw KeychainError.invalidData
        }
        return data
    }

    func deleteGenericSecret(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: securityService,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
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

    /// Create and save a new wallet after biometric setup confirmation.
    func createWalletWithBiometricSetup(name: String) async throws -> WalletAccount {
        let (privateKeyHex, publicKeyHex, address) = WalletCore.generateWallet()

        let wallet = WalletAccount(
            address: address,
            publicKeyHex: publicKeyHex,
            name: name
        )

        try await savePrivateKeyWithBiometricSetup(
            privateKeyHex,
            for: wallet.id,
            reason: "Authenticate to protect this wallet with Face ID"
        )
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

    /// Import a wallet after biometric setup confirmation.
    func importWalletWithBiometricSetup(name: String, privateKeyHex: String) async throws -> WalletAccount {
        let cleanKey = privateKeyHex.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let (publicKeyHex, address) = try WalletCore.importWallet(privateKeyHex: cleanKey)

        let wallet = WalletAccount(
            address: address,
            publicKeyHex: publicKeyHex,
            name: name
        )

        try await savePrivateKeyWithBiometricSetup(
            cleanKey,
            for: wallet.id,
            reason: "Authenticate to protect this imported wallet with Face ID"
        )
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
