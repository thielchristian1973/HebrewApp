# Designsystem
Ruhig, warm, erwachsen, hochwertige Typografie; sehr sparsame Akzente. Keine Comicmaskottchen, Goldflächen, Streak-Drohungen, Konfetti oder Leaderboards.

## Starttokens (Designvorgaben, Kontrast vor Release prüfen)
Light: background #F7F4EE, surface #FFFFFF, primary #153F40, text #192D2E, secondaryText #526362, divider #D7DED9.
Dark: background #101D1E, surface #1A2B2C, primary #A7D1C5, text #F3F3EA, secondaryText #BBCBC7.
Akzent #A96542 nur für dezente dekorative Zwecke; Fehlerzustände mit Text/Icon statt allein Farbe.
Spacing 4/8/12/16/24/32; Cards Radius 16; Buttons mindestens 44 pt bedienbare Fläche. Native semantische Textstile/Dynamic Type, keine fixen kleinen Labels.

## HebrewText
Eigene wiederverwendbare Komponente mit sprachspezifischem Font-Fallback, Platz ober-/unterhalb für Niqqud, korrekter RTL-Richtung. Deutsche Navigation LTR. Wortreihenfolge niemals durch String-Reverse ändern. Interpunktion, Ziffern, Klammern und gemischte Zeilen mit expliziten Sprachbereichen prüfen. Geordnete Tokens als Daten speichern, visuell RTL auslegen. Native Textfeld-Cursor/Selektion nutzen. Systemfont wählen, der Niqqud zuverlässig rendert; keine kommerziellen Fonts beschaffen.

## Screens
Heute: eine dominante 'Weiterlernen'-Aktion, Ziel der nächsten Einheit, kleine Review-Zeile.
Übung: Fortschritt, klarer Prompt, große hebräische Antwortfläche, Hilfen auf Anfrage, Feedback unten ohne Layoutsprung.
Sprechen: Referenz/Meine Aufnahme, klarer Aufnahmestatus, Transkript als Erkennungsergebnis, kein Pseudo-Score.
Dialog: Rollen und Ziel sichtbar; jeweils ein Antwortschritt. Tipp, Text und Aufnahme verständlich beschriftet.
Fortschritt: getrennte Kompetenzen mit Evidenz/Übungshistorie; ungemessene Bereiche ausdrücklich unbewertet.

## Accessibility
VoiceOver-Sprache pro Textbereich, deutsche Labels für Controls, nachvollziehbare Fokusreihenfolge. Reduce Motion, Light/Dark, große Textgrößen, iPad Split View und Hardwaretastatur. Satzordnung zusätzlich über zugängliche Auswahl/Move-Actions; Drag-and-drop nie einziger Weg. Kontrast nach WCAG AA prüfen und reale Ergebnisse notieren.
