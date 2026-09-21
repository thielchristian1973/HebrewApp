import Foundation
import SwiftData

/// SwiftData-backed persistence for pilot attempts and resumable session/path state
/// (ARCHITECTURE.md: "SwiftData nur für veränderliche Nutzerdaten; Kursinhalt als Bundle-JSON").
/// These `@Model` types are private storage details — everything outside the Data module only
/// ever sees the plain Domain value types via `ProgressRepository`.
@Model
final class PilotAttemptRecord {
    @Attribute(.unique) var id: UUID
    var timestampUTC: Date
    var kindRaw: String
    var itemID: String
    var correctnessRaw: String
    var hintUsed: Bool
    var schemaVersion: Int

    init(id: UUID, timestampUTC: Date, kindRaw: String, itemID: String, correctnessRaw: String, hintUsed: Bool, schemaVersion: Int) {
        self.id = id
        self.timestampUTC = timestampUTC
        self.kindRaw = kindRaw
        self.itemID = itemID
        self.correctnessRaw = correctnessRaw
        self.hintUsed = hintUsed
        self.schemaVersion = schemaVersion
    }
}

@Model
final class PronunciationAttemptRecord {
    @Attribute(.unique) var id: UUID
    var timestampUTC: Date
    var itemID: String
    var recordingRelativePath: String?
    var transcript: String?
    var feedbackKindRaw: String
    var selfAssessedAsUnderstandable: Bool?

    init(id: UUID, timestampUTC: Date, itemID: String, recordingRelativePath: String?, transcript: String?, feedbackKindRaw: String, selfAssessedAsUnderstandable: Bool?) {
        self.id = id
        self.timestampUTC = timestampUTC
        self.itemID = itemID
        self.recordingRelativePath = recordingRelativePath
        self.transcript = transcript
        self.feedbackKindRaw = feedbackKindRaw
        self.selfAssessedAsUnderstandable = selfAssessedAsUnderstandable
    }
}

/// One row per dialogue, keyed by `dialogueID` (Documentation/LOCAL_AI.md: "Ein Dialogwechsel
/// darf Historie und Versuchszähler nicht zurücksetzen" — this row is the single source of
/// truth for that dialogue's resumable state, replaced atomically on every save).
@Model
final class DialogueSessionRecord {
    @Attribute(.unique) var dialogueID: String
    var currentNodeID: String
    var historyJSON: Data
    var unsuccessfulAttemptsAtCurrentNode: Int
    var isCompleted: Bool

    init(dialogueID: String, currentNodeID: String, historyJSON: Data, unsuccessfulAttemptsAtCurrentNode: Int, isCompleted: Bool) {
        self.dialogueID = dialogueID
        self.currentNodeID = currentNodeID
        self.historyJSON = historyJSON
        self.unsuccessfulAttemptsAtCurrentNode = unsuccessfulAttemptsAtCurrentNode
        self.isCompleted = isCompleted
    }
}

@Model
final class PathProgressRecord {
    @Attribute(.unique) var pathID: String
    var completedStepIDs: [String]
    var isCompleted: Bool

    init(pathID: String, completedStepIDs: [String], isCompleted: Bool) {
        self.pathID = pathID
        self.completedStepIDs = completedStepIDs
        self.isCompleted = isCompleted
    }
}

/// First schema version. No migration stages exist yet because there is no prior version to
/// migrate from — Documentation/ARCHITECTURE.md still requires the versioning scaffolding to be
/// in place from the start so P2 can add real migrations without restructuring this layer.
enum PilotSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [PilotAttemptRecord.self, PronunciationAttemptRecord.self, DialogueSessionRecord.self, PathProgressRecord.self]
    }
}

enum PilotMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [PilotSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
