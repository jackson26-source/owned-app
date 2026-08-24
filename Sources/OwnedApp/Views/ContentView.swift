import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            ItemListView()
                .tabItem {
                    Label("Items", systemImage: "shippingbox")
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
    }
}

#Preview {
    ContentView()
        .environmentObject(ItemStore())
}
