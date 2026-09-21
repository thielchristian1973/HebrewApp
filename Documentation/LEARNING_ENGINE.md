# Lernlogik
SessionComposer priorisiert fällige Karten und schwächste relevante Dimensionen. Ziel maximal 40 % Wiederholung in normalen Sitzungen; bei großem Rückstand eine klar bezeichnete Wiederholungssitzung anbieten, nicht endlos neue Inhalte sperren. Voraussetzungen schützen Lernprogression; Nachschlagewerk und bereits freigeschaltete Inhalte frei zugänglich.

## Scheduler
FSRS hinter Scheduler-Protokoll. Vor Integration offizielle Referenz, Implementierungsversion, Lizenz und Referenz-Testvektoren verifizieren. Version im Datenbestand speichern; Initialparameter versionieren. Kein erfundenes Intervallschema als FSRS ausgeben. Im Pilot darf Review noch fehlen, aber keine fingierten FSRS-Stabilitäten anzeigen.
Rating als again/hard/good/easy im Domainmodell; echte Bibliothekswerte ausschließlich im Adapter abbilden. Falsche Antwort → again, nicht hard. Unterstützte/revealed Antwort → keine unabhängige erfolgreiche Mastery-Evidenz; Hilfe und Scheduling-Policy getrennt speichern. Selbstbewertung als solche kennzeichnen. Initial retention 0,90 als dokumentierter Default.

## Zeit und Identität
CardKey = itemID + dimension + taskVariant. Attempts unveränderliche UUID-Ereignisse. UTC Zeitpunkte und Calendar/Timezone für lokale Lerntage, jeweils nachvollziehbar speichern. Geräteuhr-Rücksprung/Zeitzonenwechsel/DST testen. Doppelte Events nicht erneut anwenden. Parameterupdates dürfen IDs und History nicht ersetzen.

## Auswertung
Nur aufgabenspezifisch normalisieren: Unicode-Normalisierung und Leerzeichen. Niqqud in einer unvokalisierten Bedeutungsaufgabe ignorieren; in Vokalisierungsaufgaben erhalten. ם/מ, ן/נ usw. nicht global gleichsetzen; Endformen sind Schriftkompetenz. Akzeptierte orthografische/grammatische Varianten redaktionell hinterlegen. Freie nicht abgedeckte Antwort = unbewertet + passende Hilfestellung, nicht pauschal falsch. Auswahl-Erfolg erhöht nicht automatisch Recall oder Production.
