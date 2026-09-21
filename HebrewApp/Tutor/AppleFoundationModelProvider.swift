import Foundation

#if canImport(FoundationModels)
import FoundationModels

/// Structured output constrained to a single field. The model is instructed to answer with one
/// of the allowed sentence IDs listed in the prompt; the caller still verifies the returned ID
/// against the allowed set before using it (Documentation/LOCAL_AI.md: never trust a single
/// model's self-report — "Keine Selbstbewertung des gleichen Modells als Qualitätsnachweis").
@available(iOS 26.0, *)
@Generable
struct TutorChoiceOutput {
    @Guide(description: "Exactly one of the allowed sentence IDs listed in the instructions, copied verbatim.")
    var chosenSentenceID: String
}

/// Uses exclusively the on-device `SystemLanguageModel`, gated behind the same real capability
/// checks as `CapabilityService` (Documentation/LOCAL_AI.md: "AppleFoundationModelProvider nutzt
/// ausschließlich das On-Device-Systemmodell, wenn verfügbar"). It only ever picks among the
/// current node's already content-approved `nextTurnID`s — never free text
/// (Documentation/LOCAL_AI.md "Sichere Pilotfunktion"). Any failure, timeout or out-of-set
/// answer is rejected here and surfaces as `TutorError`, which the caller routes back to
/// `GuidedDialogueProvider`.
@available(iOS 26.0, *)
final class AppleFoundationModelProvider: TutorProvider {
    /// LOCAL_AI.md pilot target: "Timeout spätestens 10 s."
    private let timeoutSeconds: TimeInterval = 10

    func suggestNextStep(
        for state: DialogueSessionState,
        dialogue: PilotDialogue
    ) async throws(TutorError) -> TutorSuggestion {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw TutorError.modelDisabledOrNotReady
        }

        guard let node = dialogue.nodesByID[state.currentNodeID], !node.answers.isEmpty else {
            throw TutorError.invalidTransition
        }
        let allowedIDs = node.answers.map(\.sentenceID)

        let instructions = Instructions(
            """
            Du hilfst in einem geführten hebräischen Lerndialog. Wähle ausschließlich eine der \
            folgenden erlaubten Satz-IDs als nächsten Schritt, niemals eine andere ID oder freien \
            Text: \(allowedIDs.joined(separator: ", ")).
            """
        )
        let prompt = Prompt(
            "Ziel des Dialogs: \(dialogue.objective). Aktueller Knoten: \(node.id). Antworte nur mit einer erlaubten ID."
        )

        let start = ContinuousClock.now
        do {
            let session = LanguageModelSession(instructions: instructions)
            // Only the plain String crosses the task-group boundary below — the SDK's
            // `Response<TutorChoiceOutput>` itself is not `Sendable`.
            let chosenSentenceID = try await withTimeout(seconds: timeoutSeconds) {
                try await session.respond(to: prompt, generating: TutorChoiceOutput.self).content.chosenSentenceID
            }
            guard allowedIDs.contains(chosenSentenceID) else {
                throw TutorError.invalidTransition
            }
            let elapsed = start.duration(to: .now)
            return TutorSuggestion(
                suggestedSentenceID: chosenSentenceID,
                provider: .appleFoundationModel,
                elapsedTime: Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
            )
        } catch let error as TutorError {
            throw error
        } catch is CancellationError {
            throw TutorError.cancelled
        } catch let error as LanguageModelSession.GenerationError {
            switch error {
            case .unsupportedLanguageOrLocale:
                throw TutorError.unsupportedHardwareOrLanguage
            case .exceededContextWindowSize, .assetsUnavailable, .guardrailViolation,
                 .unsupportedGuide, .decodingFailure, .rateLimited, .concurrentRequests, .refusal:
                throw TutorError.underlying("\(error)")
            @unknown default:
                throw TutorError.underlying("\(error)")
            }
        } catch {
            throw TutorError.underlying("\(error)")
        }
    }

    private func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw TutorError.timedOut
            }
            guard let result = try await group.next() else {
                throw TutorError.timedOut
            }
            group.cancelAll()
            return result
        }
    }
}
#endif
