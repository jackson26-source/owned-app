import SwiftUI

/// A perforated "ticket stub" control standing in for a plain button on
/// the one action in the app that shouldn't happen by accident: marking
/// a purchase as returned or claimed. Instead of a single tap, the two
/// halves of the control pull apart under a drag — the same motion as
/// tearing a real ticket or receipt stub — and only resolve once torn
/// past a threshold. A light haptic marks the tear; letting go before
/// the threshold snaps the stub back together with nothing triggered.
///
/// A plain double-tap also resolves it immediately, via an accessibility
/// action — the drag gesture is a flourish, not the only way in.
struct TearToResolveButton: View {
    var label: String = "Mark as returned or claimed"
    var onResolve: () -> Void

    @State private var gap: CGFloat = 0
    @State private var isTorn = false
    private let tearThreshold: CGFloat = 70

    var body: some View {
        ZStack {
            HStack(spacing: gap) {
                half(icon: "scissors")
                    .rotationEffect(
                        .degrees(-tearProgress * 5),
                        anchor: .trailing
                    )
                half(icon: "checkmark")
                    .rotationEffect(
                        .degrees(tearProgress * 5),
                        anchor: .leading
                    )
            }

            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.onAccent)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 24)
                .opacity(1 - tearProgress)
                .allowsHitTesting(false)
        }
        .frame(height: 52)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 6)
                .onChanged { value in
                    guard !isTorn else { return }
                    gap = max(0, min(value.translation.width, tearThreshold + 30))
                }
                .onEnded { _ in
                    guard !isTorn else { return }
                    if gap >= tearThreshold {
                        tear()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            gap = 0
                        }
                    }
                }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityHint("Drag apart like a ticket stub to confirm, or double-tap to confirm directly.")
        .accessibilityAction {
            guard !isTorn else { return }
            tear()
        }
    }

    /// How far through the tear gesture the control currently is, as a
    /// value from 0 (untouched) to 1 (at or past the resolve threshold).
    /// Drives the halves' rotation and the label's fade-out so both
    /// track the same drag amount instead of two separately-tuned curves.
    private var tearProgress: Double {
        Double(min(gap, tearThreshold) / tearThreshold)
    }

    private func tear() {
        isTorn = true
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        withAnimation(.easeOut(duration: 0.3)) {
            gap = 140
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onResolve()
        }
    }

    private func half(icon: String) -> some View {
        HStack {
            Spacer(minLength: 0)
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.onAccent.opacity(0.85))
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(Theme.accent)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    TearToResolveButton(onResolve: {})
        .padding()
        .background(Theme.background)
}
