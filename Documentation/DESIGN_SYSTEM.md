# Designsystem
Ruhig, warm, erwachsen, hochwertige Typografie; sehr sparsame Akzente. Keine Goldflächen, Streak-Drohungen, Konfetti oder Leaderboards.

**Rebranding 21.09.2026** (Documentation/DECISIONS.md, "Rebranding-Entscheidung"): explizite, nutzergeführte Abkehr von der ursprünglichen Cremeton-/Petrol-Palette hin zu einer kräftigen Blau-Palette, und Aufhebung des ursprünglichen Komplettverbots von Maskottchen zugunsten eines einzigen, selbst entworfenen Maskottchens (Wiedehopf/דוכיפת, `HebrewApp/DesignSystem/HoopoeMascot.swift`) — kein Löwe, keine Kopie einer fremden Marke. Weiterhin keine zusätzlichen Comicfiguren, keine Gamification-Elemente (Konfetti, Leaderboards, Streak-Drohungen) über das eine Maskottchen hinaus.

## Starttokens (Designvorgaben, Kontrast vor Release prüfen)
Light: background #F3F6FD, surface #FFFFFF, primary #2952E3, text #16213E, secondaryText #5B6B8C, divider #DCE3F5.
Dark: background #0E1730, surface #16213E, primary #7C97FF, text #EDF1FF, secondaryText #A9B6D9, divider #2A3A5C.
Akzent #C97A3B nur für dezente dekorative Zwecke, passend zum Federkamm des Maskottchens; Fehlerzustände mit Text/Icon statt allein Farbe.
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
