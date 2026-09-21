import Foundation

/// Failures loading and verifying the bundled pilot content. Never silently substitutes empty
/// data — a load failure must surface, not degrade into a blank screen
/// (ARCHITECTURE.md: "ContentRepository lädt validierte immutable Kursdaten").
enum ContentLoadError: Error, Sendable, Equatable {
    case resourceNotFound(String)
    case decodingFailed(String)
    case hashMismatch(file: String)
    case countMismatch(expected: Int, actual: Int, kind: String)
    case duplicateID(String)
    case unsupportedSchemaVersion(Int)
}

/// Failures from the persistence layer. `corruptImportRejected` guards
/// Documentation/DATA_MODEL.md's "korrupter Import verändert DB nicht".
enum PersistenceError: Error, Sendable, Equatable {
    case saveFailed(String)
    case fetchFailed(String)
    case corruptImportRejected(String)
}

/// Failures from the recording/playback pipeline. `permissionDenied` is distinct from
/// `deviceUnavailable` so the UI can show a precise, honest message.
enum RecordingError: Error, Sendable, Equatable {
    case permissionDenied
    case deviceUnavailable
    case fileWriteFailed(String)
    case alreadyRecording
    case maximumDurationExceeded
    case cancelled
}

enum SpeechSynthesisError: Error, Sendable, Equatable {
    case voiceNotFound(String)
    case cancelled
}

enum PlaybackError: Error, Sendable, Equatable {
    case fileNotFound
    case decodeFailed(String)
    case cancelled
}

/// Failures from local speech recognition. `notSupportedOnDevice` must be checked *before*
/// ever starting a request — this type exists so callers cannot accidentally ignore that check
/// (Documentation/SPEECH_SPEC.md: "Keine Erkennung auslösen, die Netzwerk benötigt").
enum TranscriptionError: Error, Sendable, Equatable {
    case notSupportedOnDevice
    case permissionDenied
    case assetsUnavailable
    case timedOut
    case cancelled
    case recognitionFailed(String)
}

/// Failures from the optional local tutor providers. Every case routes back to the guided
/// dialogue engine — none of them are recoverable by retry-with-network
/// (Documentation/LOCAL_AI.md: "Unbekannte IDs, ungültige Übergänge, Timeout oder Fehler führen
/// in denselben geführten Dialog zurück").
enum TutorError: Error, Sendable, Equatable {
    case unsupportedHardwareOrLanguage
    case modelDisabledOrNotReady
    case timedOut
    case cancelled
    case invalidTransition
    case unknownID(String)
    case underlying(String)
}
