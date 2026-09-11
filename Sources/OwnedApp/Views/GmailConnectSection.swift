import SwiftUI

/// The Settings section that drives connecting a Gmail inbox and running
/// a purchase scan. Fully wired to GmailOAuthService, GmailAPIClient,
/// and PurchaseEmailParser - the only thing standing between this and
/// working end-to-end is a real client ID in GmailOAuthConfig (see that
/// file), which needs a Google Cloud OAuth consent screen that hasn't
/// been set up yet. Until then, tapping Connect surfaces
/// GmailOAuthService's own .notConfigured error rather than silently
/// doing nothing - nothing here is a stub waiting to be rewritten later.
struct GmailConnectSection: View {
    @EnvironmentObject private var itemStore: ItemStore
    @ObservedObject private var oauth = GmailOAuthService.shared
    @ObservedObject private var purchases = PurchaseService.shared

    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var detectedPurchases: [DetectedPurchase] = []
    @State private var isShowingReview = false

    var body: some View {
        Section {
            if !purchases.hasUnlockedAutoTracking {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Automatic tracking")
                            .font(.body.weight(.medium))
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text("Beta")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Theme.accent.opacity(0.15))
                            .foregroundStyle(Theme.accent)
                            .clipShape(Capsule())
                    }
                    Text("Connect your Gmail so purchase confirmations get scanned for return windows and warranties automatically. Reads receipt emails only - nothing is sent anywhere, parsing happens entirely on this device.")
                        .font(.caption)
                        .foregroundStyle(Theme.textDim)
                }
                .padding(.vertical, 4)

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
            } else if oauth.isConnected {
                Label("Gmail connected", systemImage: "checkmark.seal")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.textPrimary)

                Button {
                    scan()
                } label: {
                    HStack {
                        Text("Scan for new purchases")
                        if isWorking {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isWorking)

                Button("Disconnect Gmail", role: .destructive) {
                    oauth.disconnect()
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Automatic tracking")
                            .font(.body.weight(.medium))
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text("Beta")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Theme.accent.opacity(0.15))
                            .foregroundStyle(Theme.accent)
                            .clipShape(Capsule())
                    }
                    Text("Connect your Gmail so purchase confirmations get scanned for return windows and warranties automatically. Reads receipt emails only - nothing is sent anywhere, parsing happens entirely on this device.")
                        .font(.caption)
                        .foregroundStyle(Theme.textDim)
                }
                .padding(.vertical, 4)

                Button {
                    connect()
                } label: {
                    HStack {
                        Text("Connect Gmail")
                        if isWorking {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isWorking)
            }
        } header: {
            Theme.sectionHeader("Automatic tracking")
        } footer: {
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(Theme.accent)
            }
        }
        .listRowBackground(Theme.panel)
        .sheet(isPresented: $isShowingReview) {
            DetectedPurchaseReviewView(purchases: detectedPurchases) { accepted in
                for purchase in accepted {
                    itemStore.add(purchase.asTrackedItem())
                }
            }
        }
    }

    private func purchase() {
        errorMessage = nil
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                try await purchases.purchase()
            } catch PurchaseService.PurchaseError.userCancelled {
                // Cancelling isn't a failure - leave the paywall state
                // exactly as it was, with no error shown.
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func connect() {
        errorMessage = nil
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                try await oauth.connect()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Looks back six months - long enough to catch most active return
    /// windows and recent warranties without turning a scan into a
    /// full-inbox crawl every time someone taps the button.
    private func scan() {
        errorMessage = nil
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                let client = GmailAPIClient()
                let alreadyImported = Set(itemStore.items.compactMap(\.importedFromGmailMessageID))
                let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
                let ids = try await client.listMessages(query: PurchaseEmailParser.searchQuery(after: sixMonthsAgo))

                var found: [DetectedPurchase] = []
                for id in ids where !alreadyImported.contains(id) {
                    guard let message = try? await client.fetchMessage(id: id),
                          let purchase = PurchaseEmailParser.parse(message)
                    else { continue }
                    found.append(purchase)
                }

                if found.isEmpty {
                    errorMessage = "No new purchases found in the last 6 months."
                } else {
                    detectedPurchases = found
                    isShowingReview = true
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private extension DetectedPurchase {
    /// Maps a scanned purchase into the same TrackedItem shape a person
    /// would get from adding one by hand - a return-window deadline
    /// defaulted to 30 days from the purchase date, no warranty guess
    /// (the parser has no reliable way to know a retailer's warranty
    /// length), and importedFromGmailMessageID set so a re-scan never
    /// re-surfaces the same email as a duplicate "new" purchase.
    func asTrackedItem() -> TrackedItem {
        TrackedItem(
            name: itemName,
            retailer: retailer,
            purchaseDate: purchaseDate,
            priceCents: priceCents,
            deadlines: [
                TrackedDeadline(
                    kind: .returnWindow,
                    date: Calendar.current.date(byAdding: .day, value: 30, to: purchaseDate) ?? purchaseDate
                )
            ],
            importedFromGmailMessageID: id
        )
    }
}

#Preview {
    List {
        GmailConnectSection()
    }
    .environmentObject(ItemStore())
}
