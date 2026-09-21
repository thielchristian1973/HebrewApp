import Foundation

/// One rendered turn of a guided dialogue, for the visible transcript
/// (Documentation/PRODUCT.md "sichtbarer Gesprächsverlauf").
struct DialogueTurn: Codable, Sendable, Hashable, Identifiable {
    let id: UUID
    let nodeID: String
    let promptSentenceID: String
    /// The sentence ID the learner ultimately confirmed at this node, if any yet.
    let chosenSentenceID: String?

    init(id: UUID = UUID(), nodeID: String, promptSentenceID: String, chosenSentenceID: String? = nil) {
        self.id = id
        self.nodeID = nodeID
        self.promptSentenceID = promptSentenceID
        self.chosenSentenceID = chosenSentenceID
    }
}

/// Persistable, resumable progress through one guided dialogue. Resetting the dialogue never
/// discards `history`/attempt counters implicitly — only an explicit restart does
/// (Documentation/LOCAL_AI.md "Ein Dialogwechsel darf Historie und Versuchszähler nicht
/// zurücksetzen").
struct DialogueSessionState: Codable, Sendable, Hashable {
    let dialogueID: String
    var currentNodeID: String
    var history: [DialogueTurn]
    /// Unsuccessful (distractor) picks at the current node; guided help kicks in after 3
    /// (Documentation/PRODUCT.md "Nach maximal drei erfolglosen Versuchen unterstützte
    /// Fortsetzung").
    var unsuccessfulAttemptsAtCurrentNode: Int
    var isCompleted: Bool

    init(dialogueID: String, startNodeID: String) {
        self.dialogueID = dialogueID
        self.currentNodeID = startNodeID
        self.history = []
        self.unsuccessfulAttemptsAtCurrentNode = 0
        self.isCompleted = false
    }
}

/// Outcome of offering a choice at the current dialogue node.
enum DialogueStepOutcome: Sendable, Equatable {
    case advanced(newState: DialogueSessionState)
    case completed(newState: DialogueSessionState)
    /// A distractor was chosen; `revealAnswer` becomes true once the 3-attempt cap is reached
    /// so the UI can show the supported continuation (Documentation/PRODUCT.md).
    case incorrectChoice(newState: DialogueSessionState, revealAnswer: Bool)
}
