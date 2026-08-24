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

                Section {
                    ComingSoonRow(
                        title: "Automatic tracking",
                        detail: "Connect your email so purchases, shipping, and returns get logged without typing anything in — a paid feature, since it costs real ongoing work to keep accurate across retailers."
                    )
                } header: {
                    Theme.sectionHeader("Coming later")
                }
                .listRowBackground(Theme.panel)

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

private struct ComingSoonRow: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("Soon")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.accent.opacity(0.15))
                    .foregroundStyle(Theme.accent)
                    .clipShape(Capsule())
            }
            Text(detail)
                .font(.caption)
                .foregroundStyle(Theme.textDim)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SettingsView()
}
