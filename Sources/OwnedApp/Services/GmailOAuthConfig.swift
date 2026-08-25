import Foundation

/// Configuration for the Google OAuth client that Gmail auto-import
/// needs. See
/// claude/macless-owned-google-oauth-verification-prep-2026-08-24.md in
/// the project for the full scope decision and verification checklist.
///
/// Values below come from the "Owned" Google Cloud project
/// (owned-506605) under the macless.dev Workspace organization,
/// created 2026-08-25. Every other piece of the OAuth flow
/// (GmailOAuthService, the PKCE math, token storage) is real and
/// didn't need to change once the real values were dropped in here.
enum GmailOAuthConfig {
    /// Google Cloud OAuth 2.0 client ID for an iOS app (client "Owned
    /// iOS", bundle ID dev.macless.owned).
    static let clientID = "80246720305-m82i9sdohs1lcs3h3jl5tbja844366fq.apps.googleusercontent.com"

    /// Must exactly match the "iOS URL scheme" Google issues alongside
    /// the client ID (it's derived from the reversed client ID) - also
    /// registered as a CFBundleURLSchemes entry in project.yml.
    static let redirectScheme = "com.googleusercontent.apps.80246720305-m82i9sdohs1lcs3h3jl5tbja844366fq"
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
