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
    private let scryptN = 1 << 15
    private let scryptR = 8
    private let scryptP = 1
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
        let config = PasswordConfig(
            salt: salt,
            verifier: verifier,
            kdf: "scrypt-sha256",
            rounds: nil,
            n: scryptN,
            r: scryptR,
            p: scryptP
        )
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
        let key = try deriveKey(password: password, salt: config.salt, config: config)
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

    private func deriveKey(password: String, salt: Data, config: PasswordConfig? = nil) throws -> SymmetricKey {
        if config?.kdf == "pbkdf2-hmac-sha256" {
            return try derivePBKDF2Key(password: password, salt: salt, rounds: config?.rounds ?? pbkdf2Rounds)
        }

        return try ScryptKDF.deriveKey(
            password: password,
            salt: salt,
            n: config?.n ?? scryptN,
            r: config?.r ?? scryptR,
            p: config?.p ?? scryptP,
            outputLength: 32
        )
    }

    private func derivePBKDF2Key(password: String, salt: Data, rounds: Int) throws -> SymmetricKey {
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
            UInt32(rounds),
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
        let n: Int?
        let r: Int?
        let p: Int?
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

private enum ScryptKDF {
    static func deriveKey(password: String, salt: Data, n: Int, r: Int, p: Int, outputLength: Int) throws -> SymmetricKey {
        guard n > 1, n & (n - 1) == 0, r > 0, p > 0, outputLength > 0 else {
            throw WalletSecurityStore.SecurityError.kdfFailed
        }

        let blockSize = 128 * r
        var b = try pbkdf2(password: password, salt: salt, rounds: 1, outputLength: p * blockSize)

        for blockIndex in 0..<p {
            let offset = blockIndex * blockSize
            var block = Array(b[offset..<(offset + blockSize)])
            try smix(block: &block, n: n, r: r)
            b.replaceSubrange(offset..<(offset + blockSize), with: block)
        }

        let derived = try pbkdf2(password: password, salt: Data(b), rounds: 1, outputLength: outputLength)
        return SymmetricKey(data: Data(derived))
    }

    private static func pbkdf2(password: String, salt: Data, rounds: Int, outputLength: Int) throws -> [UInt8] {
        var output = [UInt8](repeating: 0, count: outputLength)
        let passwordBytes = Array(password.utf8)
        let saltBytes = [UInt8](salt)
        let status = CCKeyDerivationPBKDF(
            CCPBKDFAlgorithm(kCCPBKDF2),
            passwordBytes,
            passwordBytes.count,
            saltBytes,
            saltBytes.count,
            CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
            UInt32(rounds),
            &output,
            output.count
        )

        guard status == kCCSuccess else {
            throw WalletSecurityStore.SecurityError.kdfFailed
        }
        return output
    }

    private static func smix(block: inout [UInt8], n: Int, r: Int) throws {
        let wordCount = 32 * r
        guard block.count == 128 * r else {
            throw WalletSecurityStore.SecurityError.kdfFailed
        }

        var x = bytesToWords(block)
        var v = [UInt32](repeating: 0, count: n * wordCount)

        for i in 0..<n {
            v.replaceSubrange((i * wordCount)..<((i + 1) * wordCount), with: x)
            blockMixSalsa8(&x, r: r)
        }

        for _ in 0..<n {
            let j = Int(integerify(x, r: r) & UInt64(n - 1))
            for wordIndex in 0..<wordCount {
                x[wordIndex] ^= v[j * wordCount + wordIndex]
            }
            blockMixSalsa8(&x, r: r)
        }

        block = wordsToBytes(x)
    }

    private static func blockMixSalsa8(_ block: inout [UInt32], r: Int) {
        var x = Array(block[((2 * r - 1) * 16)..<((2 * r) * 16)])
        var y = [UInt32](repeating: 0, count: block.count)

        for i in 0..<(2 * r) {
            for j in 0..<16 {
                x[j] ^= block[i * 16 + j]
            }
            salsa20_8(&x)
            y.replaceSubrange((i * 16)..<((i + 1) * 16), with: x)
        }

        for i in 0..<r {
            block.replaceSubrange((i * 16)..<((i + 1) * 16), with: y[(2 * i * 16)..<((2 * i + 1) * 16)])
        }
        for i in 0..<r {
            block.replaceSubrange(((i + r) * 16)..<((i + r + 1) * 16), with: y[((2 * i + 1) * 16)..<((2 * i + 2) * 16)])
        }
    }

    private static func salsa20_8(_ block: inout [UInt32]) {
        var x = block
        for _ in 0..<4 {
            x[4] ^= rotateLeft(x[0] &+ x[12], by: 7)
            x[8] ^= rotateLeft(x[4] &+ x[0], by: 9)
            x[12] ^= rotateLeft(x[8] &+ x[4], by: 13)
            x[0] ^= rotateLeft(x[12] &+ x[8], by: 18)

            x[9] ^= rotateLeft(x[5] &+ x[1], by: 7)
            x[13] ^= rotateLeft(x[9] &+ x[5], by: 9)
            x[1] ^= rotateLeft(x[13] &+ x[9], by: 13)
            x[5] ^= rotateLeft(x[1] &+ x[13], by: 18)

            x[14] ^= rotateLeft(x[10] &+ x[6], by: 7)
            x[2] ^= rotateLeft(x[14] &+ x[10], by: 9)
            x[6] ^= rotateLeft(x[2] &+ x[14], by: 13)
            x[10] ^= rotateLeft(x[6] &+ x[2], by: 18)

            x[3] ^= rotateLeft(x[15] &+ x[11], by: 7)
            x[7] ^= rotateLeft(x[3] &+ x[15], by: 9)
            x[11] ^= rotateLeft(x[7] &+ x[3], by: 13)
            x[15] ^= rotateLeft(x[11] &+ x[7], by: 18)

            x[1] ^= rotateLeft(x[0] &+ x[3], by: 7)
            x[2] ^= rotateLeft(x[1] &+ x[0], by: 9)
            x[3] ^= rotateLeft(x[2] &+ x[1], by: 13)
            x[0] ^= rotateLeft(x[3] &+ x[2], by: 18)

            x[6] ^= rotateLeft(x[5] &+ x[4], by: 7)
            x[7] ^= rotateLeft(x[6] &+ x[5], by: 9)
            x[4] ^= rotateLeft(x[7] &+ x[6], by: 13)
            x[5] ^= rotateLeft(x[4] &+ x[7], by: 18)

            x[11] ^= rotateLeft(x[10] &+ x[9], by: 7)
            x[8] ^= rotateLeft(x[11] &+ x[10], by: 9)
            x[9] ^= rotateLeft(x[8] &+ x[11], by: 13)
            x[10] ^= rotateLeft(x[9] &+ x[8], by: 18)

            x[12] ^= rotateLeft(x[15] &+ x[14], by: 7)
            x[13] ^= rotateLeft(x[12] &+ x[15], by: 9)
            x[14] ^= rotateLeft(x[13] &+ x[12], by: 13)
            x[15] ^= rotateLeft(x[14] &+ x[13], by: 18)
        }

        for index in 0..<16 {
            block[index] = block[index] &+ x[index]
        }
    }

    private static func integerify(_ block: [UInt32], r: Int) -> UInt64 {
        let offset = (2 * r - 1) * 16
        return UInt64(block[offset]) | (UInt64(block[offset + 1]) << 32)
    }

    private static func bytesToWords(_ bytes: [UInt8]) -> [UInt32] {
        stride(from: 0, to: bytes.count, by: 4).map { index in
            UInt32(bytes[index]) |
            (UInt32(bytes[index + 1]) << 8) |
            (UInt32(bytes[index + 2]) << 16) |
            (UInt32(bytes[index + 3]) << 24)
        }
    }

    private static func wordsToBytes(_ words: [UInt32]) -> [UInt8] {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(words.count * 4)
        for word in words {
            bytes.append(UInt8(word & 0xff))
            bytes.append(UInt8((word >> 8) & 0xff))
            bytes.append(UInt8((word >> 16) & 0xff))
            bytes.append(UInt8((word >> 24) & 0xff))
        }
        return bytes
    }

    private static func rotateLeft(_ value: UInt32, by amount: UInt32) -> UInt32 {
        (value << amount) | (value >> (32 - amount))
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
