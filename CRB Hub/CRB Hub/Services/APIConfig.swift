import CryptoKit
import Foundation
import Security

/// API configuration and generic networking layer
enum APIConfig {
    static let officialBaseURL = "https://cereblix.com"
    static var baseURL = "https://cereblix.com"

    static var walletAPI: String { "\(baseURL)/api" }
    static var poolAPI: String { "\(baseURL)/pool/api" }
    static var p2pAPI: String { "\(officialBaseURL)/otc" }

    /// Default timeout
    static let timeout: TimeInterval = 30
}

/// Unified API error type
enum CRBAPIError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case serverError(statusCode: Int, message: String?)
    case decodingError(Error)
    case badRequest(String)
    case unauthorized(String? = nil)
    case notFound
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message ?? "Unknown")"
        case .decodingError(let error):
            return "Data parsing error: \(error.localizedDescription)"
        case .badRequest(let message):
            return "Bad request: \(message)"
        case .unauthorized(let message):
            return message ?? "Authentication required. Please login again."
        case .notFound:
            return "Resource not found"
        case .rateLimited:
            return "Too many requests. Please slow down."
        }
    }
}

/// Generic API error response from server
struct APIErrorResponse: Codable {
    let error: String?
}

/// Generic networking helper
enum APIClient {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = APIConfig.timeout
        config.httpAdditionalHeaders = [
            "Accept": "application/json",
            "Content-Type": "application/json",
        ]
        return URLSession(configuration: config, delegate: PinnedURLSessionDelegate(), delegateQueue: nil)
    }()

    /// Build a URL string using URLComponents so query values are percent-encoded.
    static func makeURL(base: String, path: String = "", queryItems: [URLQueryItem] = []) throws -> String {
        guard var components = URLComponents(string: base) else {
            throw CRBAPIError.invalidURL
        }

        if !path.isEmpty {
            let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let extraPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            components.path = "/" + [basePath, extraPath].filter { !$0.isEmpty }.joined(separator: "/")
        }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw CRBAPIError.invalidURL
        }

        return url.absoluteString
    }

    /// Perform a GET request
    static func get<T: Decodable>(_ url: String, type: T.Type) async throws -> T {
        guard let url = URL(string: url) else {
            throw CRBAPIError.invalidURL
        }

        do {
            let (data, response) = try await session.data(from: url)
            try validateResponse(response, data: data)
            return try decode(data, as: T.self)
        } catch let error as CRBAPIError {
            throw error
        } catch {
            throw CRBAPIError.networkError(error)
        }
    }

    /// Perform a GET request with Bearer token
    static func getAuth<T: Decodable>(_ url: String, token: String, type: T.Type) async throws -> T {
        guard let url = URL(string: url) else {
            throw CRBAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await session.data(for: request)
            try validateResponse(response, data: data)
            return try decode(data, as: T.self)
        } catch let error as CRBAPIError {
            throw error
        } catch {
            throw CRBAPIError.networkError(error)
        }
    }

    /// Perform a POST request with JSON body
    static func post<B: Encodable, T: Decodable>(_ url: String, body: B, type: T.Type) async throws -> T {
        guard let url = URL(string: url) else {
            throw CRBAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        do {
            let (data, response) = try await session.data(for: request)
            try validateResponse(response, data: data)
            return try decode(data, as: T.self)
        } catch let error as CRBAPIError {
            throw error
        } catch {
            throw CRBAPIError.networkError(error)
        }
    }

    /// Perform a POST request with JSON body and Bearer token
    static func postAuth<B: Encodable, T: Decodable>(_ url: String, token: String, body: B, type: T.Type) async throws -> T {
        guard let url = URL(string: url) else {
            throw CRBAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        do {
            let (data, response) = try await session.data(for: request)
            try validateResponse(response, data: data)
            return try decode(data, as: T.self)
        } catch let error as CRBAPIError {
            throw error
        } catch {
            throw CRBAPIError.networkError(error)
        }
    }

    /// Simple POST with token, no response body needed
    static func postAuthSimple<B: Encodable>(_ url: String, token: String, body: B) async throws {
        guard let url = URL(string: url) else {
            throw CRBAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        do {
            let (data, response) = try await session.data(for: request)
            try validateResponse(response, data: data)
        } catch let error as CRBAPIError {
            throw error
        } catch {
            throw CRBAPIError.networkError(error)
        }
    }

    // MARK: - Helpers

    private static func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 400:
            let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            throw CRBAPIError.badRequest(errorResponse?.error ?? "Bad request")
        case 401:
            let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            throw CRBAPIError.unauthorized(errorResponse?.error)
        case 404:
            throw CRBAPIError.notFound
        case 429:
            throw CRBAPIError.rateLimited
        default:
            let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            throw CRBAPIError.serverError(statusCode: httpResponse.statusCode, message: errorResponse?.error)
        }
    }

    private static func decode<T: Decodable>(_ data: Data, as type: T.Type) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw CRBAPIError.decodingError(error)
        }
    }
}

private final class PinnedURLSessionDelegate: NSObject, URLSessionDelegate {
    private let pinnedPublicKeyHashes: [String: Set<String>] = [
        "cereblix.com": ["nu8h0e7KjZAP+twP4B/c9jaaE2ueB+62CmLw+JsDq28="]
    ]

    private let legacyLeafCertificateHashes: [String: Set<String>] = [
        "cereblix.com": ["3kRswfRe3GbqVKG96IqxkWOzKPYz1GjQy2XLO2qrzeQ="]
    ]

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let host = challenge.protectionSpace.host.lowercased()
        guard let allowedPublicKeyHashes = pinnedPublicKeyHashes[host] else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        guard SecTrustEvaluateWithError(trust, nil),
              let certificateChain = SecTrustCopyCertificateChain(trust),
              CFArrayGetCount(certificateChain) > 0 else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let leafCertificate = unsafeBitCast(CFArrayGetValueAtIndex(certificateChain, 0), to: SecCertificate.self)
        if let publicKeyHash = publicKeyHash(for: leafCertificate),
           allowedPublicKeyHashes.contains(publicKeyHash) {
            completionHandler(.useCredential, URLCredential(trust: trust))
            return
        }

        let certificateData = SecCertificateCopyData(leafCertificate) as Data
        let legacyLeafHash = Data(SHA256.hash(data: certificateData)).base64EncodedString()

        guard legacyLeafCertificateHashes[host]?.contains(legacyLeafHash) == true else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        completionHandler(.useCredential, URLCredential(trust: trust))
    }

    private func publicKeyHash(for certificate: SecCertificate) -> String? {
        guard let publicKey = SecCertificateCopyKey(certificate),
              let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
            return nil
        }

        let attributes = SecKeyCopyAttributes(publicKey) as? [String: Any]
        let keyType = attributes?[kSecAttrKeyType as String] as? String
        let keySize = attributes?[kSecAttrKeySizeInBits as String] as? Int
        let spkiData: Data

        if keyType == (kSecAttrKeyTypeECSECPrimeRandom as String), keySize == 256, publicKeyData.count == 65 {
            spkiData = Data(hexString: "3059301306072a8648ce3d020106082a8648ce3d030107034200").map { $0 + publicKeyData } ?? publicKeyData
        } else {
            spkiData = publicKeyData
        }

        return Data(SHA256.hash(data: spkiData)).base64EncodedString()
    }
}
