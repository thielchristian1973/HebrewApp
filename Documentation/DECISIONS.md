# Entscheidungen v1.1
## Bestätigte Produktentscheidungen
- Native iPhone/iPad-App; UI Deutsch, modernes israelisches Hebräisch; A0/A1 in V1, A2 später.
- Hochwertig, warm, ruhig; keine Comics, Punktewährung, Leaderboards oder Lernstrafen.
- Schrift plus echte Wörter von Beginn an; Hören, Abruf und Sprechen zentral. Reisen/Alltag früh integrieren.
- Flexible Sitzungen; Erklärungen kurz und explizit, Hilfen kompetenzabhängig.
- Kernkurs offline; kein Pflichtkonto; lokale Aufnahmen und Lernhistorie.
- Keine Sprecherkosten, keine laufenden KI-/API-Kosten. Auch bezahlte Vorproduktion ist nicht autorisiert.
- Lokale KI als optionale Erweiterung bereits für V1 prüfen; austauschbare Schicht und vollständiger geführter Fallback.
- Einmalkauf mit späteren Kurs-Erweiterungen; optionaler iCloud-Abgleich gemäß vorausgehender Planung, ohne Cloud-Zwang.

## Bewusste Korrekturen des alten Blueprints
1. Native Sprecheraufnahmen als Standard und zwei bezahlte Sprecher entfallen. Lokale System-TTS wird im Pilot geprüft. Fehlende Voice darf nie still durch Deutsch/Englisch ersetzt werden.
2. KI ist nicht erst V2; lokaler Pilot jetzt. Weder Apple-Modell noch eingebettetes Modell sind bereits für Hebräisch freigegeben.
3. Prozentuale Phonem-/Vokal-/Prosodiebewertung entfällt bis zu einer gesondert validierten Messmethode. ASR-Transkript und Selbstvergleich sind keine Aussprachebewertung. Auch 'verständlich' darf nicht allein aus ASR abgeleitet werden.
4. Konto, Analytics und Cloud-Sprachanalyse sind keine V1-Abhängigkeiten.
5. Frühere 0–3-Bewertungen sind UI-Werte, keine ungeprüft an FSRS übergebenen Bibliothekswerte. Named-enum-Adapter und Konformitätstests verwenden.
6. Der alte Alphabetplan nennt 'שלום' vor Einführung seiner Buchstaben. Komplettwörter dürfen als Hör-Chunks vorkommen; Leseabfragen erst nach den Graphem-Voraussetzungen.
7. 28 Kernlektionen × höchstens sechs neue produktive Items ergeben maximal 168, nicht 500. Für 500 produktive Items braucht es zusätzliche kurze Untereinheiten. Kernlektionen sind Themenkapitel, die sich in mindestens 84 Einführungs-Unter­einheiten aufteilen; Wiederholungen/Tests kommen hinzu. Wort-/Chunk-Zählregeln festlegen, Flexionsformen nicht als neue Lemmas aufblasen.
8. Ziel 'vollständig offline' bedeutet: installierte App samt benötigten Stimmen/Assets läuft offline. Ein einmaliger System-Voice-/Modell-Download kann nötig sein; vorab transparent prüfen. Text-Fallback allein erfüllt nicht die Freigabe des Hörkurses.
9. Ein Regelvalidator kann nur begrenzte Antwortmengen prüfen; kein Versprechen vollständiger Grammatikvalidierung freier KI-Texte.

## Implementierungsdefaults, keine neuen Nutzerentscheidungen
- Arbeitstitel HebrewApp; Swift 6; minimale OS-Version vorläufig 17.0; moderne KI optional hinter Availability-Grenzen. Gegen installierte stabile SDKs prüfen.
- Ziel-Sitzung 10 Minuten, auswählbar 5/10/15; Pause/Fortsetzen jederzeit.
- Review-Zielretention initial 0,90, erst nach belastbarer History optimieren.
- Keine Modellgewichte mitliefern, bevor Hebräischqualität, Geräteperformance und kommerzielle Redistribution geklärt sind.
- Sync und StoreKit nach lokalem Kern; kein Kaufpreis, Produkt-Identifier oder Entwickler-Team wird erfunden.

## P0/P1-Implementierungsentscheidungen (Claude Code, 21.09.2026)
Reversible technische Entscheidungen während P0/P1, dokumentiert statt stillschweigend getroffen.

1. **Bundle-Identifier**: `com.example.hebrewapp` (Präfix `com.example`, RFC 2606 reservierte Platzhalter-Domain). Kein Team wird erfunden; `DEVELOPMENT_TEAM` bleibt leer, Signierung auf „Automatic“/„Sign to Run Locally“ für Simulator-Builds. Vor echtem Gerätebuild oder Store-Einreichung muss ein echter Bundle-Identifier und ein echtes Apple-Developer-Team gesetzt werden.
2. **Projekterzeugung**: XcodeGen 2.45.4 (bereits lokal via Homebrew installiert) mit `project.yml` im Repo-Root. Reproduktion: `xcodegen generate`. Das generierte `HebrewApp.xcodeproj` wird mitgeliefert/committet (ARCHITECTURE.md: „generiertes Projekt mitliefern“), muss nach jeder `project.yml`-Änderung neu erzeugt werden.
3. **Ressourcen-Bundlepfad**: `Content/Pilot/*.json` wird als XcodeGen-„folder reference“ eingebunden. Eine Ordnerreferenz behält nur ihren eigenen Namen im App-Bundle, nicht den vollen Repo-Pfad — zur Laufzeit liegen die Dateien unter `HebrewApp.app/Pilot/*.json`, nicht `.../Content/Pilot/*.json`. `PilotContentLoader` verwendet entsprechend `subdirectory: "Pilot"`.
4. **FoundationModels-Mindestversion korrigiert**: Gegen das installierte iOS-26.5-SDK geprüft (`FoundationModels.swiftinterface`) zeigt sich, dass das gesamte Framework `@available(iOS 26.0, *)` voraussetzt — keine iOS-17/18-Einstiegspunkte vorhanden. Der lokale Apple-Tutor ist entsprechend hinter `#if canImport(FoundationModels)` **und** `if #available(iOS 26.0, *)` gekapselt, nicht hinter iOS 17. Das Deployment-Target der App bleibt 17.0; die Kernapp funktioniert vollständig ohne diese Capability.
5. **Speech-Framework-API**: Die im Übergabepaket zitierten `SFSpeechRecognizer`-APIs sind reine Objective-C-Deklarationen (keine `Speech.swiftinterface`-Einträge in diesem SDK — dort liegt nur die neue `SpeechAnalyzer`-API ab iOS 26). Gegen die installierten Header verifiziert: `supportsOnDeviceRecognition` (Bool, Instanzeigenschaft), `requiresOnDeviceRecognition` (Bool, nicht optional) auf `SFSpeechRecognitionRequest`, `SFSpeechURLRecognitionRequest(url:)` für die Transkription bereits aufgenommener Dateien (kein Live-Buffer-Tapping nötig).
6. **Farbtoken „Divider“ im Dark Mode**: DESIGN_SYSTEM.md nennt nur einen hellen Divider-Wert (#D7DED9). Für Dark wurde ein Implementierungsdefault `#2C3F3F` ergänzt (dezent heller als die dunkle Oberfläche #1A2B2C) — vor Release im echten WCAG-AA-Kontrastcheck verifizieren.
7. **Concurrency-Architektur**: Alle Apple-Framework-Wrapper (Speech-Synthese, Recorder/Player, lokale Spracherkennung, Capability-Aggregation) sind `@MainActor`-isoliert, da `AVSpeechSynthesizer`, `AVSpeechUtterance`, `SFSpeechRecognizer` und `SFSpeechRecognitionTask` im installierten SDK keine `Sendable`-Konformität tragen (ARCHITECTURE.md: unsendable Recorder/Recognizer niemals per `Task.detached` reichen). Ausnahme: einzelne zustandslose Capability-Abfragen (`availableVoices`, `capability(localeIdentifier:)`) sind bewusst `nonisolated` und die sie implementierenden Klassen `@unchecked Sendable`, weil sie keinerlei gespeicherten Zustand berühren — siehe Punkt 8.
8. **Capability-Checks laufen abseits des Main Actors**: Ein realer Fund beim P1-Gerätetest (frisch gebooteter Simulator, siehe IMPLEMENTATION_STATUS.md): `AVSpeechSynthesisVoice.speechVoices()` und das Anlegen eines `SFSpeechRecognizer` lösen bei kaltem Asset-Katalog-Cache eine synchrone System-IPC aus, die mehrere Minuten dauern kann. Da diese Aufrufe ursprünglich synchron auf dem Main Actor liefen, blockierten sie den kompletten App-Start. `CapabilityService.snapshot()` ist daher `async` und führt die Prüfungen in einem `Task.detached` aus; Domain-/Data-/Learning-Schicht bleiben unverändert synchron und leichtgewichtig.
9. **Guided-Dialogue-Distraktoren**: Das Pilot-Datenformat (dialogues.json) kodiert ausschließlich gültige Übergänge, keine falschen Antwortoptionen. `DialogueEngine` erzeugt Distraktoren deterministisch (Hash-basiert, kein `Int.random`) aus anderen bereits freigegebenen Pilotsätzen — nie aus erfundenem Text —, damit die geforderte „Nach drei erfolglosen Versuchen“-Logik (PRODUCT.md) im Pilot überhaupt beobachtbar ist.
10. **Demo-Lernstrecken-Inhalt „Vorstellen“/„Café“**: Die konkrete Zuordnung von Lexem-/Satz-IDs zu den zwei Demo-Pfaden (Documentation/PILOT.md fordert die Pfade, nennt aber keine konkrete Item-Auswahl) ist eine Implementierungsentscheidung in `PilotLearningPathCatalog`, per Unit-Test gegen die echten Pilot-Fixtures abgesichert (`PilotPathProgressTrackerTests.catalogReferencesRealFixtures`).
