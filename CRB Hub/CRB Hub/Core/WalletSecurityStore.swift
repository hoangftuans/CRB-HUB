import Foundation
import CryptoKit
import Security
import CommonCrypto

@MainActor
final class WalletSecurityStore {
    static let shared = WalletSecurityStore()

    private let configAccount = "wallet_password_config"
    private let lockoutAccount = "wallet_password_lockout"
    private let keychain = KeychainStore.shared
    private let minimumPasswordLength = 12
    private let pbkdf2Rounds = 600_000
    private let maxFailedAttempts = 5
    private let lockoutDuration: TimeInterval = 15 * 60

    private init() {}

    var isPasswordEnabled: Bool {
        (try? keychain.loadGenericSecret(account: configAccount)) != nil
    }

    func setPassword(_ password: String, wallets: [WalletAccount], usdtWallets: [USDTWallet] = []) async throws {
        let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        try validatePasswordPolicy(cleanPassword)

        let salt = randomData(count: 32)
        let passwordKey = try deriveKey(password: cleanPassword, salt: salt)
        let verifier = passwordVerifier(passwordKey)
        let config = PasswordConfig(salt: salt, verifier: verifier, kdf: "pbkdf2-hmac-sha256", rounds: pbkdf2Rounds)
        try keychain.saveGenericSecret(try JSONEncoder().encode(config), account: configAccount)
        clearPasswordLockout()
        purgeLegacyFallbackKeys(wallets: wallets, usdtWallets: usdtWallets)
    }

    func disablePassword(wallets: [WalletAccount], usdtWallets: [USDTWallet] = []) {
        keychain.deleteGenericSecret(account: configAccount)
        keychain.deleteGenericSecret(account: lockoutAccount)
        for wallet in wallets {
            keychain.deleteGenericSecret(account: fallbackAccount(wallet.id))
        }
        for wallet in usdtWallets where wallet.isNative {
            keychain.deleteGenericSecret(account: fallbackAccount(wallet.id))
        }
    }

    func syncFallbackKeys(wallets: [WalletAccount], usdtWallets: [USDTWallet] = [], password: String) async throws {
        _ = try verifiedPasswordKey(password)
        purgeLegacyFallbackKeys(wallets: wallets, usdtWallets: usdtWallets)
    }

    func loadPrivateKeyForTransaction(
        walletId: UUID,
        amountDescription: String,
        fallbackPassword: String? = nil
    ) async throws -> String {
        guard !DeviceIntegrity.isLikelyCompromised else {
            throw SecurityError.compromisedDevice
        }

        do {
            return try await keychain.loadPrivateKeyForTransaction(
                for: walletId,
                amountDescription: amountDescription
            )
        } catch KeychainStore.KeychainError.biometricAuthFailed {
            guard let fallbackPassword else {
                throw SecurityError.passwordRequired
            }
            _ = try verifiedPasswordKey(fallbackPassword)
            return try await keychain.loadPrivateKeyForTransaction(
                for: walletId,
                amountDescription: amountDescription
            )
        }
    }

    func verifyPassword(_ password: String) throws {
        _ = try verifiedPasswordKey(password)
    }

    private func verifiedPasswordKey(_ password: String) throws -> SymmetricKey {
        try enforcePasswordLockout()
        guard let configData = try keychain.loadGenericSecret(account: configAccount) else {
            throw SecurityError.passwordNotSet
        }
        let config = try JSONDecoder().decode(PasswordConfig.self, from: configData)
        let key = try deriveKey(password: password, salt: config.salt)
        guard passwordVerifier(key) == config.verifier else {
            recordPasswordFailure()
            throw SecurityError.invalidPassword
        }
        clearPasswordLockout()
        return key
    }

    private func fallbackAccount(_ walletId: UUID) -> String {
        "wallet_password_fallback_\(walletId.uuidString)"
    }

    private func deriveKey(password: String, salt: Data) throws -> SymmetricKey {
        var derived = [UInt8](repeating: 0, count: 32)
        let passwordBytes = Array(password.utf8)
        let saltBytes = [UInt8](salt)
        let status = CCKeyDerivationPBKDF(
            CCPBKDFAlgorithm(kCCPBKDF2),
            passwordBytes,
            passwordBytes.count,
            saltBytes,
            saltBytes.count,
            CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
            UInt32(pbkdf2Rounds),
            &derived,
            derived.count
        )

        guard status == kCCSuccess else {
            throw SecurityError.kdfFailed
        }
        return SymmetricKey(data: Data(derived))
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

    private func validatePasswordPolicy(_ password: String) throws {
        guard password.count >= minimumPasswordLength else {
            throw SecurityError.passwordTooShort
        }

        let hasLowercase = password.rangeOfCharacter(from: .lowercaseLetters) != nil
        let hasUppercase = password.rangeOfCharacter(from: .uppercaseLetters) != nil
        let hasDigit = password.rangeOfCharacter(from: .decimalDigits) != nil
        let hasSymbol = password.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) != nil
        guard [hasLowercase, hasUppercase, hasDigit, hasSymbol].filter({ $0 }).count >= 3 else {
            throw SecurityError.passwordTooWeak
        }
    }

    private func purgeLegacyFallbackKeys(wallets: [WalletAccount], usdtWallets: [USDTWallet]) {
        for wallet in wallets {
            keychain.deleteGenericSecret(account: fallbackAccount(wallet.id))
        }
        for wallet in usdtWallets where wallet.isNative {
            keychain.deleteGenericSecret(account: fallbackAccount(wallet.id))
        }
    }

    private func enforcePasswordLockout() throws {
        guard let data = try keychain.loadGenericSecret(account: lockoutAccount),
              let state = try? JSONDecoder().decode(PasswordLockoutState.self, from: data),
              let lockedUntil = state.lockedUntil else {
            return
        }
        if Date() < lockedUntil {
            throw SecurityError.passwordLocked(lockedUntil)
        }
        clearPasswordLockout()
    }

    private func recordPasswordFailure() {
        let existingData = try? keychain.loadGenericSecret(account: lockoutAccount)
        let existing = existingData.flatMap { try? JSONDecoder().decode(PasswordLockoutState.self, from: $0) }
        let attempts = (existing?.failedAttempts ?? 0) + 1
        let lockedUntil = attempts >= maxFailedAttempts ? Date().addingTimeInterval(lockoutDuration) : nil
        let state = PasswordLockoutState(failedAttempts: attempts, lockedUntil: lockedUntil)
        if let data = try? JSONEncoder().encode(state) {
            try? keychain.saveGenericSecret(data, account: lockoutAccount)
        }
    }

    private func clearPasswordLockout() {
        keychain.deleteGenericSecret(account: lockoutAccount)
    }

    private struct PasswordConfig: Codable {
        let salt: Data
        let verifier: Data
        let kdf: String?
        let rounds: Int?
    }

    private struct PasswordLockoutState: Codable {
        let failedAttempts: Int
        let lockedUntil: Date?
    }

    enum SecurityError: LocalizedError {
        case passwordTooShort
        case passwordTooWeak
        case passwordNotSet
        case passwordRequired
        case invalidPassword
        case passwordLocked(Date)
        case compromisedDevice
        case kdfFailed

        var errorDescription: String? {
            switch self {
            case .passwordTooShort:
                return "Password must be at least 12 characters."
            case .passwordTooWeak:
                return "Use a stronger password with at least three of: uppercase, lowercase, numbers, symbols."
            case .passwordNotSet:
                return "Wallet password has not been set."
            case .passwordRequired:
                return "Face ID failed. Please enter your wallet password."
            case .invalidPassword:
                return "Invalid wallet password."
            case .passwordLocked(let date):
                let minutes = max(1, Int(ceil(date.timeIntervalSinceNow / 60)))
                return "Too many incorrect password attempts. Try again in \(minutes) minutes."
            case .compromisedDevice:
                return "This device appears to be modified or jailbroken. Wallet signing is blocked for your protection."
            case .kdfFailed:
                return "Failed to derive a secure wallet password key."
            }
        }
    }
}

enum DeviceIntegrity {
    static var isLikelyCompromised: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        let suspiciousPaths = [
            "/Applications/Cydia.app",
            "/Applications/Sileo.app",
            "/Applications/Zebra.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt",
        ]

        if suspiciousPaths.contains(where: { FileManager.default.fileExists(atPath: $0) }) {
            return true
        }

        if getenv("DYLD_INSERT_LIBRARIES") != nil {
            return true
        }

        let testPath = "/private/crbhub_integrity_test"
        do {
            try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
            try? FileManager.default.removeItem(atPath: testPath)
            return true
        } catch {
            return false
        }
        #endif
    }
}
