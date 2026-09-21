import Foundation
import SwiftData

/// SwiftData-backed `ProgressRepository`. Confined to `@MainActor` because `ModelContext` is
/// explicitly not `Sendable` in the installed SDK ("contexts cannot be shared across
/// concurrency contexts") — this repository always uses the container's `mainContext`, which is
/// itself `@MainActor`-isolated, so no context ever crosses an actor boundary.
@MainActor
final class SwiftDataProgressRepository: ProgressRepository {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init(container: ModelContainer) {
        self.container = container
    }

    func recordAttempt(_ attempt: PilotAttempt) async throws(PersistenceError) {
        let record = PilotAttemptRecord(
            id: attempt.id,
            timestampUTC: attempt.timestampUTC,
            kindRaw: attempt.kind.rawValue,
            itemID: attempt.itemID,
            correctnessRaw: attempt.correctness.rawValue,
            hintUsed: attempt.hintUsed,
            schemaVersion: attempt.schemaVersion
        )
        context.insert(record)
        try save()
    }

    func recordPronunciationAttempt(_ attempt: PronunciationAttempt) async throws(PersistenceError) {
        let record = PronunciationAttemptRecord(
            id: attempt.id,
            timestampUTC: attempt.timestampUTC,
            itemID: attempt.itemID,
            recordingRelativePath: attempt.recordingRelativePath,
            transcript: attempt.transcript,
            feedbackKindRaw: attempt.feedbackKind.rawValue,
            selfAssessedAsUnderstandable: attempt.selfAssessedAsUnderstandable
        )
        context.insert(record)
        try save()
    }

    func allAttempts() async throws(PersistenceError) -> [PilotAttempt] {
        let descriptor = FetchDescriptor<PilotAttemptRecord>(sortBy: [SortDescriptor(\.timestampUTC, order: .reverse)])
        do {
            let records = try context.fetch(descriptor)
            return records.compactMap { record in
                guard
                    let kind = PilotAttemptKind(rawValue: record.kindRaw),
                    let correctness = PilotCorrectness(rawValue: record.correctnessRaw)
                else { return nil }
                return PilotAttempt(
                    id: record.id,
                    timestampUTC: record.timestampUTC,
                    kind: kind,
                    itemID: record.itemID,
                    correctness: correctness,
                    hintUsed: record.hintUsed,
                    schemaVersion: record.schemaVersion
                )
            }
        } catch {
            throw PersistenceError.fetchFailed("\(error)")
        }
    }

    func saveDialogueSession(_ state: DialogueSessionState) async throws(PersistenceError) {
        let historyData: Data
        do {
            historyData = try JSONEncoder().encode(state.history)
        } catch {
            throw PersistenceError.saveFailed("history encode: \(error)")
        }

        let existing = try fetchDialogueRecord(dialogueID: state.dialogueID)
        if let existing {
            existing.currentNodeID = state.currentNodeID
            existing.historyJSON = historyData
            existing.unsuccessfulAttemptsAtCurrentNode = state.unsuccessfulAttemptsAtCurrentNode
            existing.isCompleted = state.isCompleted
        } else {
            context.insert(DialogueSessionRecord(
                dialogueID: state.dialogueID,
                currentNodeID: state.currentNodeID,
                historyJSON: historyData,
                unsuccessfulAttemptsAtCurrentNode: state.unsuccessfulAttemptsAtCurrentNode,
                isCompleted: state.isCompleted
            ))
        }
        try save()
    }

    func loadDialogueSession(dialogueID: String) async throws(PersistenceError) -> DialogueSessionState? {
        guard let record = try fetchDialogueRecord(dialogueID: dialogueID) else { return nil }
        let history: [DialogueTurn]
        do {
            history = try JSONDecoder().decode([DialogueTurn].self, from: record.historyJSON)
        } catch {
            throw PersistenceError.corruptImportRejected("dialogue history decode: \(error)")
        }
        var state = DialogueSessionState(dialogueID: record.dialogueID, startNodeID: record.currentNodeID)
        state.history = history
        state.unsuccessfulAttemptsAtCurrentNode = record.unsuccessfulAttemptsAtCurrentNode
        state.isCompleted = record.isCompleted
        return state
    }

    func savePathProgress(_ progress: PilotLearningPathProgress) async throws(PersistenceError) {
        if let existing = try fetchPathRecord(pathID: progress.pathID) {
            existing.completedStepIDs = progress.completedStepIDs
            existing.isCompleted = progress.isCompleted
        } else {
            context.insert(PathProgressRecord(
                pathID: progress.pathID,
                completedStepIDs: progress.completedStepIDs,
                isCompleted: progress.isCompleted
            ))
        }
        try save()
    }

    func loadPathProgress(pathID: String) async throws(PersistenceError) -> PilotLearningPathProgress? {
        guard let record = try fetchPathRecord(pathID: pathID) else { return nil }
        var progress = PilotLearningPathProgress(pathID: record.pathID)
        progress.completedStepIDs = record.completedStepIDs
        progress.isCompleted = record.isCompleted
        return progress
    }

    func resetAllProgress() async throws(PersistenceError) {
        do {
            try context.delete(model: PilotAttemptRecord.self)
            try context.delete(model: PronunciationAttemptRecord.self)
            try context.delete(model: DialogueSessionRecord.self)
            try context.delete(model: PathProgressRecord.self)
            try save()
        } catch {
            throw PersistenceError.saveFailed("resetAllProgress: \(error)")
        }
    }

    // MARK: - Helpers

    private func fetchDialogueRecord(dialogueID: String) throws(PersistenceError) -> DialogueSessionRecord? {
        let predicate = #Predicate<DialogueSessionRecord> { $0.dialogueID == dialogueID }
        do {
            return try context.fetch(FetchDescriptor(predicate: predicate)).first
        } catch {
            throw PersistenceError.fetchFailed("\(error)")
        }
    }

    private func fetchPathRecord(pathID: String) throws(PersistenceError) -> PathProgressRecord? {
        let predicate = #Predicate<PathProgressRecord> { $0.pathID == pathID }
        do {
            return try context.fetch(FetchDescriptor(predicate: predicate)).first
        } catch {
            throw PersistenceError.fetchFailed("\(error)")
        }
    }

    private func save() throws(PersistenceError) {
        do {
            try context.save()
        } catch {
            throw PersistenceError.saveFailed("\(error)")
        }
    }
}
