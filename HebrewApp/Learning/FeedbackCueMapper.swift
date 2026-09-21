import Foundation

/// What kind of confirmation cue (haptic + optional short tone) a moment in the pilot should
/// produce. Pure decision logic, deliberately separate from `FeedbackService` (which does the
/// actual system calls) so the *decision* of when to confirm/acknowledge is unit-testable
/// without touching `UINotificationFeedbackGenerator`/`AudioServicesPlaySystemSound`.
enum FeedbackCue: Sendable, Equatable {
    /// A genuine, learner-driven success — plays the warm confirm cue.
    case confirmSuccess
    /// A wrong pick or "didn't know it" — a neutral acknowledgment, never a punishing sound
    /// (CLAUDE.md: "keine Lernstrafen").
    case acknowledgeRetry
    /// No cue at all — e.g. an "unsure" self-report, or a step the learner did not actually
    /// answer (an auto-resolved supported continuation).
    case none
}

enum FeedbackCueMapper {
    static func forVocabularyAssessment(_ correctness: PilotCorrectness) -> FeedbackCue {
        switch correctness {
        case .correct: .confirmSuccess
        case .incorrect: .acknowledgeRetry
        case .unscored: .none
        }
    }

    /// `isAutoResolved` distinguishes an outcome the learner actually produced from one applied
    /// by `DialogueEngine.applySupportedContinuation` after three unsuccessful attempts — the
    /// latter is the app resolving the step for the learner, not a success to celebrate.
    static func forDialogueOutcome(_ outcome: DialogueStepOutcome, isAutoResolved: Bool) -> FeedbackCue {
        switch outcome {
        case .advanced, .completed:
            isAutoResolved ? .none : .confirmSuccess
        case .incorrectChoice:
            .acknowledgeRetry
        }
    }
}
