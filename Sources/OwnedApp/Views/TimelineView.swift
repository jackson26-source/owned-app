import SwiftUI

private struct DeadlineEntry: Identifiable {
    let item: TrackedItem
    let deadline: TrackedDeadline
    var id: UUID { deadline.id }
}

struct TimelineView: View {
    @EnvironmentObject private var itemStore: ItemStore
    @State private var includeExpired = false

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView {
                        Label("Nothing on the clock", systemImage: "calendar")
                    } description: {
                        Text(includeExpired ? "No deadlines tracked yet." : "No upcoming deadlines. Toggle \u{201C}Show expired\u{201D} to see past ones.")
                    }
                } else {
                    List(entries) { entry in
                        NavigationLink(value: entry.item.id) {
                            row(for: entry)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Timeline")
            .navigationDestination(for: UUID.self) { itemID in
                if let item = itemStore.items.first(where: { $0.id == itemID }) {
                    ItemDetailView(item: item)
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        includeExpired.toggle()
                    } label: {
                        Label(includeExpired ? "Hide expired" : "Show expired", systemImage: includeExpired ? "eye.slash" : "eye")
                    }
                }
            }
        }
    }

    private var entries: [DeadlineEntry] {
        itemStore.items
            .flatMap { item in item.deadlines.map { DeadlineEntry(item: item, deadline: $0) } }
            .filter { includeExpired || $0.deadline.status() != .expired }
            .sorted { $0.deadline.date < $1.deadline.date }
    }

    private func row(for entry: DeadlineEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(relativeLabel(for: entry.deadline.date))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(colorForStatus(entry.deadline.status()))
                Text(entry.item.name)
                    .font(.body.weight(.medium))
                Text("\(entry.deadline.kind.label) · \(entry.item.retailer)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let price = entry.item.priceDisplay {
                Text(price)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func relativeLabel(for date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: date)).day ?? 0
        switch days {
        case ..<0: return "Expired"
        case 0: return "Today"
        case 1: return "Tomorrow"
        default: return "In \(days) days"
        }
    }

    private func colorForStatus(_ status: ItemStatus) -> Color {
        switch status {
        case .active: return .secondary
        case .expiringSoon: return .orange
        case .expired: return .secondary
        }
    }
}

#Preview {
    TimelineView()
        .environmentObject(ItemStore())
}
