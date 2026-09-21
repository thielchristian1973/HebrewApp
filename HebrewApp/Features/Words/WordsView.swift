import SwiftUI

/// Search across the pilot lexemes/sentences (Documentation/PRODUCT.md: "Wörter bietet
/// hebräische und deutsche Suche, vokalisierte Form, Beispiele und Audio"). This searches only
/// the pilot fixtures — explicitly not a claim of a complete dictionary.
struct WordsView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var query = ""
    @State private var isSpeakingID: String?

    var body: some View {
        Group {
            if let bundle = environment.contentBundle {
                List {
                    Section {
                        Text("Suche in den 50 Pilotwörtern und 20 Pilotsätzen — noch kein vollständiges Wörterbuch.")
                            .font(AppFont.germanCaption())
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                    Section("Wörter") {
                        ForEach(filteredLexemes(bundle: bundle)) { lexeme in
                            wordRow(hebrew: lexeme.hebrew, german: lexeme.german, id: lexeme.id, ttsText: lexeme.ttsText)
                        }
                    }
                    Section("Sätze") {
                        ForEach(filteredSentences(bundle: bundle)) { sentence in
                            wordRow(hebrew: sentence.hebrew, german: sentence.german, id: sentence.id, ttsText: sentence.ttsText)
                        }
                    }
                }
            } else {
                LoadingView(message: "Lade Wörter …")
            }
        }
        .searchable(text: $query, prompt: "Hebräisch oder Deutsch")
    }

    private func wordRow(hebrew: String, german: String, id: String, ttsText: String) -> some View {
        HStack {
            Button {
                Task { await speak(ttsText, id: id) }
            } label: {
                Image(systemName: isSpeakingID == id ? "speaker.wave.2.fill" : "speaker.wave.2")
            }
            .buttonStyle(.borderless)
            HebrewGermanPair(hebrew: hebrew, german: german)
        }
    }

    private func filteredLexemes(bundle: PilotContentBundle) -> [PilotLexeme] {
        guard !query.isEmpty else { return bundle.lexemes }
        return bundle.lexemes.filter { $0.hebrew.contains(query) || $0.german.localizedCaseInsensitiveContains(query) }
    }

    private func filteredSentences(bundle: PilotContentBundle) -> [PilotSentence] {
        guard !query.isEmpty else { return bundle.sentences }
        return bundle.sentences.filter { $0.hebrew.contains(query) || $0.german.localizedCaseInsensitiveContains(query) }
    }

    private func speak(_ text: String, id: String) async {
        guard let voice = environment.synthesis.availableVoices(languagePrefix: "he").first else { return }
        isSpeakingID = id
        defer { isSpeakingID = nil }
        try? await environment.synthesis.speak(text: text, voiceIdentifier: voice.id, rate: .normal)
    }
}
