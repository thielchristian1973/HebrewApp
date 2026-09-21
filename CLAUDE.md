# Verbindliche Projektregeln
## Vorrang
Aktuelle Nutzeranweisung > Documentation/DECISIONS.md > fachbezogene Spezifikationen > alter Blueprint. Dieses Paket ersetzt die kollidierenden Audio-/KI-/Speech-Abschnitte von v1.0. Implementierungsannahmen als solche in DECISIONS dokumentieren.

## Produkt und Kosten
Native SwiftUI iPhone/iPad, deutsche UI, modernes israelisches Hebräisch, erwachsene Anfänger. Offline-Kern, kein Pflichtkonto, keine Sprecherhonorare, keine entgeltliche Audio-Produktion, keine KI-/TTS-/ASR-Cloud-APIs, kein Backend. Keine Schlüssel, Cloud-SDKs oder Netzwerkanfragen für Tutor/Sprachanalyse einbauen. CloudKit ausschließlich für späteren optionalen Fortschrittsabgleich, getrennt vom Lernbetrieb. Keine Analytics-/Werbe-SDKs.

## Engineering
Swift 6, strict concurrency; SwiftData hinter Repository-Protokollen. Domain unabhängig von SwiftUI/SwiftData/Apple Speech. MainActor für UI-State; aufwändige Arbeit außerhalb. Kein Force-Unwrap, kein global veränderlicher Singleton, keine Dummy-Erfolge. Fehler, Cancellation und Zeitlimits behandeln. Abhängigkeiten minimal halten, Version/Commit und Lizenz festhalten. Keine kostenpflichtigen Downloads.

## Qualität
RTL von Beginn an. Stabile Content-IDs und atomare Fortschrittsspeicherung. Funktionierende Kernflows bei Mikrofonablehnung, fehlenden Modellen und Flugmodus. Aussagekraft von ASR niemals als Aussprache- oder Verständlichkeitsscore ausgeben. Keine eingebildeten Tests oder Sprachfreigaben. Zunächst Pilot, dann Kurs. Keine Endlosfehler-Schleifen.

## Ausführung und Übergabe
Bestehende Arbeit erhalten. Keine destruktiven Git-Befehle, keine Publikation. Unteraufträge im Paket begrenzen die jeweilige Phase. Selbstständig implementieren und verfügbare Tests durchführen; nur echte Blocker melden. Dokumentiere Projekt-/Scheme-Namen, SDK, Buildbefehle, Geräte, offene Messungen, Architekturentscheidungen und nächste Phase. Lokaler Git-Commit nur wenn Repo und Arbeitsweise es erlauben; keine fremden Änderungen committen.
