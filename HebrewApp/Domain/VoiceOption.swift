import Foundation

/// Quality tier as reported by the OS for an installed speech voice. Mirrors
/// `AVSpeechSynthesisVoiceQuality` without leaking the AVFAudio type into Domain
/// (ARCHITECTURE.md: "Domain unabhängig von ... Apple Speech").
enum VoiceQuality: String, Sendable, Hashable, Comparable {
    case `default`
    case enhanced
    case premium
    case unknown

    private var rank: Int {
        switch self {
        case .default: 0
        case .enhanced: 1
        case .premium: 2
        case .unknown: -1
        }
    }

    static func < (lhs: VoiceQuality, rhs: VoiceQuality) -> Bool { lhs.rank < rhs.rank }
}

/// A speech-synthesis voice actually installed on this device, as reported at runtime.
/// Never hardcoded (Documentation/SPEECH_SPEC.md: "Voice-ID und Qualität nicht hardcoden").
struct VoiceOption: Sendable, Hashable, Identifiable {
    let id: String
    let name: String
    let languageCode: String
    let quality: VoiceQuality
}

/// User-selectable playback rate. Documentation/SPEECH_SPEC.md is explicit that "langsam" is a
/// synthesizer rate hint, not a guaranteed 0.75× timestretch of real audio.
enum SpeechRate: String, Sendable, CaseIterable {
    case normal
    case slow
}
