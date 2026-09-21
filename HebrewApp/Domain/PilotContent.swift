import Foundation

/// Review state of a content item, per Documentation/CONTENT_GUIDE.md's editorial pipeline
/// (draft → structurally validated → linguistically reviewed → audio-checked → released).
/// The pilot fixtures are all `.draft`; nothing here claims linguistic release.
enum ReviewStatus: String, Codable, Sendable, Hashable {
    case draft
    case structurallyValidated
    case linguisticallyReviewed
    case released
}

/// A single pilot vocabulary item. Field set matches Content/Pilot/lexemes.json exactly
/// (Documentation/DATA_MODEL.md "Geliefertes Pilotformat v1"); this is intentionally a reduced
/// subset of the eventual production Lexeme contract, not a replacement for it.
struct PilotLexeme: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let hebrew: String
    let german: String
    /// Separate from `hebrew` so a future audio-checked TTS string can diverge from the display
    /// form without re-editing the display text (SPEECH_SPEC.md). In the pilot both are equal.
    let ttsText: String
    let reviewStatus: ReviewStatus
}

/// A single pilot example sentence. Field set matches Content/Pilot/sentences.json exactly.
struct PilotSentence: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let hebrew: String
    let german: String
    let ttsText: String
    let reviewStatus: ReviewStatus
}

/// One valid, pre-authored continuation from a dialogue node. Only IDs that appear in the
/// shipped content graph are ever offered — the pilot tutor may choose among these, it never
/// invents free text (Documentation/LOCAL_AI.md "Sichere Pilotfunktion").
struct PilotDialogueAnswer: Codable, Sendable, Hashable {
    let sentenceID: String
    let nextNodeID: String
}

struct PilotDialogueNode: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let promptSentenceID: String
    let answers: [PilotDialogueAnswer]
    let terminal: Bool
}

/// A fully guided (not free-conversation) dialogue: Documentation/PILOT.md's four scenarios
/// (Begrüßung, Café, Weg fragen, Einkaufen). Field set matches Content/Pilot/dialogues.json.
struct PilotDialogue: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let title: String
    let objective: String
    let startNodeID: String
    let nodes: [PilotDialogueNode]
    let reviewStatus: ReviewStatus

    var nodesByID: [String: PilotDialogueNode] {
        Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
    }
}

struct PilotManifestFile: Codable, Sendable, Hashable {
    let path: String
    let sha256: String
}

struct PilotManifestCounts: Codable, Sendable, Hashable {
    let lexemes: Int
    let sentences: Int
    let dialogues: Int
}

struct PilotManifest: Codable, Sendable, Hashable {
    let schemaVersion: Int
    let contentVersion: String
    let status: String
    let counts: PilotManifestCounts
    let files: [PilotManifestFile]
}

/// The fully loaded, hash-verified pilot content bundle held in memory for the app session.
/// Content/Pilot ships as read-only bundle JSON (ARCHITECTURE.md "Content: versionierte
/// Bundle-Daten, Manifestprüfung"); nothing here is ever mutated at runtime.
struct PilotContentBundle: Sendable {
    let manifest: PilotManifest
    let lexemes: [PilotLexeme]
    let sentences: [PilotSentence]
    let dialogues: [PilotDialogue]

    var lexemesByID: [String: PilotLexeme] {
        Dictionary(uniqueKeysWithValues: lexemes.map { ($0.id, $0) })
    }

    var sentencesByID: [String: PilotSentence] {
        Dictionary(uniqueKeysWithValues: sentences.map { ($0.id, $0) })
    }

    func dialogue(id: String) -> PilotDialogue? {
        dialogues.first { $0.id == id }
    }
}
