# Hebräisch-App – Übergabe an Claude Code v1.1
Stand: 21. September 2026. Arbeitstitel: HebrewApp; kein endgültiger Markenname.

## In drei Schritten starten
1. ZIP auf dem Mac entpacken. Den entpackten Ordner als Projektordner in Claude Code öffnen. Bei einem bestehenden Projekt die Dateien zuerst in einen separaten Übergabeordner legen; bestehende CLAUDE.md nicht blind überschreiben.
2. Den gesamten Text aus START_HERE.md als ersten Auftrag in Claude Code einfügen.
3. Claude Code erstellt und prüft zunächst den Technik-Pilot. Danach den passenden Folgeauftrag aus Prompts verwenden. Entwicklungsarbeit braucht einen Mac mit Xcode; physische Geräte sind für Audio und lokale KI erforderlich.

## Was dieses Paket ist
Eine konsolidierte, verbindliche Implementierungsspezifikation mit Agentenregeln, Arbeitsaufträgen, Abnahmekriterien und ausführbaren Prüfskripten für mitgelieferte Pilotdaten. Seit dem 21.09.2026 enthält der Ordner zusätzlich einen gebauten und automatisiert getesteten SwiftUI-Technik-Piloten (P0/P1 aus IMPLEMENTATION_PLAN.md, siehe Documentation/IMPLEMENTATION_STATUS.md für Startanleitung, Testnachweise und offene Geräteprüfungen). Es enthält weiterhin kein eingebettetes KI-Modell oder vorproduzierte Audiodateien, und keine physische Geräte-/Sprachfreigabe ist bereits erfolgt.

Grundlage: vollständig gelesener Hebraeisch_App_Blueprint_v1.0.docx vom 20.09.2026 plus spätere Entscheidungen in diesem Gespräch. Documentation/DECISIONS.md löst alte Widersprüche auf. Der ursprüngliche Blueprint ist nicht mitkopiert; die maßgeblichen Anforderungen sind hier konsolidiert.

## Lesereihenfolge
CLAUDE.md → Documentation/DECISIONS.md → PRODUCT.md → ARCHITECTURE.md → PILOT.md → TESTING.md. Danach thematisch ergänzen.
Alle genannten Spezifikationen liegen in Documentation/. START_HERE.md und Prompts/ liegen im Wurzelordner.

## Bestandteile
- Produkt, Didaktik, Curriculum, Design, Daten, Lernalgorithmus, Sprache, KI, Datenschutz und Release.
- Pilot: 50 Lexeme, 20 Sätze, vier geführte Dialoge, Manifest und Strukturvalidator.
- Pilotinhalt ist redaktioneller Entwurf. Erfolgreiche Datenvalidierung ist keine sprachliche Freigabe.
- QUALITY_STATUS.md trennt geprüfte Paketstruktur von noch offenen Geräte-/Sprachtests.
- SOURCES.md verlinkt Primärdokumentation und nennt Verifikationsaufträge.

## Lokale Paketprüfung
`python3 Scripts/validate_pilot.py`
Keine Zusatzbibliotheken erforderlich. Dieser Check prüft die Pilotdaten, nicht Swift-Code oder Hebräischqualität.

## Kostenrahmen
Keine entgeltlichen Sprecheraufnahmen, keine kostenpflichtige TTS-Erzeugung, keine kostenpflichtigen KI-Dienste zur App-Laufzeit, kein eigener Server. Entwicklung, App-Store-Vertrieb, Hardware und gegebenenfalls freiwillige Gerätesynchronisation sind separate Themen. Die Nutzung von Claude Code zur Entwicklung ist davon getrennt und richtet sich nach dem vorhandenen Zugang.
