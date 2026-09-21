import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @AppStorage("selectedVoiceIdentifier") private var selectedVoiceIdentifier = ""
    @AppStorage("selectedSpeechRate") private var selectedSpeechRateRaw = SpeechRate.normal.rawValue
    @AppStorage("developerModeEnabled") private var developerModeEnabled = false
    @State private var voices: [VoiceOption] = []
    @State private var snapshot: CapabilitySnapshot?
    @State private var showsResetConfirmation = false
    @State private var resetMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                voiceSection
                capabilitySection
                developerSection
                dataSection
            }
            .navigationTitle("Einstellungen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    private var voiceSection: some View {
        Section("Sprachausgabe") {
            if voices.isEmpty {
                Text("Keine hebräische Stimme installiert. Bitte in den iOS-Einstellungen unter Bedienungshilfen → Gesprochene Inhalte eine hebräische Stimme laden.")
                    .font(AppFont.germanCaption())
                    .foregroundStyle(ColorTokens.textSecondary)
            } else {
                Picker("Stimme", selection: $selectedVoiceIdentifier) {
                    ForEach(voices) { voice in
                        Text("\(voice.name) (\(voice.quality.rawValue))").tag(voice.id)
                    }
                }
                Picker("Tempo", selection: $selectedSpeechRateRaw) {
                    Text("Normal").tag(SpeechRate.normal.rawValue)
                    Text("Langsam").tag(SpeechRate.slow.rawValue)
                }
            }
        }
    }

    private var capabilitySection: some View {
        Section("Gerätefähigkeiten") {
            if let snapshot {
                StatusBadge(level: ttsLevel(snapshot), text: "Sprachausgabe")
                StatusBadge(level: asrLevel(snapshot), text: "Lokale Spracherkennung")
                StatusBadge(level: tutorLevel(snapshot), text: "Lokaler Tutor")
                StatusBadge(level: micLevel(snapshot), text: "Mikrofon")
                Text("\(snapshot.systemName) \(snapshot.systemVersion) · \(snapshot.deviceModelIdentifier)")
                    .font(AppFont.germanCaption())
                    .foregroundStyle(ColorTokens.textSecondary)
            } else {
                Text("Wird geprüft …")
            }
        }
    }

    private var developerSection: some View {
        Section("Entwicklermodus") {
            Toggle("Pilot-Diagnose anzeigen", isOn: $developerModeEnabled)
        }
    }

    private var dataSection: some View {
        Section("Daten") {
            Button("Fortschritt zurücksetzen", role: .destructive) {
                showsResetConfirmation = true
            }
            .confirmationDialog(
                "Gesamten Fortschritt löschen?",
                isPresented: $showsResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Löschen", role: .destructive) { Task { await resetProgress() } }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Dies löscht alle gespeicherten Versuche und Dialogfortschritte auf diesem Gerät unwiderruflich.")
            }
            if let resetMessage {
                Text(resetMessage)
                    .font(AppFont.germanCaption())
                    .foregroundStyle(ColorTokens.textSecondary)
            }
        }
    }

    private func load() async {
        voices = environment.synthesis.availableVoices(languagePrefix: "he")
        if selectedVoiceIdentifier.isEmpty, let first = voices.first {
            selectedVoiceIdentifier = first.id
        }
        await environment.refreshCapabilities()
        snapshot = environment.capabilitySnapshot
    }

    private func resetProgress() async {
        do {
            try await environment.progressRepository.resetAllProgress()
            resetMessage = "Fortschritt wurde zurückgesetzt."
        } catch {
            resetMessage = "Zurücksetzen fehlgeschlagen: \(error)"
        }
    }

    private func ttsLevel(_ snapshot: CapabilitySnapshot) -> StatusBadge.Level {
        if case .available = snapshot.textToSpeech { return .available }
        return .unavailable
    }

    private func asrLevel(_ snapshot: CapabilitySnapshot) -> StatusBadge.Level {
        if case .available = snapshot.localRecognition { return .available }
        return .unavailable
    }

    private func tutorLevel(_ snapshot: CapabilitySnapshot) -> StatusBadge.Level {
        if case .available = snapshot.localTutor { return .available }
        return .unavailable
    }

    private func micLevel(_ snapshot: CapabilitySnapshot) -> StatusBadge.Level {
        snapshot.microphonePermission == .granted ? .available : .notApplicable
    }
}
