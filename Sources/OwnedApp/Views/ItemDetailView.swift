import SwiftUI

struct ItemDetailView: View {
      let item: TrackedItem
      @EnvironmentObject private var itemStore: ItemStore
      @State private var receiptImage: UIImage?

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

                              if !item.notes.isEmpty {
                                                Section("Notes") {
                                                                      Text(item.notes)
                                                }
                              }
                }
                .navigationTitle(item.name)
                .task {
                              if let filename = item.receiptPhotoFilename {
                                                receiptImage = PhotoStorage.load(filename: filename)
                              }
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
