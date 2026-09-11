import SwiftUI

/// The small colored pill that makes an item's urgency legible at a
/// glance in the list — no need to open the item to know if it needs
/// attention today. An expired deadline gets a rubber-stamp treatment
/// instead of a plain pill — the one state final enough to earn it.
struct StatusBadge: View {
    let deadline: TrackedDeadline?

    var body: some View {
        if let deadline {
            let status = deadline.status()
            let days = deadline.daysRemaining()

            if status == .expired {
                Theme.StampBadge(text: label(status: status, days: days), color: Theme.danger)
            } else {
                Text(label(status: status, days: days))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(color(for: status).opacity(0.16))
                    .foregroundStyle(color(for: status))
                    .clipShape(Capsule())
            }
        } else {
            EmptyView()
        }
    }

    private func label(status: ItemStatus, days: Int) -> String {
        switch status {
        case .expired:
            return "Expired"
        case .expiringSoon:
            return days <= 0 ? "Due today" : "\(days)d left"
        case .active:
            return "\(days)d left"
        }
    }

    /// Functional, not decorative: green only ever means "active and
    /// fine," `Theme.warning` gold means "needs attention soon," and the
    /// expired case is drawn as a stamp above rather than through this
    /// color at all. Uses `Theme.warning` rather than `Theme.accent` so
    /// this status color stays fixed even as the brand accent changes —
    /// `accent` and `success` are the same green now, and `expiringSoon`
    /// needs a color that's neither of those.
    private func color(for status: ItemStatus) -> Color {
        switch status {
        case .active: return Theme.success
        case .expiringSoon: return Theme.warning
        case .expired: return Theme.danger
        }
    }
}
