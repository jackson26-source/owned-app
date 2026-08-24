import Foundation
import Combine

/// Local-only persistence. No account, no cloud sync, nothing ever leaves
/// the device in Phase 1 - that's a deliberate product stance, not a
/// missing feature. See README.md for why.
///
/// Storage is a single JSON file in the app's Documents directory. That's
/// intentionally low-tech: this app's whole dataset for one person is at
/// most a few hundred items, so there's no real case for Core Data or
/// SQLite yet, and a flat JSON file is trivial to reason about, trivial to
/// export/back up by hand, and trivial to migrate later if it ever needs
/// to be something heavier.
@MainActor
final class ItemStore: ObservableObject {
    @Published private(set) var items: [TrackedItem] = []

    private let fileURL: URL
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    /// Launch argument the screenshot-automation UI test target passes in
    /// (see Tests/OwnedUITests/ScreenshotUITests.swift and
    /// .github/workflows/screenshots.yml). Checked here rather than in the
    /// test target itself so the demo data always matches whatever real
    /// TrackedItem shape currently exists, instead of a hand-maintained
    /// fixture that can silently drift out of sync.
    static let screenshotModeLaunchArgument = "UI_TESTING_SCREENSHOTS"

    private static var isScreenshotMode: Bool {
        ProcessInfo.processInfo.arguments.contains(screenshotModeLaunchArgument)
    }

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else if Self.isScreenshotMode {
            // Route screenshot automation to a private, throwaway file
            // instead of the real Documents store, so a bug here can
            // never touch (or be confused with) genuine on-device data.
            self.fileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("owned-items-screenshot-demo.json")
        } else {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            self.fileURL = documents.appendingPathComponent("owned-items.json")
        }
        load()
        if Self.isScreenshotMode {
            // Always reseed fresh demo data on every screenshot run,
            // rather than only when empty, so stale leftovers from a
            // previous run (or a previous app version's shape) never
            // leak into a new set of App Store screenshots.
            items = Self.demoItems()
            save()
        }
    }

    /// A handful of realistic-looking purchases spanning every status
    /// (active, expiring soon, expired) and both deadline kinds, so the
    /// Dashboard, Items, and Timeline tabs all have something worth
    /// screenshotting instead of an empty state.
    static func demoItems() -> [TrackedItem] {
        let now = Date()
        func daysFromNow(_ n: Int) -> Date {
            Calendar.current.date(byAdding: .day, value: n, to: now) ?? now
        }

        return [
            TrackedItem(
                name: "Sony WH-1000XM5 Headphones",
                retailer: "Best Buy",
                purchaseDate: daysFromNow(-5),
                priceCents: 39_999,
                deadlines: [
                    TrackedDeadline(kind: .returnWindow, date: daysFromNow(9)),
                    TrackedDeadline(kind: .warranty, date: daysFromNow(360))
                ],
                category: .electronics
            ),
            TrackedItem(
                name: "Dyson V15 Cordless Vacuum",
                retailer: "Target",
                purchaseDate: daysFromNow(-20),
                priceCents: 64_999,
                deadlines: [
                    TrackedDeadline(kind: .warranty, date: daysFromNow(345))
                ],
                category: .homeAndKitchen
            ),
            TrackedItem(
                name: "Patagonia Down Jacket",
                retailer: "REI",
                purchaseDate: daysFromNow(-2),
                priceCents: 229_00,
                deadlines: [
                    TrackedDeadline(kind: .returnWindow, date: daysFromNow(28))
                ],
                category: .clothing
            ),
            TrackedItem(
                name: "KitchenAid Stand Mixer",
                retailer: "Williams Sonoma",
                purchaseDate: daysFromNow(-90),
                priceCents: 449_99,
                deadlines: [
                    TrackedDeadline(kind: .warranty, date: daysFromNow(275))
                ],
                category: .appliances
            ),
            TrackedItem(
                name: "Nintendo Switch 2",
                retailer: "Amazon",
                purchaseDate: daysFromNow(-1),
                priceCents: 449_00,
                deadlines: [
                    TrackedDeadline(kind: .returnWindow, date: daysFromNow(1))
                ],
                category: .toysAndGames
            ),
            TrackedItem(
                name: "Anker Portable Charger",
                retailer: "Amazon",
                purchaseDate: daysFromNow(-45),
                priceCents: 34_99,
                deadlines: [
                    TrackedDeadline(kind: .returnWindow, date: daysFromNow(-15))
                ],
                category: .electronics,
                resolvedAt: nil
            )
        ]
    }

    func add(_ item: TrackedItem) {
        items.append(item)
        save()
    }

    func update(_ item: TrackedItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index] = item
        save()
    }

    func delete(_ item: TrackedItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func delete(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        save()
    }

    func markWalletPassAdded(itemID: UUID, deadlineID: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[index].walletPassAddedForDeadlineIDs.insert(deadlineID)
        save()
    }

    /// Sorted so the most urgent item is always first - active ahead of
    /// expiring-soon would be backwards for what a person actually wants
    /// to see when they open the app.
    var sortedByUrgency: [TrackedItem] {
        items.sorted { lhs, rhs in
            let l = lhs.soonestDeadline?.date ?? .distantFuture
            let r = rhs.soonestDeadline?.date ?? .distantFuture
            return l < r
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            items = []
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            items = try decoder.decode([TrackedItem].self, from: data)
        } catch {
            // Deliberately fail soft: a corrupt or unreadable file should
            // never crash the app on launch. Worst case the person sees an
            // empty list instead of losing the ability to open the app at
            // all - and the broken file is left on disk rather than
            // silently deleted, in case it's ever worth recovering by hand.
            print("ItemStore: failed to load items - \(error)")
            items = []
        }
    }

    private func save() {
        do {
            let data = try encoder.encode(items)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("ItemStore: failed to save items - \(error)")
        }
    }
}
