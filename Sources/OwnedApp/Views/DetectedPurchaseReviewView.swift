import SwiftUI

/// The review sheet a Gmail scan opens with - one row per detected
/// purchase, letting the person accept or skip each one individually
/// before anything is written into ItemStore. Nothing is saved
/// automatically: a parser built from regexes over inconsistent retailer
/// HTML will sometimes get it wrong, and this is where a person catches
/// that rather than the item list quietly filling with bad data.
struct DetectedPurchaseReviewView: View {
    let purchases: [DetectedPurchase]
    let onAccept: ([DetectedPurchase]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var accepted: Set<String>

    init(purchases: [DetectedPurchase], onAccept: @escaping ([DetectedPurchase]) -> Void) {
        self.purchases = purchases
        self.onAccept = onAccept
        // Pre-select every confident match; low-confidence item names
        // (subject-line fallbacks) start unchecked so a person has to
        // actively confirm them instead of accidentally importing a
        // guess.
        _accepted = State(initialValue: Set(purchases.filter(\.itemNameIsConfident).map(\.id)))
    }

    var body: some View {
        NavigationStack {
            List(purchases) { purchase in
                Button {
                    toggle(purchase)
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: accepted.contains(purchase.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(accepted.contains(purchase.id) ? Theme.accent : Theme.textFaint)
                            .font(.title3)
                            .padding(.top, 2)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(purchase.itemName)
                                .font(.body.weight(.medium))
                                .foregroundStyle(Theme.textPrimary)

                            if !purchase.itemNameIsConfident {
                                // Was a small gray "check this" capsule -
                                // easy to miss, which is exactly how a
                                // parser fallback like "ed 1 item:
                                // Electronics" got through to a real
                                // device. This needs to actually stop a
                                // person, not just hint.
                                Label("Couldn't read a real item name — check before adding", systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.danger)
                            }

                            Text(purchase.retailer)
                                .font(.caption)
                                .foregroundStyle(Theme.textDim)
                            if let priceCents = purchase.priceCents {
                                Text(Self.priceFormatter.string(from: NSNumber(value: Double(priceCents) / 100.0)) ?? "")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textFaint)
                            }
                        }
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .listRowBackground(Theme.panel)
                .overlay(alignment: .leading) {
                    if !purchase.itemNameIsConfident {
                        Rectangle()
                            .fill(Theme.danger)
                            .frame(width: 3)
                    }
                }
            }
            .themedScrollBackground()
            .navigationTitle("Review purchases")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add \(accepted.count)") {
                        onAccept(purchases.filter { accepted.contains($0.id) })
                        dismiss()
                    }
                    .disabled(accepted.isEmpty)
                }
            }
        }
    }

    private func toggle(_ purchase: DetectedPurchase) {
        if accepted.contains(purchase.id) {
            accepted.remove(purchase.id)
        } else {
            accepted.insert(purchase.id)
        }
    }

    private static let priceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return formatter
    }()
}

#Preview {
    DetectedPurchaseReviewView(
        purchases: [
            DetectedPurchase(id: "1", itemName: "Wireless Mouse", retailer: "Amazon", purchaseDate: Date(), priceCents: 2999, orderNumber: "123-4567890-1234567", itemNameIsConfident: true),
            DetectedPurchase(id: "2", itemName: "Order confirmation", retailer: "Online store", purchaseDate: Date(), priceCents: 5499, orderNumber: "88213", itemNameIsConfident: false)
        ],
        onAccept: { _ in }
    )
}
