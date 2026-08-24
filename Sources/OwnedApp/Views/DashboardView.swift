import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var itemStore: ItemStore

    var body: some View {
        NavigationStack {
            Group {
                if itemStore.items.isEmpty {
                    ContentUnavailableView {
                        Label("Nothing to show yet", systemImage: "chart.bar")
                    } description: {
                        Text("Add a purchase to see your tracking stats here.")
                    }
                } else {
                    List {
                        Section {
                            statRow(label: "Tracked purchases", value: "\(itemStore.items.count)")
                            if let totalValue {
                                statRow(label: "Total value", value: totalValue)
                            }
                        }

                        Section("By status") {
                            ForEach(StatusSummary.allCases) { status in
                                statusRow(status)
                            }
                        }

                        if !categoryBreakdown.isEmpty {
                            Section("By category") {
                                ForEach(categoryBreakdown, id: \.category) { entry in
                                    categoryRow(entry)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Dashboard")
        }
    }

    // MARK: - Stats

    /// Sum of every item's price, formatted as currency — nil (and hidden)
    /// when nobody has entered a price for anything yet, since "$0.00"
    /// would read as a real total rather than "no data."
    private var totalValue: String? {
        let cents = itemStore.items.compactMap(\.priceCents).reduce(0, +)
        guard cents > 0 else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return formatter.string(from: NSNumber(value: Double(cents) / 100.0))
    }

    private var categoryBreakdown: [(category: ItemCategory, count: Int)] {
        let grouped = Dictionary(grouping: itemStore.items.compactMap { item in
            item.category.map { (category: $0, item: item) }
        }, by: { $0.category })
        return grouped.map { (category: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    private func statusRow(_ status: StatusSummary) -> some View {
        let count = itemStore.items.filter { status.matches($0.overallStatus) }.count
        return HStack {
            Label(status.label, systemImage: status.systemImage)
                .foregroundStyle(status.color)
            Spacer()
            Text("\(count)")
                .foregroundStyle(.secondary)
        }
    }

    private func categoryRow(_ entry: (category: ItemCategory, count: Int)) -> some View {
        HStack {
            Label(entry.category.label, systemImage: entry.category.systemImage)
            Spacer()
            Text("\(entry.count)")
                .foregroundStyle(.secondary)
        }
    }
}

// Deliberately separate from the model-level ItemStatus type — this is a
// fixed, always-three-rows display concept for the dashboard, not a
// per-item state, so it gets its own tiny enum rather than overloading
// ItemStatus with UI concerns.
private enum StatusSummary: CaseIterable, Identifiable {
    case active
    case expiringSoon
    case expired

    var id: Self { self }

    var label: String {
        switch self {
        case .active: return "Active"
        case .expiringSoon: return "Expiring soon"
        case .expired: return "Expired"
        }
    }

    var systemImage: String {
        switch self {
        case .active: return "checkmark.circle"
        case .expiringSoon: return "clock.badge.exclamationmark"
        case .expired: return "xmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .active: return .green
        case .expiringSoon: return .orange
        case .expired: return .secondary
        }
    }

    func matches(_ status: ItemStatus) -> Bool {
        switch (self, status) {
        case (.active, .active): return true
        case (.expiringSoon, .expiringSoon): return true
        case (.expired, .expired): return true
        default: return false
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(ItemStore())
}
