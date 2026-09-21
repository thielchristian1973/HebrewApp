import Foundation

/// Loads and structurally verifies the bundled pilot content. Concrete implementation lives in
/// the Content module; Domain only sees this protocol (ARCHITECTURE.md service boundaries).
protocol ContentRepository: Sendable {
    func loadPilotBundle() async throws(ContentLoadError) -> PilotContentBundle
}

/// Persists pilot attempts and resumable session/path state atomically. Concrete implementation
/// lives in the Data module (SwiftData); Domain only sees this protocol.
protocol ProgressRepository: Sendable {
    func recordAttempt(_ attempt: PilotAttempt) async throws(PersistenceError)
    func recordPronunciationAttempt(_ attempt: PronunciationAttempt) async throws(PersistenceError)
    func allAttempts() async throws(PersistenceError) -> [PilotAttempt]

    func saveDialogueSession(_ state: DialogueSessionState) async throws(PersistenceError)
    func loadDialogueSession(dialogueID: String) async throws(PersistenceError) -> DialogueSessionState?

    func savePathProgress(_ progress: PilotLearningPathProgress) async throws(PersistenceError)
    func loadPathProgress(pathID: String) async throws(PersistenceError) -> PilotLearningPathProgress?

    /// Deletes all locally persisted pilot progress. Used by the developer pilot screen's reset
    /// and by the exportable report flow's "start clean" action; never touches bundle content.
    func resetAllProgress() async throws(PersistenceError)
}
