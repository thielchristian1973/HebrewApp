import Foundation

/// Rendering state for a single step dot in a path's progress indicator.
enum StepDotState: Sendable, Equatable {
    case completed
    case current
    case upcoming
}

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

    /// How many of `paths` are fully completed, per the matching entry in `progress` (a path
    /// with no matching entry counts as not started, not an error).
    static func completedPathCount(paths: [PilotLearningPath], progress: [PilotLearningPathProgress]) -> Int {
        let progressByID = Dictionary(uniqueKeysWithValues: progress.map { ($0.pathID, $0) })
        return paths.filter { path in
            guard let pathProgress = progressByID[path.id] else { return false }
            return isComplete(path: path, progress: pathProgress)
        }.count
    }

    /// One dot state per step, for a step-progress indicator: completed steps first, then a
    /// single `.current` marker at the next incomplete step, then `.upcoming` for the rest. Once
    /// every step is completed, every dot reports `.completed` (there is no "current" step left).
    static func stepDotStates(path: PilotLearningPath, progress: PilotLearningPathProgress) -> [StepDotState] {
        let currentStepID = nextIncompleteStep(path: path, progress: progress)?.id
        return path.steps.map { step in
            if progress.completedStepIDs.contains(step.id) {
                .completed
            } else if step.id == currentStepID {
                .current
            } else {
                .upcoming
            }
        }
    }
}
