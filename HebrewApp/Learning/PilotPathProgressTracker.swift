import Foundation

/// Pure progression logic for a `PilotLearningPath` (ARCHITECTURE.md keeps learning rules out of
/// Views: "keine Lernregeln in Views"). Resumability (Documentation/PILOT.md: "beim Neustart
/// fortsetzbar") is just replaying `completedStepIDs` against the path's step list.
enum PilotPathProgressTracker {
    static func nextIncompleteStep(path: PilotLearningPath, progress: PilotLearningPathProgress) -> PilotLearningStep? {
        path.steps.first { !progress.completedStepIDs.contains($0.id) }
    }

    static func isComplete(path: PilotLearningPath, progress: PilotLearningPathProgress) -> Bool {
        Set(path.steps.map(\.id)).isSubset(of: Set(progress.completedStepIDs))
    }

    static func completingStep(_ stepID: String, in progress: PilotLearningPathProgress, path: PilotLearningPath) -> PilotLearningPathProgress {
        var updated = progress
        if !updated.completedStepIDs.contains(stepID) {
            updated.completedStepIDs.append(stepID)
        }
        updated.isCompleted = isComplete(path: path, progress: updated)
        return updated
    }
}
