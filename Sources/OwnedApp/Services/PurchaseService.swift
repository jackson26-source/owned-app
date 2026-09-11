import Foundation
import StoreKit

/// Drives the one-time, non-consumable "Owned Pro" unlock. Pro gates two
/// things together: the free-tier item cap (see `freeItemLimit`, enforced
/// in `AddItemView`) and the automatic (Gmail) purchase-tracking feature
/// (gated in `GmailConnectSection`). StoreKit 2 only - no server-side
/// receipt validation, no subscription, no consumables (see
/// `claude/macless-owned-storekit-engineering-brief-2026-09-11.md` in the
/// Macless/Citolex project for the full reasoning, including why this
/// widened from "just gate Gmail auto-import" to a single combined
/// unlock). Every transaction is verified locally via StoreKit 2's signed
/// JWS, consistent with "no backend" being true everywhere else in this
/// app, not just marketing copy.
@MainActor
final class PurchaseService: NSObject, ObservableObject {
    static let shared = PurchaseService()

    static let proProductID = "dev.macless.owned.pro"

    /// Lifetime cap on free manual tracking - the total number of items
    /// ever created, not a rolling/active count. Resolving an item to
    /// drop back under the limit must never reopen free item creation,
    /// so callers should compare against every item ever saved, not just
    /// currently-unresolved ones. Gmail auto-import has no free
    /// allowance at all; it's gated entirely behind the same purchase.
    static let freeItemLimit = 15

    @Published private(set) var hasUnlockedPro: Bool = false
    @Published private(set) var product: Product?

    enum PurchaseError: LocalizedError {
        case productUnavailable
        case userCancelled
        case verificationFailed
        case purchaseFailed(String)

        var errorDescription: String? {
            switch self {
            case .productUnavailable:
                return "Owned Pro isn't available to purchase right now - check back shortly."
            case .userCancelled:
                return "Purchase was cancelled."
            case .verificationFailed:
                return "The App Store couldn't verify that purchase - try again, or restore purchases from Settings."
            case .purchaseFailed(let detail):
                return "Couldn't complete the purchase: \(detail)"
            }
        }
    }

    private var updatesTask: Task<Void, Never>?

    private override init() {
        super.init()
        updatesTask = Task { await observeTransactionUpdates() }
        Task {
            await loadProduct()
            await refreshEntitlement()
        }
    }

    /// Fetches Owned Pro's `Product` from the App Store (or the local
    /// `Owned.storekit` configuration when running in the simulator with
    /// that configuration active - see project.yml). Safe to call more
    /// than once; it just refreshes `product`. Leaves `product` as `nil`
    /// on failure rather than throwing, since `PaywallView` handles a nil
    /// product by disabling the Unlock button instead of needing to show
    /// a load error on every screen that might render before the App
    /// Store responds.
    func loadProduct() async {
        do {
            let products = try await Product.products(for: [Self.proProductID])
            product = products.first
        } catch {
            product = nil
        }
    }

    /// Starts the purchase flow for Owned Pro. A user-initiated cancel is
    /// surfaced as `.userCancelled` so the caller can choose not to show
    /// it as an error - cancelling isn't a failure (see `PaywallView`).
    func purchase() async throws {
        guard let product else { throw PurchaseError.productUnavailable }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            hasUnlockedPro = true
            await transaction.finish()
        case .userCancelled:
            throw PurchaseError.userCancelled
        case .pending:
            // Waiting on approval (e.g. Ask to Buy) - Transaction.updates
            // will flip hasUnlockedPro if/when it actually goes through,
            // nothing more to do here.
            break
        @unknown default:
            break
        }
    }

    /// Re-syncs with the App Store and re-checks entitlements - the
    /// standard "Restore Purchases" flow for a non-consumable. Used both
    /// from Settings and after a reinstall/new device.
    func restore() async throws {
        do {
            try await AppStore.sync()
        } catch {
            throw PurchaseError.purchaseFailed(error.localizedDescription)
        }
        await refreshEntitlement()
    }

    /// Checks StoreKit's own record of current entitlements - the source
    /// of truth for whether this Apple ID has already unlocked Pro.
    /// Called on launch, and again after every purchase/restore, so
    /// `hasUnlockedPro` never drifts from what the App Store actually
    /// knows.
    func refreshEntitlement() async {
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            if transaction.productID == Self.proProductID {
                hasUnlockedPro = true
                return
            }
        }
        hasUnlockedPro = false
    }

    /// Listens for transactions that complete outside the direct
    /// `purchase()` call above - an Ask to Buy approval, a purchase made
    /// on another device, or something still pending from last launch.
    private func observeTransactionUpdates() async {
        for await update in Transaction.updates {
            guard let transaction = try? checkVerified(update) else { continue }
            if transaction.productID == Self.proProductID {
                hasUnlockedPro = true
            }
            await transaction.finish()
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw PurchaseError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
}
