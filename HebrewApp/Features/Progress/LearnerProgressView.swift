import SwiftUI

/// Shows only real recorded evidence — no XP, streaks or invented scores
/// (Documentation/PRODUCT.md: "Fortschritt zeigt belegte Kompetenzen und offene Ziele ohne XP").
/// Pronunciation is explicitly labelled as not objectively scored
/// (Documentation/DIDACTICS.md: "Pronunciation bleibt ohne valide Messung 'nicht objektiv
/// bewertet'").
struct LearnerProgressView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var attempts: [PilotAttempt] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                LoadingView(message: "Lade Fortschritt …")
            } else if attempts.isEmpty {
                ContentUnavailableView(
                    "Noch keine Versuche",
                    systemImage: "chart.bar",
                    description: Text("Sobald du eine Demo-Lernstrecke startest, erscheinen hier deine Versuche.")
                )
            } else {
                List {
                    Section("Zusammenfassung") {
                        summaryRow(title: "Wörter", kind: .lexemeRecall)
                        summaryRow(title: "Sätze", kind: .sentenceRecall)
                        summaryRow(title: "Dialogschritte", kind: .dialogueStep)
                    }
                    Section {
                        Text("Aussprache wird in diesem Pilot nicht objektiv bewertet — nur geübte Aktivität und Selbsteinschätzung.")
                            .font(AppFont.germanCaption())
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                    Section("Letzte Versuche") {
                        ForEach(attempts.prefix(30)) { attempt in
                            HStack {
                                Text(attempt.itemID).font(AppFont.germanCaption())
                                Spacer()
                                Text(label(for: attempt.correctness))
                                    .font(AppFont.germanCaption())
                                    .foregroundStyle(color(for: attempt.correctness))
                            }
                        }
                    }
                }
            }
        }
        .task { await load() }
    }

    private func summaryRow(title: String, kind: PilotAttemptKind) -> some View {
        let count = attempts.filter { $0.kind == kind }.count
        return HStack {
            Text(title)
            Spacer()
            Text("\(count)")
                .foregroundStyle(ColorTokens.textSecondary)
        }
    }

    private func label(for correctness: PilotCorrectness) -> String {
        switch correctness {
        case .correct: "richtig"
        case .incorrect: "nicht richtig"
        case .unscored: "nicht bewertet"
        }
    }

    private func color(for correctness: PilotCorrectness) -> Color {
        switch correctness {
        case .correct: .green
        case .incorrect: .orange
        case .unscored: ColorTokens.textSecondary
        }
    }

    private func load() async {
        attempts = (try? await environment.progressRepository.allAttempts()) ?? []
        isLoading = false
    }
}
