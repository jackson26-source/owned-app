import SwiftUI

/// The small colored pill that makes an item's urgency legible at a
/// glance in the list — no need to open the item to know if it needs
/// attention today.
struct StatusBadge: View {
    let deadline: TrackedDeadline?

    var body: some View {
        if let deadline {
            let status = deadline.status()
            let days = deadline.daysRemaining()

            Text(label(status: status, days: days))
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(color(for: status).opacity(0.16))
                .foregroundStyle(color(for: status))
                .clipShape(Capsule())
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

    private func color(for status: ItemStatus) -> Color {
        switch status {
        case .active: return .green
        case .expiringSoon: return Theme.accent
        case .expired: return Theme.textFaint
        }
    }
}
