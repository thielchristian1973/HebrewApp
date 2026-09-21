# Implementierungsstatus — P0 und P1 (Technik-Pilot)

## Schnellstart

1. Xcode 26.5 oder neuer, iOS-17+-SDK. Optional zur Reproduktion: `brew install xcodegen` (bereits als 2.45.4 verifiziert).
2. Projekt öffnen: `open HebrewApp.xcodeproj` im Repo-Root (bereits generiert und eingecheckt; nur nach `project.yml`-Änderungen `xcodegen generate` erneut ausführen).
3. Scheme „HebrewApp" wählen, ein Simulator- oder Geräteziel wählen, ⌘R. Kein Team/Signing nötig für Simulator-Läufe (`DEVELOPMENT_TEAM` ist leer); für ein echtes Gerät muss in Xcode ein eigenes Team unter „Signing & Capabilities" gesetzt werden.
4. Tests: ⌘U, oder `xcodebuild -project HebrewApp.xcodeproj -scheme HebrewApp -destination 'platform=iOS Simulator,id=<UDID>' test` (UDID über `xcrun simctl list devices` ermitteln).
5. Pilot-Diagnose (Entwicklermodus) ist im Debug-Build standardmäßig sichtbar: „Heute" → Karte „Entwicklermodus" → „Pilot-Diagnose öffnen".

Stand: 21.09.2026. Bearbeitet von Claude Code gemäß CLAUDE.md/START_HERE.md-Auftrag. Dieser Bericht ist ehrlich in „erledigt"/„offen" getrennt (QUALITY_STATUS.md-Prinzip) — eine grüne Build-/Testausgabe ist kein Ersatz für die in PILOT.md geforderten physischen Gerätetests und die redaktionelle Sprachfreigabe.

## Zusammenfassung

P0 und P1 aus IMPLEMENTATION_PLAN.md sind umgesetzt: Es existiert ein reproduzierbares, buildbares SwiftUI-Xcode-Projekt mit gemeinsamem Scheme, Testzielen, warmem Designsystem, RTL/Niqqud-fähiger Hebräisch-Komponente, lokalem Contentloader mit Hash-Verifikation, TTS mit echter Voice-Verfügbarkeitsprüfung, Aufnahme/Wiedergabe, strikt lokaler Spracherkennung, vier funktionierenden geführten Dialogen, persistenten Pilotversuchen (SwiftData) und einem capability-gesicherten Apple-On-Device-Tutor. Alle automatisierten Tests (15 Unit-Tests, 4 UI-Tests) sind grün. Ein echter, reproduzierbarer Bug wurde während der Simulator-Verifikation gefunden und behoben (siehe „Gefundene und behobene Fehler"). Physische Gerätetests, Hebräisch-Redaktion und Audioqualitätsprüfung bleiben vollständig offen — dafür gibt es kein Gerät in dieser Umgebung.

## Ausgangslage (P0)

- Repository war zu Beginn kein Git-Repository und enthielt nur das Dokumentationspaket (CLAUDE.md, Documentation/*, Content/Pilot/*, Scripts/validate_pilot.py, Prompts/*, README/START_HERE/QUALITY_STATUS) — kein Swift-Code, kein Xcode-Projekt. `git init -b main` wurde ausgeführt; lokale Commits folgen den bestehenden Dateien plus dem neuen App-Code.
- Werkzeuge lokal geprüft: Xcode 26.5 (Build 17F42), Swift 6.3.2, XcodeGen 2.45.4 (bereits per Homebrew installiert), Python 3.9.6. Simulatoren: zahlreiche iOS-18.3/26.1/26.5-Geräte vorhanden (iPhone 13/16/17-Serie, iPad-Serie); keine physischen Geräte.
- Python-Validator ausgeführt:
  ```
  python3 Scripts/validate_pilot.py
  ```
  Ergebnis: `PASS: 50 lexemes, 20 sentences, 4 reachable/terminating dialogues; IDs and SHA256 valid.` (Hinweiszeile bestätigt: Sprachredaktion, Audioqualität, iOS-Builds und Gerätetests bleiben offen.)

## Projektbasis

- **Projektname/Bundle**: `HebrewApp`, Bundle-ID `com.example.hebrewapp` (Platzhalter-Domain nach RFC 2606, kein erfundenes Unternehmen/Team; `DEVELOPMENT_TEAM` bleibt leer). Siehe Documentation/DECISIONS.md, Abschnitt „P0/P1-Implementierungsentscheidungen", Punkt 1.
- **Erzeugung**: XcodeGen aus `project.yml` im Repo-Root. Reproduktion:
  ```
  xcodegen generate
  ```
  Das generierte `HebrewApp.xcodeproj` ist Teil des Repos (ARCHITECTURE.md: „generiertes Projekt mitliefern"). Nach jeder `project.yml`-Änderung muss `xcodegen generate` erneut laufen.
- **Struktur**: `HebrewApp/{App,Domain,Data,Content,Learning,Speech,Tutor,DesignSystem,SharedUI,Features/{Today,Learn,Review,Words,Grammar,Progress,Settings,Pilot},Resources}` plus `HebrewAppTests`, `HebrewAppUITests` — deckungsgleich mit ARCHITECTURE.md.
- **Scheme**: `HebrewApp` (shared, unter `HebrewApp.xcodeproj/xcshareddata/xcschemes/`), deckt Build/Run/Test/Profile/Analyze/Archive ab.
- **Swift 6, strict concurrency**: `SWIFT_VERSION = 6.0`. Domain-Schicht ist reines Foundation (keine SwiftUI-/SwiftData-/Apple-Speech-Importe). Speech-/Data-Wrapper sind bewusst `@MainActor`-isoliert (Details in DECISIONS.md Punkt 7/8).
- **Mindestversion**: iOS/iPadOS 17.0 (Deployment Target), unverändert gegenüber IMPLEMENTATION_PLAN.md. FoundationModels-Tutor erfordert real iOS 26.0 (siehe unten) — die Kernapp läuft davon unabhängig vollständig.

## Buildnachweis

Reale Ziele vor den Befehlen ermittelt (TESTING.md: „Vor Befehlen realen Workspace/Projekt und Scheme per xcodebuild -list entdecken"):
```
xcodebuild -project HebrewApp.xcodeproj -list
```
```
Targets: HebrewApp, HebrewAppTests, HebrewAppUITests
Build Configurations: Debug, Release
Schemes: HebrewApp
```

Build (Debug, Simulator „iPhone 17 Pro", iOS 26.5, reale Simulator-UUID, kein geratenes Ziel):
```
xcodebuild -project HebrewApp.xcodeproj -scheme HebrewApp \
  -destination 'platform=iOS Simulator,id=FE627F38-C127-4D2A-9B44-BE7EC2F72DBF' \
  -configuration Debug build
```
Ergebnis: `** BUILD SUCCEEDED **`, Exitcode 0. Verbleibende Warnung im finalen Durchlauf: eine einzelne, erwartete Build-System-Meldung („Metadata extraction skipped. No AppIntents.framework dependency found." — die App verwendet bewusst kein App Intents), keine Swift-Compiler-Warnungen. (Mehrere Zwischen-Iterationen mit echten Compilerfehlern wurden behoben, siehe „Iterativer Verlauf" unten — hier wird nicht „kompiliert" aus reiner Syntaxprüfung behauptet, sondern aus einem tatsächlichen `xcodebuild build`-Exitcode 0.)

Zusätzlich erfolgreich gebaut für:
- iPad Pro 13" (M5), iOS 26.5 (Simulator-UUID `CD7F731B-EBE2-48E0-84CA-0B8A3A04F068`)
- iPhone SE (3. Generation), iOS 26.5 (Simulator-UUID `F749EEAF-DE6D-4FA2-9A52-3C0DD745EADC`) — schmalste unterstützte Breite
- iPhone 13, iOS 18.3 (Simulator-UUID `36F2478E-84EC-41CB-A199-AAACE95C8190`) — ältere OS-Version als Kompatibilitätsstichprobe

Test (Debug, gleiches Simulatorziel):
```
xcodebuild -project HebrewApp.xcodeproj -scheme HebrewApp \
  -destination 'platform=iOS Simulator,id=FE627F38-C127-4D2A-9B44-BE7EC2F72DBF' \
  -configuration Debug test
```
Ergebnis: `** TEST SUCCEEDED **`, Exitcode 0.
- HebrewAppTests: 15/15 Tests grün (`Test run with 15 tests in 4 suites passed`).
  - `PilotContentLoaderTests` (4): lädt echtes Pilotbundle, prüft Zahlen/Draft-Status/Dialogreferenzen, prüft typisierten Fehler bei fehlender Ressource.
  - `DialogueEngineTests` (5): gültiger Übergang, Distraktor ohne Übergang, Freischaltung nach drei Fehlversuchen, Distraktor-/Antwortmenge, unterstützte Fortsetzung.
  - `PilotContentModelTests` (2): Decodierung, Dialoggraph-Struktur.
  - `PilotPathProgressTrackerTests` (4): nächster offener Schritt, Vollständigkeit, Idempotenz, **Cross-Check der Demo-Pfad-Katalogdaten gegen das echte geladene Pilotbundle** (verhindert stille Drift zwischen Code und Content/Pilot/*.json).
- HebrewAppUITests: 4/4 Tests grün (echte Accessibility-Abfragen, keine Koordinaten):
  - App startet zum Heute-Tab.
  - „Vorstellen starten" navigiert zu „Schritt 1 von 3".
  - Einstellungen-Zahnrad öffnet das Einstellungen-Sheet.
  - „Pilot-Diagnose öffnen" öffnet den Entwicklerbildschirm.

Python-Validator erneut nach Contentintegration ausgeführt (unverändert grün, da Content/Pilot/*.json nicht verändert wurde):
```
python3 Scripts/validate_pilot.py
```
`PASS: 50 lexemes, 20 sentences, 4 reachable/terminating dialogues; IDs and SHA256 valid.`

### Iterativer Verlauf (zur Nachvollziehbarkeit)

Der erste `xcodebuild build`-Versuch schlug mit sechs echten Swift-6-Diagnosen fehl (nicht nur Warnungen): falsche Fehlerkonvertierung bei `withCheckedThrowingContinuation` unter typed throws, ein Sendable-Verstoß bei `LanguageModelSession.Response`, ein „region-based isolation checker"-Compilerfehler bei einer `@MainActor`-Task-Gruppe, sowie zwei Swift-6-Data-Race-Diagnosen in `AudioSessionCoordinator` (`Notification` ist nicht `Sendable`; `NSObjectProtocol`-Beobachter-Handles waren nicht aus einem nichtisolierten `deinit` erreichbar). Alle sechs wurden behoben, danach war der Build grün. Details und Begründung stehen als Codekommentare an den jeweiligen Stellen sowie in Documentation/DECISIONS.md.

## Gefundene und behobene Fehler (echte Geräteverifikation, nicht nur Compiler)

Reine Compiler-Grünheit wurde nicht als Funktionsnachweis akzeptiert (TESTING.md). Zwei Funde aus der tatsächlichen Simulator-Ausführung:

1. **App-Start-Hänger auf frisch gebootetem Simulator (bestätigt, behoben).** Auf einem zuvor nie benutzten Simulator blieb die App dauerhaft (>15 s, reproduzierbar) auf „Lade Pilotinhalte …" hängen. Log-Analyse (`xcrun simctl spawn <udid> log show`) zeigte synchrone System-IPC-Aufrufe (`(Speech) No Assistant asset for language he-IL`, TTS-Asset-Katalog-Abfragen an `mobileassetd`) beim ersten Aufruf von `AVSpeechSynthesisVoice.speechVoices()` bzw. beim Anlegen eines `SFSpeechRecognizer`. Diese liefen ursprünglich synchron auf dem Main Actor (`CapabilityService` war `@MainActor`), wodurch der komplette App-Start blockierte. Fix: `CapabilityService.snapshot()` ist jetzt `async` und führt die Prüfungen in einem `Task.detached` aus; die betroffenen Protokollmethoden (`SpeechSynthesizing.availableVoices`, `LocalTranscribing.capability`/`requestAuthorizationIfNeeded`) sind bewusst `nonisolated` (Details/Begründung in Documentation/DECISIONS.md Punkt 7/8). Nach dem Fix verifiziert auf zwei unterschiedlichen, zuvor nie gestarteten Simulatoren (iPhone SE 3. Gen. und ein komplett frisch erstelltes iPhone 13/iOS 18.3, letzteres sogar vor Abschluss des allerersten iOS-Simulator-Setups getestet): App lädt sofort zum vollständig gerenderten „Heute"-Bildschirm, kein Hänger.
2. **Nicht abschließend geklärt: Style bei `NavigationLink`.** Bei der manuellen Simulator-Bedienung reagierte ein mit `.buttonStyle(.borderedProminent)` versehener, closure-basierter `NavigationLink { dest } label: { … }` in `TodayView` wiederholt nicht auf Taps, während der wertbasierte `NavigationLink(value:)` + `.navigationDestination(for:)`-Ansatz (bereits in `LearnListView` verwendet) zuverlässig funktionierte. Da manuelle Koordinaten-Taps auf einem Screenshot fehleranfällig sind, wurde die Ursache nicht isoliert zugeordnet (Layout-Fehleinschätzung vs. echter SwiftUI-Effekt); `TodayView` wurde vorsorglich auf denselben wertbasierten Navigationsstil umgestellt und per `XCUITest` (Accessibility-Abfrage, keine Koordinaten) verifiziert — alle vier UI-Tests sind grün. Für zukünftige Arbeit: closure-basierte `NavigationLink`s außerhalb von Listen mit `.buttonStyle` verdienen besondere Vorsicht.

## P1-Umfang: was funktioniert

Alle folgenden Punkte wurden per Simulator (iPhone 17 Pro, iPad Pro 13", iPhone SE) visuell und/oder per automatisiertem Test geprüft:

- **Navigation**: iPhone-TabBar (Heute/Lernen/Wörter/Fortschritt) mit Settings-Zahnrad in der Toolbar; iPad-Sidebar mit allen sechs Zielen (Heute, Lernen, Wiederholen, Wörter, Grammatik, Fortschritt) plus direktem Zugriff auf Wiederholen/Grammatik — exakt wie PRODUCT.md gefordert. Screenshot-verifiziert in Light und Dark Mode.
- **Designsystem**: Farbtoken (Light/Dark) aus DESIGN_SYSTEM.md als benanntes Asset-Farbcatalog hinterlegt; Spacing/Radius/Hit-Target-Konstanten; native Dynamic-Type-Textstile statt fixer Labels.
- **HebrewText/RTL**: eigene Komponente mit `layoutDirection(.rightToLeft)`-Scoping, `typesettingLanguage` für he-IL (echte, verifizierte SwiftUI-API — keine erfundene `accessibilityLanguage`-API, siehe Entwicklungsverlauf), niemals String-Reverse. Visuell auf iPhone 17 Pro, iPad und iPhone SE (schmalste Breite) geprüft: hebräischer Text rechtsbündig, deutsche Übersetzung darunter, deutsche Navigation bleibt LTR.
- **Pilot-Contentloader**: lädt `manifest.json`/`lexemes.json`/`sentences.json`/`dialogues.json` aus dem App-Bundle, verifiziert SHA-256 pro Datei und Anzahl gegen das Manifest (spiegelt Scripts/validate_pilot.py), wirft typisierte Fehler statt stiller leerer Daten.
- **TTS**: `AVSpeechSynthesizer`/`AVSpeechSynthesisVoice` real abgefragt (keine hartkodierte Voice-ID), Qualität/Sprache aus dem System gelesen, normal/langsam als Rate-Optionen. Auf dem Simulator ohne extra installierte he-IL-Stimme zeigt der Wörter-Screen den Lautsprecher-Button; echte Stimmverfügbarkeit ist geräteabhängig und in PILOT.md's Testmatrix als physischer Test offen.
- **Aufnahme/Wiedergabe**: `AVAudioRecorder`/`AVAudioPlayer`, Mikrofonberechtigung erst beim ersten Aufnahmeversuch (`AVAudioApplication.requestRecordPermission()`, iOS-17-API, nicht das veraltete `AVAudioSession`-Pendant), harte 60-Sekunden-Grenze über `record(forDuration:)`, temporäre Datei im `FileManager.default.temporaryDirectory`.
- **Lokale Spracherkennung**: `SFSpeechRecognizer`/`SFSpeechURLRecognitionRequest`, `requiresOnDeviceRecognition = true` erzwungen, Start nur nach bestätigtem `supportsOnDeviceRecognition`; kein Codepfad, der Netzwerk-ASR auslösen könnte.
- **Vier geführte Dialoge**: Begrüßung, Café, (Weg fragen/Einkaufen aus denselben Fixtures) über `DialogueEngine` (reine, deterministische Zustandsmaschine, per Unit-Test abgesichert) inklusive Distraktor-Generierung und „nach drei Fehlversuchen unterstützte Fortsetzung".
- **Zwei Demo-Lernstrecken** („Vorstellen", „Café"): Wortschritt (Anhören + Selbstauskunft „Wusste ich"/„Wusste ich nicht"), Satzschritt, Dialogschritt; vollständig ohne Mikrofon und ohne KI abschließbar (Vokabular-/Satzschritte nutzen nur Anzeige+Selbstauskunft, der Dialogschritt nutzt Mehrfachauswahl aus vorab freigegebenen Sätzen); Fortschritt wird pro Schritt persistiert und beim Neustart fortgesetzt (SwiftData).
- **Persistente Pilotversuche**: SwiftData (`PilotAttemptRecord`, `PronunciationAttemptRecord`, `DialogueSessionRecord`, `PathProgressRecord`), versionierte Schema-/Migrationsplan-Scaffolding (`PilotSchemaV1`/`PilotMigrationPlan`) für spätere P2-Migrationen, `cloudKitDatabase: .none` explizit gesetzt (kein versehentlicher Sync).
- **Apple-On-Device-Tutor**: `AppleFoundationModelProvider` ausschließlich hinter `#if canImport(FoundationModels)` **und** `if #available(iOS 26.0, *)` (echte SDK-Mindestversion, siehe DECISIONS.md) sowie `SystemLanguageModel.default.availability == .available` und Sprachunterstützungsprüfung für he/de. Wählt nur unter den im aktuellen Dialogknoten bereits freigegebenen `nextTurnID`s; jede Rückgabe wird gegen die erlaubte Menge validiert, bevor sie verwendet wird (nie blind vertraut). Timeout 10 s. Fällt bei jedem Fehler/Timeout/ungültiger ID auf `GuidedDialogueProvider` zurück, der als vollständig funktionierender, KI-freier Zustandsautomat immer verfügbar ist.
- **Pilot-Diagnosebildschirm** (Entwicklermodus, `PilotDeveloperView`): Contentliste mit Abspielstatus pro Item, Capability-Übersicht, Aufnahme-/Wiedergabetest, ASR-Selbsttest, Tutor-Testvorschlag, alle vier Dialoge direkt startbar, Exportbericht als JSON (Geräte-/OS-/Voice-/Modellinfo, **keine** Sprachinhalte/Aufnahmen) über `ShareLink`. Vom Endnutzer-Pfad getrennt (nur über „Entwicklermodus"-Karte auf „Heute" erreichbar, standardmäßig nur in DEBUG-Builds aktiv).
- **Fortschrittsanzeige**: zeigt nur real aufgezeichnete Versuche, keine erfundene Bewertung; Hinweistext, dass Aussprache in diesem Pilot nicht objektiv bewertet wird.
- **Ehrliche Platzhalter statt leerer Kurs-Behauptung**: Grammatik- und Wiederholungs-Screens zeigen explizit „Teil des Lernkerns (P2), noch nicht Teil dieses Technik-Pilots" statt leerer/verwirrender Ansichten.

## Bewusst nicht umgesetzt in P1 (gehört zu P2+)

- Produktionsschema/-validator über die Pilotfixtures hinaus, echter FSRS-Scheduler, SessionComposer, PrerequisiteEngine, AnswerEvaluator mit Niqqud-Normalisierung, HelpPolicy/Mastery-Stufen — all das ist laut IMPLEMENTATION_PLAN.md P2 „Lernkern".
- A0/A1-Kursinhalte, Grammatiknachschlagewerk, Wiederholungs-Queue.
- StoreKit, optionaler iCloud-Abgleich, Export/Import von Nutzerdaten über den reinen Reset hinaus.

## Offen — erfordert physische Geräte oder redaktionelle Prüfung (nicht durch diese Sitzung leistbar)

Diese Punkte sind laut PILOT.md/TESTING.md Abnahmebedingungen und werden hier ausdrücklich **nicht** als erledigt behauptet:

- Alle vier Testmatrix-Zeilen aus PILOT.md, die ein physisches Gerät voraussetzen: älteres iPhone ohne Apple Intelligence, Apple-Intelligence-fähiges iPhone (verfügbar/deaktiviert/Modell fehlt/Sprache fehlt), iPad mit Tastatur, sowie alle gerätespezifischen Fälle (Flugmodus nach Kaltstart, Mikrofon verweigert, Bluetooth/Headset-Wechsel, Unterbrechung, Modelltimeout unter Realbedingungen).
- Hebräische Sprachqualität, Niqqud-Korrektheit, Wort-/Satzgrenzen und Verständlichkeit der 70 TTS-Items — erfordert qualifizierte muttersprachliche Prüfung, nicht durch Code-Review ersetzbar.
- VoiceOver-Aussprache und tatsächliche Screenreader-Bedienung.
- WCAG-AA-Kontrastmessung der Designsystem-Farben (inklusive des in DECISIONS.md dokumentierten Dark-Divider-Implementierungsdefaults).
- Performance-/Thermik-/RAM-Messung des lokalen Tutors über 15 Minuten (LOCAL_AI.md-Zielwerte) — auf dem Simulator nicht aussagekräftig messbar (PILOT.md: „Simulator … nicht als Beleg für physische Audio-/Modellqualität verwenden").
- 100+ Held-out-Prompts für den Tutor-Benchmark (LOCAL_AI.md „Pilot-Ziele") — dieser Pilot-Build stellt die technische Infrastruktur dafür bereit (capability-gesicherter Provider mit Validierung gegen erlaubte IDs), führt den eigentlichen Sprachqualitäts-Benchmark aber nicht automatisch aus.
- Große Dynamic-Type-Textgrößen und Reduce-Motion wurden nicht systematisch durchgetestet (nur Standardgröße visuell geprüft).

## Nächste Phase

P1-Abnahmepunkt ist hiermit erreicht und dokumentiert; es wird **kein** Go/No-Go für den Kern oder den lokalen Tutor behauptet — das ist laut PILOT.md „Entscheidung nach Pilot" an die oben offenen physischen/redaktionellen Prüfungen gebunden. Empfohlener nächster Schritt gemäß IMPLEMENTATION_PLAN.md: P2 „Lernkern" (Produktionsschema/-validator, SwiftData-Migrationen für echte Kursdaten, LessonEngine, gepinnter FSRS-Adapter, echte Übungstypen E01–E12) — erst nach dieser P1-Dokumentation und nach Rücksprache, welche der oben offenen physischen Prüfungen zuerst nachgeholt werden.
