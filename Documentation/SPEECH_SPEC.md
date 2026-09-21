# Sprache und Audio
## Sprachausgabe
System-TTS über AVSpeechSynthesizer, verfügbare hebräische Voices abfragen; he-IL bevorzugen. Voice-ID und Qualität nicht hardcoden. Verfügbarkeit, verständliche Stimme, richtige Vokalisierung und offline funktionierende Assets auf echten Geräten prüfen. Als 'Hörprobe' anbieten, gewählte Voice speichern und nach Änderungen neu auflösen. Wenn keine geeignete Voice installiert ist: Einrichtungshinweis und Textlernen; Hörkurs nicht als vollständig offline freigegeben markieren.
TTS-Eingabe separat vom Anzeige-Niqqud zulassen (ttsText), aber nur nach redaktioneller Prüfung; Niqqud kann je Stimme anders verarbeitet werden. Die Pilotdaten enthalten zunächst ttsText = hebrew, ohne behauptete Vokalisierungsqualität. Keine Aussprache von Buchstabennamen ungeprüft aus einem einzelnen Glyph ableiten; eigene geprüfte TTS-Zieltexte vorsehen.
Normal/langsam als verständliche Optionen. Synthetische Sprechrate ist kein garantiert exaktes 0,75-faches Tempo. Bei echten Audiodateien wäre timestretch getrennt zu implementieren. Keine Audio-Bibliothek durch OS-Voice-Export aufbauen, ohne Redistribution/Nutzungsbedingungen separat zu klären; V1 spricht lokal zur Laufzeit.

## Aufnahme
Mikrofonberechtigung erst beim ersten Aufnahmeversuch. Start/Stop, sichtbarer Zustand, Abbruch, Wiedergeben, Löschen. Session-Unterbrechung, Bluetooth/Headset-Wechsel, Hintergrund und Navigation testen. Temporäre Aufnahmen nach Verlassen/Auswertung löschen; dauerhafte Speicherung nur ausdrücklich. Maximal 60 Sekunden je Übung als initiale Grenze. Aufnahme auch ohne ASR zulassen.

## Lokale Erkennung
he-IL-Recognizer und supportsOnDeviceRecognition prüfen. Request nur starten, wenn diese Capability vorliegt; requiresOnDeviceRecognition zwingend aktivieren. SDK-API und Fehlerverhalten prüfen. Keine Erkennung auslösen, die Netzwerk benötigt. Nicht unterstützt/keine Berechtigung/Assets fehlen → Aufnahme+Selbstvergleich und Text-/Auswahlalternative.
Transkripte dürfen als 'Erkannt: …' angezeigt werden. 'Nicht sicher erkannt' ist kein Beweis falscher Aussprache. Confidence nicht als Prozent für Sprachqualität verwenden. Leises Umfeld empfehlen nur bei konkretem Signalproblem.

## Feedback
Bewertungsklassen: transcriptMatchesTarget, transcriptDiffers, recognitionUnavailable, selfReviewed. Keine Phonem-, Akzent-, Betonungs- oder Verständlichkeitsnote. Inhaltsbezogene Fehler (z.B. falsches erwartetes Wort) nur mit Bezug auf das Transkript und optionaler Nutzerbestätigung. Worterkennung allein setzt Pronunciation-Mastery niemals auf bestanden.
Hören, Nachsprechen, eigener Vergleich und erneut versuchen bleiben zentrale Lernaktivitäten. Kein Sprachfehler-Label nach bloßer Berechtigungsablehnung.
