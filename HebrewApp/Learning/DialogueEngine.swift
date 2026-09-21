import Foundation

/// One offered choice at a dialogue node: either a genuine, content-approved continuation, or a
/// distractor drawn from other released sentences. The shipped dialogue graph
/// (Content/Pilot/dialogues.json) only encodes valid transitions, so distractors are generated
/// here — never invented free text, only other already-reviewed sentences
/// (Documentation/LOCAL_AI.md: "im Pilot dürfen nur geprüfte Antwort-IDs/zulässige Übergänge als
/// Kurskorrektur verwendet werden").
struct DialogueChoice: Sendable, Hashable, Identifiable {
    let id: String
    let sentenceID: String
    let isValidContinuation: Bool
}

/// The fully implemented, deterministic guided-dialogue state machine
/// (ARCHITECTURE.md: "DialogueEngine allein entscheidet über Übergang/Ergebnis").
/// Pure logic over `PilotDialogue` data — no UI, no persistence, no AI. Depending only on
/// Foundation, it is trivially unit-testable and independent of any Apple framework.
struct DialogueEngine: Sendable {
    /// Distractor pool: any other sentence in the bundle not currently valid at this node.
    private let allSentenceIDs: [String]
    private let maximumUnsuccessfulAttempts = 3
    private let distractorCount = 2

    init(allSentenceIDs: [String]) {
        self.allSentenceIDs = allSentenceIDs
    }

    func startSession(for dialogue: PilotDialogue) -> DialogueSessionState {
        DialogueSessionState(dialogueID: dialogue.id, startNodeID: dialogue.startNodeID)
    }

    /// The choices to present at the session's current node, in a stable, seed-derived order
    /// (no `Int.random`/`Date` — deterministic so tests and previews are reproducible).
    func choices(for state: DialogueSessionState, dialogue: PilotDialogue) -> [DialogueChoice] {
        guard let node = dialogue.nodesByID[state.currentNodeID] else { return [] }
        let validIDs = Set(node.answers.map(\.sentenceID))
        var choices = node.answers.map {
            DialogueChoice(id: "valid_\($0.sentenceID)", sentenceID: $0.sentenceID, isValidContinuation: true)
        }
        let distractorPool = allSentenceIDs.filter { !validIDs.contains($0) }
        let stableSeed = abs(state.currentNodeID.hashValue)
        let picked = stablePick(from: distractorPool, count: distractorCount, seed: stableSeed)
        choices += picked.map { DialogueChoice(id: "distractor_\($0)", sentenceID: $0, isValidContinuation: false) }
        return choices.sorted { stableSortKey($0.id, seed: stableSeed) < stableSortKey($1.id, seed: stableSeed) }
    }

    /// Learner picked `choice` at the session's current node.
    func submit(choice: DialogueChoice, state: DialogueSessionState, dialogue: PilotDialogue) -> DialogueStepOutcome {
        guard let node = dialogue.nodesByID[state.currentNodeID] else {
            return .incorrectChoice(newState: state, revealAnswer: false)
        }

        if let answer = node.answers.first(where: { $0.sentenceID == choice.sentenceID }) {
            var next = state
            next.history.append(DialogueTurn(nodeID: node.id, promptSentenceID: node.promptSentenceID, chosenSentenceID: choice.sentenceID))
            next.currentNodeID = answer.nextNodeID
            next.unsuccessfulAttemptsAtCurrentNode = 0

            if let nextNode = dialogue.nodesByID[answer.nextNodeID], nextNode.terminal {
                next.isCompleted = true
                return .completed(newState: next)
            }
            return .advanced(newState: next)
        }

        var next = state
        next.unsuccessfulAttemptsAtCurrentNode += 1
        let shouldReveal = next.unsuccessfulAttemptsAtCurrentNode >= maximumUnsuccessfulAttempts
        return .incorrectChoice(newState: next, revealAnswer: shouldReveal)
    }

    /// Applies the supported continuation after 3 unsuccessful attempts
    /// (Documentation/PRODUCT.md: "Nach maximal drei erfolglosen Versuchen unterstützte
    /// Fortsetzung"), using the first content-approved answer at the current node.
    func applySupportedContinuation(state: DialogueSessionState, dialogue: PilotDialogue) -> DialogueStepOutcome {
        guard let node = dialogue.nodesByID[state.currentNodeID], let firstAnswer = node.answers.first else {
            return .incorrectChoice(newState: state, revealAnswer: true)
        }
        let choice = DialogueChoice(id: "valid_\(firstAnswer.sentenceID)", sentenceID: firstAnswer.sentenceID, isValidContinuation: true)
        return submit(choice: choice, state: state, dialogue: dialogue)
    }

    // MARK: - Deterministic helpers (no Foundation randomness, so results are reproducible)

    private func stableSortKey(_ value: String, seed: Int) -> Int {
        var hasher = Hasher()
        hasher.combine(value)
        hasher.combine(seed)
        return hasher.finalize()
    }

    private func stablePick(from pool: [String], count: Int, seed: Int) -> [String] {
        guard !pool.isEmpty else { return [] }
        let sorted = pool.sorted { stableSortKey($0, seed: seed) < stableSortKey($1, seed: seed) }
        return Array(sorted.prefix(count))
    }
}
