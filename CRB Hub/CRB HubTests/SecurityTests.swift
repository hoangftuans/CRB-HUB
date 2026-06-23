import XCTest
@testable import CRB_Hub

/// Security hardening unit tests
/// Tests for node URL validation, P2P nonce validation, address sanitization, and CRBUnits edge cases.
final class SecurityTests: XCTestCase {

    // MARK: - Node URL Validator Tests

    func testValidHTTPSURL() {
        let result = NodeURLValidator.validate("https://cereblix.com")
        if case .valid = result {
            // Pass
        } else {
            XCTFail("Expected valid for official HTTPS URL")
        }
    }

    func testValidHTTPSSubdomain() {
        let result = NodeURLValidator.validate("https://api.cereblix.com")
        if case .valid = result {
            // Pass
        } else {
            XCTFail("Expected valid for official subdomain")
        }
    }

    func testRejectHTTP() {
        let result = NodeURLValidator.validate("http://evil.com")
        if case .invalid(let msg) = result {
            XCTAssertTrue(msg.contains("HTTPS"), "Should mention HTTPS in error")
        } else {
            XCTFail("Expected invalid for HTTP URL")
        }
    }

    func testRejectHTTPLocalhost() {
        let result = NodeURLValidator.validate("http://localhost:18751")
        if case .invalid(let msg) = result {
            XCTAssertTrue(msg.contains("HTTPS"), "Should require HTTPS for localhost too")
        } else {
            XCTFail("Expected invalid for localhost HTTP")
        }
    }

    func testRejectHTTPLoopback() {
        let result = NodeURLValidator.validate("http://127.0.0.1:18751")
        if case .invalid(let msg) = result {
            XCTAssertTrue(msg.contains("HTTPS"), "Should require HTTPS for loopback too")
        } else {
            XCTFail("Expected invalid for 127.0.0.1 HTTP")
        }
    }

    func testWarnNonOfficialDomain() {
        let result = NodeURLValidator.validate("https://mynode.example.com")
        if case .validWithWarning(let warning) = result {
            XCTAssertTrue(warning.contains("official"), "Should warn about non-official node")
        } else {
            XCTFail("Expected validWithWarning for non-official domain")
        }
    }

    func testRejectEmptyURL() {
        let result = NodeURLValidator.validate("")
        if case .invalid = result {
            // Pass
        } else {
            XCTFail("Expected invalid for empty URL")
        }
    }

    func testRejectNoScheme() {
        let result = NodeURLValidator.validate("cereblix.com")
        if case .invalid = result {
            // Pass
        } else {
            XCTFail("Expected invalid for URL without scheme")
        }
    }

    func testRejectFTPScheme() {
        let result = NodeURLValidator.validate("ftp://cereblix.com")
        if case .invalid = result {
            // Pass
        } else {
            XCTFail("Expected invalid for FTP scheme")
        }
    }

    // MARK: - P2P Nonce Validation Tests

    func testValidNonce() {
        XCTAssertTrue(WalletCore.validateP2PNonce("abc12345"))
        XCTAssertTrue(WalletCore.validateP2PNonce("aB3-_xyz1234567890"))
        XCTAssertTrue(WalletCore.validateP2PNonce(String(repeating: "a", count: 128)))
    }

    func testRejectShortNonce() {
        XCTAssertFalse(WalletCore.validateP2PNonce("abc"))        // too short (< 8)
        XCTAssertFalse(WalletCore.validateP2PNonce(""))           // empty
    }

    func testRejectLongNonce() {
        let longNonce = String(repeating: "x", count: 129)
        XCTAssertFalse(WalletCore.validateP2PNonce(longNonce))
    }

    func testRejectNonceWithSpecialChars() {
        XCTAssertFalse(WalletCore.validateP2PNonce("abc!@#$%^&"))
        XCTAssertFalse(WalletCore.validateP2PNonce("nonce with spaces"))
        XCTAssertFalse(WalletCore.validateP2PNonce("nonce\nnewline"))
    }

    func testP2PLoginMessageIsCanonical() throws {
        let nonce = "abc12345"
        XCTAssertEqual(try WalletCore.p2pLoginMessage(nonce: nonce), "cereblix-otc-login|\(nonce)")
    }
    
    func testP2PLoginSignsExactChallengeMessage() throws {
        let wallet = WalletCore.generateWallet()
        let signature = try WalletCore.signP2PLogin(
            nonce: "abc12345",
            message: "cereblix-otc-login|abc12345",
            privateKeyHex: wallet.privateKeyHex
        )
        XCTAssertEqual(signature.count, 128)
    }

    func testP2PLoginRejectsServerProvidedMessage() {
        let wallet = WalletCore.generateWallet()
        XCTAssertThrowsError(
            try WalletCore.signP2PLogin(
                nonce: "abc12345",
                message: "Sign this server supplied message: abc12345",
                privateKeyHex: wallet.privateKeyHex
            )
        )
    }

    // MARK: - Address Validation Tests

    func testValidCRBAddress() {
        let valid = "crb1" + String(repeating: "a", count: 40)
        XCTAssertTrue(AddressValidator.isValidAddress(valid))
    }

    func testInvalidCRBAddressPrefix() {
        let invalid = "btc1" + String(repeating: "a", count: 40)
        XCTAssertFalse(AddressValidator.isValidAddress(invalid))
    }

    func testInvalidCRBAddressLength() {
        let tooShort = "crb1" + String(repeating: "a", count: 10)
        XCTAssertFalse(AddressValidator.isValidAddress(tooShort))
    }
    
    func testRejectUppercaseCRBAddress() {
        let uppercase = "crb1" + String(repeating: "A", count: 40)
        XCTAssertFalse(AddressValidator.isValidAddress(uppercase))
    }
    
    func testRejectCRBAddressWithWhitespace() {
        let valid = "crb1" + String(repeating: "a", count: 40)
        XCTAssertFalse(AddressValidator.isValidAddress(" \(valid) "))
    }

    // MARK: - Input Sanitization Tests

    func testSanitizeInputTrimsWhitespace() {
        let result = AddressValidator.sanitizeInput("  hello world  ")
        XCTAssertEqual(result, "hello world")
    }

    func testSanitizeInputStripsControlChars() {
        let input = "hello\u{0000}world\u{0001}test"
        let result = AddressValidator.sanitizeInput(input)
        XCTAssertFalse(result.contains("\u{0000}"))
        XCTAssertFalse(result.contains("\u{0001}"))
    }

    func testSanitizeInputPreservesNewlines() {
        let input = "line1\nline2"
        let result = AddressValidator.sanitizeInput(input)
        XCTAssertTrue(result.contains("\n"))
    }

    func testSanitizeSingleLineStripsNewlines() {
        let input = "line1\nline2"
        let result = AddressValidator.sanitizeSingleLine(input)
        XCTAssertFalse(result.contains("\n"))
        XCTAssertEqual(result, "line1line2")
    }

    // MARK: - CRBUnits Edge Cases

    func testCRBUnitsZero() {
        let result = CRBUnits.toBaseUnits(0)
        XCTAssertEqual(result, 0 as UInt64?)
    }

    func testCRBUnitsSmallAmount() {
        let result = CRBUnits.toBaseUnits(Decimal(string: "0.00000001")!)
        XCTAssertEqual(result, 1 as UInt64?)
    }

    func testCRBUnitsLargeAmount() {
        let result = CRBUnits.toBaseUnits(Decimal(string: "1000000")!)
        XCTAssertEqual(result, 100_000_000_000_000 as UInt64?)
    }

    func testCRBUnitsRoundTrip() {
        let original: UInt64 = 123_456_789
        let display = CRBUnits.toDisplayCRB(original)
        let backToBase = CRBUnits.toBaseUnits(display)
        XCTAssertEqual(backToBase, original as UInt64?)
    }

    func testCRBUnitsRejectFractionalSynapse() {
        let result = CRBUnits.toBaseUnits(Decimal(string: "0.000000001")!)
        XCTAssertNil(result)
    }

    func testCRBUnitsRejectNegativeAmount() {
        let result = CRBUnits.toBaseUnits(Decimal(string: "-1")!)
        XCTAssertNil(result)
    }

    func testURLBuilderEncodesQueryItems() throws {
        let url = try APIClient.makeURL(
            base: "https://cereblix.com/api",
            path: "history",
            queryItems: [URLQueryItem(name: "addr", value: "crb1abc test")]
        )
        XCTAssertEqual(url, "https://cereblix.com/api/history?addr=crb1abc%20test")
    }
}
