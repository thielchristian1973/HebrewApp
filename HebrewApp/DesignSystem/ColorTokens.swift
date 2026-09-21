import SwiftUI

/// Starting color tokens from Documentation/DESIGN_SYSTEM.md. These are implementation
/// defaults, not a validated brand system — contrast still needs a real WCAG AA pass before
/// release (DESIGN_SYSTEM.md: "Kontrast vor Release prüfen").
enum ColorTokens {
    // Light
    static let lightBackground = Color(hex: 0xF7F4EE)
    static let lightSurface = Color(hex: 0xFFFFFF)
    static let lightPrimary = Color(hex: 0x153F40)
    static let lightText = Color(hex: 0x192D2E)
    static let lightSecondaryText = Color(hex: 0x526362)
    static let lightDivider = Color(hex: 0xD7DED9)

    // Dark
    static let darkBackground = Color(hex: 0x101D1E)
    static let darkSurface = Color(hex: 0x1A2B2C)
    static let darkPrimary = Color(hex: 0xA7D1C5)
    static let darkText = Color(hex: 0xF3F3EA)
    static let darkSecondaryText = Color(hex: 0xBBCBC7)

    /// Sparse decorative accent only — never used to carry meaning by itself
    /// (DESIGN_SYSTEM.md: "Fehlerzustände mit Text/Icon statt allein Farbe").
    static let accent = Color(hex: 0xA96542)

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
