import SwiftUI

private struct DeadlineEntry: Identifiable {
    let item: TrackedItem
    let deadline: TrackedDeadline
    var id: UUID { deadline.id }
}

struct TimelineView: View {
    @EnvironmentObject private var itemStore: ItemStore
    @State private var includeExpired = false
    @State private var isPresentingAddItem = false
    @State private var isPresentingGmailImport = false

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    EmptyStateView(
                        icon: "calendar",
                        title: "Nothing on the clock",
                        message: includeExpired ? "No deadlines tracked yet." : "No upcoming deadlines. Toggle \u{201C}Show expired\u{201D} to see past ones.",
                        actionTitle: itemStore.items.isEmpty ? "Add a purchase" : nil,
                        action: itemStore.items.isEmpty ? { isPresentingAddItem = true } : nil,
                        secondaryActionTitle: itemStore.items.isEmpty ? "Add from Gmail" : nil,
                        secondaryAction: itemStore.items.isEmpty ? { isPresentingGmailImport = true } : nil
                    )
                } else {
                    List(entries) { entry in
                        NavigationLink(value: entry.item.id) {
                            row(for: entry)
                        }
                        .listRowBackground(Theme.panel)
                    }
                    .listStyle(.plain)
                    .listRowSeparatorTint(Theme.border)
                    .themedScrollBackground()
                    .monospacedDigit()
                }
            }
            .background(Theme.background)
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
            .sheet(isPresented: $isPresentingAddItem) {
                AddItemView()
            }
            .sheet(isPresented: $isPresentingGmailImport) {
                GmailImportSheet()
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
                    .font(Theme.eyebrow(11))
                    .foregroundStyle(colorForStatus(entry.deadline.status()))
                Text(entry.item.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.textPrimary)
                Text("\(entry.deadline.kind.label) · \(entry.item.retailer)")
                    .font(.caption)
                    .foregroundStyle(Theme.textDim)
            }
            Spacer()
            if let price = entry.item.priceDisplay {
                Text(price)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.textDim)
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

    /// Functional, not decorative, matching `StatusBadge`'s convention:
    /// active is safe-green, expiring-soon gets `Theme.warning`'s "pay
    /// attention" gold, and expired gets danger-red — the same
    /// three-way scale used everywhere else in the app (StatusBadge,
    /// DashboardView) so urgency reads identically on every tab
    /// instead of each screen inventing its own color language. Uses
    /// `Theme.warning` rather than `Theme.accent` so this status color
    /// stays fixed even as the brand accent changes — `accent` and
    /// `success` are the same green now, and `expiringSoon` needs a
    /// color that's neither of those.
    private func colorForStatus(_ status: ItemStatus) -> Color {
        switch status {
        case .active: return Theme.success
        case .expiringSoon: return Theme.warning
        case .expired: return Theme.danger
        }
    }
}

#Preview {
    TimelineView()
        .environmentObject(ItemStore())
}
