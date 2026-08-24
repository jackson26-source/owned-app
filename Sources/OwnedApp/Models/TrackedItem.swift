import Foundation

/// The three lifecycle clocks a single purchase can be running at once.
/// A single item can have any combination of these — a $40 pair of
/// headphones might have a 30-day return window AND a 1-year warranty
/// at the same time, and later, in Phase 2, a shipping status before
/// either of those clocks even starts.
enum TrackedDeadlineKind: String, Codable, CaseIterable, Identifiable {
    case returnWindow
    case warranty

    var id: String { rawValue }

    var label: String {
        switch self {
        case .returnWindow: return "Return window"
        case .warranty: return "Warranty"
        }
    }
}

enum ItemStatus: String, Codable {
    case active
    case expiringSoon
    case expired

    /// Days-until-deadline that flips an item into "expiring soon".
    /// 14 days felt right for a first pass — a return window is usually
    /// much shorter than this, so most return items will spend their
    /// whole life in this state, which is the point: they should feel
    /// urgent right away, not just in the final days.
    static let expiringSoonThresholdDays = 14
}

/// Broad purchase categories, used for filtering and for the dashboard's
/// breakdown-by-category. Optional and unset by default — categorizing
/// a purchase is a nice-to-have, not something Phase 1 should ever block
/// adding an item over.
enum ItemCategory: String, Codable, CaseIterable, Identifiable {
    case electronics
    case clothing
    case homeAndKitchen
    case appliances
    case furniture
    case beauty
    case toysAndGames
    case sportsAndOutdoors
    case tools
    case groceries
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .electronics: return "Electronics"
        case .clothing: return "Clothing"
        case .homeAndKitchen: return "Home & Kitchen"
        case .appliances: return "Appliances"
        case .furniture: return "Furniture"
        case .beauty: return "Beauty"
        case .toysAndGames: return "Toys & Games"
        case .sportsAndOutdoors: return "Sports & Outdoors"
        case .tools: return "Tools"
        case .groceries: return "Groceries"
        case .other: return "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .electronics: return "tv"
        case .clothing: return "tshirt"
        case .homeAndKitchen: return "house"
        case .appliances: return "washer"
        case .furniture: return "sofa"
        case .beauty: return "sparkles"
        case .toysAndGames: return "gamecontroller"
        case .sportsAndOutdoors: return "figure.run"
        case .tools: return "wrench.and.screwdriver"
        case .groceries: return "cart"
        case .other: return "shippingbox"
        }
    }
}

struct TrackedDeadline: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var kind: TrackedDeadlineKind
    var date: Date

    func status(now: Date = Date()) -> ItemStatus {
        let days = Calendar.current.dateComponents([.day], from: now, to: date).day ?? 0
        if date < now {
            return .expired
        } else if days <= ItemStatus.expiringSoonThresholdDays {
            return .expiringSoon
        } else {
            return .active
        }
    }

    func daysRemaining(now: Date = Date()) -> Int {
        Calendar.current.dateComponents([.day], from: now, to: date).day ?? 0
    }
}

/// A single tracked purchase. Everything about it lives only on-device —
/// see ItemStore for the local-only persistence, no account, no cloud sync.
struct TrackedItem: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var retailer: String
    var purchaseDate: Date
    var priceCents: Int?
    var notes: String = ""

    /// One item can carry more than one deadline (return window, warranty,
    /// both, or — once Phase 2 lands — neither yet, because it's still
    /// just "ordered, not shipped").
    var deadlines: [TrackedDeadline] = []

    /// Filename of a locally-stored receipt photo, relative to the app's
    /// Documents directory. Never uploaded anywhere.
    var receiptPhotoFilename: String?

    /// Set once the person has confirmed adding a deadline to Apple Wallet
    /// via the notification flow, so we don't ask again for the same one.
    var walletPassAddedForDeadlineIDs: Set<UUID> = []

    /// Optional — nil means "uncategorized." Declared Optional (rather than
    /// a non-optional with a default) specifically so JSONDecoder can
    /// decode existing saved items that predate this field: a missing key
    /// decodes to nil for free, no migration step needed.
    var category: ItemCategory?

    /// When the person marked this item as returned or successfully
    /// claimed under warranty — nil until then. This is what the
    /// dashboard's lifetime "money protected" stat counts: an item only
    /// contributes once someone has actually confirmed the outcome, not
    /// just because its window happened to pass. Optional for the same
    /// Codable back-compat reason as the category field above.
    var resolvedAt: Date?

    var priceDisplay: String? {
        guard let priceCents else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return formatter.string(from: NSNumber(value: Double(priceCents) / 100.0))
    }

    /// The single most urgent deadline on this item, if any — this is what
    /// the list row's status badge is driven by.
    var soonestDeadline: TrackedDeadline? {
        deadlines
            .filter { $0.status() != .expired }
            .sorted { $0.date < $1.date }
            .first
            ?? deadlines.sorted { $0.date < $1.date }.first
    }

    var overallStatus: ItemStatus {
        soonestDeadline?.status() ?? .active
    }
}
