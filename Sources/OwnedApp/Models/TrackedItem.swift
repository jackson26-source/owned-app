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
