# Technik-Pilot P1
## Umfang
50 Wörter, 20 Sätze und vier Dialoge: Begrüßung, Café, Weg fragen, Einkaufen. Bestehende Fixtures nutzen. Zwei einfache vollständig bedienbare Demo-Lernstrecken aus dem Material erstellen (Vorstellen, Café), aber nicht als vollständige A0-Lektionen deklarieren.

## Bedienung
Entwickler-Pilotscreen zeigt Contentliste, TTS-Hörprobe, Stimmenstatus, Aufnahme/Wiedergabe, lokale ASR-Verfügbarkeit, Tutor-Verfügbarkeit und vier Dialoge. Endnutzer-Demoscreen bleibt frei von technischen Logs. Geräte-/OS-/Voice-/Modellinformationen in lokal exportierbarem Bericht; keine personenbezogenen Sprachinhalte automatisch exportieren.

## Testmatrix
A: älteres iPhone ohne Apple Intelligence – vollständiger geführter Lernpfad.
B: Apple-Intelligence-fähiges iPhone – verfügbar/deaktiviert/Modell fehlt/Sprache fehlt.
C: iPad – Sidebar, Split View, Tastatur und Audio.
D: Simulator – UI/Persistenz/Domain; nicht als Beleg für physische Audio-/Modellqualität verwenden.
Je physischem Gerät online eingerichtet, Flugmodus, App-Kaltstart, Mikrofon verweigert, ASR nicht unterstützt, Unterbrechung/Headsetwechsel, Modelltimeout. Nicht vorhandene Geräte als ungetestet kennzeichnen.

## Abnahme
- 50/20/4 vollständig ladbar, IDs/Graphen konsistent.
- Beide Demo-Lernstrecken ohne KI und ohne Mikrofon abschließbar; beim Neustart fortsetzbar.
- Mit vorinstallierter Voice alle 70 TTS-Items im Flugmodus abspielbar. Hebräischqualität pro Item durch qualifizierte Prüfung dokumentieren; Wort/Satzgrenzen, Vokalisierung und Verständlichkeit prüfen. Ein falsches kritisches Zielwort sperrt das betreffende Item.
- Geführte Dialoge immer verfügbar. Lokale KI nur bei erfüllter Capability; Ungültiges/Timeout führt zum gültigen nächsten geführten Schritt.
- Kein automatischer Netzaufruf für Tutor/ASR/TTS-Inferenz; Geräte-/Asset-Downloads als Einrichtung unterscheiden. Code-Audit plus tatsächlicher Offline-Durchlauf.
- Performanceziele aus LOCAL_AI messen; fehlende Messungen nicht als bestanden verbuchen.
- RTL/Niqqud/VoiceOver auf kleiner iPhone-Breite und iPad visuell/manuell prüfen.

## Entscheidung nach Pilot
Go für Kern nur bei tragfähiger lokaler Audioqualität und funktionierendem geführten Pfad. Go für lokalen generativen Tutor separat. Bei fehlender Apple-Hebräischqualität Embedded-Model-Benchmark als nächster isolierter Versuch, keine automatische Festlegung auf beliebige Gewichte. Ungenügende TTS-Qualität transparent als Zielkonflikt melden; keine kostenpflichtige Lösung still einführen.
