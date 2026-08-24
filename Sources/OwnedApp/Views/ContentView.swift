import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var itemStore: ItemStore

    var body: some View {
        TabView {
            ItemListView()
                .tabItem {
                    Label("Items", systemImage: "shippingbox")
                }

            TimelineView()
                .tabItem {
                    Label("Timeline", systemImage: "calendar")
                }

            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .task {
            NotificationService.shared.scheduleWeeklyDigest(for: itemStore.items)
        }
        .onChange(of: itemStore.items) { _, newItems in
            NotificationService.shared.scheduleWeeklyDigest(for: newItems)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ItemStore())
}
