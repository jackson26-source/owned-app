import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var itemStore: ItemStore
    @State private var selectedTab = 0

    init() {
        Theme.applyAppearance()
    }

    var body: some View {
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
        // Was a plain VStack wrapping the TabView, with the strip as a
        // sibling above it. That fought each tab's own NavigationStack
        // for the top safe area and was the actual source of the extra
        // blank gap under the strip — safeAreaInset is the SwiftUI-native
        // way to pin persistent chrome above tab content without that
        // conflict.
        .safeAreaInset(edge: .top) {
            if let entry = mostUrgentEntry {
                UrgentItemStrip(item: entry.item, deadline: entry.deadline) {
                    selectedTab = 0
                }
            }
        }
        .task {
            NotificationService.shared.scheduleWeeklyDigest(for: itemStore.items)
        }
        .onChange(of: itemStore.items) { _, newItems in
            NotificationService.shared.scheduleWeeklyDigest(for: newItems)
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
