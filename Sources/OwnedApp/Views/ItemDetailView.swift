import SwiftUI

struct ItemDetailView: View {
    let item: TrackedItem
    @EnvironmentObject private var itemStore: ItemStore
    @State private var receiptImage: UIImage?
    @State private var category: ItemCategory?
    @State private var claimPackURL: URL?
    @State private var resolvedAt: Date?

    var body: some View {
        List {
            Section {
                if let receiptImage {
                    Image(uiImage: receiptImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 240)
                        .frame(maxWidth: .infinity)
                }
                LabeledContent("Retailer", value: item.retailer.isEmpty ? "—" : item.retailer)
                LabeledContent("Purchased", value: item.purchaseDate.formatted(date: .abbreviated, time: .omitted))
                if let price = item.priceDisplay {
                    LabeledContent("Price", value: price)
                }
                Picker("Category", selection: $category) {
                    Text("Uncategorized").tag(ItemCategory?.none)
                    ForEach(ItemCategory.allCases) { option in
                        Label(option.label, systemImage: option.systemImage).tag(ItemCategory?.some(option))
                    }
                }
            }

            Section("Deadlines") {
                if item.deadlines.isEmpty {
                    Text("No return window or warranty tracked for this item.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(item.deadlines.sorted(by: { $0.date < $1.date })) { deadline in
                        deadlineRow(deadline)
                    }
                }
            }

            Section("Outcome") {
                if let resolvedAt {
                    Label {
                        Text("Returned or claimed on \(resolvedAt.formatted(date: .abbreviated, time: .omitted))")
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    Button("Undo", role: .destructive) {
                        markResolved(nil)
                    }
                } else {
                    Button("Mark as returned or claimed") {
                        markResolved(Date())
                    }
                }
            }

            if !item.notes.isEmpty {
                Section("Notes") {
                    Text(item.notes)
                }
            }

            Section {
                if let claimPackURL {
                    ShareLink(item: claimPackURL) {
                        Label("Share claim pack (PDF)", systemImage: "doc.richtext")
                    }
                } else {
                    Label("Preparing claim pack…", systemImage: "doc.richtext")
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("Bundles this item's details, deadlines, and receipt photo into a PDF you can attach to a return or warranty claim.")
            }
        }
        .navigationTitle(item.name)
        .task {
            if let filename = item.receiptPhotoFilename {
                receiptImage = PhotoStorage.load(filename: filename)
            }
            category = item.category
            resolvedAt = item.resolvedAt
            prepareClaimPack()
        }
        .onChange(of: category) { _, newValue in
            guard newValue != item.category else { return }
            var updated = item
            updated.category = newValue
            itemStore.update(updated)
        }
    }

    private func deadlineRow(_ deadline: TrackedDeadline) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(deadline.kind.label)
                        .font(.body.weight(.medium))
                    Text(deadline.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                StatusBadge(deadline: deadline)
            }

            if deadline.status() != .expired {
                Button {
                    addToWallet(deadline)
                } label: {
                    Label("Add to Wallet", systemImage: "wallet.pass")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 2)
    }

    private func addToWallet(_ deadline: TrackedDeadline) {
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return }
        WalletPassService.shared.presentAddPass(for: item, deadline: deadline, from: root)
        itemStore.markWalletPassAdded(itemID: item.id, deadlineID: deadline.id)
    }

    private func markResolved(_ date: Date?) {
        var updated = item
        updated.resolvedAt = date
        itemStore.update(updated)
        resolvedAt = date
    }

    private func prepareClaimPack() {
        let data = ClaimPackGenerator.makePDF(for: item, receiptImage: receiptImage)
        let safeName = item.name.replacingOccurrences(of: "/", with: "-")
        let filename = safeName.isEmpty ? "claim-pack.pdf" : "\(safeName)-claim-pack.pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            claimPackURL = url
        } catch {
            claimPackURL = nil
        }
    }
}

#Preview {
    NavigationStack {
        ItemDetailView(item: TrackedItem(
            name: "Sony WH-1000XM5",
            retailer: "Best Buy",
            purchaseDate: Date(),
            priceCents: 34_800,
            deadlines: [
                TrackedDeadline(kind: .returnWindow, date: Calendar.current.date(byAdding: .day, value: 12, to: Date())!),
                TrackedDeadline(kind: .warranty, date: Calendar.current.date(byAdding: .year, value: 1, to: Date())!)
            ]
        ))
        .environmentObject(ItemStore())
    }
}
