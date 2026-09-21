import Foundation

/// One step within a demo learning path. Every step is completable without a microphone or any
/// AI provider (Documentation/PILOT.md acceptance: "Beide Demo-Lernstrecken ohne KI und ohne
/// Mikrofon abschließbar").
enum PilotLearningStepKind: Sendable, Hashable {
    case vocabulary(lexemeIDs: [String])
    case sentences(sentenceIDs: [String])
    case dialogue(dialogueID: String)
}

struct PilotLearningStep: Sendable, Hashable, Identifiable {
    let id: String
    let title: String
    let kind: PilotLearningStepKind
}

/// A minimal, explicitly-labeled-as-demo learning path built from pilot fixtures
/// (Documentation/PILOT.md: "Zwei einfache vollständig bedienbare Demo-Lernstrecken ... aber
/// nicht als vollständige A0-Lektionen deklarieren"). This is intentionally not the production
/// `Lesson`/`SessionComposer` model from Documentation/DATA_MODEL.md and ARCHITECTURE.md —
/// that lands in P2.
struct PilotLearningPath: Sendable, Hashable, Identifiable {
    let id: String
    let title: String
    let objective: String
    let steps: [PilotLearningStep]
}

/// Resumable progress through one demo path (Documentation/PILOT.md: "beim Neustart
/// fortsetzbar").
struct PilotLearningPathProgress: Codable, Sendable, Hashable {
    let pathID: String
    var completedStepIDs: [String]
    var isCompleted: Bool

    init(pathID: String) {
        self.pathID = pathID
        self.completedStepIDs = []
        self.isCompleted = false
    }
}

/// The two demo paths shipped with the pilot: "Vorstellen" (greeting/introduction) and "Café".
enum PilotLearningPathCatalog {
    static let vorstellen = PilotLearningPath(
        id: "path_vorstellen",
        title: "Vorstellen",
        objective: "Sich begrüßen und den eigenen Namen nennen.",
        steps: [
            PilotLearningStep(
                id: "path_vorstellen_vocab",
                title: "Wörter",
                kind: .vocabulary(lexemeIDs: ["lex_001", "lex_002", "lex_003", "lex_004", "lex_005"])
            ),
            PilotLearningStep(
                id: "path_vorstellen_sentences",
                title: "Sätze",
                kind: .sentences(sentenceIDs: ["sent_001", "sent_002", "sent_003", "sent_004"])
            ),
            PilotLearningStep(
                id: "path_vorstellen_dialogue",
                title: "Dialog",
                kind: .dialogue(dialogueID: "dialog_greeting")
            )
        ]
    )

    static let cafe = PilotLearningPath(
        id: "path_cafe",
        title: "Café",
        objective: "Im Café etwas bestellen und auf eine Rückfrage antworten.",
        steps: [
            PilotLearningStep(
                id: "path_cafe_vocab",
                title: "Wörter",
                kind: .vocabulary(lexemeIDs: ["lex_002", "lex_003", "lex_006"])
            ),
            PilotLearningStep(
                id: "path_cafe_sentences",
                title: "Sätze",
                kind: .sentences(sentenceIDs: ["sent_007", "sent_009"])
            ),
            PilotLearningStep(
                id: "path_cafe_dialogue",
                title: "Dialog",
                kind: .dialogue(dialogueID: "dialog_cafe")
            )
        ]
    )

    static let all: [PilotLearningPath] = [vorstellen, cafe]
}
