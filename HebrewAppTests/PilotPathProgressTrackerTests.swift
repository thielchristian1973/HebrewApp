import Testing
@testable import HebrewApp

@Suite("PilotPathProgressTracker")
struct PilotPathProgressTrackerTests {
    @Test("next incomplete step is the first step not yet completed")
    func nextIncompleteStep() {
        let path = PilotLearningPathCatalog.vorstellen
        var progress = PilotLearningPathProgress(pathID: path.id)
        #expect(PilotPathProgressTracker.nextIncompleteStep(path: path, progress: progress)?.id == path.steps.first?.id)

        progress.completedStepIDs = [path.steps[0].id]
        #expect(PilotPathProgressTracker.nextIncompleteStep(path: path, progress: progress)?.id == path.steps[1].id)
    }

    @Test("path is complete only once every step id is present")
    func isComplete() {
        let path = PilotLearningPathCatalog.cafe
        var progress = PilotLearningPathProgress(pathID: path.id)
        #expect(!PilotPathProgressTracker.isComplete(path: path, progress: progress))

        progress.completedStepIDs = path.steps.map(\.id)
        #expect(PilotPathProgressTracker.isComplete(path: path, progress: progress))
    }

    @Test("completing a step is idempotent")
    func completingStepIsIdempotent() {
        let path = PilotLearningPathCatalog.vorstellen
        let progress = PilotLearningPathProgress(pathID: path.id)
        let firstStepID = path.steps[0].id

        let once = PilotPathProgressTracker.completingStep(firstStepID, in: progress, path: path)
        let twice = PilotPathProgressTracker.completingStep(firstStepID, in: once, path: path)
        #expect(twice.completedStepIDs == [firstStepID])
    }

    @Test("catalog paths only reference existing pilot fixture IDs")
    func catalogReferencesRealFixtures() async throws {
        let bundle = try await PilotContentLoader(bundle: .main).loadPilotBundle()
        for path in PilotLearningPathCatalog.all {
            for step in path.steps {
                switch step.kind {
                case .vocabulary(let ids):
                    for id in ids { #expect(bundle.lexemesByID[id] != nil, "missing lexeme \(id)") }
                case .sentences(let ids):
                    for id in ids { #expect(bundle.sentencesByID[id] != nil, "missing sentence \(id)") }
                case .dialogue(let id):
                    #expect(bundle.dialogue(id: id) != nil, "missing dialogue \(id)")
                }
            }
        }
    }
}
