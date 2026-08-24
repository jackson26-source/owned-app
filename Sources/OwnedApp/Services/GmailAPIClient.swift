import Foundation

/// A minimal Gmail REST API v1 client - just enough to search for and
/// fetch the handful of messages PurchaseEmailParser knows how to read.
/// No third-party SDK; every call goes straight to
/// https://gmail.googleapis.com over URLSession, authorized with the
/// access token GmailOAuthService hands back.
struct GmailAPIClient {
    private let oauth: GmailOAuthService

    init(oauth: GmailOAuthService = .shared) {
        self.oauth = oauth
    }

    private static let baseURL = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me")!

    /// Lists message IDs matching `query` (see
    /// PurchaseEmailParser.searchQuery for what's actually sent). Gmail's
    /// list endpoint only returns IDs; each one needs a separate
    /// fetchMessage call to get the actual content.
    func listMessages(query: String, maxResults: Int = 50) async throws -> [String] {
        var components = URLComponents(url: Self.baseURL.appendingPathComponent("messages"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "maxResults", value: String(maxResults))
        ]

        struct MessageSummary: Decodable { let id: String }
        struct ListResponse: Decodable { let messages: [MessageSummary]? }

        let response: ListResponse = try await get(components.url!)
        return response.messages?.map(\.id) ?? []
    }

    struct GmailMessage {
        let id: String
        let subject: String
        let from: String
        let date: Date?
        /// Decoded plain-text and/or HTML body, concatenated - most
        /// receipt emails send both parts, and PurchaseEmailParser's
        /// regexes are written to tolerate either.
        let bodyText: String
    }

    /// Fetches one message's headers and body, already base64url-decoded
    /// and flattened into a single string PurchaseEmailParser can scan.
    func fetchMessage(id: String) async throws -> GmailMessage {
        var components = URLComponents(url: Self.baseURL.appendingPathComponent("messages/\(id)"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "format", value: "full")]

        struct Header: Decodable { let name: String; let value: String }
        struct Body: Decodable { let data: String? }
        struct Part: Decodable {
            let body: Body?
            let parts: [Part]?
        }
        struct Payload: Decodable {
            let headers: [Header]
            let body: Body?
            let parts: [Part]?
        }
        struct MessageResponse: Decodable {
            let payload: Payload
        }

        let decoded: MessageResponse = try await get(components.url!)

        let headers = decoded.payload.headers
        let subject = headers.first(where: { $0.name.caseInsensitiveCompare("Subject") == .orderedSame })?.value ?? ""
        let from = headers.first(where: { $0.name.caseInsensitiveCompare("From") == .orderedSame })?.value ?? ""
        let dateString = headers.first(where: { $0.name.caseInsensitiveCompare("Date") == .orderedSame })?.value
        let date = dateString.flatMap { Self.rfc2822Formatter.date(from: $0) }

        var textFragments: [String] = []
        func collect(_ part: Part) {
            if let data = part.body?.data, let decodedText = Self.decodeBase64URL(data) {
                textFragments.append(decodedText)
            }
            part.parts?.forEach(collect)
        }
        if let data = decoded.payload.body?.data, let decodedText = Self.decodeBase64URL(data) {
            textFragments.append(decodedText)
        }
        decoded.payload.parts?.forEach(collect)

        return GmailMessage(id: id, subject: subject, from: from, date: date, bodyText: textFragments.joined(separator: "\n"))
    }

    // MARK: - Plumbing

    private func get<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        let token = try await oauth.validAccessToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "(no body)"
            throw NSError(
                domain: "GmailAPIClient",
                code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                userInfo: [NSLocalizedDescriptionKey: body]
            )
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func decodeBase64URL(_ string: String) -> String? {
        var base64 = string.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }
        guard let data = Data(base64Encoded: base64) else { return nil }
        // Gmail bodies are typically UTF-8; if strict decoding fails
        // (rare, but retailer templates aren't always clean), fall back
        // to a lossy decode rather than dropping the message entirely -
        // a slightly mangled string is still useful to regex against.
        return String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
    }

    private static let rfc2822Formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, d MMM yyyy HH:mm:ss Z"
        return formatter
    }()
}
