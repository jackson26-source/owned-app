import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var itemStore: ItemStore
    @State private var isPresentingAddItem = false

    var body: some View {
        NavigationStack {
            Group {
                if itemStore.items.isEmpty {
                    EmptyStateView(
                        icon: "chart.bar",
                        title: "Nothing to show yet",
                        message: "Add a purchase to see your tracking stats here.",
                        actionTitle: "Add a purchase",
                        action: { isPresentingAddItem = true }
                    )
                } else {
                    List {
                        Section {
                            heroStat
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)

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

                        if lifetimeProtectedCount > 0 {
                            Section("Lifetime") {
                                statRow(label: "Returns and claims resolved", value: "\(lifetimeProtectedCount)")
                                if let lifetimeProtectedValue {
                                    statRow(label: "Money protected", value: lifetimeProtectedValue)
                                }
                            }
                        }
                    }
                    .monospacedDigit()
                }
            }
            .navigationTitle("Dashboard")
            .sheet(isPresented: $isPresentingAddItem) {
                AddItemView()
            }
        }
    }

    // MARK: - Hero

    /// The headline stat at the top of the dashboard: how much money is
    /// currently sitting inside an open return window or active warranty
    /// — the thing Owned exists to protect, front and center rather than
    /// buried in a list row like every other number here. Styled after
    /// the marketing site's own hero treatment: a small monospace
    /// eyebrow label over a large double-struck serif number in the
    /// accent color, set on a bordered panel card — the one figure in
    /// the app that earns the double-strike ink treatment.
    private var heroStat: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PROTECTED RIGHT NOW")
                .font(Theme.eyebrow())
                .tracking(0.6)
                .foregroundStyle(Theme.textFaint)
            Theme.DoubleStrikeText(
                text: protectedValueDisplay ?? "$0",
                font: Theme.serif(44),
                color: Theme.accent
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Theme.panel)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Stats

    /// Sum of every item's price, formatted as currency — nil (and hidden)
    /// when nobody has entered a price for anything yet, since "$0.00"
    /// would read as a real total rather than "no data."
    private var totalValue: String? {
        let cents = itemStore.items.compactMap(\.priceCents).reduce(0, +)
        guard cents > 0 else { return nil }
        return currency(cents)
    }

    /// Sum of priceCents for items that haven't expired yet — this is the
    /// value still "protected" by an open return window or active
    /// warranty, as opposed to totalValue, which counts everything ever
    /// tracked regardless of whether its clock has already run out.
    private var protectedValue: Int {
        itemStore.items
            .filter { $0.overallStatus != .expired }
            .compactMap(\.priceCents)
            .reduce(0, +)
    }

    private var protectedValueDisplay: String? {
        guard protectedValue > 0 else { return nil }
        return currency(protectedValue)
    }

    /// How many items someone has actually confirmed as returned or
    /// successfully claimed under warranty — the "Lifetime" section only
    /// appears once this is above zero, so an app with no resolved items
    /// yet doesn't show an empty, premature stat block.
    private var lifetimeProtectedCount: Int {
        itemStore.items.filter { $0.resolvedAt != nil }.count
    }

    private var lifetimeProtectedValue: String? {
        let cents = itemStore.items
            .filter { $0.resolvedAt != nil }
            .compactMap(\.priceCents)
            .reduce(0, +)
        guard cents > 0 else { return nil }
        return currency(cents)
    }

    private var categoryBreakdown: [(category: ItemCategory, count: Int)] {
        let grouped = Dictionary(grouping: itemStore.items.compactMap { item in
            item.category.map { (category: $0, item: item) }
        }, by: { $0.category })
        return grouped.map { (category: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    /// Shared currency formatter used by every dollar figure on this
    /// screen, so the hero stat and the list rows below it always agree
    /// on locale and formatting.
    private func currency(_ cents: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return formatter.string(from: NSNumber(value: Double(cents) / 100.0)) ?? "$0"
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

    /// Functional, not decorative — matches `StatusBadge`'s own color
    /// convention exactly: green only ever means "active and fine,"
    /// accent means "needs attention soon," and this expired row is the
    /// one place danger-red actually belongs, not the faded grey it used
    /// to share with "nothing to see here."
    var color: Color {
        switch self {
        case .active: return Theme.success
        case .expiringSoon: return Theme.accent
        case .expired: return Theme.danger
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
