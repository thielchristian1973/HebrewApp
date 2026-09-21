import AVFAudio
import Foundation

/// Records to a local file via `AVAudioRecorder`. Confined to the main actor for the same
/// reason as `SpeechSynthesizing` — `AVAudioRecorder`/`AVAudioApplication` are reference types
/// tied to shared hardware state and must not be casually shared across concurrency domains.
@MainActor
protocol AudioRecording: AnyObject {
    var isRecording: Bool { get }
    func currentPermission() -> MicrophonePermission
    /// Only requests the OS permission prompt; never called automatically at launch
    /// (Documentation/SPEECH_SPEC.md: "Mikrofonberechtigung erst beim ersten
    /// Aufnahmeversuch").
    func requestPermission() async -> MicrophonePermission
    func startRecording() async throws(RecordingError) -> Void
    /// Stops and returns the temporary file URL. The caller owns cleanup
    /// (Documentation/ARCHITECTURE.md: "Temporäre Aufnahmen nach Verlassen/Auswertung
    /// löschen").
    func stopRecording() throws(RecordingError) -> URL
    func cancelRecording()
    func deleteRecording(at url: URL)
}

@MainActor
final class AVAudioRecorderService: NSObject, AudioRecording {
    /// Documentation/SPEECH_SPEC.md: "Maximal 60 Sekunden je Übung als initiale Grenze."
    static let maximumDuration: TimeInterval = 60

    private let sessionCoordinator: AudioSessionCoordinator
    private var recorder: AVAudioRecorder?
    private var currentFileURL: URL?

    init(sessionCoordinator: AudioSessionCoordinator) {
        self.sessionCoordinator = sessionCoordinator
    }

    var isRecording: Bool { recorder?.isRecording ?? false }

    func currentPermission() -> MicrophonePermission {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: .granted
        case .denied: .denied
        case .undetermined: .notRequested
        @unknown default: .notRequested
        }
    }

    func requestPermission() async -> MicrophonePermission {
        if case .granted = currentPermission() { return .granted }
        let granted = await AVAudioApplication.requestRecordPermission()
        return granted ? .granted : .denied
    }

    func startRecording() async throws(RecordingError) {
        guard !isRecording else { throw RecordingError.alreadyRecording }

        let permission = await requestPermission()
        guard permission == .granted else { throw RecordingError.permissionDenied }

        try sessionCoordinator.activateRecordAndPlaybackSession()

        let fileURL = Self.makeTemporaryFileURL()
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let newRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            newRecorder.delegate = self
            guard newRecorder.record(forDuration: Self.maximumDuration) else {
                throw RecordingError.deviceUnavailable
            }
            recorder = newRecorder
            currentFileURL = fileURL
        } catch let error as RecordingError {
            throw error
        } catch {
            throw RecordingError.fileWriteFailed("\(error)")
        }
    }

    func stopRecording() throws(RecordingError) -> URL {
        guard let recorder, let currentFileURL else { throw RecordingError.deviceUnavailable }
        recorder.stop()
        self.recorder = nil
        return currentFileURL
    }

    func cancelRecording() {
        guard let recorder else { return }
        recorder.stop()
        recorder.deleteRecording()
        self.recorder = nil
        if let currentFileURL {
            deleteRecording(at: currentFileURL)
        }
        currentFileURL = nil
    }

    func deleteRecording(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    private static func makeTemporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("pilot-recording-\(UUID().uuidString)")
            .appendingPathExtension("m4a")
    }
}

extension AVAudioRecorderService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        // The 60s hard cap stops the recorder itself; `stopRecording()` already cleared our
        // reference for a user-initiated stop, so there is nothing to reconcile here beyond
        // logging in a future diagnostics pass.
    }
}
