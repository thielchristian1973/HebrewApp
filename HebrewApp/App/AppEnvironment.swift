import Foundation
import SwiftData
import Observation

/// Composition root (ARCHITECTURE.md: "App: Composition root und Router"). Built once in
/// `HebrewAppApp` and shared via the SwiftUI environment. Holds only protocol references so
/// Features never import SwiftData/Speech/FoundationModels directly.
@MainActor
@Observable
final class AppEnvironment {
    let contentRepository: any ContentRepository
    let progressRepository: any ProgressRepository
    let synthesis: any SpeechSynthesizing
    let recording: any AudioRecording
    let playback: any AudioPlayback
    let transcription: any LocalTranscribing
    let capabilityService: CapabilityService
    let guidedDialogueProvider: any TutorProvider
    private let sessionCoordinator: AudioSessionCoordinator

    private(set) var contentBundle: PilotContentBundle?
    private(set) var contentLoadError: ContentLoadError?
    private(set) var capabilitySnapshot: CapabilitySnapshot?

    init(modelContainer: ModelContainer) {
        let synthesis = AVSpeechSynthesisService()
        let transcription = SFSpeechTranscriptionService()
        let sessionCoordinator = AudioSessionCoordinator()

        self.contentRepository = PilotContentLoader()
        self.progressRepository = SwiftDataProgressRepository(container: modelContainer)
        self.synthesis = synthesis
        self.recording = AVAudioRecorderService(sessionCoordinator: sessionCoordinator)
        self.playback = AVAudioPlaybackService()
        self.transcription = transcription
        self.capabilityService = CapabilityService(synthesis: synthesis, transcription: transcription)
        self.guidedDialogueProvider = GuidedDialogueProvider()
        self.sessionCoordinator = sessionCoordinator
    }

    /// The Apple on-device tutor, created only when the real capability check already reported
    /// it available — never speculatively instantiated (Documentation/LOCAL_AI.md: capability
    /// must be confirmed before any generation attempt).
    func makeAppleFoundationModelProviderIfAvailable() -> (any TutorProvider)? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), case .available = capabilitySnapshot?.localTutor {
            return AppleFoundationModelProvider()
        }
        return nil
        #else
        return nil
        #endif
    }

    func loadContentIfNeeded() async {
        guard contentBundle == nil, contentLoadError == nil else { return }
        do {
            contentBundle = try await contentRepository.loadPilotBundle()
        } catch {
            contentLoadError = error
        }
    }

    func refreshCapabilities() async {
        capabilitySnapshot = await capabilityService.snapshot()
    }

    func makeDialogueEngine() -> DialogueEngine? {
        guard let contentBundle else { return nil }
        return DialogueEngine(allSentenceIDs: contentBundle.sentences.map(\.id))
    }
}
