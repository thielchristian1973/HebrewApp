import SwiftUI

/// The one dominant call-to-action shape used across Today/Learn (Documentation/DESIGN_SYSTEM.md:
/// "Buttons mindestens 44 pt bedienbare Fläche").
struct PrimaryButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void

    init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .font(AppFont.germanBody().weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: HitTarget.minimum)
        }
        .buttonStyle(.borderedProminent)
        .tint(ColorTokens.primary)
    }
}

struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(AppFont.germanBody())
            .frame(minHeight: HitTarget.minimum)
    }
}
