import Foundation
import CryptoKit
import Security

@MainActor
final class WalletSecurityStore {
    static let shared = WalletSecurityStore()

    private let configAccount = "wallet_password_config"
    private let keychain = KeychainStore.shared

    private init() {}

    var isPasswordEnabled: Bool {
        (try? keychain.loadGenericSecret(account: configAccount)) != nil
    }

    func setPassword(_ password: String, wallets: [WalletAccount], usdtWallets: [USDTWallet] = []) async throws {
        let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanPassword.count >= 8 else {
            throw SecurityError.passwordTooShort
        }

        let salt = randomData(count: 16)
        let passwordKey = deriveKey(password: cleanPassword, salt: salt)
        let verifier = passwordVerifier(passwordKey)
        let config = PasswordConfig(salt: salt, verifier: verifier)
        try keychain.saveGenericSecret(try JSONEncoder().encode(config), account: configAccount)

        var syncedWalletIds: [UUID] = []
        do {
            for wallet in wallets {
                let privateKey = try await keychain.loadPrivateKeySecure(
                    for: wallet.id,
                    reason: "Authenticate to sync this wallet with your password"
                )
                try savePasswordFallbackKey(privateKey, walletId: wallet.id, passwordKey: passwordKey)
                syncedWalletIds.append(wallet.id)
            }

            for wallet in usdtWallets where wallet.isNative {
                let privateKey = try await keychain.loadPrivateKeySecure(
                    for: wallet.id,
                    reason: "Authenticate to sync this USDT wallet with your password"
                )
                try savePasswordFallbackKey(privateKey, walletId: wallet.id, passwordKey: passwordKey)
                syncedWalletIds.append(wallet.id)
            }
        } catch {
            keychain.deleteGenericSecret(account: configAccount)
            for walletId in syncedWalletIds {
                keychain.deleteGenericSecret(account: fallbackAccount(walletId))
            }
            throw error
        }
    }

    func disablePassword(wallets: [WalletAccount], usdtWallets: [USDTWallet] = []) {
        keychain.deleteGenericSecret(account: configAccount)
        for wallet in wallets {
            keychain.deleteGenericSecret(account: fallbackAccount(wallet.id))
        }
        for wallet in usdtWallets where wallet.isNative {
            keychain.deleteGenericSecret(account: fallbackAccount(wallet.id))
        }
    }

    func syncFallbackKeys(wallets: [WalletAccount], usdtWallets: [USDTWallet] = [], password: String) async throws {
        let passwordKey = try verifiedPasswordKey(password)
        for wallet in wallets {
            let privateKey = try await keychain.loadPrivateKeySecure(
                for: wallet.id,
                reason: "Authenticate to sync this wallet with your password"
            )
            try savePasswordFallbackKey(privateKey, walletId: wallet.id, passwordKey: passwordKey)
        }

        for wallet in usdtWallets where wallet.isNative {
            let privateKey = try await keychain.loadPrivateKeySecure(
                for: wallet.id,
                reason: "Authenticate to sync this USDT wallet with your password"
            )
            try savePasswordFallbackKey(privateKey, walletId: wallet.id, passwordKey: passwordKey)
        }
    }

    func loadPrivateKeyForTransaction(
        walletId: UUID,
        amountDescription: String,
        fallbackPassword: String? = nil
    ) async throws -> String {
        do {
            return try await keychain.loadPrivateKeyForTransaction(
                for: walletId,
                amountDescription: amountDescription
            )
        } catch KeychainStore.KeychainError.biometricAuthFailed {
            guard let fallbackPassword else {
                throw SecurityError.passwordRequired
            }
            return try loadPasswordFallbackKey(walletId: walletId, password: fallbackPassword)
        }
    }

    func verifyPassword(_ password: String) throws {
        _ = try verifiedPasswordKey(password)
    }

    private func verifiedPasswordKey(_ password: String) throws -> SymmetricKey {
        guard let configData = try keychain.loadGenericSecret(account: configAccount) else {
            throw SecurityError.passwordNotSet
        }
        let config = try JSONDecoder().decode(PasswordConfig.self, from: configData)
        let key = deriveKey(password: password, salt: config.salt)
        guard passwordVerifier(key) == config.verifier else {
            throw SecurityError.invalidPassword
        }
        return key
    }

    private func savePasswordFallbackKey(_ privateKey: String, walletId: UUID, passwordKey: SymmetricKey) throws {
        let sealedBox = try AES.GCM.seal(Data(privateKey.utf8), using: passwordKey)
        guard let combined = sealedBox.combined else {
            throw SecurityError.encryptionFailed
        }
        try keychain.saveGenericSecret(combined, account: fallbackAccount(walletId))
    }

    private func loadPasswordFallbackKey(walletId: UUID, password: String) throws -> String {
        let passwordKey = try verifiedPasswordKey(password)
        guard let encrypted = try keychain.loadGenericSecret(account: fallbackAccount(walletId)) else {
            throw SecurityError.passwordFallbackMissing
        }
        let sealedBox = try AES.GCM.SealedBox(combined: encrypted)
        let data = try AES.GCM.open(sealedBox, using: passwordKey)
        guard let privateKey = String(data: data, encoding: .utf8) else {
            throw SecurityError.decryptFailed
        }
        return privateKey
    }

    private func fallbackAccount(_ walletId: UUID) -> String {
        "wallet_password_fallback_\(walletId.uuidString)"
    }

    private func deriveKey(password: String, salt: Data) -> SymmetricKey {
        var data = Data(password.utf8) + salt
        for _ in 0..<120_000 {
            data = Data(SHA256.hash(data: data))
        }
        return SymmetricKey(data: data)
    }

    private func passwordVerifier(_ key: SymmetricKey) -> Data {
        key.withUnsafeBytes { bytes in
            Data(SHA256.hash(data: Data(bytes) + Data("crbhub-password-verifier-v1".utf8)))
        }
    }

    private func randomData(count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
    }

    private struct PasswordConfig: Codable {
        let salt: Data
        let verifier: Data
    }

    enum SecurityError: LocalizedError {
        case passwordTooShort
        case passwordNotSet
        case passwordRequired
        case invalidPassword
        case passwordFallbackMissing
        case encryptionFailed
        case decryptFailed

        var errorDescription: String? {
            switch self {
            case .passwordTooShort:
                return "Password must be at least 8 characters."
            case .passwordNotSet:
                return "Wallet password has not been set."
            case .passwordRequired:
                return "Face ID failed. Please enter your wallet password."
            case .invalidPassword:
                return "Invalid wallet password."
            case .passwordFallbackMissing:
                return "Password fallback is not synced for this wallet."
            case .encryptionFailed:
                return "Failed to encrypt wallet fallback key."
            case .decryptFailed:
                return "Failed to unlock wallet with password."
            }
        }
    }
}
