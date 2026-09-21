import Foundation

/// Why a capability is currently unavailable. Kept separate per feature (TTS / ASR / Tutor)
/// because each has independent device, OS and language conditions (Documentation/SOURCES.md:
/// "TTS, ASR und Textmodell haben voneinander unabhängige Sprach-/Gerätebedingungen").
enum UnavailabilityReason: Sendable, Hashable {
    case deviceNotEligible
    case osVersionTooOld
    case featureDisabledByUser
    case languageNotSupported
    case assetNotInstalled
    case permissionDenied
    case permissionNotRequested
    case modelNotReady
    case unknown(String)
}

/// Text-to-speech availability for a specific requested locale. Never a boolean — a missing
/// voice must surface as a concrete setup hint, not a silent fallback to German/English
/// (Documentation/DECISIONS.md correction 1).
enum TextToSpeechCapability: Sendable, Hashable {
    case available(voiceCount: Int)
    case unavailable(UnavailabilityReason)
}

/// On-device speech recognition availability. Only ever offered when both the recognizer and
/// its on-device path are confirmed for the locale (Documentation/SPEECH_SPEC.md).
enum LocalRecognitionCapability: Sendable, Hashable {
    case available
    case unavailable(UnavailabilityReason)
}

/// Local generative tutor availability. Distinct from `LocalRecognitionCapability`/
/// `TextToSpeechCapability` — Documentation/LOCAL_AI.md's "zwei getrennte Fragen": can the
/// model run at all, and (separately, not modeled as a boolean here) is its Hebrew good enough.
enum LocalTutorCapability: Sendable, Hashable {
    case available
    case unavailable(UnavailabilityReason)
}

/// Microphone recording permission, independent of ASR — recording must work even when speech
/// recognition itself is unsupported (Documentation/SPEECH_SPEC.md).
enum MicrophonePermission: Sendable, Hashable {
    case notRequested
    case granted
    case denied
}

/// Snapshot of every device/OS/feature capability the pilot screen and guided flows need to
/// branch on. Produced by `CapabilityService`; a pure value so it can be unit tested without
/// touching real hardware APIs.
struct CapabilitySnapshot: Sendable, Hashable {
    let textToSpeech: TextToSpeechCapability
    let localRecognition: LocalRecognitionCapability
    let localTutor: LocalTutorCapability
    let microphonePermission: MicrophonePermission
    let deviceModelIdentifier: String
    let systemName: String
    let systemVersion: String
}
