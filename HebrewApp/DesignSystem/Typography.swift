import SwiftUI

/// Native semantic text styles only, so Dynamic Type keeps working end to end
/// (DESIGN_SYSTEM.md: "Native semantische Textstile/Dynamic Type, keine fixen kleinen Labels").
enum AppFont {
    static func hebrewDisplay() -> Font { .system(.title2, design: .default).weight(.semibold) }
    static func hebrewBody() -> Font { .system(.title3, design: .default) }
    static func germanBody() -> Font { .system(.body, design: .default) }
    static func germanCaption() -> Font { .system(.footnote, design: .default) }
    static func sectionHeader() -> Font { .system(.headline, design: .default) }
}
