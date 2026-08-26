import SwiftUI

struct ItemDetailView: View {
    let item: TrackedItem
    @EnvironmentObject private var itemStore: ItemStore
    @State private var receiptImage: UIImage?
    @State private var category: ItemCategory?
    @State private var claimPackURL: URL?
    @State private var resolvedAt: Date?
    @State private var showResolvedToast = false

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
            .listRowBackground(Theme.panel)

            Section {
                if item.deadlines.isEmpty {
                    Text("No return window or warranty tracked for this item.")
                        .foregroundStyle(Theme.textDim)
                } else {
                    ForEach(item.deadlines.sorted(by: { $0.date < $1.date })) { deadline in
                        deadlineRow(deadline)
                    }
                }
            } header: {
                Theme.sectionHeader("Deadlines")
            }
            .listRowBackground(Theme.panel)

            Section {
                if let resolvedAt {
                    HStack {
                        Label {
                            Text("Returned or claimed on \(resolvedAt.formatted(date: .abbreviated, time: .omitted))")
                                .foregroundStyle(Theme.textPrimary)
                        } icon: {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.success)
                        }
                        Spacer()
                        Theme.StampBadge(text: "Resolved", color: Theme.success, rotation: -8)
                    }
                    Button("Undo", role: .destructive) {
                        markResolved(nil)
                    }
                } else {
                    TearToResolveButton {
                        markResolved(Date())
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            } header: {
                Theme.sectionHeader("Outcome")
            }
            .listRowBackground(Theme.panel)

            if !item.notes.isEmpty {
                Section {
                    Text(item.notes)
                        .foregroundStyle(Theme.textPrimary)
                } header: {
                    Theme.sectionHeader("Notes")
                }
                .listRowBackground(Theme.panel)
            }

            Section {
                if let claimPackURL {
                    ShareLink(item: claimPackURL) {
                        Label("Share claim pack (PDF)", systemImage: "doc.richtext")
                    }
                    .foregroundStyle(Theme.accent)
                } else {
                    Label("Preparing claim pack…", systemImage: "doc.richtext")
                        .foregroundStyle(Theme.textDim)
                }

                ShareLink(item: claimMessage) {
                    Label("Share claim message", systemImage: "text.bubble")
                }
                .foregroundStyle(Theme.accent)
            } footer: {
                Text("The claim pack bundles this item's details, deadlines, and receipt photo into a PDF. The claim message is a ready-to-send draft — fill in the blank and attach the pack.")
                    .foregroundStyle(Theme.textFaint)
            }
            .listRowBackground(Theme.panel)
        }
        .listRowSeparatorTint(Theme.border)
        .themedScrollBackground()
        .monospacedDigit()
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
        .overlay(alignment: .bottom) {
            if showResolvedToast {
                resolvedToast
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    /// The confirmation that appears for a few seconds right after tearing
    /// an item to resolve it — the list used to just silently reorder,
    /// which gave the single most satisfying moment in the app (you just
    /// protected yourself from losing money) no acknowledgment at all.
    /// Naming the actual dollar figure is the point: it's the concrete
    /// payoff for having tracked this thing in the first place.
    private var resolvedToast: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(Theme.success)
            Text(resolvedToastMessage)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.panel)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        .padding(.horizontal, 20)
    }

    private var resolvedToastMessage: String {
        if let price = item.priceDisplay {
            return "You just avoided losing \(price)"
        }
        return "Nice — marked as resolved"
    }

    /// A ready-to-send return or warranty request, pre-filled with
    /// everything Owned already knows about this item — see
    /// ClaimPackGenerator.makeClaimMessage for why this exists as its own
    /// share action alongside the PDF claim pack rather than folding into it.
    private var claimMessage: String {
        ClaimPackGenerator.makeClaimMessage(for: item, deadline: item.soonestDeadline)
    }

    private func deadlineRow(_ deadline: TrackedDeadline) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(deadline.kind.label)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Theme.textPrimary)
                    Text(deadline.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(Theme.textDim)
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
                .buttonStyle(.pillOutline)
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

        guard date != nil else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showResolvedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                showResolvedToast = false
            }
        }
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
