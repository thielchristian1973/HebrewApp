import SwiftUI

/// The FSRS-backed review queue is a P2 "Lernkern" deliverable
/// (Documentation/IMPLEMENTATION_PLAN.md). No fabricated scheduler state ships here
/// (Documentation/LEARNING_ENGINE.md: "keine fingierten FSRS-Stabilitäten anzeigen").
struct ReviewView: View {
    var body: some View {
        ContentUnavailableView(
            "Wiederholung folgt",
            systemImage: "arrow.clockwise",
            description: Text("Die verteilte Wiederholung (FSRS-Scheduler) ist Teil des Lernkerns (P2) und noch nicht Teil dieses Technik-Pilots.")
        )
    }
}
