import AVFAudio
import Foundation
import Speech
import UIKit

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Aggregates every device/OS/feature capability the pilot needs to branch on, checked fresh
/// each time rather than cached indefinitely (voices/permissions can change while the app runs).
/// Every framework check here is a *capability* check only — never a claim about Hebrew
/// linguistic quality (Documentation/LOCAL_AI.md "zwei getrennte Fragen").
///
/// Not main-actor-isolated on purpose: `snapshot()` calls into `SpeechSynthesizing`'s and
/// `LocalTranscribing`'s `nonisolated` capability checks, which can trigger slow, uncached
/// system asset-catalog IPC (TTS voice listing, Speech recognizer/model lookup) on first call —
/// observed as a multi-minute app-launch hang on a freshly booted simulator when this ran
/// synchronously on the main actor. `snapshot()` runs that work on a detached task instead.
final class CapabilityService: Sendable {
    private let hebrewLocaleIdentifier = "he-IL"
    private let synthesis: any SpeechSynthesizing & Sendable
    private let transcription: any LocalTranscribing & Sendable

    init(synthesis: any SpeechSynthesizing & Sendable, transcription: any LocalTranscribing & Sendable) {
        self.synthesis = synthesis
        self.transcription = transcription
    }

    func snapshot() async -> CapabilitySnapshot {
        // UIDevice is main-actor-isolated; read its (instant) properties up front, then move the
        // potentially slow capability checks off the main actor.
        let (systemName, systemVersion) = await MainActor.run {
            (UIDevice.current.systemName, UIDevice.current.systemVersion)
        }

        return await Task.detached(priority: .userInitiated) { [synthesis, transcription, hebrewLocaleIdentifier] in
            CapabilitySnapshot(
                textToSpeech: Self.textToSpeechCapability(synthesis: synthesis),
                localRecognition: transcription.capability(localeIdentifier: hebrewLocaleIdentifier),
                localTutor: Self.localTutorCapability(),
                microphonePermission: Self.microphonePermission(),
                deviceModelIdentifier: Self.deviceModelIdentifier(),
                systemName: systemName,
                systemVersion: systemVersion
            )
        }.value
    }

    private static func textToSpeechCapability(synthesis: any SpeechSynthesizing) -> TextToSpeechCapability {
        let voices = synthesis.availableVoices(languagePrefix: "he")
        return voices.isEmpty ? .unavailable(.assetNotInstalled) : .available(voiceCount: voices.count)
    }

    private static func microphonePermission() -> MicrophonePermission {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: .granted
        case .denied: .denied
        case .undetermined: .notRequested
        @unknown default: .notRequested
        }
    }

    /// FoundationModels requires iOS 26.0 at minimum in the installed SDK — there is no iOS 17
    /// entry point at all (verified against FoundationModels.swiftinterface). The deployment
    /// target stays 17.0; this capability is simply unavailable below iOS 26.
    private static func localTutorCapability() -> LocalTutorCapability {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else {
            return .unavailable(.osVersionTooOld)
        }
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            let hebrew = Locale.Language(languageCode: Locale.LanguageCode("he"), region: Locale.Region("IL"))
            let german = Locale.Language(languageCode: Locale.LanguageCode("de"), region: Locale.Region("DE"))
            guard model.supportsLocale(Locale(identifier: "he_IL")) || model.supportedLanguages.contains(hebrew) else {
                return .unavailable(.languageNotSupported)
            }
            guard model.supportsLocale(Locale(identifier: "de_DE")) || model.supportedLanguages.contains(german) else {
                return .unavailable(.languageNotSupported)
            }
            return .available
        case .unavailable(.deviceNotEligible):
            return .unavailable(.deviceNotEligible)
        case .unavailable(.appleIntelligenceNotEnabled):
            return .unavailable(.featureDisabledByUser)
        case .unavailable(.modelNotReady):
            return .unavailable(.modelNotReady)
        @unknown default:
            return .unavailable(.unknown("SystemLanguageModel.Availability.unknown"))
        }
        #else
        return .unavailable(.osVersionTooOld)
        #endif
    }

    private static func deviceModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        return machineMirror.children.reduce(into: "") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            identifier += String(UnicodeScalar(UInt8(value)))
        }
    }
}
