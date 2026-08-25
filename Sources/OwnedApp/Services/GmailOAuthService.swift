import Foundation
import AuthenticationServices
import Security
import CryptoKit
import UIKit

/// Drives Google's OAuth 2.0 + PKCE flow for Gmail read-only access, and
/// stores the resulting tokens in the Keychain. No GoogleSignIn SDK and
/// no server round-trip - this is the same flow Google's own
/// documentation describes for a "native app" client, implemented
/// directly against ASWebAuthenticationSession and URLSession.
///
/// Requires GmailOAuthConfig.clientID to be a real value (see that file)
/// before connect() will do anything but throw .notConfigured.
@MainActor
final class GmailOAuthService: NSObject, ObservableObject {
    static let shared = GmailOAuthService()

    @Published private(set) var isConnected: Bool = false

    private var webAuthSession: ASWebAuthenticationSession?

    private override init() {
        super.init()
        isConnected = Self.hasStoredTokens()
    }

    enum OAuthError: LocalizedError {
        case notConfigured
        case userCancelled
        case invalidCallback
        case tokenExchangeFailed(String)

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "Gmail import isn't set up yet - check back once it's available."
            case .userCancelled:
                return "Sign-in was cancelled."
            case .invalidCallback:
                return "Google's sign-in response was missing what we needed."
            case .tokenExchangeFailed(let detail):
                return "Couldn't finish connecting to Gmail: \(detail)"
            }
        }
    }

    /// Starts the browser-based sign-in flow. Throws OAuthError.notConfigured
    /// until a real client ID is in place in GmailOAuthConfig.
    func connect() async throws {
        guard GmailOAuthConfig.isConfigured else { throw OAuthError.notConfigured }

        let verifier = Self.generateCodeVerifier()
        let challenge = Self.codeChallenge(for: verifier)

        var components = URLComponents(url: GmailOAuthConfig.authorizationEndpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: GmailOAuthConfig.clientID),
            URLQueryItem(name: "redirect_uri", value: GmailOAuthConfig.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: GmailOAuthConfig.scope),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            // Ensures a refresh token comes back even if the person has
            // authorized this app before.
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]

        let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: components.url!,
                callbackURLScheme: GmailOAuthConfig.redirectScheme
            ) { url, error in
                if let url {
                    continuation.resume(returning: url)
                } else if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    continuation.resume(throwing: OAuthError.userCancelled)
                } else {
                    continuation.resume(throwing: error ?? OAuthError.invalidCallback)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.webAuthSession = session
            session.start()
        }

        guard
            let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "code" })?.value
        else { throw OAuthError.invalidCallback }

        try await exchangeCodeForTokens(code: code, verifier: verifier)
        isConnected = true
    }

    func disconnect() {
        Self.deleteStoredTokens()
        isConnected = false
    }

    /// Returns a valid access token, refreshing it first if it's expired.
    /// GmailAPIClient calls this before every request rather than caching
    /// a token itself, so refresh logic lives in exactly one place.
    func validAccessToken() async throws -> String {
        guard var tokens = Self.loadStoredTokens() else { throw OAuthError.notConfigured }

        if tokens.expiresAt > Date().addingTimeInterval(60) {
            return tokens.accessToken
        }

        guard let refreshToken = tokens.refreshToken else {
            throw OAuthError.tokenExchangeFailed("No refresh token stored - reconnect Gmail in Settings.")
        }
        tokens = try await refreshAccessToken(refreshToken: refreshToken)
        Self.storeTokens(tokens)
        return tokens.accessToken
    }

    // MARK: - Token exchange

    private struct StoredTokens: Codable {
        var accessToken: String
        var refreshToken: String?
        var expiresAt: Date
    }

    private func exchangeCodeForTokens(code: String, verifier: String) async throws {
        var request = URLRequest(url: GmailOAuthConfig.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formEncode([
            "client_id": GmailOAuthConfig.clientID,
            "code": code,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": GmailOAuthConfig.redirectURI
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw OAuthError.tokenExchangeFailed(String(data: data, encoding: .utf8) ?? "(no body)")
        }

        struct TokenResponse: Decodable {
            let access_token: String
            let refresh_token: String?
            let expires_in: Int
        }
        let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
        Self.storeTokens(StoredTokens(
            accessToken: decoded.access_token,
            refreshToken: decoded.refresh_token,
            expiresAt: Date().addingTimeInterval(TimeInterval(decoded.expires_in))
        ))
    }

    private func refreshAccessToken(refreshToken: String) async throws -> StoredTokens {
        var request = URLRequest(url: GmailOAuthConfig.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formEncode([
            "client_id": GmailOAuthConfig.clientID,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw OAuthError.tokenExchangeFailed(String(data: data, encoding: .utf8) ?? "(no body)")
        }

        struct TokenResponse: Decodable {
            let access_token: String
            let expires_in: Int
        }
        let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
        // Google doesn't resend the refresh token on a refresh call -
        // keep the one already stored.
        return StoredTokens(
            accessToken: decoded.access_token,
            refreshToken: refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(decoded.expires_in))
        )
    }

    private static func formEncode(_ params: [String: String]) -> Data {
        params.map { key, value in
            let allowed = CharacterSet.urlQueryAllowed.subtracting(.init(charactersIn: "+&="))
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let encodedValue = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(encodedKey)=\(encodedValue)"
        }
        .joined(separator: "&")
        .data(using: .utf8)!
    }

    // MARK: - PKCE

    private static func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return base64URLEncode(Data(bytes))
    }

    private static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return base64URLEncode(Data(digest))
    }

    private static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - Keychain storage

    private static let keychainAccount = "dev.macless.owned.gmail-tokens"

    private static func storeTokens(_ tokens: StoredTokens) {
        guard let data = try? JSONEncoder().encode(tokens) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private static func loadStoredTokens() -> StoredTokens? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return try? JSONDecoder().decode(StoredTokens.self, from: data)
    }

    private static func deleteStoredTokens() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
    }

    private static func hasStoredTokens() -> Bool {
        loadStoredTokens() != nil
    }
}

extension GmailOAuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first(where: { $0.isKeyWindow }) ?? ASPresentationAnchor()
    }
}
