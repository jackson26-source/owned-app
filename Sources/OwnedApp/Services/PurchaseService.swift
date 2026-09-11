import Foundation
import StoreKit

/// Drives the one-time, non-consumable unlock for automatic (Gmail)
/// purchase tracking. StoreKit 2 only - no server-side receipt
/// validation, no subscription, no consumables (see
/// `claude/macless-owned-storekit-engineering-brief-2026-09-11.md` in the
/// Macless/Citolex project for the full reasoning). Every transaction is
/// verified locally via StoreKit 2's signed JWS, consistent with "no
/// backend" being true everywhere else in this app, not just marketing
/// copy.
@MainActor
final class PurchaseService: NSObject, ObservableObject {
    static let shared = PurchaseService()

    static let autoTrackingProductID = "dev.macless.owned.automatic_tracking"

    @Published private(set) var hasUnlockedAutoTracking: Bool = false
    @Published private(set) var product: Product?

    enum PurchaseError: LocalizedError {
        case productUnavailable
        case userCancelled
        case verificationFailed
        case purchaseFailed(String)

        var errorDescription: String? {
            switch self {
            case .productUnavailable:
                return "Automatic tracking isn't available to purchase right now - check back shortly."
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

    /// Fetches the non-consumable's `Product` from the App Store (or the
    /// local `Owned.storekit` configuration when running in the
    /// simulator with that configuration active - see project.yml).
    /// Safe to call more than once; it just refreshes `product`. Leaves
    /// `product` as `nil` on failure rather than throwing, since the
    /// paywall card handles a nil product by disabling the Unlock button
    /// instead of needing to show a load error on every screen that
    /// might render before the App Store responds.
    func loadProduct() async {
        do {
            let products = try await Product.products(for: [Self.autoTrackingProductID])
            product = products.first
        } catch {
            product = nil
        }
    }

    /// Starts the purchase flow for automatic tracking. A user-initiated
    /// cancel is surfaced as `.userCancelled` so the caller can choose
    /// not to show it as an error - cancelling isn't a failure (see the
    /// paywall card in `GmailConnectSection`).
    func purchase() async throws {
        guard let product else { throw PurchaseError.productUnavailable }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            hasUnlockedAutoTracking = true
            await transaction.finish()
        case .userCancelled:
            throw PurchaseError.userCancelled
        case .pending:
            // Waiting on approval (e.g. Ask to Buy) - Transaction.updates
            // will flip hasUnlockedAutoTracking if/when it actually goes
            // through, nothing more to do here.
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
    /// of truth for whether this Apple ID has already unlocked automatic
    /// tracking. Called on launch, and again after every purchase/restore,
    /// so `hasUnlockedAutoTracking` never drifts from what the App Store
    /// actually knows.
    func refreshEntitlement() async {
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            if transaction.productID == Self.autoTrackingProductID {
                hasUnlockedAutoTracking = true
                return
            }
        }
        hasUnlockedAutoTracking = false
    }

    /// Listens for transactions that complete outside the direct
    /// `purchase()` call above - an Ask to Buy approval, a purchase made
    /// on another device, or StoreKit finishing something that was still
    /// pending when the app last launched.
    private func observeTransactionUpdates() async {
        for await update in Transaction.updates {
            guard let transaction = try? checkVerified(update) else { continue }
            if transaction.productID == Self.autoTrackingProductID {
                hasUnlockedAutoTracking = true
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
