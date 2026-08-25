import Foundation

/// A purchase this device found by scanning a connected Gmail inbox, not
/// yet confirmed by the person. Deliberately close in shape to
/// TrackedItem so turning one into the other is a straight mapping, but
/// kept as its own type since not every field is guaranteed - a parser
/// this simple should surface uncertainty rather than guess silently.
struct DetectedPurchase: Identifiable, Hashable {
    /// The source Gmail message ID - stable across re-scans, so the same
    /// email never turns into two duplicate review entries.
    let id: String
    var itemName: String
    var retailer: String
    var purchaseDate: Date
    var priceCents: Int?
    var orderNumber: String?
    /// False when itemName fell back to the email's subject line rather
    /// than a specific line-item match - worth flagging in the review UI
    /// so the person double-checks it before saving.
    var itemNameIsConfident: Bool
}

/// Pattern-matches known retailer order-confirmation email formats to
/// pull out a purchase. Entirely on-device, no network calls, no AI -
/// just regexes and known sender/subject shapes, matching Owned's
/// on-device-only stance everywhere else in the app.
///
/// Coverage is deliberately scoped to what's actually common: Amazon,
/// Target, Walmart, Best Buy, and Costco by name, plus a generic
/// Shopify-template matcher that covers a large share of smaller
/// retailers (most Shopify stores don't customize their confirmation
/// email's structure). Anything else comes back as nil rather than a
/// bad guess - the review screen is where a person catches what the
/// parser missed, not this layer pretending to be more certain than it
/// is.
enum PurchaseEmailParser {

    /// The Gmail search query GmailAPIClient.listMessages should use to
    /// narrow down to messages worth running through parse(). Combines
    /// known retailer senders with receipt-shaped subject keywords, and
    /// excludes the shipping/delivery follow-up emails retailers send
    /// for the same order - those would otherwise show up as duplicate,
    /// worse-quality parses of a purchase the original confirmation
    /// email already caught.
    static func searchQuery(after: Date) -> String {
        let dateString = Self.gmailDateFormatter.string(from: after)

        let knownSenders = [
            "auto-confirm@amazon.com",
            "orders@oe1.target.com",
            "BestBuyInfo@emailinfo.bestbuy.com"
        ].map { "from:\($0)" }.joined(separator: " OR ")

        let subjectKeywords = [
            "order confirmation", "order confirmed", "thanks for your order",
            "your order", "order #", "receipt"
        ].map { "subject:\"\($0)\"" }.joined(separator: " OR ")

        return "((\(knownSenders)) OR (\(subjectKeywords))) "
            + "-subject:(shipped OR delivery OR delivered OR cancelled OR canceled OR refund) "
            + "after:\(dateString)"
    }

    static func parse(_ message: GmailAPIClient.GmailMessage) -> DetectedPurchase? {
        guard let retailer = detectRetailer(from: message) else { return nil }
        guard let priceCents = extractPriceCents(from: message.bodyText) else { return nil }

        let (itemName, isConfident) = extractItemName(from: message, retailer: retailer)
        let orderNumber = extractOrderNumber(from: message.bodyText, retailer: retailer)

        return DetectedPurchase(
            id: message.id,
            itemName: itemName,
            retailer: retailer.displayName,
            purchaseDate: message.date ?? Date(),
            priceCents: priceCents,
            orderNumber: orderNumber,
            itemNameIsConfident: isConfident
        )
    }

    // MARK: - Retailer detection

    private enum Retailer {
        case amazon, target, walmart, bestBuy, costco
        case shopifyGeneric(storeHint: String)

        var displayName: String {
            switch self {
            case .amazon: return "Amazon"
            case .target: return "Target"
            case .walmart: return "Walmart"
            case .bestBuy: return "Best Buy"
            case .costco: return "Costco"
            case .shopifyGeneric(let hint): return hint
            }
        }
    }

    private static func detectRetailer(from message: GmailAPIClient.GmailMessage) -> Retailer? {
        let from = message.from.lowercased()

        if from.contains("amazon.com") { return .amazon }
        if from.contains("target.com") { return .target }
        if from.contains("walmart.com") { return .walmart }
        if from.contains("bestbuy.com") { return .bestBuy }
        if from.contains("costco.com") { return .costco }

        // Generic Shopify-template detection: nearly every Shopify
        // store's confirmation email pairs an "order confirmed" style
        // subject with a "#1234" order-number format, regardless of the
        // store's own domain - that combination is the signal, not any
        // one sender address.
        let subject = message.subject.lowercased()
        let looksLikeOrderConfirmation = subject.contains("order confirm") || subject.contains("your order is confirmed")
        let hasOrderNumberFormat = message.bodyText.range(of: #"#\d{3,}"#, options: .regularExpression) != nil
        guard looksLikeOrderConfirmation && hasOrderNumberFormat else { return nil }

        let displayNamePart = message.from
            .components(separatedBy: "<").first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let hint = (displayNamePart?.isEmpty == false ? displayNamePart : nil) ?? "Online store"
        return .shopifyGeneric(storeHint: hint!)
    }

    // MARK: - Field extraction

    /// Matches a dollar amount near words that mean "this is the final
    /// total," not a subtotal or a per-item price. Order-confirmation
    /// emails from every retailer researched put the grand total near
    /// one of these phrases, so anchoring on the phrase and taking the
    /// nearest dollar amount is more robust than trying to find "the
    /// biggest number in the email."
    private static func extractPriceCents(from body: String) -> Int? {
        let anchors = ["order total", "grand total", "total charged", "total:"]

        for anchor in anchors {
            guard let anchorRange = body.range(of: anchor, options: [.caseInsensitive]) else { continue }
            let searchWindow = String(body[anchorRange.upperBound...].prefix(200))
            if let cents = firstDollarAmountCents(in: searchWindow) {
                return cents
            }
        }
        // Fall back to the first dollar amount anywhere in the email -
        // worse odds of being the true total, but still better than
        // discarding the message outright when a retailer's template
        // doesn't match any known anchor phrase.
        return firstDollarAmountCents(in: body)
    }

    private static func firstDollarAmountCents(in text: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: #"\$\s?(\d{1,3}(?:,\d{3})*\.\d{2})"#) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let amountRange = Range(match.range(at: 1), in: text)
        else { return nil }
        let amountString = text[amountRange].replacingOccurrences(of: ",", with: "")
        guard let amount = Double(amountString) else { return nil }
        return Int((amount * 100).rounded())
    }

    private static func extractOrderNumber(from body: String, retailer: Retailer) -> String? {
        let patterns: [String]
        switch retailer {
        case .amazon:
            patterns = [#"\d{3}-\d{7}-\d{7}"#]
        default:
            patterns = [#"(?:Order|Confirmation)\s*#\s*([A-Za-z0-9-]{4,20})"#, #"#(\d{4,20})"#]
        }

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(body.startIndex..., in: body)
            guard let match = regex.firstMatch(in: body, range: range) else { continue }
            // Prefer a capture group if the pattern has one, else the
            // whole match (Amazon's pattern has no group).
            let groupIndex = match.numberOfRanges > 1 ? 1 : 0
            if let matchRange = Range(match.range(at: groupIndex), in: body) {
                return String(body[matchRange])
            }
        }
        return nil
    }

    /// Shopify's standard template renders each line item as
    /// "{quantity}x {product title}" - e.g. "2x Blue Shirt". For
    /// retailers without a reliably parseable line-item format (Amazon,
    /// Target, Walmart, Best Buy, and Costco all vary their HTML
    /// structure too often to regex safely), the email subject line is a
    /// reasonable stand-in - most order-confirmation subjects already
    /// name the item for single-item orders, and worst case the person
    /// just retypes it in the review step, which they'd have to check
    /// anyway.
    private static func extractItemName(from message: GmailAPIClient.GmailMessage, retailer: Retailer) -> (name: String, confident: Bool) {
        if case .shopifyGeneric = retailer,
           let regex = try? NSRegularExpression(pattern: #"\d+x\s+([^\n<]{3,80})"#, options: [.caseInsensitive]) {
            let range = NSRange(message.bodyText.startIndex..., in: message.bodyText)
            if let match = regex.firstMatch(in: message.bodyText, range: range),
               let nameRange = Range(match.range(at: 1), in: message.bodyText) {
                let name = message.bodyText[nameRange].trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty { return (name, true) }
            }
        }

        let cleanedSubject = message.subject
            .replacingOccurrences(
                of: #"(?i)^(your |thanks for )?(order|order confirmation|receipt)[:\-]?\s*"#,
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (cleanedSubject.isEmpty ? message.subject : cleanedSubject, false)
    }

    private static let gmailDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter
    }()
}
