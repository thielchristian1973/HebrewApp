import Testing
@testable import HebrewApp

@Suite("FeedbackCueMapper")
struct FeedbackCueMapperTests {
    @Test("a confident correct self-assessment confirms success")
    func vocabularyCorrect() {
        #expect(FeedbackCueMapper.forVocabularyAssessment(.correct) == .confirmSuccess)
    }

    @Test("an incorrect self-assessment acknowledges retry, never punishes")
    func vocabularyIncorrect() {
        #expect(FeedbackCueMapper.forVocabularyAssessment(.incorrect) == .acknowledgeRetry)
    }

    @Test("an unsure self-assessment gives no confirm/retry cue")
    func vocabularyUnsure() {
        #expect(FeedbackCueMapper.forVocabularyAssessment(.unscored) == .none)
    }

    private func makeDialogue() -> PilotDialogue {
        PilotDialogue(
            id: "d", title: "t", objective: "o", startNodeID: "a",
            nodes: [
                PilotDialogueNode(id: "a", promptSentenceID: "s1", answers: [PilotDialogueAnswer(sentenceID: "s2", nextNodeID: "b")], terminal: false),
                PilotDialogueNode(id: "b", promptSentenceID: "s3", answers: [], terminal: true)
            ],
            reviewStatus: .draft
        )
    }

    @Test("advancing to the next node confirms success")
    func dialogueAdvanced() {
        let dialogue = makeDialogue()
        let engine = DialogueEngine(allSentenceIDs: ["s1", "s2", "s3"])
        let state = engine.startSession(for: dialogue)
        let outcome = engine.submit(
            choice: DialogueChoice(id: "valid_s2", sentenceID: "s2", isValidContinuation: true),
            state: state,
            dialogue: dialogue
        )
        #expect(FeedbackCueMapper.forDialogueOutcome(outcome, isAutoResolved: false) == .confirmSuccess)
    }

    @Test("picking a distractor acknowledges retry")
    func dialogueIncorrectChoice() {
        let dialogue = makeDialogue()
        let engine = DialogueEngine(allSentenceIDs: ["s1", "s2", "s3", "s9"])
        let state = engine.startSession(for: dialogue)
        let outcome = engine.submit(
            choice: DialogueChoice(id: "distractor_s9", sentenceID: "s9", isValidContinuation: false),
            state: state,
            dialogue: dialogue
        )
        #expect(FeedbackCueMapper.forDialogueOutcome(outcome, isAutoResolved: false) == .acknowledgeRetry)
    }

    @Test("an auto-resolved supported continuation gives no success cue, since the learner did not answer it")
    func dialogueAutoResolvedAdvance() {
        let dialogue = makeDialogue()
        let engine = DialogueEngine(allSentenceIDs: ["s1", "s2", "s3"])
        let state = engine.startSession(for: dialogue)
        let outcome = engine.applySupportedContinuation(state: state, dialogue: dialogue)
        #expect(FeedbackCueMapper.forDialogueOutcome(outcome, isAutoResolved: true) == .none)
    }
}
