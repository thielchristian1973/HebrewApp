import AVFAudio
import Foundation

/// System TTS via `AVSpeechSynthesizer` (Documentation/SPEECH_SPEC.md: "System-TTS über
/// AVSpeechSynthesizer, verfügbare hebräische Voices abfragen; he-IL bevorzugen"). Confined to
/// the main actor because `AVSpeechSynthesizer`/`AVSpeechUtterance` are not `Sendable`
/// (`NS_SWIFT_NONSENDABLE`, verified against the installed SDK headers) and ARCHITECTURE.md
/// requires unsendable Apple objects to stay on their intended actor rather than being passed
/// through `Task.detached`.
@MainActor
protocol SpeechSynthesizing: AnyObject {
    /// Real installed voices for the given BCP-47 language prefix (e.g. "he"). Never hardcoded
    /// (SPEECH_SPEC.md: "Voice-ID und Qualität nicht hardcoden"). Deliberately `nonisolated`:
    /// `AVSpeechSynthesisVoice` is `NS_SWIFT_SENDABLE`, and the underlying system query
    /// (`speechVoices()`) can be slow on a cold asset-catalog cache — it must never block the
    /// main actor (observed as a multi-minute app-launch hang on a freshly booted simulator
    /// before this was split out).
    nonisolated func availableVoices(languagePrefix: String) -> [VoiceOption]
    var isSpeaking: Bool { get }
    func speak(text: String, voiceIdentifier: String, rate: SpeechRate) async throws(SpeechSynthesisError)
    func stopSpeaking()
}

/// `@unchecked Sendable`: the main-actor-isolated methods (`speak`, `stopSpeaking`, the delegate
/// callbacks) exclusively touch `synthesizer`/`pendingContinuation`; the `nonisolated`
/// `availableVoices` touches neither — it only calls the Sendable, stateless
/// `AVSpeechSynthesisVoice.speechVoices()`. No stored state is ever reachable from both an
/// isolated and a nonisolated call path, so there is no actual data race for the compiler to
/// miss here. This conformance exists solely so `CapabilityService` can call
/// `availableVoices` from a detached task without hopping onto the main actor.
@MainActor
final class AVSpeechSynthesisService: NSObject, SpeechSynthesizing, @unchecked Sendable {
    private let synthesizer = AVSpeechSynthesizer()
    private var pendingContinuation: CheckedContinuation<Void, any Error>?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    var isSpeaking: Bool { synthesizer.isSpeaking }

    nonisolated func availableVoices(languagePrefix: String = "he") -> [VoiceOption] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(languagePrefix) }
            .map { voice in
                VoiceOption(
                    id: voice.identifier,
                    name: voice.name,
                    languageCode: voice.language,
                    quality: Self.mapQuality(voice.quality)
                )
            }
            .sorted { $0.quality > $1.quality }
    }

    func speak(text: String, voiceIdentifier: String, rate: SpeechRate) async throws(SpeechSynthesisError) {
        guard let voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) else {
            throw SpeechSynthesisError.voiceNotFound(voiceIdentifier)
        }
        stopSpeaking()

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = rate == .slow
            ? AVSpeechUtteranceDefaultSpeechRate * 0.6
            : AVSpeechUtteranceDefaultSpeechRate

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                self.pendingContinuation = continuation
                self.synthesizer.speak(utterance)
            }
        } catch is CancellationError {
            throw SpeechSynthesisError.cancelled
        } catch {
            throw SpeechSynthesisError.cancelled
        }
    }

    func stopSpeaking() {
        guard synthesizer.isSpeaking else { return }
        _ = synthesizer.stopSpeaking(at: .immediate)
    }

    private func finishPending(cancelled: Bool) {
        guard let pendingContinuation else { return }
        self.pendingContinuation = nil
        if cancelled {
            pendingContinuation.resume(throwing: CancellationError())
        } else {
            pendingContinuation.resume()
        }
    }

    private nonisolated static func mapQuality(_ quality: AVSpeechSynthesisVoiceQuality) -> VoiceQuality {
        switch quality {
        case .default: .default
        case .enhanced: .enhanced
        case .premium: .premium
        @unknown default: .unknown
        }
    }
}

extension AVSpeechSynthesisService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in self?.finishPending(cancelled: false) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in self?.finishPending(cancelled: true) }
    }
}
