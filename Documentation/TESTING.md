# Test- und Abnahmeplan
## Automatisiert
Content: IDs, Referenzen, Dialog-Erreichbarkeit, terminale Zustände, Zählung, Hashes, Draft/Released-Grenzen; CI und Build scheitern bei ungültigem freigegebenem Content.
Domain: Antwortvarianten und kontextspezifische Niqqud-Normalisierung, Finalformen, Mastery nur mit unabhängigen Nachweisen, Hints, Drei-Versuche-Grenze, Voraussetzungen.
Scheduler: Referenzvektoren der gepinnten FSRS-Version, Ratingmapping, DST/Zeitzonen, Clock rollback, überfällige Karten, idempotenter Import.
Persistenz: Versuch+State atomar, Relaunch, Migration bestehender Fixtures ohne Historyverlust, korrupter Import verändert DB nicht.
Tutor: unsupported hardware/language, disabled model, timeout/cancel, malformed/unknown IDs, unzulässiger Übergang, Prompt-Steuerungsversuch und funktionaler Fallback. Mockzustände in Tests kennzeichnen; nicht als echte Capability ausgeben.
Speech: Permission-State, Abbruch/Cleanup, keine ASR-Anfrage ohne lokale Capability, verpflichtender On-Device-Flag, TTS-Voiceverlust und UI-Fallback.
UI: Onboarding → Demo → Abschluss → Neustart → Review; iPad Navigation; Texteingabe RTL; große Textgrößen. Sinnvolle Regressionstests statt Tests, die Implementierung nur spiegeln.

## Manuell/physisch
Hebräischredaktion, Niqqud, Sprachqualität, VoiceOver-Aussprache, Mikrofon/Audio-Unterbrechung, Bluetooth, Flugmodus nach Kaltstart, lokale Modelllatency/RAM/Thermik. Je Befund Gerät/OS/Build/Schritt/Ergebnis notieren. 'Nicht ausführbar' bleibt offen, kein Pass.

## Buildnachweis
Vor Befehlen realen Workspace/Projekt und Scheme per xcodebuild -list entdecken. Verfügbare Ziele prüfen, dann tatsächliche Build-/Test-Befehle mit existierenden Destinations ausführen. Kein geratenes Simulator-UUID. Ergebnis, Exitcode und verbleibende Warnungen dokumentieren. Kein 'kompiliert' bei reiner Syntaxprüfung.

## Release-Gates
Erfolgreicher Xcode-Build, kritische Tests grün, physische Offline-/Sprachprüfung, Contentfreigabe, funktionaler Export/Reset, Datenschutz-/Berechtigungstexte und VoiceOver/RTL ohne kritische Fehler. Lokaler Tutor besitzt separates Feature-Gate. Kein A1-Marketing bei nur Pilotmaterial.
