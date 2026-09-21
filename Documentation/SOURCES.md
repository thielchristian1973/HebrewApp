# Quellen und Verifikationsstand
Technische Primärquellen am 21.09.2026 recherchiert. Laufzeitverfügbarkeit, Sprachabdeckung und SDK-Signaturen sind zusätzlich beim Implementieren und auf Zielgeräten zu prüfen. Ein Suchtreffer ersetzt keinen Build.

- Apple SystemLanguageModel, On-Device und Verfügbarkeit: https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel
- Foundation Models Sprachen/Locales: https://developer.apple.com/documentation/foundationmodels/supporting-languages-and-locales-with-foundation-models
- supportedLanguages / supportsLocale: https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/supportedlanguages
- Apple-Intelligence-Geräteanforderungen: https://support.apple.com/de-de/121115
- System-TTS: https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer
- Voice-Auswahl: https://developer.apple.com/documentation/avfaudio/avspeechsynthesisvoice
- Lokale ASR-Capability: https://developer.apple.com/documentation/speech/sfspeechrecognizer/supportsondevicerecognition
- Lokale Anfrage: https://developer.apple.com/documentation/speech/sfspeechrecognitionrequest/requiresondevicerecognition
- FSRS Projekt/Implementierungsreferenzen: https://github.com/open-spaced-repetition/free-spaced-repetition-scheduler
- FSRS Rating-Semantik: https://github.com/open-spaced-repetition/fsrs4anki/blob/main/docs/tutorial.md

Apple-Intelligence-fähige Hardware ist eine Voraussetzung des Systemmodells; ein ausreichend neues iOS allein genügt nicht. Hebräischunterstützung wird hier nicht pauschal behauptet. TTS, ASR und Textmodell haben voneinander unabhängige Sprach-/Gerätebedingungen. Eine unterstützte Sprache ist keine Garantie ausreichender Lernqualität.

Produktquelle: Hebraeisch_App_Blueprint_v1.0.docx, 20.09.2026, vollständig gelesen am 21.09.2026. Konsolidierung mit den nachfolgenden expliziten Entscheidungen: keine Sprecher-/API-Kosten, hochwertiger Offline-Kern, lokaler KI-Pilot. Designfarben, Defaults und Pilot-Schwellen sind eigene Umsetzungsvorgaben, keine wissenschaftlich validierten Befunde.
