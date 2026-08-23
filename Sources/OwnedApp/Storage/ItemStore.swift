import Foundation
import Combine

/// Local-only persistence. No account, no cloud sync, nothing ever leaves
/// the device in Phase 1 — that's a deliberate product stance, not a
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

      init(fileURL: URL? = nil) {
                if let fileURL {
                              self.fileURL = fileURL
                } else {
                              let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                              self.fileURL = documents.appendingPathComponent("owned-items.json")
                }
                load()
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

      /// Sorted so the most urgent item is always first — active ahead of
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
                              // all — and the broken file is left on disk rather than
                              // silently deleted, in case it's ever worth recovering by hand.
                              print("ItemStore: failed to load items — \(error)")
                              items = []
                }
      }

      private func save() {
                do {
                              let data = try encoder.encode(items)
                              try data.write(to: fileURL, options: [.atomic])
                } catch {
                              print("ItemStore: failed to save items — \(error)")
                }
      }
}
