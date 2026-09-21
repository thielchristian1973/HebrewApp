# Lokale KI
## Zwei getrennte Fragen
1. Kann ein lokales Modell ausgeführt werden? Capability-Test auf Gerät/OS/Sprache.
2. Kann es ausreichend gutes Hebräisch für diesen Kurs liefern? Eigener Qualitätsbenchmark. supportsLocale ist keine pädagogische Qualitätsfreigabe.

## Provider
GuidedDialogueProvider ist vollständig implementierter lokaler Zustandsautomat, keine KI-Attrappe. AppleFoundationModelProvider nutzt ausschließlich das On-Device-Systemmodell, wenn verfügbar und he-IL sowie benötigte deutsche Erklärungen unterstützt sind. Implementierung gegen SDK-Dokumentation prüfen. EmbeddedModelProvider ist ein späterer Integrationspunkt, kein V1-Dummy. Core ML/andere lokale Runtime ist eine Ausführungstechnik, kein fertiges Hebräischmodell. Kein Modell ohne dokumentierte Quelle, Version/Hash, Lizenz, kommerzielle Nutzbarkeit, Tokenizer, Ressourcenprofil und Gerätetest auswählen.

## Sichere Pilotfunktion
Der Tutor erhält ScenarioID, Zustand, bekannte Vokabel-/Regel-IDs, zulässige Antwort-/Korrektur-IDs und maximal die letzten relevanten Gesprächsschritte. Im ersten Pilot wählt er aus zulässigen nextTurnIDs/feedbackIDs; die Texte stammen aus redaktionell freigegebenem Content. Unbekannte IDs, ungültige Übergänge, Timeout oder Fehler führen in denselben geführten Dialog zurück. Ein Dialogwechsel darf Historie und Versuchszähler nicht zurücksetzen.
Das ist begrenzte Tutor-Unterstützung, kein offener Chat. Optional freie Generation im separaten Entwickler-Benchmark testen, nicht als geprüfte Lernkorrektur ausspielen. Bei späterer Freigabe freie Antworten klar von Kurswahrheit trennen; sie verändern weder Content noch Mastery. Menschlich geprüfte Held-out-Fälle verwenden. Keine Selbstbewertung des gleichen Modells als Qualitätsnachweis.

## Datenschutz und Kosten
Keine API-Schlüssel, keine Remote-Generation, kein automatischer Cloud-Fallback. Keine privaten Sprachdaten im Promptlog. Modell nicht im Hintergrund dauerhaft halten; vor/nach Generierung Speicher messen, bei Warnung freigeben. Kontext begrenzen, laufende Ausgabe abbrechbar machen. Modell-Download optional, mit Größe und Abbruch; kein stiller mehrgigabytegroßer Download.

## Pilot-Ziele (interne Vorgaben, keine gemessenen Ergebnisse)
Mindestens 100 Held-out-Prompts, darunter absichtlich mehrdeutige/einfache falsche Eingaben und Steuerungsversuche. Ungültige IDs/Übergänge müssen zu 100 % verworfen werden. Bei aktivierter freier Benchmark-Ausgabe mindestens 95 % fachlich und zum Lernniveau passende Antworten als erste Schwelle; jeder schwerwiegende Lehrfehler sperrt die Freigabe bis zur Korrektur. Keine Behauptung, dies garantiere Fehlerfreiheit.
Warm p95 bis zur ersten nutzbaren Antwort ≤3 s, Gesamtantwort ≤8 s; Timeout spätestens 10 s. Ziele pro Gerät tatsächlich messen; keine nicht erreichten Werte durch Mittelwerte verbergen. Cold start separat berichten. Kein Crash, keine schwere dauerhafte thermische Drosselung im 15-Minuten-Test. Energieverbrauch vergleichend dokumentieren, keine fiktive Akku-Prozentmessung.
