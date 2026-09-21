import SwiftUI

/// Renders Hebrew text correctly: explicit right-to-left layout direction scoped to just this
/// view (the surrounding German UI stays LTR — Documentation/DESIGN_SYSTEM.md: "Deutsche
/// Navigation LTR"), native Dynamic Type, and headroom above/below for niqqud marks. Word order
/// is never touched — SwiftUI's `Text` already applies the Unicode Bidi algorithm to the string
/// as authored; this view must never reverse or reorder the string itself
/// (DESIGN_SYSTEM.md: "Wortreihenfolge niemals durch String-Reverse ändern").
struct HebrewText: View {
    private let text: String
    private let font: Font
    private let color: Color

    init(_ text: String, font: Font = AppFont.hebrewBody(), color: Color = ColorTokens.textPrimary) {
        self.text = text
        self.font = font
        self.color = color
    }

    /// he-IL, used both for VoiceOver pronunciation hints and correct multilingual line
    /// shaping. Constructed from `Locale.LanguageCode`/`Locale.Region`, not a bare
    /// `Locale.Language(identifier:)` initializer (that overload does not exist on this type in
    /// the installed SDK — verified against Foundation.swiftinterface).
    private static let hebrewLanguage = Locale.Language(
        languageCode: Locale.LanguageCode("he"),
        region: Locale.Region("IL")
    )

    var body: some View {
        Text(verbatim: text)
            .font(font)
            .foregroundStyle(color)
            .lineSpacing(6) // headroom for niqqud above/below the base letters
            .multilineTextAlignment(.trailing)
            .environment(\.layoutDirection, .rightToLeft)
            .typesettingLanguage(Self.hebrewLanguage)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: text))
    }
}

/// A Hebrew/German pair, stacked with the Hebrew line dominant and the German gloss secondary —
/// the recurring "prompt + translation" shape used across Words, Learn and Pilot screens.
struct HebrewGermanPair: View {
    private let hebrew: String
    private let german: String

    init(hebrew: String, german: String) {
        self.hebrew = hebrew
        self.german = german
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: Spacing.xxs) {
            HebrewText(hebrew, font: AppFont.hebrewDisplay())
            Text(german)
                .font(AppFont.germanCaption())
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}
