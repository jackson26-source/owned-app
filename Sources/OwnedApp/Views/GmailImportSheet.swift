import SwiftUI

/// Reuses `GmailConnectSection` as-is (same paywall/connect/scan states it
/// already handles in Settings) rather than re-implementing the Gmail flow
/// at every call site. This sheet just gives that section its own modal
/// home so "Add from Gmail" is reachable from wherever it needs to live —
/// the Items toolbar's Add menu, and the empty states on Items, Timeline,
/// and Dashboard — without three or four separate copies of the same
/// connect/scan/paywall logic. Factored out of `ItemListView` (which used
/// to define this inline as a private computed property) once a second and
/// third call site needed the identical sheet.
struct GmailImportSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                GmailConnectSection()
            }
            .listRowSeparatorTint(Theme.border)
            .themedScrollBackground()
            .navigationTitle("Add from Gmail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
