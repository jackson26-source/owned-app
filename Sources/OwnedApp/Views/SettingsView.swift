import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Everything in Owned stays on this device.", systemImage: "lock.shield")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textPrimary)
                } footer: {
                    Text("No account, no cloud sync, nothing sent anywhere. Deleting the app deletes your data — there's nothing to recover from a server, because there isn't one.")
                        .foregroundStyle(Theme.textFaint)
                }
                .listRowBackground(Theme.panel)

                GmailConnectSection()

                Section {
                    LabeledContent("Version", value: "0.1.0")
                } header: {
                    Theme.sectionHeader("About")
                }
                .listRowBackground(Theme.panel)
            }
            .listRowSeparatorTint(Theme.border)
            .themedScrollBackground()
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(ItemStore())
}
