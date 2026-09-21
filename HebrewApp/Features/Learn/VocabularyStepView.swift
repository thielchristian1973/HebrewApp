import SwiftUI

/// One card per lexeme: hear it, recall the meaning, reveal, self-rate on three honest levels.
/// Fully usable without a microphone or AI — recall is a self-assessment, never an invented
/// text-matching score (Documentation/DECISIONS.md correction 3 and
/// Documentation/LEARNING_ENGINE.md). "Unsicher" maps to `.unscored`, not to a forced right/wrong
/// — DIDACTICS.md: "Ungeprüfte freie Sprache ist 'nicht bewertet', nicht falsch".
struct VocabularyStepView: View {
    let lexemes: [PilotLexeme]
    let onFinished: () async -> Void

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                                .transition(revealTransition)
                        } else {
                            SecondaryButton(title: "Bedeutung anzeigen") {
                                withAnimation(revealAnimation) { isRevealed = true }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .id(lexeme.id)
                .transition(cardTransition)

                if isRevealed {
                    selfAssessmentButtons(lexeme: lexeme)
                        .transition(revealTransition)
                }
            }
        }
        .padding(Spacing.md)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: index)
    }

    private func selfAssessmentButtons(lexeme: PilotLexeme) -> some View {
        HStack(spacing: Spacing.xs) {
            assessmentButton(title: "Nicht gewusst", systemImage: "xmark.circle", tint: .orange) {
                Task { await advance(lexeme: lexeme, correctness: .incorrect) }
            }
            assessmentButton(title: "Unsicher", systemImage: "questionmark.circle", tint: ColorTokens.textSecondary) {
                Task { await advance(lexeme: lexeme, correctness: .unscored) }
            }
            assessmentButton(title: "Gewusst", systemImage: "checkmark.circle.fill", tint: ColorTokens.primary) {
                Task { await advance(lexeme: lexeme, correctness: .correct) }
            }
        }
    }

    private func assessmentButton(title: String, systemImage: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: Spacing.xxs) {
                Image(systemName: systemImage)
                    .accessibilityHidden(true)
                Text(title).font(AppFont.germanCaption())
            }
            .frame(maxWidth: .infinity, minHeight: HitTarget.minimum)
        }
        .buttonStyle(TactileButtonStyle())
        .tint(tint)
        .accessibilityLabel(title)
    }

    private var cardTransition: AnyTransition {
        reduceMotion ? .identity : .asymmetric(
            insertion: .opacity.combined(with: .move(edge: .trailing)),
            removal: .opacity.combined(with: .move(edge: .leading))
        )
    }

    private var revealTransition: AnyTransition {
        reduceMotion ? .identity : .opacity.combined(with: .scale(scale: 0.96, anchor: .top))
    }

    private var revealAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.2)
    }

    private func speak(_ text: String) async {
        guard let voice = environment.synthesis.availableVoices(languagePrefix: "he").first else { return }
        isSpeaking = true
        defer { isSpeaking = false }
        try? await environment.synthesis.speak(text: text, voiceIdentifier: voice.id, rate: .normal)
    }

    private func advance(lexeme: PilotLexeme, correctness: PilotCorrectness) async {
        environment.feedback.play(FeedbackCueMapper.forVocabularyAssessment(correctness))

        let attempt = PilotAttempt(
            timestampUTC: Date(),
            kind: .lexemeRecall,
            itemID: lexeme.id,
            correctness: correctness
        )
        try? await environment.progressRepository.recordAttempt(attempt)

        let isLastLexeme = index + 1 >= lexemes.count
        let animation = reduceMotion ? nil : Animation.easeInOut(duration: 0.25)
        withAnimation(animation) {
            isRevealed = false
            if !isLastLexeme {
                index += 1
            }
        }
        if isLastLexeme {
            await onFinished()
        }
    }
}
