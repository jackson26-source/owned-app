import SwiftUI

struct ItemListView: View {
      @EnvironmentObject private var itemStore: ItemStore
      @State private var isPresentingAddItem = false

      var body: some View {
                NavigationStack {
                              Group {
                                                if itemStore.items.isEmpty {
                                                                      emptyState
                                                } else {
                                                                      List {
                                                                                                ForEach(itemStore.sortedByUrgency) { item in
                                                                                                                                                                NavigationLink(value: item.id) {
                                                                                                                                                                                                  row(for: item)
                                                                                                                                                                }
                                                                                                                                   }
                                                                                                .onDelete { offsets in
                                                                                                                                       let idsToDelete = offsets.map { itemStore.sortedByUrgency[$0].id }
                                                                                                                                       for id in idsToDelete {
                                                                                                                                                                         if let item = itemStore.items.first(where: { $0.id == id }) {
                                                                                                                                                                                                               NotificationService.shared.cancelReminders(for: item)
                                                                                                                                                                                                               itemStore.delete(item)
                                                                                                                                                                                                           }
                                                                                                                                       }
                                                                                                          }
                                                                      }
                                                }
                              }
                              .navigationTitle("Owned")
                              .navigationDestination(for: UUID.self) { itemID in
                                                                                      if let item = itemStore.items.first(where: { $0.id == itemID }) {
                                                                                                            ItemDetailView(item: item)
                                                                                      }
                                                                     }
                              .toolbar {
                                                ToolbarItem(placement: .primaryAction) {
                                                                      Button {
                                                                                                isPresentingAddItem = true
                                                                      } label: {
                                                                                                Label("Add", systemImage: "plus")
                                                                      }
                                                }
                              }
                              .sheet(isPresented: $isPresentingAddItem) {
                                                AddItemView()
                              }
                }
      }

      private var emptyState: some View {
                ContentUnavailableView {
                              Label("Nothing tracked yet", systemImage: "shippingbox")
                } description: {
                              Text("Add a purchase to track its return window or warranty.")
                } actions: {
                              Button("Add a purchase") {
                                                isPresentingAddItem = true
                              }
                }
      }

      private func row(for item: TrackedItem) -> some View {
                HStack {
                              VStack(alignment: .leading, spacing: 4) {
                                                Text(item.name)
                                                    .font(.body.weight(.medium))
                                                HStack(spacing: 6) {
                                                                      Text(item.retailer)
                                                                      if let price = item.priceDisplay {
                                                                                                Text("·")
                                                                                                Text(price)
                                                                      }
                                                }
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                              }

                              Spacer()

                              StatusBadge(deadline: item.soonestDeadline)
                }
                .padding(.vertical, 4)
      }
}

#Preview {
      let store = ItemStore()
      return ItemListView()
          .environmentObject(store)
}
