import Testing
import Foundation
@testable import HebrewApp

@Suite("DialogueEngine")
struct DialogueEngineTests {
    private func makeGreetingDialogue() -> PilotDialogue {
        PilotDialogue(
            id: "dialog_test",
            title: "Test",
            objective: "Test objective",
            startNodeID: "n1",
            nodes: [
                PilotDialogueNode(id: "n1", promptSentenceID: "sent_001", answers: [
                    PilotDialogueAnswer(sentenceID: "sent_002", nextNodeID: "n2")
                ], terminal: false),
                PilotDialogueNode(id: "n2", promptSentenceID: "sent_003", answers: [], terminal: true)
            ],
            reviewStatus: .draft
        )
    }

    @Test("submitting the valid answer advances to the next node")
    func validAnswerAdvances() {
        let dialogue = makeGreetingDialogue()
        let engine = DialogueEngine(allSentenceIDs: ["sent_001", "sent_002", "sent_003", "sent_099"])
        let state = engine.startSession(for: dialogue)

        let choice = DialogueChoice(id: "valid_sent_002", sentenceID: "sent_002", isValidContinuation: true)
        let outcome = engine.submit(choice: choice, state: state, dialogue: dialogue)

        guard case .completed(let newState) = outcome else {
            Issue.record("Expected completion, got \(outcome)")
            return
        }
        #expect(newState.currentNodeID == "n2")
        #expect(newState.isCompleted)
        #expect(newState.history.count == 1)
    }

    @Test("submitting a distractor increments the unsuccessful counter without advancing")
    func distractorDoesNotAdvance() {
        let dialogue = makeGreetingDialogue()
        let engine = DialogueEngine(allSentenceIDs: ["sent_001", "sent_002", "sent_003", "sent_099"])
        let state = engine.startSession(for: dialogue)

        let distractor = DialogueChoice(id: "distractor_sent_099", sentenceID: "sent_099", isValidContinuation: false)
        let outcome = engine.submit(choice: distractor, state: state, dialogue: dialogue)

        guard case .incorrectChoice(let newState, let reveal) = outcome else {
            Issue.record("Expected incorrectChoice, got \(outcome)")
            return
        }
        #expect(newState.currentNodeID == "n1")
        #expect(newState.unsuccessfulAttemptsAtCurrentNode == 1)
        #expect(!reveal)
    }

    @Test("reveal triggers only after three unsuccessful attempts")
    func revealAfterThreeAttempts() {
        let dialogue = makeGreetingDialogue()
        let engine = DialogueEngine(allSentenceIDs: ["sent_001", "sent_002", "sent_003", "sent_099"])
        var state = engine.startSession(for: dialogue)
        let distractor = DialogueChoice(id: "distractor_sent_099", sentenceID: "sent_099", isValidContinuation: false)

        for expectedCount in 1...3 {
            let outcome = engine.submit(choice: distractor, state: state, dialogue: dialogue)
            guard case .incorrectChoice(let newState, let reveal) = outcome else {
                Issue.record("Expected incorrectChoice")
                return
            }
            state = newState
            #expect(newState.unsuccessfulAttemptsAtCurrentNode == expectedCount)
            #expect(reveal == (expectedCount == 3))
        }
    }

    @Test("choices always include every content-approved answer")
    func choicesIncludeAllValidAnswers() {
        let dialogue = makeGreetingDialogue()
        let engine = DialogueEngine(allSentenceIDs: ["sent_001", "sent_002", "sent_003", "sent_099", "sent_100"])
        let state = engine.startSession(for: dialogue)
        let choices = engine.choices(for: state, dialogue: dialogue)
        #expect(choices.contains { $0.sentenceID == "sent_002" && $0.isValidContinuation })
    }

    @Test("applying the supported continuation always completes an unresolved node")
    func supportedContinuationResolves() {
        let dialogue = makeGreetingDialogue()
        let engine = DialogueEngine(allSentenceIDs: ["sent_001", "sent_002", "sent_003"])
        let state = engine.startSession(for: dialogue)
        let outcome = engine.applySupportedContinuation(state: state, dialogue: dialogue)
        guard case .completed = outcome else {
            Issue.record("Expected completion via supported continuation, got \(outcome)")
            return
        }
    }
}
