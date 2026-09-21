import SwiftUI

/// A small row of dots showing progress through a fixed number of steps. Never the sole signal —
/// always paired with the existing "Schritt X von Y" text for VoiceOver and for anyone who
/// can't distinguish the dot states by color alone (Documentation/DESIGN_SYSTEM.md).
struct StepDotIndicator: View {
    let states: [StepDotState]

    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(Array(states.enumerated()), id: \.offset) { _, state in
                let diameter: CGFloat = state == .current ? 10 : 8
                let borderWidth: CGFloat = state == .current ? 1.5 : 0
                Circle()
                    .fill(fillColor(for: state))
                    .frame(width: diameter, height: diameter)
                    .overlay(Circle().strokeBorder(ColorTokens.primary, lineWidth: borderWidth))
            }
        }
        .accessibilityHidden(true)
    }

    private func fillColor(for state: StepDotState) -> Color {
        switch state {
        case .completed: ColorTokens.primary
        case .current: ColorTokens.surface
        case .upcoming: ColorTokens.divider
        }
    }
}
