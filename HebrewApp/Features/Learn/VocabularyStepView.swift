import SwiftUI

/// One card per lexeme: hear it, recall the meaning, reveal, self-rate. Fully usable without a
/// microphone or AI — recall is a self-assessment, never an invented text-matching score
/// (Documentation/DECISIONS.md correction 3 and Documentation/LEARNING_ENGINE.md).
struct VocabularyStepView: View {
    let lexemes: [PilotLexeme]
    let onFinished: () async -> Void

    @Environment(AppEnvironment.self) private var environment
    @State private var index = 0
    @State private var isRevealed = false
    @State private var isSpeaking = false

    var body: some View {
        VStack(spacing: Spacing.lg) {
            if lexemes.isEmpty {
                Text("Keine Wörter für diesen Schritt.")
            } else if index < lexemes.count {
                let lexeme = lexemes[index]
                CardView {
                    VStack(spacing: Spacing.md) {
                        HebrewText(lexeme.hebrew, font: AppFont.hebrewDisplay())
                        Button {
                            Task { await speak(lexeme.ttsText) }
                        } label: {
                            Label(isSpeaking ? "Spielt ab …" : "Anhören", systemImage: "speaker.wave.2.fill")
                        }
                        .disabled(isSpeaking)

                        if isRevealed {
                            Text(lexeme.german)
                                .font(AppFont.germanBody())
                                .foregroundStyle(ColorTokens.textSecondary)
                        } else {
                            SecondaryButton(title: "Bedeutung anzeigen") { isRevealed = true }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                if isRevealed {
                    HStack(spacing: Spacing.sm) {
                        SecondaryButton(title: "Wusste ich nicht") {
                            Task { await advance(lexeme: lexeme, correct: false) }
                        }
                        PrimaryButton("Wusste ich") {
                            Task { await advance(lexeme: lexeme, correct: true) }
                        }
                    }
                }
            }
        }
        .padding(Spacing.md)
    }

    private func speak(_ text: String) async {
        guard let voice = environment.synthesis.availableVoices(languagePrefix: "he").first else { return }
        isSpeaking = true
        defer { isSpeaking = false }
        try? await environment.synthesis.speak(text: text, voiceIdentifier: voice.id, rate: .normal)
    }

    private func advance(lexeme: PilotLexeme, correct: Bool) async {
        let attempt = PilotAttempt(
            timestampUTC: Date(),
            kind: .lexemeRecall,
            itemID: lexeme.id,
            correctness: correct ? .correct : .incorrect
        )
        try? await environment.progressRepository.recordAttempt(attempt)

        isRevealed = false
        if index + 1 < lexemes.count {
            index += 1
        } else {
            await onFinished()
        }
    }
}
