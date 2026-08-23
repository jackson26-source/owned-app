import SwiftUI

struct SettingsView: View {
      var body: some View {
                NavigationStack {
                              List {
                                                Section {
                                                                      Label("Everything in Owned stays on this device.", systemImage: "lock.shield")
                                                                          .font(.subheadline)
                                                } footer: {
                                                                      Text("No account, no cloud sync, nothing sent anywhere. Deleting the app deletes your data — there's nothing to recover from a server, because there isn't one.")
                                                }

                                                Section("Coming later") {
                                                                      ComingSoonRow(
                                                                                                title: "Automatic tracking",
                                                                                                detail: "Connect your email so purchases, shipping, and returns get logged without typing anything in — a paid feature, since it costs real ongoing work to keep accurate across retailers."
                                                                      )
                                                }

                                                Section("About") {
                                                                      LabeledContent("Version", value: "0.1.0")
                                                }
                              }
                              .navigationTitle("Settings")
                }
      }
}

private struct ComingSoonRow: View {
      let title: String
      let detail: String

      var body: some View {
                VStack(alignment: .leading, spacing: 4) {
                              HStack {
                                                Text(title)
                                                    .font(.body.weight(.medium))
                                                Spacer()
                                                Text("Soon")
                                                    .font(.caption2.weight(.semibold))
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 3)
                                                    .background(Color.secondary.opacity(0.15))
                                                    .clipShape(Capsule())
                              }
                              Text(detail)
                                  .font(.caption)
                                  .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
      }
}

#Preview {
      SettingsView()
}
