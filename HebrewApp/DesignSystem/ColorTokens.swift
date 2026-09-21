import SwiftUI

/// Color tokens from Documentation/DESIGN_SYSTEM.md. Rebranded to a bold-blue palette plus the
/// Wiedehopf (hoopoe) mascot on 21.09.2026 — a deliberate, explicit product decision that
/// supersedes the original "ruhig, warm, erwachsen" cream/petrol palette and the earlier
/// no-mascot rule (Documentation/DECISIONS.md, "Rebranding-Entscheidung"). These are still
/// implementation defaults, not a validated brand system — contrast still needs a real WCAG AA
/// pass before release (DESIGN_SYSTEM.md: "Kontrast vor Release prüfen").
enum ColorTokens {
    // Light
    static let lightBackground = Color(hex: 0xF3F6FD)
    static let lightSurface = Color(hex: 0xFFFFFF)
    static let lightPrimary = Color(hex: 0x2952E3)
    static let lightText = Color(hex: 0x16213E)
    static let lightSecondaryText = Color(hex: 0x5B6B8C)
    static let lightDivider = Color(hex: 0xDCE3F5)

    // Dark
    static let darkBackground = Color(hex: 0x0E1730)
    static let darkSurface = Color(hex: 0x16213E)
    static let darkPrimary = Color(hex: 0x7C97FF)
    static let darkText = Color(hex: 0xEDF1FF)
    static let darkSecondaryText = Color(hex: 0xA9B6D9)
    static let darkDivider = Color(hex: 0x2A3A5C)

    /// Sparse decorative accent only — never used to carry meaning by itself
    /// (DESIGN_SYSTEM.md: "Fehlerzustände mit Text/Icon statt allein Farbe"). Matches the
    /// mascot's crest tone so the illustration and UI accent read as one system.
    static let accent = Color(hex: 0xC97A3B)

    static let background = Color("AppBackground", bundle: .main)
    static let surface = Color("AppSurface", bundle: .main)
    static let primary = Color("AppPrimary", bundle: .main)
    static let textPrimary = Color("AppText", bundle: .main)
    static let textSecondary = Color("AppSecondaryText", bundle: .main)
    static let divider = Color("AppDivider", bundle: .main)
}

extension Color {
    init(hex: UInt32) {
        let red = Double((hex & 0xFF0000) >> 16) / 255
        let green = Double((hex & 0x00FF00) >> 8) / 255
        let blue = Double(hex & 0x0000FF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}
