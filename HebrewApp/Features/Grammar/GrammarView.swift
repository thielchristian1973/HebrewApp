import SwiftUI

/// Documentation/IMPLEMENTATION_PLAN.md scopes the grammar reference to P2 ("Lernkern"). This
/// pilot screen states that honestly instead of shipping an empty section disguised as content
/// (Documentation/PRODUCT.md: "keine leeren A1-Kapitel als vollständigen Kurs verkaufen").
struct GrammarView: View {
    var body: some View {
        ContentUnavailableView(
            "Grammatiknachschlagewerk folgt",
            systemImage: "text.book.closed",
            description: Text("Das Grammatiknachschlagewerk ist Teil des Lernkerns (P2) und noch nicht Teil dieses Technik-Pilots.")
        )
    }
}
