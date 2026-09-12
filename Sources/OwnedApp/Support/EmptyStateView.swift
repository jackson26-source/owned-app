import SwiftUI

/// Owned's themed stand-in for `ContentUnavailableView`. The system version
/// draws a plain SF Symbol and default system type, which reads as a stock
/// iOS screen dropped into an otherwise custom, warm-paper-and-serif app —
/// most noticeable on first launch, when every tab (Dashboard, Items,
/// Timeline) is empty and this is the very first thing a new user sees.
/// This version wraps the icon in an accent-tinted badge, sets the title in
/// the same Georgia serif used for nav titles and the Dashboard hero stat,
/// and offers an optional primary-action pill button so the empty state
/// isn't just an explanation — it's an invitation to do the one thing that
/// fixes it. An optional secondary action sits below the pill as a plain
/// text link — for "Add a purchase" specifically, that's "Add from Gmail",
/// so the very first screen someone with an empty account ever sees offers
/// the same choice the Items toolbar's Add menu does, instead of funneling
/// everyone through manual entry until they happen to discover Gmail
/// import elsewhere.
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?
    var secondaryActionTitle: String?
    var secondaryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)

            iconBadge

            VStack(spacing: 8) {
                Text(title)
                    .font(Theme.serif(22))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textDim)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 36)
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.pill)
                    .padding(.top, 4)
            }

            if let secondaryActionTitle, let secondaryAction {
                Button(secondaryActionTitle, action: secondaryAction)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.accent)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 32)
        .background(Theme.background)
    }

    /// A soft circular panel behind the symbol, echoing the Dashboard hero
    /// stat's bordered-card treatment, so the icon reads as a deliberate
    /// piece of the app's visual language rather than a bare glyph floating
    /// on the page.
    private var iconBadge: some View {
        ZStack {
            Circle()
                .fill(Theme.panel)
                .frame(width: 84, height: 84)
                .overlay(
                    Circle().stroke(Theme.border, lineWidth: 1)
                )
            Image(systemName: icon)
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(Theme.accent)
        }
    }
}

#Preview("With action") {
    EmptyStateView(
        icon: "shippingbox",
        title: "Nothing tracked yet",
        message: "Add a purchase to track its return window or warranty.",
        actionTitle: "Add a purchase",
        action: {},
        secondaryActionTitle: "Add from Gmail",
        secondaryAction: {}
    )
}

#Preview("Without action") {
    EmptyStateView(
        icon: "line.3.horizontal.decrease.circle",
        title: "No matches",
        message: "No purchases match your filters."
    )
}
