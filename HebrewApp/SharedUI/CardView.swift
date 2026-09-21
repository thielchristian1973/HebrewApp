import SwiftUI

/// DESIGN_SYSTEM.md: "Cards Radius 16."
struct CardView<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ColorTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous))
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(AppFont.sectionHeader())
            .foregroundStyle(ColorTokens.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
