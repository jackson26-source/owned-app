import SwiftUI

struct SettingsView: View {
    @ObservedObject private var purchases = PurchaseService.shared
    @State private var isRestoring = false
    @State private var restoreError: String?

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
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")

                    Button {
                        restore()
                    } label: {
                        HStack {
                            Text("Restore Purchases")
                            if isRestoring {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isRestoring)
                } header: {
                    Theme.sectionHeader("About")
                } footer: {
                    if let restoreError {
                        Text(restoreError)
                            .foregroundStyle(Theme.accent)
                    }
                }
                .listRowBackground(Theme.panel)
            }
            .listRowSeparatorTint(Theme.border)
            .themedScrollBackground()
            .navigationTitle("Settings")
        }
    }

    private func restore() {
        restoreError = nil
        isRestoring = true
        Task {
            defer { isRestoring = false }
            do {
                try await purchases.restore()
            } catch {
                restoreError = error.localizedDescription
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(ItemStore())
}
