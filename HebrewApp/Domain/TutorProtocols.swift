import Foundation

enum TutorProviderKind: String, Sendable, Hashable {
    case guided
    case appleFoundationModel
}

/// A bounded tutor suggestion: at most a pointer at one of the *already valid* answers for the
/// current dialogue node, optionally a short pre-authored hint. Never free text
/// (Documentation/LOCAL_AI.md "Sichere Pilotfunktion" — the tutor "wählt aus zulässigen
/// nextTurnIDs/feedbackIDs"). Matches the shape of Documentation/DATA_MODEL.md's `TutorResult`,
/// reduced to the pilot's needs.
struct TutorSuggestion: Sendable, Equatable {
    let suggestedSentenceID: String?
    let provider: TutorProviderKind
    let elapsedTime: TimeInterval
}

/// A tutor provider proposes which already-valid dialogue continuation to nudge the learner
/// toward. It never decides the transition itself — `DialogueEngine` alone does that
/// (ARCHITECTURE.md: "DialogueEngine allein entscheidet über Übergang/Ergebnis"). Any error,
/// timeout or unsupported state must be caught by the caller and routed back to the guided
/// dialogue path.
protocol TutorProvider: Sendable {
    func suggestNextStep(
        for state: DialogueSessionState,
        dialogue: PilotDialogue
    ) async throws(TutorError) -> TutorSuggestion
}
