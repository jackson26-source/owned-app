import Foundation

/// Configuration for the (not-yet-verified) Google OAuth client that
/// Gmail auto-import needs. See
/// claude/macless-owned-google-oauth-verification-prep-2026-08-24.md in
/// the project for the full scope decision and verification checklist.
///
/// This is deliberately a placeholder until a real Google Cloud project
/// exists - creating that project is blocked on a one-time account
/// re-authentication only Jackson can do. Every other piece of the OAuth
/// flow (GmailOAuthService, the PKCE math, token storage) is real and
/// doesn't need to change once the real values are dropped in here.
enum GmailOAuthConfig {
    /// Google Cloud OAuth 2.0 client ID for an iOS app. Replace once the
    /// Google Cloud Console project exists.
    static let clientID = "REPLACE_WITH_GOOGLE_OAUTH_CLIENT_ID"

    /// Must exactly match the "iOS URL scheme" Google issues alongside
    /// the client ID (it's derived from the reversed client ID) - also
    /// registered as a CFBundleURLSchemes entry in project.yml.
    static let redirectScheme = "dev.macless.owned.oauth"
    static let redirectURI = "\(redirectScheme):/oauth2redirect"

    static let authorizationEndpoint = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
    static let tokenEndpoint = URL(string: "https://oauth2.googleapis.com/token")!

    /// Read-only Gmail scope only - Owned never sends, deletes, or
    /// modifies anything in the person's inbox.
    static let scope = "https://www.googleapis.com/auth/gmail.readonly"

    static var isConfigured: Bool {
        clientID != "REPLACE_WITH_GOOGLE_OAUTH_CLIENT_ID"
    }
}
