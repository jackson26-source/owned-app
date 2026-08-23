import SwiftUI

struct ContentView: View {
      var body: some View {
                TabView {
                              ItemListView()
                                  .tabItem {
                                                        Label("Items", systemImage: "shippingbox")
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
