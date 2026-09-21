import SwiftUI

/// A bordered button with a small press-scale for a more tactile feel. Uses the environment's
/// `accessibilityReduceMotion` so the scale animation is skipped when the user asked for less
/// motion (Documentation/DESIGN_SYSTEM.md: "Reduce Motion").
struct TactileButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, Spacing.xs)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.card / 2, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.card / 2, style: .continuous)
                    .strokeBorder(ColorTokens.divider, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
