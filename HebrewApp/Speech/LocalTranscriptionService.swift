import Foundation
import Speech

/// Strictly on-device speech recognition. `SFSpeechRecognizer`/`SFSpeechRecognitionTask` carry
/// no `Sendable` annotation in the installed SDK, so the stateful recognition path
/// (`transcribe`/`runRecognition`, which stores `activeTask`) stays main-actor-confined like the
/// other Speech services. `capability`/`requestAuthorizationIfNeeded` are `nonisolated` — they
/// create-and-immediately-discard a recognizer within one call rather than sharing it across
/// actors, which stays within the Sendable-safety rule while keeping slow first-time asset
/// queries off the main actor. Recognition is only ever attempted once `supportsOnDeviceRecognition`
/// is confirmed true for the requested locale, and `requiresOnDeviceRecognition` is always set
/// (Documentation/SPEECH_SPEC.md: "Request nur starten, wenn diese Capability vorliegt;
/// requiresOnDeviceRecognition zwingend aktivieren. ... Keine Erkennung auslösen, die Netzwerk
/// benötigt.").
@MainActor
protocol LocalTranscribing: AnyObject {
    /// Deliberately `nonisolated`: creating an `SFSpeechRecognizer` to read its availability
    /// properties triggers a synchronous system asset-catalog query that can be slow on a cold
    /// cache — it must never block the main actor (same reasoning as
    /// `SpeechSynthesizing.availableVoices`).
    nonisolated func capability(localeIdentifier: String) -> LocalRecognitionCapability
    nonisolated func requestAuthorizationIfNeeded() async -> Bool
    /// Transcribes an already-recorded file. Never used for live network recognition — the
    /// file already exists locally, and `requiresOnDeviceRecognition` is forced on.
    func transcribe(fileURL: URL, localeIdentifier: String, timeout: TimeInterval) async throws(TranscriptionError) -> String
}

/// `@unchecked Sendable`: the main-actor-isolated stateful path (`transcribe`/`runRecognition`)
/// exclusively touches `activeTask`; the `nonisolated` `capability`/`requestAuthorizationIfNeeded`
/// touch no stored state at all — they create-and-discard a fresh `SFSpeechRecognizer` locally or
/// call static APIs. No stored state is reachable from both an isolated and a nonisolated call
/// path, so there is no actual data race here. This conformance exists solely so
/// `CapabilityService` can call these methods from a detached task without hopping onto the main
/// actor.
@MainActor
final class SFSpeechTranscriptionService: NSObject, LocalTranscribing, @unchecked Sendable {
    private var activeTask: SFSpeechRecognitionTask?

    nonisolated func capability(localeIdentifier: String) -> LocalRecognitionCapability {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)) else {
            return .unavailable(.languageNotSupported)
        }
        guard recognizer.isAvailable else {
            return .unavailable(.assetNotInstalled)
        }
        guard recognizer.supportsOnDeviceRecognition else {
            return .unavailable(.assetNotInstalled)
        }
        switch SFSpeechRecognizer.authorizationStatus() {
        case .denied, .restricted:
            return .unavailable(.permissionDenied)
        case .notDetermined, .authorized:
            return .available
        @unknown default:
            return .available
        }
    }

    nonisolated func requestAuthorizationIfNeeded() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            break
        @unknown default:
            break
        }
        return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func transcribe(
        fileURL: URL,
        localeIdentifier: String,
        timeout: TimeInterval
    ) async throws(TranscriptionError) -> String {
        guard case .available = capability(localeIdentifier: localeIdentifier) else {
            throw TranscriptionError.notSupportedOnDevice
        }
        guard await requestAuthorizationIfNeeded() else {
            throw TranscriptionError.permissionDenied
        }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)) else {
            throw TranscriptionError.notSupportedOnDevice
        }

        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false

        do {
            return try await withTimeout(seconds: timeout) { [weak self] in
                try await self?.runRecognition(recognizer: recognizer, request: request) ?? ""
            }
        } catch let error as TranscriptionError {
            throw error
        } catch {
            throw TranscriptionError.recognitionFailed("\(error)")
        }
    }

    private func runRecognition(
        recognizer: SFSpeechRecognizer,
        request: SFSpeechURLRecognitionRequest
    ) async throws(TranscriptionError) -> String {
        do {
            return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, any Error>) in
                var didResume = false
                self.activeTask = recognizer.recognitionTask(with: request) { result, error in
                    Task { @MainActor in
                        guard !didResume else { return }
                        if let error {
                            didResume = true
                            continuation.resume(throwing: TranscriptionError.recognitionFailed("\(error)"))
                            return
                        }
                        guard let result, result.isFinal else { return }
                        didResume = true
                        continuation.resume(returning: result.bestTranscription.formattedString)
                    }
                }
            }
        } catch let error as TranscriptionError {
            throw error
        } catch {
            throw TranscriptionError.recognitionFailed("\(error)")
        }
    }

    private func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @escaping @MainActor () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw TranscriptionError.timedOut
            }
            guard let result = try await group.next() else {
                throw TranscriptionError.timedOut
            }
            group.cancelAll()
            return result
        }
    }
}
