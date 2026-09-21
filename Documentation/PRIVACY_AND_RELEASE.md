# Datenschutz, Sync und Release
## Daten
Lernfortschritt lokal, keine Pflichtregistrierung. Aufnahmen kurzlebig und nicht in Analytics/Sync. Eigene Aufnahme dauerhaft nur auf ausdrücklichen Wunsch; lokal löschbar. Export enthält standardmäßig Fortschritt/Einstellungen, keine Audioaufnahmen. Komplettes Zurücksetzen mit Bestätigung und definierter Sync-Semantik.
Mikrofon-/Speech-Zwecktexte auf Deutsch, erst kontextbezogen anfragen. Privacy Manifest und App-Store-Datenschutzangaben anhand tatsächlich verwendeter APIs/SDKs erstellen, keine pauschale 'keine Daten'-Behauptung bei optionalem Sync.

## Optionaler iCloud-Abgleich
Späte V1-Phase, opt-in, bestehendes Apple-iCloud-Konto statt eigenem App-Konto. Keine Erfordernis für den Kern. Private CloudKit-Datenbank nur für Progress/Settings; keine Sprachdaten. Datenmodell/Synchronisationsconstraints prüfen, bevor SwiftData-CloudKit gewählt wird. Event-UUIDs deduplizieren, History erhalten, State deterministisch neu ableiten. Settings mit expliziter Konfliktregel; Löschmarker dürfen gelöschte Daten nicht wiederbeleben. Sync-Ausfälle dürfen lokalen Lernfortschritt nie blockieren. Echte iCloud-Mehrgeräteprüfung getrennt, ohne Credentials erfinden.

## Vertrieb
Einmalkauf für Kernapp, später Kurs-Erweiterungen. StoreKit 2 für digitale Erweiterungen mit lokalem StoreKit-Testplan, Restore und vorhandenen Offline-Entitlements. Keine künstlichen Produktions-IDs/Preise. Keine Runtime-KI-Abos. App-Store-/Signatur-/Rechtsdetails vor tatsächlichem Release aktuell prüfen; hier keine Rechtsfreigabe behaupten.
App-Store-Assets: deutscher Titel/Subtitel/Beschreibung, echte Screenshots, Support-/Datenschutz-URL und App-Icon. Unbekannten finalen Namen, Team und URLs als offene Releaseentscheidungen dokumentieren, nicht in UI als Platzhalter stehen lassen. Keine Veröffentlichung oder TestFlight-Einladung ohne Nutzerauftrag.
