import SwiftUI

struct SentenceStepView: View {
    let sentences: [PilotSentence]
    let onFinished: () async -> Void

    @Environment(AppEnvironment.self) private var environment
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
                        } else {
                            SecondaryButton(title: "Übersetzung anzeigen") { isRevealed = true }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                if isRevealed {
                    PrimaryButton(index + 1 < sentences.count ? "Weiter" : "Fertig") {
                        Task { await advance(sentence: sentence) }
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

    private func advance(sentence: PilotSentence) async {
        let attempt = PilotAttempt(
            timestampUTC: Date(),
            kind: .sentenceRecall,
            itemID: sentence.id,
            correctness: .unscored
        )
        try? await environment.progressRepository.recordAttempt(attempt)

        isRevealed = false
        if index + 1 < sentences.count {
            index += 1
        } else {
            await onFinished()
        }
    }
}
