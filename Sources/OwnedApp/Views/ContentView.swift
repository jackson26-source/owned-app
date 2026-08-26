import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var itemStore: ItemStore
    @State private var selectedTab = 0

    init() {
        Theme.applyAppearance()
    }

    var body: some View {
        VStack(spacing: 0) {
            if let entry = mostUrgentEntry {
                UrgentItemStrip(item: entry.item, deadline: entry.deadline) {
                    selectedTab = 0
                }
            }

            TabView(selection: $selectedTab) {
                ItemListView()
                    .tabItem {
                        Label("Items", systemImage: "shippingbox")
                    }
                    .tag(0)

                TimelineView()
                    .tabItem {
                        Label("Timeline", systemImage: "calendar")
                    }
                    .tag(1)

                DashboardView()
                    .tabItem {
                        Label("Dashboard", systemImage: "chart.bar")
                    }
                    .tag(2)

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .tag(3)
            }
            .tint(Theme.accent)
            .task {
                NotificationService.shared.scheduleWeeklyDigest(for: itemStore.items)
            }
            .onChange(of: itemStore.items) { _, newItems in
                NotificationService.shared.scheduleWeeklyDigest(for: newItems)
            }
        }
    }

    /// The single closest, not-yet-expired deadline across every tracked
    /// item — this is what the persistent strip surfaces above the tab
    /// bar. Expired deadlines are excluded: once something's window has
    /// already closed there's nothing actionable left to surface here,
    /// and a resolved item drops out entirely.
    private var mostUrgentEntry: (item: TrackedItem, deadline: TrackedDeadline)? {
        itemStore.items
            .filter { $0.resolvedAt == nil }
            .flatMap { item in item.deadlines.map { (item: item, deadline: $0) } }
            .filter { $0.deadline.status() != .expired }
            .min { $0.deadline.date < $1.deadline.date }
    }
}

#Preview {
    ContentView()
        .environmentObject(ItemStore())
}
