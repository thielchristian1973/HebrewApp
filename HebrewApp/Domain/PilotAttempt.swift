import Foundation

/// What kind of pilot interaction an attempt records. Deliberately narrow — the pilot has no
/// production exercise types (E01–E12 land in P2, Documentation/CONTENT_GUIDE.md).
enum PilotAttemptKind: String, Codable, Sendable, Hashable {
    case lexemeRecall
    case sentenceRecall
    case dialogueStep
    case pronunciationSelfCheck
}

/// Correctness classification. Matches Documentation/DATA_MODEL.md's Attempt contract
/// (`correct` / `incorrect` / `unscored`) — never a percentage, never a pronunciation score.
enum PilotCorrectness: String, Codable, Sendable, Hashable {
    case correct
    case incorrect
    case unscored
}

/// A single immutable, append-only pilot attempt event. This is a deliberately reduced subset
/// of the production `Attempt` contract in Documentation/DATA_MODEL.md — it captures only what
/// the P1 technical pilot needs (evidence that persistence and resumability work end to end),
/// and is not the production learning-history schema. `schemaVersion` lets P2 migrate it.
struct PilotAttempt: Codable, Sendable, Hashable, Identifiable {
    let id: UUID
    /// UTC instant of the attempt, per DATA_MODEL.md ("UUID, UTC timestamp").
    let timestampUTC: Date
    let kind: PilotAttemptKind
    /// Lexeme/sentence/dialogue-node id this attempt refers to.
    let itemID: String
    let correctness: PilotCorrectness
    /// Whether a hint (e.g. revealed answer) was used before this attempt was recorded.
    let hintUsed: Bool
    let schemaVersion: Int

    init(
        id: UUID = UUID(),
        timestampUTC: Date,
        kind: PilotAttemptKind,
        itemID: String,
        correctness: PilotCorrectness,
        hintUsed: Bool = false,
        schemaVersion: Int = 1
    ) {
        self.id = id
        self.timestampUTC = timestampUTC
        self.kind = kind
        self.itemID = itemID
        self.correctness = correctness
        self.hintUsed = hintUsed
        self.schemaVersion = schemaVersion
    }
}

/// A self-assessment or ASR-transcript comparison for a recorded pronunciation attempt. Kept
/// separate from `PilotAttempt` per DATA_MODEL.md's `PronunciationAttempt`: never a phoneme,
/// accent or intelligibility score — only these coarse, honestly-labeled outcomes
/// (Documentation/SPEECH_SPEC.md "Bewertungsklassen").
enum PronunciationFeedbackKind: String, Codable, Sendable, Hashable {
    case transcriptMatchesTarget
    case transcriptDiffers
    case recognitionUnavailable
    case selfReviewed
}

struct PronunciationAttempt: Codable, Sendable, Hashable, Identifiable {
    let id: UUID
    let timestampUTC: Date
    let itemID: String
    /// Relative path under Application Support, never an absolute path (DATA_MODEL.md).
    let recordingRelativePath: String?
    let transcript: String?
    let feedbackKind: PronunciationFeedbackKind
    /// User's own judgement, recorded separately from any ASR outcome.
    let selfAssessedAsUnderstandable: Bool?

    init(
        id: UUID = UUID(),
        timestampUTC: Date,
        itemID: String,
        recordingRelativePath: String? = nil,
        transcript: String? = nil,
        feedbackKind: PronunciationFeedbackKind,
        selfAssessedAsUnderstandable: Bool? = nil
    ) {
        self.id = id
        self.timestampUTC = timestampUTC
        self.itemID = itemID
        self.recordingRelativePath = recordingRelativePath
        self.transcript = transcript
        self.feedbackKind = feedbackKind
        self.selfAssessedAsUnderstandable = selfAssessedAsUnderstandable
    }
}
