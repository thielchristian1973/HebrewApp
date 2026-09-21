import Foundation

/// Documentation/PILOT.md: "Geräte-/OS-/Voice-/Modellinformationen in lokal exportierbarem
/// Bericht; keine personenbezogenen Sprachinhalte automatisch exportieren." This report never
/// includes recorded audio or transcripts — only capability facts and counts.
struct PilotDiagnosticReport: Codable {
    struct TTSItemResult: Codable {
        let itemID: String
        let played: Bool
    }

    let generatedAtUTC: Date
    let deviceModelIdentifier: String
    let systemName: String
    let systemVersion: String
    let selectedVoiceIdentifier: String?
    let availableHebrewVoiceCount: Int
    let textToSpeechAvailable: Bool
    let localRecognitionAvailable: Bool
    let localTutorAvailable: Bool
    let microphonePermissionGranted: Bool
    let contentCounts: PilotManifestCounts
    let ttsItemResults: [TTSItemResult]
    let openManualChecks: [String]

    func encodedText() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
