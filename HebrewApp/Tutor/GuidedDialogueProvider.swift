import Foundation

/// The always-available tutor provider: a fully implemented deterministic rule, not an AI stand-in
/// (Documentation/LOCAL_AI.md: "GuidedDialogueProvider ist vollständig implementierter lokaler
/// Zustandsautomat, keine KI-Attrappe"). It always nudges toward the first content-approved
/// continuation at the current node, so the guided dialogue works completely without AI or a
/// microphone (Documentation/PILOT.md acceptance criteria).
struct GuidedDialogueProvider: TutorProvider {
    func suggestNextStep(
        for state: DialogueSessionState,
        dialogue: PilotDialogue
    ) async throws(TutorError) -> TutorSuggestion {
        guard let node = dialogue.nodesByID[state.currentNodeID] else {
            throw TutorError.invalidTransition
        }
        return TutorSuggestion(
            suggestedSentenceID: node.answers.first?.sentenceID,
            provider: .guided,
            elapsedTime: 0
        )
    }
}
