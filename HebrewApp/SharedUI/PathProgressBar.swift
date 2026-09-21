import SwiftUI

/// A slim segmented progress bar for a learning path — one segment per step, filled once that
/// step is completed. Reuses `StepDotState` so the fill logic stays identical to
/// `StepDotIndicator`'s dots; only the shape differs.
struct PathProgressBar: View {
    let states: [StepDotState]

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            ForEach(Array(states.enumerated()), id: \.offset) { _, state in
                Capsule()
                    .fill(state == .completed ? ColorTokens.primary : ColorTokens.divider)
                    .frame(height: 5)
            }
        }
        .accessibilityHidden(true)
    }
}
