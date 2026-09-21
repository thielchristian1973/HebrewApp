import SwiftUI

struct SentenceStepView: View {
    let sentences: [PilotSentence]
    let onFinished: () async -> Void

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0
    @State private var isRevealed = false
    @State private var isSpeaking = false

    var body: some View {
        VStack(spacing: Spacing.lg) {
            if sentences.isEmpty {
                Text("Keine Sätze für diesen Schritt.")
            } else if index < sentences.count {
                let sentence = sentences[index]
                CardView {
                    VStack(spacing: Spacing.md) {
                        HebrewText(sentence.hebrew, font: AppFont.hebrewDisplay())
                        Button {
                            Task { await speak(sentence.ttsText) }
                        } label: {
                            Label(isSpeaking ? "Spielt ab …" : "Anhören", systemImage: "speaker.wave.2.fill")
                        }
                        .disabled(isSpeaking)

                        if isRevealed {
                            Text(sentence.german)
                                .font(AppFont.germanBody())
                                .foregroundStyle(ColorTokens.textSecondary)
                                .transition(revealTransition)
                        } else {
                            SecondaryButton(title: "Übersetzung anzeigen") {
                                withAnimation(revealAnimation) { isRevealed = true }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .id(sentence.id)
                .transition(cardTransition)

                if isRevealed {
                    PrimaryButton(index + 1 < sentences.count ? "Weiter" : "Fertig") {
                        Task { await advance(sentence: sentence) }
                    }
                    .transition(revealTransition)
                }
            }
        }
        .padding(Spacing.md)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: index)
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

    private func advance(sentence: PilotSentence) async {
        environment.feedback.lightTap()

        let attempt = PilotAttempt(
            timestampUTC: Date(),
            kind: .sentenceRecall,
            itemID: sentence.id,
            correctness: .unscored
        )
        try? await environment.progressRepository.recordAttempt(attempt)

        let isLastSentence = index + 1 >= sentences.count
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
            isRevealed = false
            if !isLastSentence {
                index += 1
            }
        }
        if isLastSentence {
            await onFinished()
        }
    }
}
