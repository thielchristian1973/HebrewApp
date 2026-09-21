import SwiftUI

/// A capability/availability indicator that always pairs an icon with text — colour alone never
/// carries the meaning (Documentation/DESIGN_SYSTEM.md: "Fehlerzustände mit Text/Icon statt
/// allein Farbe").
struct StatusBadge: View {
    enum Level {
        case available
        case unavailable
        case notApplicable

        var symbol: String {
            switch self {
            case .available: "checkmark.circle.fill"
            case .unavailable: "exclamationmark.triangle.fill"
            case .notApplicable: "minus.circle"
            }
        }

        var tint: Color {
            switch self {
            case .available: .green
            case .unavailable: .orange
            case .notApplicable: ColorTokens.textSecondary
            }
        }
    }

    let level: Level
    let text: String

    var body: some View {
        Label(text, systemImage: level.symbol)
            .font(AppFont.germanCaption())
            .foregroundStyle(level.tint)
            .labelStyle(.titleAndIcon)
    }
}
