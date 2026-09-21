# Datenverträge
## Produktionsmodell
ContentManifest: schemaVersion, contentVersion, minimumAppVersion, Dateien + SHA256, status.
Lexeme: id, hebrew, niqqud optional bis redaktionell freigegeben, lemma, transliteration optional, germanSenses, partOfSpeech, gender/number/root/binyan soweit fachlich sinnvoll, level, exampleSentenceIDs, audioSpec, reviewStatus. Frequenzrang nur mit belegter Datenquelle, sonst null.
Sentence: id, hebrew, niqqud, german, tokenIDs/geordnete Tokens, grammarTags, level, audioSpec, acceptedVariants, reviewStatus.
Lesson: id, moduleID, order, objectives, prerequisiteIDs, graphemePrerequisites, unitIDs, exerciseBlueprints, exitCriteria.
ExerciseBlueprint: id, type, promptRefs, targetDimension, answerPolicyID, difficulty, hintPolicy; E01–E12 siehe CONTENT_GUIDE.
SkillState: localProfileID, itemID, dimension, stability, difficulty, dueAt, lapses, helpLevel, evidenceStatus, independentSuccessDays. Nicht valide messbare Zustände nullable, keine Null als 'schlecht' interpretieren.
Attempt: UUID, UTC timestamp, localLearningDay, cardKey, response optional, correctness (correct/incorrect/unscored), hintUse, errorTags, latency, assessmentSource, schemaVersion.
PronunciationAttempt: UUID, optional relative audioLocalRef, optional transcript/confidence, feedbackKind, selfAssessment; keine erfundenen Segment-/Prosodiewerte.
SessionState: id, lessonID, contentVersion, currentStepID, completedAttemptIDs, pausedAt.
TutorResult: optional nextTurnID, feedbackID, provider, elapsedTime, capabilityStatus; freie Benchmarktexte getrennt und nicht im Kursbestand.

## Geliefertes Pilotformat v1
lexemes.json: Array von 50 Einträgen mit id/hebrew/german/ttsText/reviewStatus.
sentences.json: Array von 20 Einträgen mit denselben Feldern.
dialogues.json: vier Objekte mit id/title/objective/startNodeID/nodes/reviewStatus. Node hat id, promptSentenceID, answers, terminal. Antwort hat sentenceID, nextNodeID. Terminalknoten keine Antworten. IDs referenzieren die mitgelieferten Sätze. Pilotdialoge sind geführte Kommunikationsübungen, keine freie Konversationsprüfung.
Alle Pilottexte reviewStatus=draft. Fehlende Niqqud/grammatische Metadaten sind bewusst noch nicht fachlich freigegeben. Nicht aus diesen reduzierten Fixtures ein dauerhaft reduziertes Lexikonmodell ableiten. Claude Code erweitert das Produktionsschema und migriert mit dokumentierten Regeln.

## Migration/Sync
Content-IDs unveränderlich, gelöschte Items tombstonen. Neue Content-Version darf Fortschritt nicht verwerfen. Attempts append-only, idempotenter Import über UUID. Ableitungen bei Bedarf deterministisch aus History und Scheduler-Version rekonstruieren. JSON-Export mit schemaVersion; Import validieren, vor Änderung Backup, atomare Anwendung. Keine importierten Pfade ungeprüft öffnen.
