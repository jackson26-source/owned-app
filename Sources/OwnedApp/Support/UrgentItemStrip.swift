import SwiftUI

/// A single-line strip pinned above the tab bar's content on every tab,
/// surfacing whichever deadline is closest to expiring across the whole
/// item list. The blank space at the top of every screen used to do
/// nothing; this gives it one job — so the single most time-sensitive
/// thing you own is always one glance (and one tap) away, no matter
/// which tab you're on.
struct UrgentItemStrip: View {
    let item: TrackedItem
    let deadline: TrackedDeadline
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(color)
                Text(message)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textFaint)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.panel)
            .overlay(
                Rectangle()
                    .fill(Theme.border)
                    .frame(height: 1),
                alignment: .bottom
            )
        }
        .buttonStyle(.plain)
    }

    private var status: ItemStatus { deadline.status() }

    /// Matches `StatusBadge` and `DashboardView`'s color convention:
    /// `Theme.warning` rather than `Theme.accent` for expiringSoon, so
    /// this status color stays fixed even as the brand accent changes —
    /// `accent` and `success` are the same green now, and `expiringSoon`
    /// needs a color that's neither of those.
    private var color: Color {
        switch status {
        case .active: return Theme.success
        case .expiringSoon: return Theme.warning
        case .expired: return Theme.danger
        }
    }

    private var iconName: String {
        switch status {
        case .expired: return "exclamationmark.triangle.fill"
        case .expiringSoon: return "clock.fill"
        case .active: return "checkmark.seal.fill"
        }
    }

    private var message: String {
        let days = deadline.daysRemaining()
        let timing: String
        switch status {
        case .expired:
            timing = "\(deadline.kind.label) expired"
        case .expiringSoon, .active:
            let closes = days <= 0 ? "closes today" : days == 1 ? "closes tomorrow" : "closes in \(days) days"
            timing = "\(deadline.kind.label) \(closes)"
        }
        if let price = item.priceDisplay {
            return "\(item.name) — \(timing) — \(price)"
        }
        return "\(item.name) — \(timing)"
    }
}
