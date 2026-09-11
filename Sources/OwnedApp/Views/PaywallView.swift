import SwiftUI
import StoreKit

/// Shared paywall content for Owned Pro, presented from both gates: the
/// free-item cap in `AddItemView` (via `PaywallSheet` below) and the
/// automatic Gmail tracking section in `GmailConnectSection` (embedded
/// directly inline in its Section). One purchase unlocks both - see
/// `claude/macless-owned-storekit-engineering-brief-2026-09-11.md` in the
/// Macless/Citolex project for why they're a single unlock rather than
/// two separate purchases.
struct PaywallView: View {
    /// Called once a purchase made from this specific view succeeds.
    /// Callers that embed this inline (`GmailConnectSection`) don't need
    /// it, since `PurchaseService.hasUnlockedPro` flipping already swaps
    /// their own content out from under this view on the next render;
    /// callers that present it as a sheet (`PaywallSheet`) use it to
    /// dismiss.
    var onUnlocked: (() -> Void)?

    @ObservedObject private var purchases = PurchaseService.shared
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Owned Pro")
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)

            Text("Unlimited tracked items and automatic Gmail import — one-time purchase, no subscription.")
                .font(.caption)
                .foregroundStyle(Theme.textDim)

            Button {
                purchase()
            } label: {
                HStack {
                    Text(purchases.product.map { "Unlock — \($0.displayPrice)" } ?? "Unlock")
                    if isWorking {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(isWorking || purchases.product == nil)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(.vertical, 4)
    }

    private func purchase() {
        errorMessage = nil
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                try await purchases.purchase()
                onUnlocked?()
            } catch PurchaseService.PurchaseError.userCancelled {
                // Cancelling isn't a failure - leave state exactly as it
                // was, with no error shown.
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

/// Full-screen presentation of `PaywallView`, used when a gate needs to
/// interrupt a modal flow - specifically, hitting the free-item cap
/// inside `AddItemView` - rather than swap inline content the way
/// `GmailConnectSection` does directly in its own Section.
struct PaywallSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PaywallView(onUnlocked: { dismiss() })
                } footer: {
                    Text("You've tracked \(PurchaseService.freeItemLimit) free items - Owned Pro removes the limit.")
                }
                .listRowBackground(Theme.panel)
            }
            .themedScrollBackground()
            .navigationTitle("Owned Pro")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    PaywallSheet()
}
