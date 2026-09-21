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
            .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
            .shadow(color: .black.opacity(0.06), radius: 12, y: 8)
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
