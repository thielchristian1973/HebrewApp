# Architektur
## Projektaufbau
HebrewApp/App, Domain, Data, Content, Learning, Speech, Tutor, DesignSystem, SharedUI, Features/{Today,Learn,Review,Words,Grammar,Progress,Settings,Pilot}, Resources.
HebrewAppTests, HebrewAppUITests, Documentation, Scripts, Content/Pilot.

App: Composition root und Router. Domain: Codable/Sendable-Werte, keine UI/Framework-Singletons. Data: SwiftData-Persistenz, Repositories, Migration. Content: versionierte Bundle-Daten, Manifestprüfung. Learning: SessionComposer, PrerequisiteEngine, AnswerEvaluator, HelpPolicy, SchedulerAdapter. Speech: getrennte Playback-/Recorder-/ASR-Capabilities. Tutor: geführte Engine plus optionale lokale Provider. UI: Darstellung und Intents, keine Lernregeln in Views.

## Servicegrenzen
ContentRepository lädt validierte immutable Kursdaten. ProgressRepository schreibt Attempt und abgeleiteten Zustand atomar. Clock injiziert Zeit. Scheduler verarbeitet Named Ratings pro CardKey. SpeechSynthesizing listet Voices und spricht mit Cancellation. Recording verwaltet Session und Datei-Lebenszyklus. LocalTranscribing liefert verfügbarkeitsgeprüfte Resultate oder typed errors. TutorProvider liefert strukturierte Vorschläge; DialogueEngine allein entscheidet über Übergang/Ergebnis. CapabilityService liefert getrennte Zustände je Feature, Sprache und Asset-Verfügbarkeit.

## Concurrency und Lifecycle
UI und UI-gebundene Apple-Objekte gemäß SDK auf ihrem vorgesehenen Actor isolieren; niemals unsendable Recorder/Recognizer über Task.detached reichen. CPU-/Dateiarbeit in passenden Actors/Tasks. Jede laufende Aufnahme, Transkription, TTS und Generation hat Cancellation, Timeout und sauberen Cleanup. Navigation beendet Tasks; Audio-Unterbrechung pausiert und lässt Wiederaufnahme zu. Keine parallelen TTS-/Mikrofonsessions mit versehentlicher Selbsttranskription.

## Persistenz
SwiftData nur für veränderliche Nutzerdaten; Kursinhalt als Bundle-JSON. Lokales Profil UUID, keine E-Mail erforderlich. Große Audiodateien im Application-Support-Verzeichnis, DB hält relative Pfade. Migrationen versionieren, vor Import/Migration konsistente Sicherung erzeugen. Abgebrochene Schreibvorgänge dürfen keine halben Sessionstände hinterlassen.

## Kompatibilität
Kern ab vorläufig iOS/iPadOS 17. Swift-Compiler/SDK und Deployment Target unterscheiden. Foundation-Models-Integration über reale SDK-Verfügbarkeit, Compilation Guard und Runtime Availability kapseln. Kein Apple-Intelligence-Gerätezwang im App-Manifest. Fehlende Sprache, deaktiviertes/nicht geladenes Modell und unsupported hardware separat anzeigen.

## Build
Echtes Xcode-Projekt mit Shared Scheme und Test Targets erstellen. Falls XcodeGen gewählt wird, vollständiges project.yml und reproduzierbare Erzeugung dokumentieren; generiertes Projekt mitliefern. Kein Projekt, das nur aus nicht eingebundenen Swift-Dateien besteht. Python-Contentvalidator als Build-/CI-Gate. macOS-CI nur falls entsprechendes Repo vorhanden; lokale Prüfung bleibt möglich.
