import SwiftUI

/// The developer-only pilot diagnostic screen (Documentation/PILOT.md "Bedienung"). Never shown
/// to end users by default — reached only through Today's developer-mode card. Kept separate
/// from the end-user demo screens, which stay free of technical logs.
struct PilotDeveloperView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var playedItemIDs: Set<String> = []
    @State private var currentlyPlayingID: String?
    @State private var snapshot: CapabilitySnapshot?
    @State private var isRecording = false
    @State private var lastRecordingURL: URL?
    @State private var recordingStatus = "Bereit"
    @State private var transcriptionStatus = "Noch nicht getestet"
    @State private var tutorTestStatus = "Noch nicht getestet"
    @State private var reportText: String?
    @State private var reportFileURL: URL?

    var body: some View {
        List {
            if let bundle = environment.contentBundle {
                contentSection(bundle: bundle)
            }
            capabilitySection
            recordingSection
            transcriptionSection
            tutorSection
            if let bundle = environment.contentBundle {
                dialogueSection(bundle: bundle)
            }
            reportSection
        }
        .navigationTitle("Pilot-Diagnose")
        .task { snapshot = await environment.capabilityService.snapshot() }
    }

    private func contentSection(bundle: PilotContentBundle) -> some View {
        Section("Content (\(bundle.lexemes.count) Wörter, \(bundle.sentences.count) Sätze, \(bundle.dialogues.count) Dialoge)") {
            Text("\(playedItemIDs.count) / \(bundle.lexemes.count + bundle.sentences.count) TTS-Items abgespielt")
                .font(AppFont.germanCaption())
                .foregroundStyle(ColorTokens.textSecondary)
            ForEach(bundle.lexemes) { lexeme in
                ttsRow(id: lexeme.id, hebrew: lexeme.hebrew, ttsText: lexeme.ttsText)
            }
            ForEach(bundle.sentences) { sentence in
                ttsRow(id: sentence.id, hebrew: sentence.hebrew, ttsText: sentence.ttsText)
            }
        }
    }

    private func ttsRow(id: String, hebrew: String, ttsText: String) -> some View {
        HStack {
            Button {
                Task { await playTTS(id: id, text: ttsText) }
            } label: {
                Image(systemName: playedItemIDs.contains(id) ? "checkmark.circle.fill" : "speaker.wave.2")
                    .foregroundStyle(playedItemIDs.contains(id) ? .green : ColorTokens.primary)
            }
            .buttonStyle(.borderless)
            .disabled(currentlyPlayingID != nil)
            HebrewText(hebrew, font: AppFont.hebrewBody())
            Spacer()
            Text(id).font(.caption2).foregroundStyle(ColorTokens.textSecondary)
        }
    }

    private var capabilitySection: some View {
        Section("Capabilities") {
            if let snapshot {
                Text("Gerät: \(snapshot.deviceModelIdentifier), \(snapshot.systemName) \(snapshot.systemVersion)")
                    .font(AppFont.germanCaption())
                capabilityRow("Sprachausgabe", available: isAvailable(snapshot.textToSpeech))
                capabilityRow("Lokale Spracherkennung", available: isAvailable(snapshot.localRecognition))
                capabilityRow("Lokaler Tutor", available: isAvailable(snapshot.localTutor))
                capabilityRow("Mikrofon", available: snapshot.microphonePermission == .granted)
            }
            Button("Erneut prüfen") {
                Task { snapshot = await environment.capabilityService.snapshot() }
            }
        }
    }

    private func capabilityRow(_ title: String, available: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            StatusBadge(level: available ? .available : .unavailable, text: available ? "verfügbar" : "nicht verfügbar")
        }
    }

    private var recordingSection: some View {
        Section("Aufnahme & Wiedergabe") {
            Text(recordingStatus).font(AppFont.germanCaption()).foregroundStyle(ColorTokens.textSecondary)
            HStack {
                Button(isRecording ? "Stopp" : "Aufnehmen") {
                    Task { await toggleRecording() }
                }
                if let lastRecordingURL {
                    Button("Abspielen") {
                        Task { try? await environment.playback.play(url: lastRecordingURL) }
                    }
                }
            }
        }
    }

    private var transcriptionSection: some View {
        Section("Lokale Spracherkennung (Selbstvergleich)") {
            Text(transcriptionStatus).font(AppFont.germanCaption()).foregroundStyle(ColorTokens.textSecondary)
            Button("Letzte Aufnahme transkribieren") {
                Task { await testTranscription() }
            }
            .disabled(lastRecordingURL == nil)
        }
    }

    private var tutorSection: some View {
        Section("Lokaler Tutor") {
            Text(tutorTestStatus).font(AppFont.germanCaption()).foregroundStyle(ColorTokens.textSecondary)
            Button("Testvorschlag anfordern") {
                Task { await testTutor() }
            }
        }
    }

    private func dialogueSection(bundle: PilotContentBundle) -> some View {
        Section("Dialoge") {
            ForEach(bundle.dialogues) { dialogue in
                NavigationLink(dialogue.title) {
                    DialogueStepView(dialogue: dialogue, onFinished: {})
                }
            }
        }
    }

    private var reportSection: some View {
        Section("Prüfbericht") {
            Button("Bericht erstellen") {
                Task { await buildReport() }
            }
            if let reportText {
                Text(reportText)
                    .font(.system(.caption2, design: .monospaced))
                    .textSelection(.enabled)
            }
            if let reportFileURL {
                ShareLink(item: reportFileURL) {
                    Label("Bericht teilen/exportieren", systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    private func playTTS(id: String, text: String) async {
        guard let voice = environment.synthesis.availableVoices(languagePrefix: "he").first else { return }
        currentlyPlayingID = id
        defer { currentlyPlayingID = nil }
        do {
            try await environment.synthesis.speak(text: text, voiceIdentifier: voice.id, rate: .normal)
            playedItemIDs.insert(id)
        } catch {
            // Left unplayed; the row simply stays unchecked so a real playback failure is visible.
        }
    }

    private func toggleRecording() async {
        if isRecording {
            lastRecordingURL = try? environment.recording.stopRecording()
            isRecording = false
            recordingStatus = lastRecordingURL != nil ? "Aufnahme gespeichert" : "Aufnahme fehlgeschlagen"
        } else {
            do {
                try await environment.recording.startRecording()
                isRecording = true
                recordingStatus = "Aufnahme läuft …"
            } catch RecordingError.permissionDenied {
                recordingStatus = "Mikrofon-Berechtigung verweigert"
            } catch {
                recordingStatus = "Aufnahme nicht möglich: \(error)"
            }
        }
    }

    private func testTranscription() async {
        guard let url = lastRecordingURL else { return }
        transcriptionStatus = "Läuft …"
        do {
            let text = try await environment.transcription.transcribe(fileURL: url, localeIdentifier: "he-IL", timeout: 10)
            transcriptionStatus = "Erkannt: \(text)"
        } catch TranscriptionError.notSupportedOnDevice {
            transcriptionStatus = "Lokale Erkennung für he-IL nicht unterstützt"
        } catch {
            transcriptionStatus = "Fehler: \(error)"
        }
    }

    private func testTutor() async {
        guard
            let bundle = environment.contentBundle,
            let dialogue = bundle.dialogues.first,
            let engine = environment.makeDialogueEngine()
        else { return }
        let state = engine.startSession(for: dialogue)
        let provider = environment.makeAppleFoundationModelProviderIfAvailable()
        guard let provider else {
            tutorTestStatus = "Lokaler Tutor nicht verfügbar — geführter Fallback aktiv"
            return
        }
        do {
            let suggestion = try await provider.suggestNextStep(for: state, dialogue: dialogue)
            tutorTestStatus = "Vorschlag: \(suggestion.suggestedSentenceID ?? "–") in \(String(format: "%.1f", suggestion.elapsedTime))s"
        } catch {
            tutorTestStatus = "Fehler, geführter Fallback bleibt aktiv: \(error)"
        }
    }

    private func buildReport() async {
        guard let bundle = environment.contentBundle else { return }
        let currentSnapshot = await environment.capabilityService.snapshot()
        let ttsResults = (bundle.lexemes.map(\.id) + bundle.sentences.map(\.id)).map {
            PilotDiagnosticReport.TTSItemResult(itemID: $0, played: playedItemIDs.contains($0))
        }
        let report = PilotDiagnosticReport(
            generatedAtUTC: Date(),
            deviceModelIdentifier: currentSnapshot.deviceModelIdentifier,
            systemName: currentSnapshot.systemName,
            systemVersion: currentSnapshot.systemVersion,
            selectedVoiceIdentifier: environment.synthesis.availableVoices(languagePrefix: "he").first?.id,
            availableHebrewVoiceCount: environment.synthesis.availableVoices(languagePrefix: "he").count,
            textToSpeechAvailable: isAvailable(currentSnapshot.textToSpeech),
            localRecognitionAvailable: isAvailable(currentSnapshot.localRecognition),
            localTutorAvailable: isAvailable(currentSnapshot.localTutor),
            microphonePermissionGranted: currentSnapshot.microphonePermission == .granted,
            contentCounts: bundle.manifest.counts,
            ttsItemResults: ttsResults,
            openManualChecks: [
                "Hebräischqualität pro Item durch qualifizierte Prüfung (redaktionell offen)",
                "Physische Geräteprüfung Flugmodus/Mikrofonverweigerung/Unterbrechung",
                "VoiceOver-Aussprache und WCAG-AA-Kontrast auf echtem Gerät",
                "Thermik/RAM/Latenz des lokalen Tutors über 15 Minuten"
            ]
        )
        guard let text = try? report.encodedText() else { return }
        reportText = text
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("pilot-report-\(UUID().uuidString).json")
        try? text.write(to: url, atomically: true, encoding: .utf8)
        reportFileURL = url
    }

    private func isAvailable(_ capability: TextToSpeechCapability) -> Bool {
        if case .available = capability { return true }
        return false
    }

    private func isAvailable(_ capability: LocalRecognitionCapability) -> Bool {
        if case .available = capability { return true }
        return false
    }

    private func isAvailable(_ capability: LocalTutorCapability) -> Bool {
        if case .available = capability { return true }
        return false
    }
}
