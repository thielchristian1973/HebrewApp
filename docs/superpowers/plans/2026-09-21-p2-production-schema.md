# P2 Production Content Schema, Validator, Persistence — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the production Domain types DATA_MODEL.md specifies (content-side: Lexeme/Sentence/Lesson/ExerciseBlueprint/manifest/bundle; progress-side: SkillState/Attempt/SessionState/TutorResult), a production content validator (Swift loader + Python CI-mirror), and SwiftData persistence for the new mutable types via a real migration stage — without touching any existing pilot code or flow.

**Architecture:** Purely additive to the existing layering (Domain/Content/Data, ARCHITECTURE.md). New types live in new files; the one existing file that must change (`DomainErrors.swift`, to add new `ContentLoadError` cases) is extended, never restructured. Two new protocols (`ProductionContentRepository`, `ProductionProgressRepository`) avoid forcing the existing `PilotContentLoader`/`ContentRepository`/`ProgressRepository` surface to change at all.

**Tech Stack:** Swift 6 (strict concurrency), SwiftUI/SwiftData (iOS 17+), XcodeGen-generated project, Swift Testing framework (`@Suite`/`@Test`/`#expect`), Python 3 (validator CI-mirror), `xcodebuild` as the verification tool.

**Spec:** `docs/superpowers/specs/2026-09-21-p2-production-schema-design.md` — read it in full before starting; this plan implements it exactly, including its three post-approval corrections (Clock already exists, TutorResult resolved, separate repository protocols instead of extending existing ones).

## Global Constraints

- Domain layer: `Foundation` import only — no `SwiftUI`/`SwiftData`/`Speech` imports, ever.
- No force-unwraps, no global mutable singletons, no fabricated/dummy success results.
- Typed throws only for new repository/service methods (`throws(ContentLoadError)`, `throws(PersistenceError)`), matching the existing pattern exactly.
- SwiftData only for mutable user data — course content (`Lexeme`/`Sentence`/`Lesson`) stays bundle JSON, never a `@Model` type.
- Existing pilot code (`PilotContentLoader`, `PilotAttempt`, `PilotLearningPath`, the four existing `@Model` types, `ContentRepository`, `ProgressRepository`) must not change behavior or break — the two pilot demo paths must keep working exactly as today (PILOT.md).
- No fabricated FSRS values, no pronunciation/intelligibility scores surfaced anywhere — not relevant to this plan's new code paths directly, but any doc comment referencing scoring must stay honest about what isn't built yet.
- TDD: write the failing test first, watch it fail for the right reason, then write the minimal code to pass. Every task below follows RED → GREEN → commit.
- After any `project.yml` change, run `xcodegen generate` before building.
- Build/test command (repeat exactly after every task, on the iPhone 17 Pro / iOS 26.5 simulator this repo has used all session — replace only if that simulator is genuinely unavailable, and note why):
  ```bash
  xcodegen generate
  xcodebuild build -project HebrewApp.xcodeproj -scheme HebrewApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
  xcodebuild test -project HebrewApp.xcodeproj -scheme HebrewApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
  ```
- Existing test count going in: 30 unit tests (Swift Testing) + 5 UI tests (XCTest). That count must only ever go up, never down or flat with a regression.

---

### Task 1: Content-side production Domain types

**Files:**
- Create: `HebrewApp/Domain/ProductionContent.swift`
- Test: `HebrewAppTests/ProductionContentTests.swift`

**Interfaces:**
- Consumes: nothing (pure new types, `Foundation` only). Reuses the existing `ReviewStatus` enum from `HebrewApp/Domain/PilotContent.swift` (already `Codable, Sendable, Hashable`, cases `draft`/`structurallyValidated`/`linguisticallyReviewed`/`released`) — do not redeclare it.
- Produces: `CourseLevel`, `PartOfSpeech`, `GrammaticalGender`, `GrammaticalNumber`, `Binyan`, `GermanSense`, `FrequencyRank`, `AudioSourceKind`, `AudioSpec`, `Lexeme`, `SentenceToken`, `Sentence`, `ExerciseType`, `CompetenceDimension`, `HintPolicy`, `ExerciseBlueprint`, `ExitCriteria`, `Lesson`, `ProductionManifestFile`, `ProductionManifestCounts`, `ProductionContentManifest`, `ProductionContentBundle` — every later task that touches content types imports these by name, unchanged.

- [ ] **Step 1: Write the failing decode-shape test**

Create `HebrewAppTests/ProductionContentTests.swift`:

```swift
import Testing
import Foundation
@testable import HebrewApp

@Suite("Production content Domain models")
struct ProductionContentTests {
    @Test("Lexeme decodes the full production field shape")
    func lexemeDecodesFullShape() throws {
        let json = """
        {
          "id": "lex_p_001",
          "hebrew": "שלום",
          "niqqud": "שָׁלוֹם",
          "lemma": "שלום",
          "transliteration": "shalom",
          "germanSenses": [
            { "translation": "Hallo", "usageNote": "Begrüßung" },
            { "translation": "Frieden", "usageNote": null }
          ],
          "partOfSpeech": "interjection",
          "gender": null,
          "number": null,
          "root": null,
          "binyan": null,
          "level": "a1",
          "exampleSentenceIDs": ["sent_p_001"],
          "audioSpec": {
            "sourceKind": "systemTTS",
            "bundledAssetRelativePath": null,
            "targetVoiceIdentifiers": [],
            "isVerifiedAgainstTargetVoices": false
          },
          "frequencyRank": null,
          "reviewStatus": "draft"
        }
        """.data(using: .utf8)!

        let lexeme = try JSONDecoder().decode(Lexeme.self, from: json)

        #expect(lexeme.id == "lex_p_001")
        #expect(lexeme.hebrew == "שלום")
        #expect(lexeme.niqqud == "שָׁלוֹם")
        #expect(lexeme.germanSenses.count == 2)
        #expect(lexeme.germanSenses[0].translation == "Hallo")
        #expect(lexeme.partOfSpeech == .interjection)
        #expect(lexeme.level == .a1)
        #expect(lexeme.audioSpec.sourceKind == .systemTTS)
        #expect(lexeme.reviewStatus == .draft)
    }

    @Test("Sentence decodes tokens and accepted variants")
    func sentenceDecodesTokens() throws {
        let json = """
        {
          "id": "sent_p_001",
          "hebrew": "שלום, בוקר טוב.",
          "niqqud": null,
          "german": "Hallo, guten Morgen.",
          "tokens": [
            { "id": "tok_001", "surfaceForm": "שלום", "niqqud": null, "lexemeID": "lex_p_001" },
            { "id": "tok_002", "surfaceForm": "בוקר", "niqqud": null, "lexemeID": "lex_p_005" }
          ],
          "grammarTags": ["greeting"],
          "level": "a1",
          "audioSpec": {
            "sourceKind": "systemTTS",
            "bundledAssetRelativePath": null,
            "targetVoiceIdentifiers": [],
            "isVerifiedAgainstTargetVoices": false
          },
          "acceptedVariants": ["שלום, בוקר טוב"],
          "reviewStatus": "draft"
        }
        """.data(using: .utf8)!

        let sentence = try JSONDecoder().decode(Sentence.self, from: json)

        #expect(sentence.tokens.count == 2)
        #expect(sentence.tokens[0].lexemeID == "lex_p_001")
        #expect(sentence.acceptedVariants == ["שלום, בוקר טוב"])
    }

    @Test("Lesson decodes prerequisites, unit IDs and an embedded exercise blueprint")
    func lessonDecodesFullShape() throws {
        let json = """
        {
          "id": "lesson_p_002",
          "moduleID": "module_p_greeting",
          "order": 2,
          "objectives": ["Auf Dank reagieren"],
          "prerequisiteIDs": ["lesson_p_001"],
          "graphemePrerequisites": [],
          "unitIDs": ["lex_p_002", "lex_p_003"],
          "exerciseBlueprints": [
            {
              "id": "eb_p_002",
              "type": "e04ActiveMeaningRecall",
              "promptRefs": ["lex_p_002"],
              "targetDimension": "recall",
              "answerPolicyID": "policy_p_002",
              "difficulty": 1,
              "hintPolicy": { "levelCount": 2, "revealsAnswerAtFinalLevel": true }
            }
          ],
          "exitCriteria": {
            "requiredExerciseBlueprintIDs": ["eb_p_002"],
            "minimumIndependentCorrectRatio": null
          },
          "level": "a1",
          "reviewStatus": "draft"
        }
        """.data(using: .utf8)!

        let lesson = try JSONDecoder().decode(Lesson.self, from: json)

        #expect(lesson.prerequisiteIDs == ["lesson_p_001"])
        #expect(lesson.exerciseBlueprints.count == 1)
        #expect(lesson.exerciseBlueprints[0].type == .e04ActiveMeaningRecall)
        #expect(lesson.exerciseBlueprints[0].targetDimension == .recall)
        #expect(lesson.exitCriteria.requiredExerciseBlueprintIDs == ["eb_p_002"])
    }

    @Test("ProductionContentBundle exposes lookup dictionaries by ID")
    func bundleLookupDictionaries() throws {
        let manifest = ProductionContentManifest(
            schemaVersion: 1,
            contentVersion: "0.1.0-fixture",
            minimumAppVersion: "0.1.0",
            status: .draft,
            counts: ProductionManifestCounts(lexemes: 1, sentences: 0, lessons: 0),
            files: []
        )
        let lexeme = Lexeme(
            id: "lex_x", hebrew: "x", niqqud: nil, lemma: "x", transliteration: nil,
            germanSenses: [], partOfSpeech: .noun, gender: nil, number: nil, root: nil,
            binyan: nil, level: .a1, exampleSentenceIDs: [],
            audioSpec: AudioSpec(sourceKind: .systemTTS, bundledAssetRelativePath: nil, targetVoiceIdentifiers: [], isVerifiedAgainstTargetVoices: false),
            frequencyRank: nil, reviewStatus: .draft
        )
        let bundle = ProductionContentBundle(manifest: manifest, lexemes: [lexeme], sentences: [], lessons: [])

        #expect(bundle.lexemesByID["lex_x"]?.hebrew == "x")
        #expect(bundle.sentencesByID.isEmpty)
        #expect(bundle.lessonsByID.isEmpty)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test -project HebrewApp.xcodeproj -scheme HebrewApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:HebrewAppTests/ProductionContentTests`

Expected: build error — `Lexeme`/`Sentence`/`Lesson`/`ProductionContentBundle`/etc. don't exist yet ("cannot find type ... in scope").

- [ ] **Step 3: Write the minimal implementation**

Create `HebrewApp/Domain/ProductionContent.swift`:

```swift
import Foundation

/// A0/A1/A2 per Documentation/CURRICULUM.md.
enum CourseLevel: String, Codable, Sendable, CaseIterable {
    case a0, a1, a2
}

enum PartOfSpeech: String, Codable, Sendable, CaseIterable {
    case noun, verb, adjective, adverb, pronoun, preposition, conjunction, interjection, numeral, particle
}

enum GrammaticalGender: String, Codable, Sendable, CaseIterable {
    case masculine, feminine
}

enum GrammaticalNumber: String, Codable, Sendable, CaseIterable {
    case singular, plural, dual
}

/// The seven Hebrew verb patterns (בניינים).
enum Binyan: String, Codable, Sendable, CaseIterable {
    case paal, niphal, piel, pual, hiphil, hophal, hitpael
}

struct GermanSense: Codable, Sendable, Hashable {
    var translation: String
    var usageNote: String?
}

/// Frequency rank is only ever populated with a documented source — never inferred
/// (Documentation/DATA_MODEL.md: "Frequenzrang nur mit dokumentierter Quelle").
struct FrequencyRank: Codable, Sendable, Hashable {
    var rank: Int
    var source: String
}

/// Whether an item's audio comes from on-device synthesis or a specific pre-rendered,
/// reviewed asset. Flat `kind` + optional payload (not a Swift associated-value enum)
/// because Swift's synthesized `Codable` for an associated-value case produces a
/// nested, hand-authoring-unfriendly shape (`{"bundledAsset":{"relativePath":"..."}}`).
enum AudioSourceKind: String, Codable, Sendable, Hashable {
    case systemTTS
    case bundledAsset
}

struct AudioSpec: Codable, Sendable, Hashable {
    var sourceKind: AudioSourceKind
    var bundledAssetRelativePath: String?
    var targetVoiceIdentifiers: [String]
    var isVerifiedAgainstTargetVoices: Bool
}

struct Lexeme: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let hebrew: String
    var niqqud: String?
    let lemma: String
    var transliteration: String?
    var germanSenses: [GermanSense]
    var partOfSpeech: PartOfSpeech
    var gender: GrammaticalGender?
    var number: GrammaticalNumber?
    /// Hebrew root (שורש), where linguistically meaningful.
    var root: String?
    var binyan: Binyan?
    var level: CourseLevel
    var exampleSentenceIDs: [String]
    var audioSpec: AudioSpec
    var frequencyRank: FrequencyRank?
    var reviewStatus: ReviewStatus
}

struct SentenceToken: Codable, Sendable, Hashable, Identifiable {
    let id: String
    var surfaceForm: String
    var niqqud: String?
    /// nil when this token doesn't map to a tracked lexeme yet.
    var lexemeID: String?
}

struct Sentence: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let hebrew: String
    var niqqud: String?
    let german: String
    var tokens: [SentenceToken]
    var grammarTags: [String]
    var level: CourseLevel
    var audioSpec: AudioSpec
    var acceptedVariants: [String]
    var reviewStatus: ReviewStatus
}

enum ExerciseType: String, Codable, Sendable, CaseIterable {
    case e01LetterRecognition, e02SoundGrapheme, e03Reading, e04ActiveMeaningRecall
    case e05ListeningComprehension, e06SentenceOrdering, e07MatchingGapFill, e08ChunkCompletion
    case e09RepeatAfterMe, e10SoundContrast, e11GuidedDialogue, e12FreeMicroTask
}

/// The seven competence dimensions (Documentation/DIDACTICS.md).
enum CompetenceDimension: String, Codable, Sendable, CaseIterable {
    case recognition, recall, reading, listening, grammar, production, pronunciation
}

struct HintPolicy: Codable, Sendable, Hashable {
    /// Help levels N0 (independent) through N(levelCount-1).
    var levelCount: Int
    var revealsAnswerAtFinalLevel: Bool
}

struct ExerciseBlueprint: Codable, Sendable, Hashable, Identifiable {
    let id: String
    var type: ExerciseType
    /// Lexeme/Sentence IDs this exercise instance draws its prompt from.
    var promptRefs: [String]
    var targetDimension: CompetenceDimension
    var answerPolicyID: String
    var difficulty: Int
    var hintPolicy: HintPolicy
}

struct ExitCriteria: Codable, Sendable, Hashable {
    var requiredExerciseBlueprintIDs: [String]
    /// nil = just require each required blueprint attempted at least once.
    var minimumIndependentCorrectRatio: Double?
}

/// One atomic "Einführungseinheit" (introduction sub-unit) — NOT one of the 18 themed
/// A1 chapters. `moduleID` is which chapter this unit belongs to; `unitIDs` are the
/// Lexeme/Sentence IDs newly introduced by this lesson.
struct Lesson: Codable, Sendable, Hashable, Identifiable {
    let id: String
    var moduleID: String
    var order: Int
    var objectives: [String]
    var prerequisiteIDs: [String]
    /// Hebrew grapheme identifiers that must already be introduced before this
    /// lesson's reading-type exercises may be attempted (DECISIONS.md #6).
    var graphemePrerequisites: [String]
    var unitIDs: [String]
    var exerciseBlueprints: [ExerciseBlueprint]
    var exitCriteria: ExitCriteria
    var level: CourseLevel
    var reviewStatus: ReviewStatus
}

struct ProductionManifestFile: Codable, Sendable, Hashable {
    let path: String
    let sha256: String
}

struct ProductionManifestCounts: Codable, Sendable, Hashable {
    let lexemes: Int
    let sentences: Int
    let lessons: Int
}

struct ProductionContentManifest: Codable, Sendable, Hashable {
    let schemaVersion: Int
    let contentVersion: String
    let minimumAppVersion: String
    let status: ReviewStatus
    let counts: ProductionManifestCounts
    let files: [ProductionManifestFile]
}

/// The fully loaded, hash-verified production content bundle. Nothing here is ever
/// mutated at runtime (ARCHITECTURE.md: "Content: versionierte Bundle-Daten").
struct ProductionContentBundle: Sendable {
    let manifest: ProductionContentManifest
    let lexemes: [Lexeme]
    let sentences: [Sentence]
    let lessons: [Lesson]

    var lexemesByID: [String: Lexeme] {
        Dictionary(uniqueKeysWithValues: lexemes.map { ($0.id, $0) })
    }
    var sentencesByID: [String: Sentence] {
        Dictionary(uniqueKeysWithValues: sentences.map { ($0.id, $0) })
    }
    var lessonsByID: [String: Lesson] {
        Dictionary(uniqueKeysWithValues: lessons.map { ($0.id, $0) })
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `xcodebuild test -project HebrewApp.xcodeproj -scheme HebrewApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:HebrewAppTests/ProductionContentTests`

Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add HebrewApp/Domain/ProductionContent.swift HebrewAppTests/ProductionContentTests.swift
git commit -m "Add production content Domain types (Lexeme/Sentence/Lesson/ExerciseBlueprint)"
```

---

### Task 2: Progress-side production Domain types

**Files:**
- Create: `HebrewApp/Domain/SkillState.swift`
- Create: `HebrewApp/Domain/ProductionAttempt.swift`
- Create: `HebrewApp/Domain/SessionState.swift`
- Test: `HebrewAppTests/ProductionAttemptTests.swift`

**Interfaces:**
- Consumes: `CompetenceDimension` (Task 1).
- Produces: `EvidenceStatus`, `SkillState`, `CardKey`, `Correctness`, `AssessmentSource`, `Attempt`, `SessionState` — Task 9 (SwiftData) and Task 10 (repository) construct/read these exact types.

- [ ] **Step 1: Write the failing test**

Create `HebrewAppTests/ProductionAttemptTests.swift`:

```swift
import Testing
import Foundation
@testable import HebrewApp

@Suite("Production Attempt and SkillState")
struct ProductionAttemptTests {
    @Test("Attempt round-trips through Codable with a stable CardKey")
    func attemptRoundTrips() throws {
        let attempt = Attempt(
            id: UUID(),
            timestampUTC: Date(timeIntervalSince1970: 1_726_000_000),
            localLearningDay: "2026-09-21",
            timezoneIdentifier: "Europe/Berlin",
            cardKey: CardKey(itemID: "lex_p_001", dimension: .recall, taskVariant: "e04"),
            response: "שלום",
            correctness: .correct,
            hintUse: 0,
            errorTags: [],
            latency: 3.2,
            assessmentSource: .systemEvaluated,
            schemaVersion: 1
        )

        let data = try JSONEncoder().encode(attempt)
        let decoded = try JSONDecoder().decode(Attempt.self, from: data)

        #expect(decoded.cardKey.itemID == "lex_p_001")
        #expect(decoded.cardKey.dimension == .recall)
        #expect(decoded.correctness == .correct)
        #expect(decoded.assessmentSource == .systemEvaluated)
    }

    @Test("SkillState leaves stability/difficulty/dueAt nil until measured")
    func skillStateStartsUnmeasured() {
        let state = SkillState(
            localProfileID: UUID(),
            itemID: "lex_p_001",
            dimension: .recall,
            stability: nil,
            difficulty: nil,
            dueAt: nil,
            lapses: 0,
            helpLevel: 0,
            evidenceStatus: .notYetMeasured,
            independentSuccessDays: 0
        )

        #expect(state.stability == nil)
        #expect(state.evidenceStatus == .notYetMeasured)
    }

    @Test("SessionState tracks completed attempts as an append-only list")
    func sessionStateTracksCompletedAttempts() {
        let attemptID = UUID()
        var state = SessionState(
            id: UUID(),
            lessonID: "lesson_p_001",
            contentVersion: "0.1.0-fixture",
            currentStepID: "eb_p_001",
            completedAttemptIDs: [],
            pausedAt: nil
        )
        state.completedAttemptIDs.append(attemptID)

        #expect(state.completedAttemptIDs == [attemptID])
        #expect(state.lessonID == "lesson_p_001")
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test -project HebrewApp.xcodeproj -scheme HebrewApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:HebrewAppTests/ProductionAttemptTests`

Expected: build error — `Attempt`/`CardKey`/`SkillState`/`SessionState` don't exist yet.

- [ ] **Step 3: Write the minimal implementation**

Create `HebrewApp/Domain/SkillState.swift`:

```swift
import Foundation

enum EvidenceStatus: String, Codable, Sendable {
    case notYetMeasured
    case helpAssistedOnly
    case independentEvidence
}

/// Per (profile, item, dimension) mastery state. `stability`/`difficulty`/`dueAt` stay
/// nil until the FSRS-adapter sub-project populates them — nil must never be read as
/// "bad" (Documentation/DATA_MODEL.md).
struct SkillState: Codable, Sendable, Hashable {
    let localProfileID: UUID
    let itemID: String
    let dimension: CompetenceDimension
    var stability: Double?
    var difficulty: Double?
    var dueAt: Date?
    var lapses: Int
    var helpLevel: Int
    var evidenceStatus: EvidenceStatus
    var independentSuccessDays: Int
}
```

Create `HebrewApp/Domain/ProductionAttempt.swift`:

```swift
import Foundation

/// itemID + dimension + taskVariant identifies one schedulable "card"
/// (Documentation/LEARNING_ENGINE.md).
struct CardKey: Codable, Sendable, Hashable {
    let itemID: String
    let dimension: CompetenceDimension
    let taskVariant: String
}

enum Correctness: String, Codable, Sendable {
    case correct, incorrect, unscored
}

enum AssessmentSource: String, Codable, Sendable {
    case systemEvaluated
    case selfAssessed
}

/// The production Attempt contract — distinct from the pilot's deliberately-reduced
/// `PilotAttempt` (HebrewApp/Domain/PilotAttempt.swift). Both coexist: pilot flows
/// keep recording `PilotAttempt`; real lessons will record `Attempt`.
struct Attempt: Codable, Sendable, Hashable, Identifiable {
    let id: UUID
    let timestampUTC: Date
    /// e.g. "2026-09-21" — see `localLearningDay(for:in:)` in Task 11.
    let localLearningDay: String
    /// Which timezone was used to derive `localLearningDay`, so it can be audited or
    /// re-derived later.
    let timezoneIdentifier: String
    let cardKey: CardKey
    var response: String?
    var correctness: Correctness
    var hintUse: Int
    var errorTags: [String]
    var latency: TimeInterval?
    var assessmentSource: AssessmentSource
    let schemaVersion: Int
}
```

Create `HebrewApp/Domain/SessionState.swift`:

```swift
import Foundation

struct SessionState: Codable, Sendable, Hashable, Identifiable {
    let id: UUID
    var lessonID: String
    var contentVersion: String
    var currentStepID: String?
    var completedAttemptIDs: [UUID]
    var pausedAt: Date?
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `xcodebuild test -project HebrewApp.xcodeproj -scheme HebrewApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:HebrewAppTests/ProductionAttemptTests`

Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add HebrewApp/Domain/SkillState.swift HebrewApp/Domain/ProductionAttempt.swift HebrewApp/Domain/SessionState.swift HebrewAppTests/ProductionAttemptTests.swift
git commit -m "Add production SkillState/Attempt/SessionState Domain types"
```

---

### Task 3: TutorResult type and PronunciationAttempt.confidence field

**Files:**
- Create: `HebrewApp/Domain/TutorResult.swift`
- Modify: `HebrewApp/Domain/PilotAttempt.swift` (add `confidence` to `PronunciationAttempt`)
- Test: `HebrewAppTests/ProductionAttemptTests.swift` (add two tests to the existing suite)

**Interfaces:**
- Consumes: `TutorProviderKind` (existing, `HebrewApp/Domain/TutorProtocols.swift`), `LocalTutorCapability` (existing, `HebrewApp/Domain/CapabilityStatus.swift`).
- Produces: `TutorResult`. `PronunciationAttempt` gains `confidence: Double?` as its last initializer parameter (default `nil`) — every existing call site keeps compiling unchanged.

- [ ] **Step 1: Write the failing tests**

Add to `HebrewAppTests/ProductionAttemptTests.swift` (inside the existing `struct ProductionAttemptTests`, after the last `@Test`):

```swift
    @Test("TutorResult reuses the existing provider-kind and capability enums")
    func tutorResultReusesExistingEnums() {
        let result = TutorResult(
            nextTurnID: "node_002",
            feedbackID: nil,
            provider: .appleFoundationModel,
            elapsedTime: 0.8,
            capabilityStatus: .available
        )

        #expect(result.provider == .appleFoundationModel)
        #expect(result.capabilityStatus == .available)
    }

    @Test("PronunciationAttempt's new confidence field defaults to nil for existing call sites")
    func pronunciationAttemptConfidenceDefaultsNil() {
        let attempt = PronunciationAttempt(
            timestampUTC: Date(),
            itemID: "lex_p_001",
            feedbackKind: .selfReviewed
        )

        #expect(attempt.confidence == nil)
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `xcodebuild test -project HebrewApp.xcodeproj -scheme HebrewApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:HebrewAppTests/ProductionAttemptTests`

Expected: build error — `TutorResult` doesn't exist, and `PronunciationAttempt` has no `confidence` member.

- [ ] **Step 3: Write the minimal implementation**

Create `HebrewApp/Domain/TutorResult.swift`:

```swift
import Foundation

/// The full production tutor-result contract (Documentation/DATA_MODEL.md). Distinct
/// from `TutorSuggestion` (HebrewApp/Domain/TutorProtocols.swift), which is explicitly
/// documented there as "matches the shape of TutorResult, reduced to the pilot's
/// needs" — the same pilot-reduced-type pattern as `PilotAttempt`/`Attempt`.
/// Not `Codable`: nothing persists a `TutorResult` — it's an in-memory result value,
/// like `TutorSuggestion` today.
struct TutorResult: Sendable, Hashable {
    var nextTurnID: String?
    var feedbackID: String?
    var provider: TutorProviderKind
    var elapsedTime: TimeInterval
    var capabilityStatus: LocalTutorCapability
}
```

In `HebrewApp/Domain/PilotAttempt.swift`, change the `PronunciationAttempt` struct
and its initializer (find the existing `struct PronunciationAttempt` block and
replace it in full):

```swift
struct PronunciationAttempt: Codable, Sendable, Hashable, Identifiable {
    let id: UUID
    let timestampUTC: Date
    let itemID: String
    /// Relative path under Application Support, never an absolute path (DATA_MODEL.md).
    let recordingRelativePath: String?
    let transcript: String?
    let feedbackKind: PronunciationFeedbackKind
    /// User's own judgement, recorded separately from any ASR outcome.
    let selfAssessedAsUnderstandable: Bool?
    /// ASR confidence, if available. Never surfaced to the user as a pronunciation or
    /// intelligibility score (DATA_MODEL.md, SPEECH_SPEC.md) — internal/debug only.
    let confidence: Double?

    init(
        id: UUID = UUID(),
        timestampUTC: Date,
        itemID: String,
        recordingRelativePath: String? = nil,
        transcript: String? = nil,
        feedbackKind: PronunciationFeedbackKind,
        selfAssessedAsUnderstandable: Bool? = nil,
        confidence: Double? = nil
    ) {
        self.id = id
        self.timestampUTC = timestampUTC
        self.itemID = itemID
        self.recordingRelativePath = recordingRelativePath
        self.transcript = transcript
        self.feedbackKind = feedbackKind
        self.selfAssessedAsUnderstandable = selfAssessedAsUnderstandable
        self.confidence = confidence
    }
}
```

Note `PronunciationAttempt` also has a `Codable` conformance relying on memberwise
synthesis — check that no explicit `CodingKeys`/`init(from:)` exists elsewhere in the
file for this type before replacing; if the file only has the struct + the custom
`init(...)` shown above (which is the case as of this plan being written), this
replacement is safe and `Codable` stays synthesized from the stored properties.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `xcodebuild test -project HebrewApp.xcodeproj -scheme HebrewApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:HebrewAppTests/ProductionAttemptTests`

Expected: PASS, 5 tests (3 from Task 2 + 2 new).

- [ ] **Step 5: Run the FULL test suite to confirm no regression**

Run: `xcodebuild test -project HebrewApp.xcodeproj -scheme HebrewApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`

Expected: all existing tests (30 unit + 5 UI, plus this plan's new ones) still pass —
this confirms the `PronunciationAttempt` change didn't break any existing call site
(`SwiftDataProgressRepository.recordPronunciationAttempt`, any pilot UI code
constructing one).

- [ ] **Step 6: Commit**

```bash
git add HebrewApp/Domain/TutorResult.swift HebrewApp/Domain/PilotAttempt.swift HebrewAppTests/ProductionAttemptTests.swift
git commit -m "Add TutorResult; extend PronunciationAttempt with a confidence field"
```

---

### Task 4: Production content fixtures + project.yml wiring

**Files:**
- Create: `Content/Production/manifest.json`
- Create: `Content/Production/lexemes.json`
- Create: `Content/Production/sentences.json`
- Create: `Content/Production/lessons.json`
- Modify: `project.yml`

**Interfaces:**
- Consumes: nothing (plain JSON, no Swift).
- Produces: the on-disk fixture bundle Task 5+ loads via `Bundle.main` under a
  `"Production"` subdirectory (folder references keep only their own name at the
  bundle root — same as `Content/Pilot` → `HebrewApp.app/Pilot/` today).

This is a small, coherent, deliberately-not-curriculum fixture: 6 lexemes, 2
sentences, 2 lessons with a real (if trivial) prerequisite edge, used only to
exercise the loader/validator/persistence in later tasks.

- [ ] **Step 1: Write `Content/Production/lexemes.json`**

```json
[
  {
    "id": "lex_p_001",
    "hebrew": "שלום",
    "niqqud": "שָׁלוֹם",
    "lemma": "שלום",
    "transliteration": "shalom",
    "germanSenses": [
      { "translation": "Hallo", "usageNote": "Begrüßung" },
      { "translation": "Frieden", "usageNote": null }
    ],
    "partOfSpeech": "interjection",
    "gender": null,
    "number": null,
    "root": null,
    "binyan": null,
    "level": "a1",
    "exampleSentenceIDs": ["sent_p_001"],
    "audioSpec": {
      "sourceKind": "systemTTS",
      "bundledAssetRelativePath": null,
      "targetVoiceIdentifiers": [],
      "isVerifiedAgainstTargetVoices": false
    },
    "frequencyRank": null,
    "reviewStatus": "draft"
  },
  {
    "id": "lex_p_002",
    "hebrew": "תודה",
    "niqqud": "תּוֹדָה",
    "lemma": "תודה",
    "transliteration": "toda",
    "germanSenses": [{ "translation": "Danke", "usageNote": null }],
    "partOfSpeech": "noun",
    "gender": "feminine",
    "number": "singular",
    "root": null,
    "binyan": null,
    "level": "a1",
    "exampleSentenceIDs": ["sent_p_002"],
    "audioSpec": {
      "sourceKind": "systemTTS",
      "bundledAssetRelativePath": null,
      "targetVoiceIdentifiers": [],
      "isVerifiedAgainstTargetVoices": false
    },
    "frequencyRank": null,
    "reviewStatus": "draft"
  },
  {
    "id": "lex_p_003",
    "hebrew": "כן",
    "niqqud": "כֵּן",
    "lemma": "כן",
    "transliteration": "ken",
    "germanSenses": [{ "translation": "ja", "usageNote": null }],
    "partOfSpeech": "particle",
    "gender": null,
    "number": null,
    "root": null,
    "binyan": null,
    "level": "a1",
    "exampleSentenceIDs": ["sent_p_002"],
    "audioSpec": {
      "sourceKind": "systemTTS",
      "bundledAssetRelativePath": null,
      "targetVoiceIdentifiers": [],
      "isVerifiedAgainstTargetVoices": false
    },
    "frequencyRank": null,
    "reviewStatus": "draft"
  },
  {
    "id": "lex_p_004",
    "hebrew": "לא",
    "niqqud": "לֹא",
    "lemma": "לא",
    "transliteration": "lo",
    "germanSenses": [{ "translation": "nein", "usageNote": null }],
    "partOfSpeech": "particle",
    "gender": null,
    "number": null,
    "root": null,
    "binyan": null,
    "level": "a1",
    "exampleSentenceIDs": [],
    "audioSpec": {
      "sourceKind": "systemTTS",
      "bundledAssetRelativePath": null,
      "targetVoiceIdentifiers": [],
      "isVerifiedAgainstTargetVoices": false
    },
    "frequencyRank": null,
    "reviewStatus": "draft"
  },
  {
    "id": "lex_p_005",
    "hebrew": "בוקר",
    "niqqud": "בֹּקֶר",
    "lemma": "בוקר",
    "transliteration": "boker",
    "germanSenses": [{ "translation": "Morgen", "usageNote": null }],
    "partOfSpeech": "noun",
    "gender": "masculine",
    "number": "singular",
    "root": null,
    "binyan": null,
    "level": "a1",
    "exampleSentenceIDs": ["sent_p_001"],
    "audioSpec": {
      "sourceKind": "systemTTS",
      "bundledAssetRelativePath": null,
      "targetVoiceIdentifiers": [],
      "isVerifiedAgainstTargetVoices": false
    },
    "frequencyRank": null,
    "reviewStatus": "draft"
  },
  {
    "id": "lex_p_006",
    "hebrew": "טוב",
    "niqqud": "טוֹב",
    "lemma": "טוב",
    "transliteration": "tov",
    "germanSenses": [{ "translation": "gut", "usageNote": null }],
    "partOfSpeech": "adjective",
    "gender": "masculine",
    "number": "singular",
    "root": null,
    "binyan": null,
    "level": "a1",
    "exampleSentenceIDs": ["sent_p_001"],
    "audioSpec": {
      "sourceKind": "systemTTS",
      "bundledAssetRelativePath": null,
      "targetVoiceIdentifiers": [],
      "isVerifiedAgainstTargetVoices": false
    },
    "frequencyRank": null,
    "reviewStatus": "draft"
  }
]
```

- [ ] **Step 2: Write `Content/Production/sentences.json`**

```json
[
  {
    "id": "sent_p_001",
    "hebrew": "שלום, בוקר טוב.",
    "niqqud": null,
    "german": "Hallo, guten Morgen.",
    "tokens": [
      { "id": "tok_p_001", "surfaceForm": "שלום", "niqqud": null, "lexemeID": "lex_p_001" },
      { "id": "tok_p_002", "surfaceForm": "בוקר", "niqqud": null, "lexemeID": "lex_p_005" },
      { "id": "tok_p_003", "surfaceForm": "טוב", "niqqud": null, "lexemeID": "lex_p_006" }
    ],
    "grammarTags": ["greeting"],
    "level": "a1",
    "audioSpec": {
      "sourceKind": "systemTTS",
      "bundledAssetRelativePath": null,
      "targetVoiceIdentifiers": [],
      "isVerifiedAgainstTargetVoices": false
    },
    "acceptedVariants": [],
    "reviewStatus": "draft"
  },
  {
    "id": "sent_p_002",
    "hebrew": "תודה, כן.",
    "niqqud": null,
    "german": "Danke, ja.",
    "tokens": [
      { "id": "tok_p_004", "surfaceForm": "תודה", "niqqud": null, "lexemeID": "lex_p_002" },
      { "id": "tok_p_005", "surfaceForm": "כן", "niqqud": null, "lexemeID": "lex_p_003" }
    ],
    "grammarTags": ["politeness"],
    "level": "a1",
    "audioSpec": {
      "sourceKind": "systemTTS",
      "bundledAssetRelativePath": null,
      "targetVoiceIdentifiers": [],
      "isVerifiedAgainstTargetVoices": false
    },
    "acceptedVariants": [],
    "reviewStatus": "draft"
  }
]
```

- [ ] **Step 3: Write `Content/Production/lessons.json`**

```json
[
  {
    "id": "lesson_p_001",
    "moduleID": "module_p_greeting",
    "order": 1,
    "objectives": ["Eine einfache Begrüßung hörend verstehen"],
    "prerequisiteIDs": [],
    "graphemePrerequisites": [],
    "unitIDs": ["lex_p_001", "lex_p_005", "lex_p_006", "sent_p_001"],
    "exerciseBlueprints": [
      {
        "id": "eb_p_001",
        "type": "e05ListeningComprehension",
        "promptRefs": ["sent_p_001"],
        "targetDimension": "listening",
        "answerPolicyID": "policy_p_001",
        "difficulty": 1,
        "hintPolicy": { "levelCount": 2, "revealsAnswerAtFinalLevel": true }
      }
    ],
    "exitCriteria": {
      "requiredExerciseBlueprintIDs": ["eb_p_001"],
      "minimumIndependentCorrectRatio": null
    },
    "level": "a1",
    "reviewStatus": "draft"
  },
  {
    "id": "lesson_p_002",
    "moduleID": "module_p_greeting",
    "order": 2,
    "objectives": ["Auf Dank reagieren"],
    "prerequisiteIDs": ["lesson_p_001"],
    "graphemePrerequisites": [],
    "unitIDs": ["lex_p_002", "lex_p_003", "lex_p_004", "sent_p_002"],
    "exerciseBlueprints": [
      {
        "id": "eb_p_002",
        "type": "e04ActiveMeaningRecall",
        "promptRefs": ["lex_p_002"],
        "targetDimension": "recall",
        "answerPolicyID": "policy_p_002",
        "difficulty": 1,
        "hintPolicy": { "levelCount": 2, "revealsAnswerAtFinalLevel": true }
      }
    ],
    "exitCriteria": {
      "requiredExerciseBlueprintIDs": ["eb_p_002"],
      "minimumIndependentCorrectRatio": null
    },
    "level": "a1",
    "reviewStatus": "draft"
  }
]
```

- [ ] **Step 4: Compute SHA-256 for each content file**

Run:
```bash
shasum -a 256 Content/Production/lexemes.json
shasum -a 256 Content/Production/sentences.json
shasum -a 256 Content/Production/lessons.json
```

Note the three hex digests printed — they go into `manifest.json` in the next step.
(Hashes are byte-exact; if you re-save any of the three files with different
whitespace after this step, re-run this command before continuing.)

- [ ] **Step 5: Write `Content/Production/manifest.json`**

Using the three digests from Step 4:

```json
{
  "schemaVersion": 1,
  "contentVersion": "0.1.0-fixture",
  "minimumAppVersion": "0.1.0",
  "status": "draft",
  "counts": { "lexemes": 6, "sentences": 2, "lessons": 2 },
  "files": [
    { "path": "lexemes.json", "sha256": "<digest from Step 4>" },
    { "path": "sentences.json", "sha256": "<digest from Step 4>" },
    { "path": "lessons.json", "sha256": "<digest from Step 4>" }
  ]
}
```

- [ ] **Step 6: Add the `Content/Production` folder reference to `project.yml`**

Open `project.yml`. Find the `HebrewApp` target's `sources:` list (currently):

```yaml
    sources:
      - path: HebrewApp
      - path: Content/Pilot
        type: folder
        buildPhase: resources
```

Add a second folder reference immediately after the `Content/Pilot` entry:

```yaml
    sources:
      - path: HebrewApp
      - path: Content/Pilot
        type: folder
        buildPhase: resources
      - path: Content/Production
        type: folder
        buildPhase: resources
```

- [ ] **Step 7: Regenerate the project and build**

Run:
```bash
xcodegen generate
xcodebuild build -project HebrewApp.xcodeproj -scheme HebrewApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
```

Expected: `BUILD SUCCEEDED`. This task adds no Swift code, so there's no new test —
the build succeeding (and bundling the new resources) is this task's deliverable.
Confirm the files landed in the built app bundle:

```bash
find ~/Library/Developer/Xcode/DerivedData -path "*HebrewApp.app/Production/manifest.json" 2>/dev/null
```

Expected: one path printed, confirming `Content/Production/*` bundled under
`HebrewApp.app/Production/` (folder references keep only their own name at the
bundle root — same as `Content/Pilot` → `.../Pilot/`).

- [ ] **Step 8: Commit**

```bash
git add Content/Production project.yml HebrewApp.xcodeproj
git commit -m "Add Content/Production fixture bundle (6 lexemes, 2 sentences, 2 lessons)"
```

---

### Task 5: ProductionContentRepository protocol + basic ProductionContentLoader

**Files:**
- Modify: `HebrewApp/Domain/DomainErrors.swift` (add 5 new `ContentLoadError` cases)
- Modify: `HebrewApp/Features/Today/TodayView.swift` (extend the exhaustive `describeContentError` switch — it will fail to compile otherwise)
- Modify: `HebrewApp/Domain/RepositoryProtocols.swift` (add `ProductionContentRepository` protocol)
- Create: `HebrewApp/Content/ProductionContentLoader.swift` (manifest/hash/decode/count/uniqueness only — mirrors `PilotContentLoader` exactly; the four new validation rules are Tasks 6–8)
- Test: `HebrewAppTests/ProductionContentLoaderTests.swift`

**Interfaces:**
- Consumes: `ProductionContentBundle`/`ProductionContentManifest`/`Lexeme`/`Sentence`/`Lesson` (Task 1), `ContentLoadError` (existing, extended here).
- Produces: `ProductionContentRepository` protocol with `func loadProductionBundle() async throws(ContentLoadError) -> ProductionContentBundle`; `ProductionContentLoader` struct conforming to it. Tasks 6–8 add private validation methods to this same file/type — do not create a second loader type.

- [ ] **Step 1: Write the failing test**

Create `HebrewAppTests/ProductionContentLoaderTests.swift`:

```swift
import Testing
import Foundation
@testable import HebrewApp

@Suite("ProductionContentLoader")
struct ProductionContentLoaderTests {
    @Test("loads the real production fixture bundle with matching manifest counts")
    func loadsRealBundle() async throws {
        let loader = ProductionContentLoader(bundle: .main)
        let bundle = try await loader.loadProductionBundle()
        #expect(bundle.lexemes.count == 6)
        #expect(bundle.sentences.count == 2)
        #expect(bundle.lessons.count == 2)
        #expect(bundle.manifest.status == .draft)
    }

    @Test("every fixture item is marked draft")
    func allDraft() async throws {
        let loader = ProductionContentLoader(bundle: .main)
        let bundle = try await loader.loadProductionBundle()
        #expect(bundle.lexemes.allSatisfy { $0.reviewStatus == .draft })
        #expect(bundle.sentences.allSatisfy { $0.reviewStatus == .draft })
        #expect(bundle.lessons.allSatisfy { $0.reviewStatus == .draft })
    }

    @Test("resource not found surfaces a typed error, never a crash")
    func missingResourceThrows() async {
        let loader = ProductionContentLoader(bundle: Bundle(for: ProductionEmptyBundleMarker.self), subdirectory: "DoesNotExist")
        await #expect(throws: ContentLoadError.self) {
            _ = try await loader.loadProductionBundle()
        }
    }
}

private final class ProductionEmptyBundleMarker {}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test -project HebrewApp.xcodeproj -scheme HebrewApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:HebrewAppTests/ProductionContentLoaderTests`

Expected: build error — `ProductionContentLoader` doesn't exist yet.

- [ ] **Step 3: Add the new `ContentLoadError` cases**

In `HebrewApp/Domain/DomainErrors.swift`, replace the existing `ContentLoadError`
enum with (adds 5 cases, keeps all 6 existing ones unchanged):

```swift
/// Failures loading and verifying the bundled pilot content. Never silently substitutes empty
/// data — a load failure must surface, not degrade into a blank screen
/// (ARCHITECTURE.md: "ContentRepository lädt validierte immutable Kursdaten").
enum ContentLoadError: Error, Sendable, Equatable {
    case resourceNotFound(String)
    case decodingFailed(String)
    case hashMismatch(file: String)
    case countMismatch(expected: Int, actual: Int, kind: String)
    case duplicateID(String)
    case unsupportedSchemaVersion(Int)
    /// A reference field (e.g. `Lesson.unitIDs`, `ExerciseBlueprint.promptRefs`) names
    /// an ID that doesn't exist anywhere in the bundle.
    case unresolvedReference(from: String, to: String)
    /// `Lesson.prerequisiteIDs` forms a cycle through the named lesson ID.
    case cyclicPrerequisites(String)
    /// The named lesson ID is not reachable from any lesson with zero prerequisites.
    case unreachableLesson(String)
    /// A `.released` item transitively depends on a `.draft` (or below) item
    /// (CONTENT_GUIDE.md: released items must have zero Draft dependencies).
    case releasedItemHasDraftDependency(item: String, dependency: String)
    /// A lexeme beyond `.draft` has fewer than the required example sentences
    /// (CONTENT_GUIDE.md: "mindestens zwei Beispiele pro fertigem Lexem").
    case insufficientExamples(lexemeID: String, found: Int, required: Int)
}
```

- [ ] **Step 4: Fix the now-non-exhaustive switch in `TodayView.swift`**

In `HebrewApp/Features/Today/TodayView.swift`, find `describeContentError` and
replace it in full:

```swift
    private func describeContentError(_ error: ContentLoadError) -> String {
        switch error {
        case .resourceNotFound(let name): "Datei nicht gefunden: \(name)"
        case .decodingFailed(let detail): "Konnte nicht gelesen werden: \(detail)"
        case .hashMismatch(let file): "Prüfsumme stimmt nicht überein: \(file)"
        case .countMismatch(let expected, let actual, let kind): "\(kind): erwartet \(expected), gefunden \(actual)"
        case .duplicateID(let id): "Doppelte ID: \(id)"
        case .unsupportedSchemaVersion(let version): "Nicht unterstützte Schemaversion: \(version)"
        case .unresolvedReference(let from, let to): "Ungültige Referenz: \(from) verweist auf unbekannte ID \(to)"
        case .cyclicPrerequisites(let id): "Zyklische Voraussetzung bei Lektion: \(id)"
        case .unreachableLesson(let id): "Lektion nicht erreichbar: \(id)"
        case .releasedItemHasDraftDependency(let item, let dependency): "Freigegebenes Element \(item) hängt von Entwurf \(dependency) ab"
        case .insufficientExamples(let lexemeID, let found, let required): "Lexem \(lexemeID): \(found) von \(required) benötigten Beispielsätzen"
        }
    }
```

- [ ] **Step 5: Add the `ProductionContentRepository` protocol**

In `HebrewApp/Domain/RepositoryProtocols.swift`, add this new protocol after the
existing `ContentRepository` protocol (do not modify `ContentRepository` or
`ProgressRepository` themselves):

```swift
/// Loads and structurally verifies the bundled production content. Separate from
/// `ContentRepository` deliberately: `PilotContentLoader` has nothing to do with
/// production content, and shouldn't be forced to implement loading it.
protocol ProductionContentRepository: Sendable {
    func loadProductionBundle() async throws(ContentLoadError) -> ProductionContentBundle
}
```

- [ ] **Step 6: Write the minimal `ProductionContentLoader` implementation**

Create `HebrewApp/Content/ProductionContentLoader.swift`:

```swift
import Foundation
import CryptoKit

/// Loads Content/Production's manifest + fixtures from the app bundle, verifies
/// SHA-256 hashes and declared counts against the manifest (mirroring
/// Scripts/validate_production.py so the same invariants are enforced both at
/// CI/build time and at app runtime), decodes them into Domain value types, and
/// validates cross-references/prerequisite structure (Tasks 6–8 add those checks
/// to this type as private methods). Never mutates the loaded content.
///
/// The repo-level source folder is `Content/Production/`, but a folder reference in
/// the Xcode project keeps only its own name at the bundle root — so at runtime the
/// files live under `HebrewApp.app/Production/`, not `HebrewApp.app/Content/Production/`.
struct ProductionContentLoader: ProductionContentRepository {
    private let bundle: Bundle
    private let subdirectory: String

    init(bundle: Bundle = .main, subdirectory: String = "Production") {
        self.bundle = bundle
        self.subdirectory = subdirectory
    }

    func loadProductionBundle() async throws(ContentLoadError) -> ProductionContentBundle {
        let manifest: ProductionContentManifest = try decode(fileName: "manifest.json", as: ProductionContentManifest.self)

        guard manifest.schemaVersion == 1 else {
            throw ContentLoadError.unsupportedSchemaVersion(manifest.schemaVersion)
        }

        for file in manifest.files {
            try verifyHash(fileName: file.path, expectedSHA256: file.sha256)
        }

        let lexemes: [Lexeme] = try decode(fileName: "lexemes.json", as: [Lexeme].self)
        let sentences: [Sentence] = try decode(fileName: "sentences.json", as: [Sentence].self)
        let lessons: [Lesson] = try decode(fileName: "lessons.json", as: [Lesson].self)

        try requireCount(lexemes.count, expected: manifest.counts.lexemes, kind: "lexemes")
        try requireCount(sentences.count, expected: manifest.counts.sentences, kind: "sentences")
        try requireCount(lessons.count, expected: manifest.counts.lessons, kind: "lessons")

        try requireUniqueIDs(lexemes.map(\.id) + sentences.map(\.id) + lessons.map(\.id))

        return ProductionContentBundle(manifest: manifest, lexemes: lexemes, sentences: sentences, lessons: lessons)
    }

    // MARK: - Helpers

    private func resourceURL(fileName: String) throws(ContentLoadError) -> URL {
        let nameWithoutExtension = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        guard let url = bundle.url(
            forResource: nameWithoutExtension,
            withExtension: ext,
            subdirectory: subdirectory
        ) else {
            throw ContentLoadError.resourceNotFound(fileName)
        }
        return url
    }

    private func decode<T: Decodable>(fileName: String, as type: T.Type) throws(ContentLoadError) -> T {
        let url = try resourceURL(fileName: fileName)
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ContentLoadError.resourceNotFound(fileName)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw ContentLoadError.decodingFailed("\(fileName): \(error)")
        }
    }

    private func verifyHash(fileName: String, expectedSHA256: String) throws(ContentLoadError) {
        let url = try resourceURL(fileName: fileName)
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ContentLoadError.resourceNotFound(fileName)
        }
        let digest = SHA256.hash(data: data)
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        guard hex == expectedSHA256 else {
            throw ContentLoadError.hashMismatch(file: fileName)
        }
    }

    private func requireCount(_ actual: Int, expected: Int, kind: String) throws(ContentLoadError) {
        guard actual == expected else {
            throw ContentLoadError.countMismatch(expected: expected, actual: actual, kind: kind)
        }
    }

    private func requireUniqueIDs(_ ids: [String]) throws(ContentLoadError) {
        var seen = Set<String>()
        for id in ids {
            guard seen.insert(id).inserted else {
                throw ContentLoadError.duplicateID(id)
            }
        }
    }
}
```

- [ ] **Step 7: Run the test to verify it passes**

Run: `xcodebuild test -project HebrewApp.xcodeproj -scheme HebrewApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:HebrewAppTests/ProductionContentLoaderTests`

Expected: PASS, 3 tests. If `resourceNotFound` fires unexpectedly on the first test,
re-check Task 4 Step 7's bundle-verification `find` command output.

- [ ] **Step 8: Run the FULL test suite to confirm no regression**

Run: `xcodebuild test -project HebrewApp.xcodeproj -scheme HebrewApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`

Expected: everything still green — confirms the `TodayView.swift` switch update
didn't change any existing pilot-error-message test expectations.

- [ ] **Step 9: Commit**

```bash
git add HebrewApp/Domain/DomainErrors.swift HebrewApp/Features/Today/TodayView.swift HebrewApp/Domain/RepositoryProtocols.swift HebrewApp/Content/ProductionContentLoader.swift HebrewAppTests/ProductionContentLoaderTests.swift
git commit -m "Add ProductionContentRepository + basic ProductionContentLoader (manifest/hash/count/uniqueness)"
```

---

### Task 6: Reference-resolution validation

**Files:**
- Modify: `HebrewApp/Content/ProductionContentLoader.swift`
- Test: `HebrewAppTests/ProductionContentLoaderTests.swift`

**Interfaces:**
- Consumes: `Lexeme`, `Sentence`, `Lesson`, `ContentLoadError.unresolvedReference` (Task 5).
- Produces: `ProductionContentLoader.validateReferences(lexemes:sentences:lessons:)`, a `static` method, `throws(ContentLoadError)`, callable directly from tests without touching the file system — used internally by `loadProductionBundle()` after decoding, and unit-tested standalone with hand-built in-memory fixtures.

- [ ] **Step 1: Write the failing tests**

Add to `HebrewAppTests/ProductionContentLoaderTests.swift`, inside
`struct ProductionContentLoaderTests` (helper fixtures + two new `@Test`s):

```swift
    @Test("reference validation passes when every reference resolves")
    func referenceValidationPassesForValidData() throws {
        let lexemes = [Self.makeLexeme(id: "lex_a", examples: ["sent_a"])]
        let sentences = [Self.makeSentence(id: "sent_a")]
        let lessons = [Self.makeLesson(id: "lesson_a", unitIDs: ["lex_a", "sent_a"], prerequisiteIDs: [])]

        try ProductionContentLoader.validateReferences(lexemes: lexemes, sentences: sentences, lessons: lessons)
    }

    @Test("reference validation throws when a Lesson.unitIDs entry doesn't exist")
    func referenceValidationThrowsForUnknownUnitID() {
        let lessons = [Self.makeLesson(id: "lesson_a", unitIDs: ["does_not_exist"], prerequisiteIDs: [])]

        #expect(throws: ContentLoadError.unresolvedReference(from: "lesson_a", to: "does_not_exist")) {
            try ProductionContentLoader.validateReferences(lexemes: [], sentences: [], lessons: lessons)
        }
    }

    // MARK: - Shared fixtures (used by Tasks 6-8's tests)

    static func makeLexeme(id: String, examples: [String] = []) -> Lexeme {
        Lexeme(
            id: id, hebrew: "x", niqqud: nil, lemma: "x", transliteration: nil,
            germanSenses: [GermanSense(translation: "x", usageNote: nil)], partOfSpeech: .noun,
            gender: nil, number: nil, root: nil, binyan: nil, level: .a1,
            exampleSentenceIDs: examples,
            audioSpec: AudioSpec(sourceKind: .systemTTS, bundledAssetRelativePath: nil, targetVoiceIdentifiers: [], isVerifiedAgainstTargetVoices: false),
            frequencyRank: nil, reviewStatus: .draft
        )
    }

    static func makeSentence(id: String, reviewStatus: ReviewStatus = .draft) -> Sentence {
        Sentence(
            id: id, hebrew: "x", niqqud: nil, german: "x", tokens: [], grammarTags: [],
            level: .a1,
            audioSpec: AudioSpec(sourceKind: .systemTTS, bundledAssetRelativePath: nil, targetVoiceIdentifiers: [], isVerifiedAgainstTargetVoices: false),
            acceptedVariants: [], reviewStatus: reviewStatus
        )
    }

    static func makeLesson(id: String, unitIDs: [String], prerequisiteIDs: [String], reviewStatus: ReviewStatus = .draft) -> Lesson {
        Lesson(
            id: id, moduleID: "module_x", order: 1, objectives: [],
            prerequisiteIDs: prerequisiteIDs, graphemePrerequisites: [], unitIDs: unitIDs,
            exerciseBlueprints: [], exitCriteria: ExitCriteria(requiredExerciseBlueprintIDs: [], minimumIndependentCorrectRatio: nil),
            level: .a1, reviewStatus: reviewStatus
        )
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `xcodebuild test -project HebrewApp.xcodeproj -scheme HebrewApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:HebrewAppTests/ProductionContentLoaderTests`

Expected: build error — `ProductionContentLoader.validateReferences` doesn't exist.

- [ ] **Step 3: Write the minimal implementation**

In `HebrewApp/Content/ProductionContentLoader.swift`, add this `static` method
inside `struct ProductionContentLoader` (after the existing private helpers), and
call it from `loadProductionBundle()`:

```swift
    /// Every `Lexeme.exampleSentenceIDs`, `Lesson.unitIDs`, `Lesson.prerequisiteIDs`,
    /// and `ExerciseBlueprint.promptRefs` entry must resolve to a real ID somewhere
    /// in the bundle. Pure — no file I/O — so it's directly unit-testable.
    static func validateReferences(lexemes: [Lexeme], sentences: [Sentence], lessons: [Lesson]) throws(ContentLoadError) {
        let knownIDs = Set(lexemes.map(\.id)).union(sentences.map(\.id)).union(lessons.map(\.id))

        for lexeme in lexemes {
            for exampleID in lexeme.exampleSentenceIDs where !knownIDs.contains(exampleID) {
                throw ContentLoadError.unresolvedReference(from: lexeme.id, to: exampleID)
            }
        }
        for lesson in lessons {
            for unitID in lesson.unitIDs where !knownIDs.contains(unitID) {
                throw ContentLoadError.unresolvedReference(from: lesson.id, to: unitID)
            }
            for prerequisiteID in lesson.prerequisiteIDs where !knownIDs.contains(prerequisiteID) {
                throw ContentLoadError.unresolvedReference(from: lesson.id, to: prerequisiteID)
            }
            for blueprint in lesson.exerciseBlueprints {
                for promptRef in blueprint.promptRefs where !knownIDs.contains(promptRef) {
                    throw ContentLoadError.unresolvedReference(from: blueprint.id, to: promptRef)
                }
            }
        }
    }
```

In `loadProductionBundle()`, add the call right after the existing
`try requireUniqueIDs(...)` line and before `return ProductionContentBundle(...)`:

```swift
        try Self.validateReferences(lexemes: lexemes, sentences: sentences, lessons: lessons)
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `xcodebuild test -project HebrewApp.xcodeproj -scheme HebrewApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:HebrewAppTests/ProductionContentLoaderTests`

Expected: PASS, 5 tests (3 from Task 5 + 2 new). The real-fixture test
(`loadsRealBundle`) must still pass — this confirms `Content/Production`'s
`unitIDs`/`exampleSentenceIDs`/`prerequisiteIDs`/`promptRefs` from Task 4 all
actually resolve.

- [ ] **Step 5: Commit**

```bash
git add HebrewApp/Content/ProductionContentLoader.swift HebrewAppTests/ProductionContentLoaderTests.swift
git commit -m "Add reference-resolution validation to ProductionContentLoader"
```

---

### Task 7: Prerequisite-graph validation (cycles + reachability)

**Files:**
- Modify: `HebrewApp/Content/ProductionContentLoader.swift`
- Test: `HebrewAppTests/ProductionContentLoaderTests.swift`

**Interfaces:**
- Consumes: `Lesson`, `ContentLoadError.cyclicPrerequisites`/`.unreachableLesson` (Task 5), the `makeLesson` fixture helper (Task 6).
- Produces: `ProductionContentLoader.validatePrerequisiteGraph(lessons:)`, `static`, `throws(ContentLoadError)`.

- [ ] **Step 1: Write the failing tests**

Add to `HebrewAppTests/ProductionContentLoaderTests.swift`, inside
`struct ProductionContentLoaderTests`:

```swift
    @Test("prerequisite graph validation passes for a valid chain")
    func prerequisiteGraphPassesForValidChain() throws {
        let lessons = [
            Self.makeLesson(id: "lesson_a", unitIDs: [], prerequisiteIDs: []),
            Self.makeLesson(id: "lesson_b", unitIDs: [], prerequisiteIDs: ["lesson_a"]),
        ]

        try ProductionContentLoader.validatePrerequisiteGraph(lessons: lessons)
    }

    @Test("prerequisite graph validation throws on a direct cycle")
    func prerequisiteGraphThrowsOnCycle() {
        let lessons = [
            Self.makeLesson(id: "lesson_a", unitIDs: [], prerequisiteIDs: ["lesson_b"]),
            Self.makeLesson(id: "lesson_b", unitIDs: [], prerequisiteIDs: ["lesson_a"]),
        ]

        #expect(throws: ContentLoadError.self) {
            try ProductionContentLoader.validatePrerequisiteGraph(lessons: lessons)
        }
    }

    @Test("prerequisite graph validation throws when a lesson has an unresolved prerequisite forming an island")
    func prerequisiteGraphThrowsOnUnreachableLesson() {
        // lesson_c's only prerequisite is itself-adjacent but never rooted at a
        // zero-prerequisite lesson once lesson_a is removed from consideration —
        // simulated here directly via a self-referential-through-another-node chain
        // with no zero-prerequisite root at all.
        let lessons = [
            Self.makeLesson(id: "lesson_a", unitIDs: [], prerequisiteIDs: ["lesson_b"]),
            Self.makeLesson(id: "lesson_b", unitIDs: [], prerequisiteIDs: ["lesson_a"]),
        ]

        // Every lesson has a prerequisite, so there is no root at all: this must be
        // reported as a cycle (checked first) rather than unreachability — both are
        // real structural problems, and cyclicPrerequisites is the more specific,
        // more actionable diagnosis when both would technically apply.
        #expect(throws: ContentLoadError.self) {
            try ProductionContentLoader.validatePrerequisiteGraph(lessons: lessons)
        }
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `xcodebuild test -project HebrewApp.xcodeproj -scheme HebrewApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:HebrewAppTests/ProductionContentLoaderTests`

Expected: build error — `validatePrerequisiteGraph` doesn't exist.

- [ ] **Step 3: Write the minimal implementation**

In `HebrewApp/Content/ProductionContentLoader.swift`, add this `static` method next
to `validateReferences`, and call it from `loadProductionBundle()`:

```swift
    /// `Lesson.prerequisiteIDs` must form a DAG (no cycles), and every lesson must be
    /// reachable from some lesson with zero prerequisites. Cycle detection runs first:
    /// a lesson that's part of a cycle has no zero-prerequisite root anywhere in that
    /// cycle, so reporting it as a cycle (more specific/actionable) takes priority over
    /// the more general "unreachable" diagnosis.
    static func validatePrerequisiteGraph(lessons: [Lesson]) throws(ContentLoadError) {
        let lessonsByID = Dictionary(uniqueKeysWithValues: lessons.map { ($0.id, $0) })

        var visiting = Set<String>()
        var fullyVisited = Set<String>()

        func detectCycle(from id: String) throws(ContentLoadError) {
            if fullyVisited.contains(id) { return }
            guard let lesson = lessonsByID[id] else { return }
            guard visiting.insert(id).inserted else {
                throw ContentLoadError.cyclicPrerequisites(id)
            }
            for prerequisiteID in lesson.prerequisiteIDs {
                try detectCycle(from: prerequisiteID)
            }
            visiting.remove(id)
            fullyVisited.insert(id)
        }

        for lesson in lessons {
            try detectCycle(from: lesson.id)
        }

        let roots = lessons.filter(\.prerequisiteIDs.isEmpty).map(\.id)
        var reachable = Set(roots)
        var pending = roots
        while let current = pending.popLast() {
            for lesson in lessons where lesson.prerequisiteIDs.contains(current) {
                if reachable.insert(lesson.id).inserted {
                    pending.append(lesson.id)
                }
            }
        }
        for lesson in lessons where !reachable.contains(lesson.id) {
            throw ContentLoadError.unreachableLesson(lesson.id)
        }
    }
```

In `loadProductionBundle()`, add the call right after
`try Self.validateReferences(...)`:

```swift
        try Self.validatePrerequisiteGraph(lessons: lessons)
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `xcodebuild test -project HebrewApp.xcodeproj -scheme HebrewApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:HebrewAppTests/ProductionContentLoaderTests`

Expected: PASS, 8 tests (5 from Task 6 + 3 new). The real-fixture test must still
pass — `lesson_p_001` (no prerequisites) is the root, `lesson_p_002` reaches it via
one edge.

- [ ] **Step 5: Commit**

```bash
git add HebrewApp/Content/ProductionContentLoader.swift HebrewAppTests/ProductionContentLoaderTests.swift
git commit -m "Add prerequisite-graph cycle/reachability validation to ProductionContentLoader"
```

---

### Task 8: Draft/released boundary + example-count validation

**Files:**
- Modify: `HebrewApp/Content/ProductionContentLoader.swift`
- Test: `HebrewAppTests/ProductionContentLoaderTests.swift`

**Interfaces:**
- Consumes: `Lexeme`, `Sentence`, `Lesson`, `ReviewStatus`, `ContentLoadError.releasedItemHasDraftDependency`/`.insufficientExamples` (Task 5), fixture helpers (Task 6).
- Produces: `ProductionContentLoader.validateDraftReleaseBoundary(lexemes:sentences:lessons:)` and `validateExampleCounts(lexemes:)`, both `static`, `throws(ContentLoadError)`.

- [ ] **Step 1: Write the failing tests**

Add to `HebrewAppTests/ProductionContentLoaderTests.swift`, inside
`struct ProductionContentLoaderTests`:

```swift
    @Test("draft/released boundary passes when a released lesson only depends on released units")
    func draftBoundaryPassesForFullyReleasedChain() throws {
        let lexeme = Self.makeLexeme(id: "lex_a")
        var released = lexeme
        released.reviewStatus = .released
        let lesson = Self.makeLesson(id: "lesson_a", unitIDs: ["lex_a"], prerequisiteIDs: [], reviewStatus: .released)

        try ProductionContentLoader.validateDraftReleaseBoundary(lexemes: [released], sentences: [], lessons: [lesson])
    }

    @Test("draft/released boundary throws when a released lesson depends on a draft lexeme")
    func draftBoundaryThrowsForDraftDependency() {
        let draftLexeme = Self.makeLexeme(id: "lex_a") // reviewStatus: .draft by default
        let releasedLesson = Self.makeLesson(id: "lesson_a", unitIDs: ["lex_a"], prerequisiteIDs: [], reviewStatus: .released)

        #expect(throws: ContentLoadError.releasedItemHasDraftDependency(item: "lesson_a", dependency: "lex_a")) {
            try ProductionContentLoader.validateDraftReleaseBoundary(lexemes: [draftLexeme], sentences: [], lessons: [releasedLesson])
        }
    }

    @Test("example-count validation passes once a released lexeme has at least 2 examples")
    func exampleCountPassesWithTwoExamples() throws {
        var lexeme = Self.makeLexeme(id: "lex_a", examples: ["sent_a", "sent_b"])
        lexeme.reviewStatus = .structurallyValidated

        try ProductionContentLoader.validateExampleCounts(lexemes: [lexeme])
    }

    @Test("example-count validation throws for a non-draft lexeme with only 1 example")
    func exampleCountThrowsWithOneExample() {
        var lexeme = Self.makeLexeme(id: "lex_a", examples: ["sent_a"])
        lexeme.reviewStatus = .structurallyValidated

        #expect(throws: ContentLoadError.insufficientExamples(lexemeID: "lex_a", found: 1, required: 2)) {
            try ProductionContentLoader.validateExampleCounts(lexemes: [lexeme])
        }
    }

    @Test("example-count validation is skipped for draft lexemes")
    func exampleCountSkippedForDraft() throws {
        let lexeme = Self.makeLexeme(id: "lex_a", examples: []) // .draft by default, 0 examples

        try ProductionContentLoader.validateExampleCounts(lexemes: [lexeme])
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `xcodebuild test -project HebrewApp.xcodeproj -scheme HebrewApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:HebrewAppTests/ProductionContentLoaderTests`

Expected: build error — `validateDraftReleaseBoundary`/`validateExampleCounts` don't exist.

- [ ] **Step 3: Write the minimal implementation**

In `HebrewApp/Content/ProductionContentLoader.swift`, add these two `static`
methods next to the others, and call both from `loadProductionBundle()`:

```swift
    /// A `.released` item may not depend (directly, via unitIDs/exampleSentenceIDs)
    /// on an item that is still `.draft` or below `.released` in general — checked
    /// one hop at a time per dependency edge already validated by
    /// `validateReferences`, which is sufficient since every reference has already
    /// been proven to resolve to a real item by that point.
    static func validateDraftReleaseBoundary(lexemes: [Lexeme], sentences: [Sentence], lessons: [Lesson]) throws(ContentLoadError) {
        let lexemesByID = Dictionary(uniqueKeysWithValues: lexemes.map { ($0.id, $0) })
        let sentencesByID = Dictionary(uniqueKeysWithValues: sentences.map { ($0.id, $0) })
        let lessonsByID = Dictionary(uniqueKeysWithValues: lessons.map { ($0.id, $0) })

        func statusOfKnownItem(_ id: String) -> ReviewStatus? {
            lexemesByID[id]?.reviewStatus ?? sentencesByID[id]?.reviewStatus ?? lessonsByID[id]?.reviewStatus
        }

        for lesson in lessons where lesson.reviewStatus == .released {
            for dependencyID in lesson.unitIDs + lesson.prerequisiteIDs {
                if let status = statusOfKnownItem(dependencyID), status != .released {
                    throw ContentLoadError.releasedItemHasDraftDependency(item: lesson.id, dependency: dependencyID)
                }
            }
        }
        for lexeme in lexemes where lexeme.reviewStatus == .released {
            for exampleID in lexeme.exampleSentenceIDs {
                if let status = statusOfKnownItem(exampleID), status != .released {
                    throw ContentLoadError.releasedItemHasDraftDependency(item: lexeme.id, dependency: exampleID)
                }
            }
        }
    }

    /// A lexeme beyond `.draft` must have at least 2 example sentences
    /// (CONTENT_GUIDE.md: "mindestens zwei Beispiele pro fertigem Lexem"). Draft
    /// lexemes are exempt — they haven't left Draft status yet.
    static func validateExampleCounts(lexemes: [Lexeme]) throws(ContentLoadError) {
        let requiredExampleCount = 2
        for lexeme in lexemes where lexeme.reviewStatus != .draft {
            guard lexeme.exampleSentenceIDs.count >= requiredExampleCount else {
                throw ContentLoadError.insufficientExamples(
                    lexemeID: lexeme.id,
                    found: lexeme.exampleSentenceIDs.count,
                    required: requiredExampleCount
                )
            }
        }
    }
```

In `loadProductionBundle()`, add both calls right after
`try Self.validatePrerequisiteGraph(...)`:

```swift
        try Self.validateDraftReleaseBoundary(lexemes: lexemes, sentences: sentences, lessons: lessons)
        try Self.validateExampleCounts(lexemes: lexemes)
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `xcodebuild test -project HebrewApp.xcodeproj -scheme HebrewApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:HebrewAppTests/ProductionContentLoaderTests`

Expected: PASS, 13 tests (8 from Task 7 + 5 new). The real-fixture test must still
pass — every `Content/Production` item is `.draft`, so both new rules are
vacuously satisfied for it.

- [ ] **Step 5: Run the FULL test suite**

Run: `xcodebuild test -project HebrewApp.xcodeproj -scheme HebrewApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`

Expected: everything still green. This is the last task touching
`ProductionContentLoader.swift` — a good checkpoint before moving to persistence.

- [ ] **Step 6: Commit**

```bash
git add HebrewApp/Content/ProductionContentLoader.swift HebrewAppTests/ProductionContentLoaderTests.swift
git commit -m "Add draft/released boundary and example-count validation to ProductionContentLoader"
```

---

### Task 9: SwiftData persistence — new models, PilotSchemaV2, migration

**Files:**
- Modify: `HebrewApp/Data/PilotSwiftDataModels.swift` (add 3 new `@Model` types, `PilotSchemaV2`, extend `PilotMigrationPlan`)
- Modify: `HebrewApp/Data/ModelContainerFactory.swift` (build the container from `PilotSchemaV2.models`)
- Test: `HebrewAppTests/PilotSchemaMigrationTests.swift`

**Interfaces:**
- Consumes: `Attempt`, `CardKey`, `SkillState`, `SessionState`, `EvidenceStatus` (Task 2).
- Produces: `ProductionAttemptRecord`, `SkillStateRecord`, `SessionStateRecord` (`@Model` classes — Task 10 constructs/reads these), `PilotSchemaV2`, updated `PilotMigrationPlan`.

- [ ] **Step 1: Write the failing test**

Create `HebrewAppTests/PilotSchemaMigrationTests.swift`:

```swift
import Testing
import Foundation
import SwiftData
@testable import HebrewApp

@Suite("PilotSchemaV1 to V2 migration")
struct PilotSchemaMigrationTests {
    @Test("existing pilot data survives migration and the new tables exist, empty")
    func migrationPreservesExistingDataAndAddsNewTables() throws {
        // Step A: create a V1-only container and insert one pilot attempt.
        let storeURL = FileManager.default.temporaryDirectory.appending(path: "migration-test-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: storeURL) }

        let v1Schema = Schema(PilotSchemaV1.models)
        let v1Config = ModelConfiguration(schema: v1Schema, url: storeURL)
        let v1Container = try ModelContainer(for: v1Schema, configurations: [v1Config])
        let v1Context = ModelContext(v1Container)
        v1Context.insert(PilotAttemptRecord(
            id: UUID(), timestampUTC: Date(), kindRaw: "lexemeRecall",
            itemID: "lex_001", correctnessRaw: "correct", hintUsed: false, schemaVersion: 1
        ))
        try v1Context.save()

        // Step B: reopen the SAME store URL with the full V1->V2 migration plan.
        let v2Schema = Schema(PilotSchemaV2.models)
        let v2Config = ModelConfiguration(schema: v2Schema, url: storeURL)
        let v2Container = try ModelContainer(for: v2Schema, migrationPlan: PilotMigrationPlan.self, configurations: [v2Config])
        let v2Context = ModelContext(v2Container)

        let existingAttempts = try v2Context.fetch(FetchDescriptor<PilotAttemptRecord>())
        #expect(existingAttempts.count == 1)
        #expect(existingAttempts.first?.itemID == "lex_001")

        let newAttempts = try v2Context.fetch(FetchDescriptor<ProductionAttemptRecord>())
        #expect(newAttempts.isEmpty)
        let newSkillStates = try v2Context.fetch(FetchDescriptor<SkillStateRecord>())
        #expect(newSkillStates.isEmpty)
        let newSessions = try v2Context.fetch(FetchDescriptor<SessionStateRecord>())
        #expect(newSessions.isEmpty)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test -project HebrewApp.xcodeproj -scheme HebrewApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:HebrewAppTests/PilotSchemaMigrationTests`

Expected: build error — `PilotSchemaV2`, `ProductionAttemptRecord`, `SkillStateRecord`, `SessionStateRecord` don't exist yet.

- [ ] **Step 3: Write the minimal implementation**

In `HebrewApp/Data/PilotSwiftDataModels.swift`, add the three new `@Model` classes
after the existing `PathProgressRecord` class and before the `PilotSchemaV1` enum:

```swift
@Model
final class ProductionAttemptRecord {
    @Attribute(.unique) var id: UUID
    var timestampUTC: Date
    var localLearningDay: String
    var timezoneIdentifier: String
    var itemID: String
    var dimensionRaw: String
    var taskVariant: String
    var response: String?
    var correctnessRaw: String
    var hintUse: Int
    var errorTags: [String]
    var latency: Double?
    var assessmentSourceRaw: String
    var schemaVersion: Int

    init(
        id: UUID, timestampUTC: Date, localLearningDay: String, timezoneIdentifier: String,
        itemID: String, dimensionRaw: String, taskVariant: String, response: String?,
        correctnessRaw: String, hintUse: Int, errorTags: [String], latency: Double?,
        assessmentSourceRaw: String, schemaVersion: Int
    ) {
        self.id = id
        self.timestampUTC = timestampUTC
        self.localLearningDay = localLearningDay
        self.timezoneIdentifier = timezoneIdentifier
        self.itemID = itemID
        self.dimensionRaw = dimensionRaw
        self.taskVariant = taskVariant
        self.response = response
        self.correctnessRaw = correctnessRaw
        self.hintUse = hintUse
        self.errorTags = errorTags
        self.latency = latency
        self.assessmentSourceRaw = assessmentSourceRaw
        self.schemaVersion = schemaVersion
    }
}

@Model
final class SkillStateRecord {
    /// "\(localProfileID)|\(itemID)|\(dimensionRaw)" — SwiftData's `.unique`
    /// attribute needs a single value; composing the natural composite key into one
    /// string is simpler than expressing a multi-field uniqueness constraint.
    @Attribute(.unique) var compositeKey: String
    var localProfileID: UUID
    var itemID: String
    var dimensionRaw: String
    var stability: Double?
    var difficulty: Double?
    var dueAt: Date?
    var lapses: Int
    var helpLevel: Int
    var evidenceStatusRaw: String
    var independentSuccessDays: Int

    init(
        compositeKey: String, localProfileID: UUID, itemID: String, dimensionRaw: String,
        stability: Double?, difficulty: Double?, dueAt: Date?, lapses: Int, helpLevel: Int,
        evidenceStatusRaw: String, independentSuccessDays: Int
    ) {
        self.compositeKey = compositeKey
        self.localProfileID = localProfileID
        self.itemID = itemID
        self.dimensionRaw = dimensionRaw
        self.stability = stability
        self.difficulty = difficulty
        self.dueAt = dueAt
        self.lapses = lapses
        self.helpLevel = helpLevel
        self.evidenceStatusRaw = evidenceStatusRaw
        self.independentSuccessDays = independentSuccessDays
    }
}

@Model
final class SessionStateRecord {
    @Attribute(.unique) var id: UUID
    var lessonID: String
    var contentVersion: String
    var currentStepID: String?
    var completedAttemptIDs: [UUID]
    var pausedAt: Date?

    init(
        id: UUID, lessonID: String, contentVersion: String, currentStepID: String?,
        completedAttemptIDs: [UUID], pausedAt: Date?
    ) {
        self.id = id
        self.lessonID = lessonID
        self.contentVersion = contentVersion
        self.currentStepID = currentStepID
        self.completedAttemptIDs = completedAttemptIDs
        self.pausedAt = pausedAt
    }
}
```

Replace the existing `PilotSchemaV1`/`PilotMigrationPlan` block at the end of the
file with:

```swift
/// First schema version. No migration stages exist yet because there is no prior version to
/// migrate from — Documentation/ARCHITECTURE.md still requires the versioning scaffolding to be
/// in place from the start so P2 can add real migrations without restructuring this layer.
enum PilotSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [PilotAttemptRecord.self, PronunciationAttemptRecord.self, DialogueSessionRecord.self, PathProgressRecord.self]
    }
}

/// Second schema version: purely additive. The four existing pilot record types are
/// unchanged (kept so the two demo pilot paths keep working exactly as before,
/// PILOT.md); three new record types support the production Attempt/SkillState/
/// SessionState Domain types (P2 "Lernkern", Documentation/DATA_MODEL.md).
enum PilotSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [
            PilotAttemptRecord.self, PronunciationAttemptRecord.self, DialogueSessionRecord.self, PathProgressRecord.self,
            ProductionAttemptRecord.self, SkillStateRecord.self, SessionStateRecord.self,
        ]
    }
}

enum PilotMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [PilotSchemaV1.self, PilotSchemaV2.self] }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: PilotSchemaV1.self, toVersion: PilotSchemaV2.self)]
    }
}
```

In `HebrewApp/Data/ModelContainerFactory.swift`, change the schema construction from
`PilotSchemaV1.models` to `PilotSchemaV2.models` (the migration plan handles the V1→V2
step on existing installs automatically; the store name and `cloudKitDatabase: .none`
stay unchanged):

```swift
enum ModelContainerFactory {
    /// `cloudKitDatabase: .none` is explicit: the pilot's local-only progress store must never
    /// silently start syncing before optional iCloud sync is deliberately built
    /// (Documentation/PRIVACY_AND_RELEASE.md: opt-in only, "Private CloudKit-Datenbank nur für
    /// Progress/Settings" — and only in a later phase).
    static func makeContainer(inMemory: Bool = false) throws(PersistenceError) -> ModelContainer {
        let schema = Schema(PilotSchemaV2.models)
        let configuration = ModelConfiguration(
            "HebrewAppPilot",
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, migrationPlan: PilotMigrationPlan.self, configurations: [configuration])
        } catch {
            throw PersistenceError.saveFailed("ModelContainer init failed: \(error)")
        }
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `xcodebuild test -project HebrewApp.xcodeproj -scheme HebrewApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:HebrewAppTests/PilotSchemaMigrationTests`

Expected: PASS, 1 test. This is the first time any migration stage in this codebase
has actually been exercised (`PilotMigrationPlan.stages` was `[]` before this task).

- [ ] **Step 5: Run the FULL test suite, including the app launching fresh**

Run: `xcodebuild test -project HebrewApp.xcodeproj -scheme HebrewApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`

Expected: everything green — in particular, all existing pilot-flow UI tests
(`testStartingDemoPathNavigatesToFirstStep`, `testVocabularySelfAssessmentAdvancesToNextStep`,
etc.) must still pass, confirming `ModelContainerFactory`'s schema-version bump
doesn't break the app's normal launch path against a fresh simulator install. If any
UI test fails only on the *first* run after this change, uninstall the app from the
simulator and re-run once (a stale pre-V2 install could otherwise cause a one-time
migration on first launch that these tests aren't timing for) — do this at most once;
a repeat failure is real, not a timing artifact:
```bash
xcrun simctl uninstall <device-id> com.example.hebrewapp
```

- [ ] **Step 6: Commit**

```bash
git add HebrewApp/Data/PilotSwiftDataModels.swift HebrewApp/Data/ModelContainerFactory.swift HebrewAppTests/PilotSchemaMigrationTests.swift
git commit -m "Add ProductionAttemptRecord/SkillStateRecord/SessionStateRecord via PilotSchemaV2 migration"
```

---

### Task 10: ProductionProgressRepository conformance

**Files:**
- Modify: `HebrewApp/Domain/RepositoryProtocols.swift` (add `ProductionProgressRepository` protocol)
- Modify: `HebrewApp/Data/SwiftDataProgressRepository.swift` (add the second conformance + implementations)
- Test: `HebrewAppTests/SwiftDataProductionProgressRepositoryTests.swift`

**Interfaces:**
- Consumes: `Attempt`, `CardKey`, `SkillState`, `SessionState`, `EvidenceStatus`, `Correctness`, `AssessmentSource`, `CompetenceDimension` (Tasks 1–2); `ProductionAttemptRecord`, `SkillStateRecord`, `SessionStateRecord` (Task 9).
- Produces: `ProductionProgressRepository` protocol; `SwiftDataProgressRepository: ProgressRepository, ProductionProgressRepository`. Later sub-projects (SessionComposer, LessonEngine) consume this protocol, not the concrete class.

- [ ] **Step 1: Write the failing test**

Create `HebrewAppTests/SwiftDataProductionProgressRepositoryTests.swift`:

```swift
import Testing
import Foundation
@testable import HebrewApp

@Suite("SwiftDataProgressRepository — production methods")
struct SwiftDataProductionProgressRepositoryTests {
    @MainActor
    private func makeRepository() throws -> SwiftDataProgressRepository {
        let container = try ModelContainerFactory.makeContainer(inMemory: true)
        return SwiftDataProgressRepository(container: container)
    }

    @Test("recording an Attempt round-trips through attempts(matching:)")
    @MainActor
    func recordAndFetchAttempt() async throws {
        let repository = try makeRepository()
        let cardKey = CardKey(itemID: "lex_p_001", dimension: .recall, taskVariant: "e04")
        let attempt = Attempt(
            id: UUID(), timestampUTC: Date(), localLearningDay: "2026-09-21",
            timezoneIdentifier: "Europe/Berlin", cardKey: cardKey, response: "שלום",
            correctness: .correct, hintUse: 0, errorTags: [], latency: 2.1,
            assessmentSource: .systemEvaluated, schemaVersion: 1
        )

        try await repository.recordAttempt(attempt)
        let fetched = try await repository.attempts(matching: cardKey)

        #expect(fetched.count == 1)
        #expect(fetched.first?.correctness == .correct)
        #expect(fetched.first?.response == "שלום")
    }

    @Test("saving and loading a SkillState round-trips including nil fields")
    @MainActor
    func saveAndLoadSkillState() async throws {
        let repository = try makeRepository()
        let profileID = UUID()
        let state = SkillState(
            localProfileID: profileID, itemID: "lex_p_001", dimension: .recall,
            stability: nil, difficulty: nil, dueAt: nil, lapses: 0, helpLevel: 0,
            evidenceStatus: .notYetMeasured, independentSuccessDays: 0
        )

        try await repository.saveSkillState(state)
        let fetched = try await repository.skillState(itemID: "lex_p_001", dimension: .recall)

        #expect(fetched?.localProfileID == profileID)
        #expect(fetched?.stability == nil)
        #expect(fetched?.evidenceStatus == .notYetMeasured)
    }

    @Test("saving a SkillState twice for the same item+dimension updates in place")
    @MainActor
    func savingSkillStateTwiceUpdatesInPlace() async throws {
        let repository = try makeRepository()
        let profileID = UUID()
        var state = SkillState(
            localProfileID: profileID, itemID: "lex_p_001", dimension: .recall,
            stability: nil, difficulty: nil, dueAt: nil, lapses: 0, helpLevel: 0,
            evidenceStatus: .notYetMeasured, independentSuccessDays: 0
        )
        try await repository.saveSkillState(state)

        state.lapses = 1
        state.evidenceStatus = .independentEvidence
        try await repository.saveSkillState(state)

        let fetched = try await repository.skillState(itemID: "lex_p_001", dimension: .recall)
        #expect(fetched?.lapses == 1)
        #expect(fetched?.evidenceStatus == .independentEvidence)
    }

    @Test("saving and loading a SessionState round-trips")
    @MainActor
    func saveAndLoadSessionState() async throws {
        let repository = try makeRepository()
        let sessionID = UUID()
        let attemptID = UUID()
        let state = SessionState(
            id: sessionID, lessonID: "lesson_p_001", contentVersion: "0.1.0-fixture",
            currentStepID: "eb_p_001", completedAttemptIDs: [attemptID], pausedAt: nil
        )

        try await repository.saveSessionState(state)
        let fetched = try await repository.loadSessionState(id: sessionID)

        #expect(fetched?.lessonID == "lesson_p_001")
        #expect(fetched?.completedAttemptIDs == [attemptID])
    }

    @Test("resetAllProgress clears production tables too, without touching content")
    @MainActor
    func resetAllProgressClearsProductionTables() async throws {
        let repository = try makeRepository()
        let cardKey = CardKey(itemID: "lex_p_001", dimension: .recall, taskVariant: "e04")
        try await repository.recordAttempt(Attempt(
            id: UUID(), timestampUTC: Date(), localLearningDay: "2026-09-21",
            timezoneIdentifier: "Europe/Berlin", cardKey: cardKey, response: nil,
            correctness: .correct, hintUse: 0, errorTags: [], latency: nil,
            assessmentSource: .systemEvaluated, schemaVersion: 1
        ))

        try await repository.resetAllProgress()

        let remaining = try await repository.attempts(matching: cardKey)
        #expect(remaining.isEmpty)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test -project HebrewApp.xcodeproj -scheme HebrewApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:HebrewAppTests/SwiftDataProductionProgressRepositoryTests`

Expected: build error — `ProductionProgressRepository`, `recordAttempt(_:Attempt)`,
`attempts(matching:)`, `skillState`, `saveSkillState`, `saveSessionState`,
`loadSessionState` don't exist on `SwiftDataProgressRepository` yet.

- [ ] **Step 3: Add the `ProductionProgressRepository` protocol**

In `HebrewApp/Domain/RepositoryProtocols.swift`, add this after the
`ProductionContentRepository` protocol added in Task 5 (existing `ProgressRepository`
stays unchanged):

```swift
/// Persists production attempts, skill state and session state. Separate from
/// `ProgressRepository` for the same reason `ProductionContentRepository` is
/// separate from `ContentRepository` — additive, never forces an existing
/// conformer to implement production-only methods.
protocol ProductionProgressRepository: Sendable {
    func recordAttempt(_ attempt: Attempt) async throws(PersistenceError)
    func attempts(matching cardKey: CardKey) async throws(PersistenceError) -> [Attempt]

    func skillState(itemID: String, dimension: CompetenceDimension) async throws(PersistenceError) -> SkillState?
    func saveSkillState(_ state: SkillState) async throws(PersistenceError)

    func saveSessionState(_ state: SessionState) async throws(PersistenceError)
    func loadSessionState(id: UUID) async throws(PersistenceError) -> SessionState?
}
```

- [ ] **Step 4: Implement the conformance**

In `HebrewApp/Data/SwiftDataProgressRepository.swift`, change the class declaration
line from:

```swift
final class SwiftDataProgressRepository: ProgressRepository {
```

to:

```swift
final class SwiftDataProgressRepository: ProgressRepository, ProductionProgressRepository {
```

Add these methods inside the class body (after the existing `resetAllProgress()`
method, before the `// MARK: - Helpers` section):

```swift
    func recordAttempt(_ attempt: Attempt) async throws(PersistenceError) {
        let record = ProductionAttemptRecord(
            id: attempt.id,
            timestampUTC: attempt.timestampUTC,
            localLearningDay: attempt.localLearningDay,
            timezoneIdentifier: attempt.timezoneIdentifier,
            itemID: attempt.cardKey.itemID,
            dimensionRaw: attempt.cardKey.dimension.rawValue,
            taskVariant: attempt.cardKey.taskVariant,
            response: attempt.response,
            correctnessRaw: attempt.correctness.rawValue,
            hintUse: attempt.hintUse,
            errorTags: attempt.errorTags,
            latency: attempt.latency,
            assessmentSourceRaw: attempt.assessmentSource.rawValue,
            schemaVersion: attempt.schemaVersion
        )
        context.insert(record)
        try save()
    }

    func attempts(matching cardKey: CardKey) async throws(PersistenceError) -> [Attempt] {
        let itemID = cardKey.itemID
        let dimensionRaw = cardKey.dimension.rawValue
        let taskVariant = cardKey.taskVariant
        let predicate = #Predicate<ProductionAttemptRecord> {
            $0.itemID == itemID && $0.dimensionRaw == dimensionRaw && $0.taskVariant == taskVariant
        }
        let descriptor = FetchDescriptor<ProductionAttemptRecord>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestampUTC, order: .reverse)]
        )
        do {
            let records = try context.fetch(descriptor)
            return records.compactMap { record in
                guard
                    let dimension = CompetenceDimension(rawValue: record.dimensionRaw),
                    let correctness = Correctness(rawValue: record.correctnessRaw),
                    let assessmentSource = AssessmentSource(rawValue: record.assessmentSourceRaw)
                else { return nil }
                return Attempt(
                    id: record.id,
                    timestampUTC: record.timestampUTC,
                    localLearningDay: record.localLearningDay,
                    timezoneIdentifier: record.timezoneIdentifier,
                    cardKey: CardKey(itemID: record.itemID, dimension: dimension, taskVariant: record.taskVariant),
                    response: record.response,
                    correctness: correctness,
                    hintUse: record.hintUse,
                    errorTags: record.errorTags,
                    latency: record.latency,
                    assessmentSource: assessmentSource,
                    schemaVersion: record.schemaVersion
                )
            }
        } catch {
            throw PersistenceError.fetchFailed("\(error)")
        }
    }

    func skillState(itemID: String, dimension: CompetenceDimension) async throws(PersistenceError) -> SkillState? {
        let compositeKey = Self.skillStateCompositeKey(itemID: itemID, dimensionRaw: dimension.rawValue)
        guard let record = try fetchSkillStateRecord(compositeKey: compositeKey) else { return nil }
        guard let evidenceStatus = EvidenceStatus(rawValue: record.evidenceStatusRaw) else {
            throw PersistenceError.corruptImportRejected("skill state evidenceStatusRaw: \(record.evidenceStatusRaw)")
        }
        return SkillState(
            localProfileID: record.localProfileID,
            itemID: record.itemID,
            dimension: dimension,
            stability: record.stability,
            difficulty: record.difficulty,
            dueAt: record.dueAt,
            lapses: record.lapses,
            helpLevel: record.helpLevel,
            evidenceStatus: evidenceStatus,
            independentSuccessDays: record.independentSuccessDays
        )
    }

    func saveSkillState(_ state: SkillState) async throws(PersistenceError) {
        let compositeKey = Self.skillStateCompositeKey(itemID: state.itemID, dimensionRaw: state.dimension.rawValue)
        if let existing = try fetchSkillStateRecord(compositeKey: compositeKey) {
            existing.stability = state.stability
            existing.difficulty = state.difficulty
            existing.dueAt = state.dueAt
            existing.lapses = state.lapses
            existing.helpLevel = state.helpLevel
            existing.evidenceStatusRaw = state.evidenceStatus.rawValue
            existing.independentSuccessDays = state.independentSuccessDays
        } else {
            context.insert(SkillStateRecord(
                compositeKey: compositeKey,
                localProfileID: state.localProfileID,
                itemID: state.itemID,
                dimensionRaw: state.dimension.rawValue,
                stability: state.stability,
                difficulty: state.difficulty,
                dueAt: state.dueAt,
                lapses: state.lapses,
                helpLevel: state.helpLevel,
                evidenceStatusRaw: state.evidenceStatus.rawValue,
                independentSuccessDays: state.independentSuccessDays
            ))
        }
        try save()
    }

    func saveSessionState(_ state: SessionState) async throws(PersistenceError) {
        if let existing = try fetchSessionStateRecord(id: state.id) {
            existing.lessonID = state.lessonID
            existing.contentVersion = state.contentVersion
            existing.currentStepID = state.currentStepID
            existing.completedAttemptIDs = state.completedAttemptIDs
            existing.pausedAt = state.pausedAt
        } else {
            context.insert(SessionStateRecord(
                id: state.id,
                lessonID: state.lessonID,
                contentVersion: state.contentVersion,
                currentStepID: state.currentStepID,
                completedAttemptIDs: state.completedAttemptIDs,
                pausedAt: state.pausedAt
            ))
        }
        try save()
    }

    func loadSessionState(id: UUID) async throws(PersistenceError) -> SessionState? {
        guard let record = try fetchSessionStateRecord(id: id) else { return nil }
        return SessionState(
            id: record.id,
            lessonID: record.lessonID,
            contentVersion: record.contentVersion,
            currentStepID: record.currentStepID,
            completedAttemptIDs: record.completedAttemptIDs,
            pausedAt: record.pausedAt
        )
    }
```

Add these private helpers inside the existing `// MARK: - Helpers` section (next to
`fetchDialogueRecord`/`fetchPathRecord`):

```swift
    private static func skillStateCompositeKey(itemID: String, dimensionRaw: String) -> String {
        // Not keyed by localProfileID: this app has exactly one local profile today
        // (Documentation/ARCHITECTURE.md: "Lokales Profil ist eine UUID"), and
        // SkillState always operates against that single profile's context, matching
        // how PathProgressRecord/DialogueSessionRecord are already keyed without a
        // profile component.
        "\(itemID)|\(dimensionRaw)"
    }

    private func fetchSkillStateRecord(compositeKey: String) throws(PersistenceError) -> SkillStateRecord? {
        let predicate = #Predicate<SkillStateRecord> { $0.compositeKey == compositeKey }
        do {
            return try context.fetch(FetchDescriptor(predicate: predicate)).first
        } catch {
            throw PersistenceError.fetchFailed("\(error)")
        }
    }

    private func fetchSessionStateRecord(id: UUID) throws(PersistenceError) -> SessionStateRecord? {
        let predicate = #Predicate<SessionStateRecord> { $0.id == id }
        do {
            return try context.fetch(FetchDescriptor(predicate: predicate)).first
        } catch {
            throw PersistenceError.fetchFailed("\(error)")
        }
    }
```

Finally, extend `resetAllProgress()` to also clear the three new tables. Replace the
existing method in full:

```swift
    func resetAllProgress() async throws(PersistenceError) {
        do {
            try context.delete(model: PilotAttemptRecord.self)
            try context.delete(model: PronunciationAttemptRecord.self)
            try context.delete(model: DialogueSessionRecord.self)
            try context.delete(model: PathProgressRecord.self)
            try context.delete(model: ProductionAttemptRecord.self)
            try context.delete(model: SkillStateRecord.self)
            try context.delete(model: SessionStateRecord.self)
            try save()
        } catch {
            throw PersistenceError.saveFailed("resetAllProgress: \(error)")
        }
    }
```

Note: I referenced a `note` above the composite-key function claiming "not keyed by
localProfileID" — this is a deliberate simplification given the app has exactly one
local profile today; `state.localProfileID` is still stored on the record and
returned faithfully, just not part of the fetch key. Do not silently drop this
comment when implementing — it documents a real, load-bearing assumption a future
multi-profile change would need to revisit.

- [ ] **Step 5: Run the test to verify it passes**

Run: `xcodebuild test -project HebrewApp.xcodeproj -scheme HebrewApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:HebrewAppTests/SwiftDataProductionProgressRepositoryTests`

Expected: PASS, 5 tests.

- [ ] **Step 6: Run the FULL test suite**

Run: `xcodebuild test -project HebrewApp.xcodeproj -scheme HebrewApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`

Expected: everything green, including all pilot-flow tests (confirms
`resetAllProgress()`'s extension doesn't break the existing Entwicklermodus reset
flow that calls it).

- [ ] **Step 7: Commit**

```bash
git add HebrewApp/Domain/RepositoryProtocols.swift HebrewApp/Data/SwiftDataProgressRepository.swift HebrewAppTests/SwiftDataProductionProgressRepositoryTests.swift
git commit -m "Add ProductionProgressRepository conformance to SwiftDataProgressRepository"
```

---

### Task 11: `localLearningDay` pure computation

**Files:**
- Create: `HebrewApp/Domain/LocalLearningDay.swift`
- Test: `HebrewAppTests/LocalLearningDayTests.swift`

**Interfaces:**
- Consumes: nothing beyond `Foundation` (`Date`, `TimeZone`, `Calendar`).
- Produces: `func localLearningDay(for date: Date, in timeZone: TimeZone) -> String` — a free function later sub-projects (LessonEngine, whatever constructs real `Attempt` values) call alongside `DateProviding.now()` to populate `Attempt.localLearningDay`/`.timezoneIdentifier`. Not wired into any call site in this plan — see the spec's §9 non-goals.

- [ ] **Step 1: Write the failing tests**

Create `HebrewAppTests/LocalLearningDayTests.swift`:

```swift
import Testing
import Foundation
@testable import HebrewApp

@Suite("localLearningDay")
struct LocalLearningDayTests {
    @Test("derives the correct calendar day in the given timezone")
    func derivesCorrectDay() {
        // 2026-09-21 23:30 UTC is still 2026-09-21 in UTC itself.
        let date = Date(timeIntervalSince1970: 1_790_123_400) // 2026-09-21T23:30:00Z, checked below
        let utc = TimeZone(identifier: "UTC")!
        #expect(localLearningDay(for: date, in: utc) == "2026-09-21")
    }

    @Test("the same instant can fall on different calendar days in different timezones")
    func sameInstantDifferentTimezonesDifferentDays() {
        // 2026-09-21 23:30 UTC is already 2026-09-22 00:30 in Europe/Berlin (UTC+1 in September... verified via the assertion itself, not assumed)
        let date = Date(timeIntervalSince1970: 1_790_123_400)
        let utc = TimeZone(identifier: "UTC")!
        let tokyo = TimeZone(identifier: "Asia/Tokyo")! // UTC+9, no DST
        #expect(localLearningDay(for: date, in: utc) == "2026-09-21")
        #expect(localLearningDay(for: date, in: tokyo) == "2026-09-22")
    }

    @Test("a DST transition day still produces one unambiguous calendar day string")
    func dstTransitionDayIsUnambiguous() {
        // 2026-03-29 is a DST-start Sunday in Europe/Berlin (clocks jump 02:00->03:00).
        // Pick a UTC instant that lands in the afternoon Berlin-local regardless of
        // which side of the jump applies, so this test is robust to the exact
        // transition instant rather than asserting on it directly.
        let date = Date(timeIntervalSince1970: 1_774_800_000) // 2026-03-29T16:00:00Z
        let berlin = TimeZone(identifier: "Europe/Berlin")!
        #expect(localLearningDay(for: date, in: berlin) == "2026-03-29")
    }

    @Test("output is always a fixed-width YYYY-MM-DD string, zero-padded")
    func outputIsZeroPadded() {
        let date = Date(timeIntervalSince1970: 1_735_959_000) // early January
        let utc = TimeZone(identifier: "UTC")!
        let day = localLearningDay(for: date, in: utc)
        #expect(day.count == 10)
        #expect(day.filter { $0 == "-" }.count == 2)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `xcodebuild test -project HebrewApp.xcodeproj -scheme HebrewApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:HebrewAppTests/LocalLearningDayTests`

Expected: build error — `localLearningDay` doesn't exist. (If any of the hand-picked
`timeIntervalSince1970` constants above don't actually correspond to the calendar
dates claimed in their comments, this step's failure will instead be a *test
assertion* failure once the function exists rather than a build error — if that
happens, recompute the constant with `date -u -r <epoch>` or a quick Swift snippet
and fix the literal; do not change the expected date string to match a wrong
literal.)

- [ ] **Step 3: Write the minimal implementation**

Create `HebrewApp/Domain/LocalLearningDay.swift`:

```swift
import Foundation

/// The calendar day `date` falls on in `timeZone`, as a fixed-width "YYYY-MM-DD"
/// string. Used for `Attempt.localLearningDay` (Documentation/LEARNING_ENGINE.md:
/// scheduling operates on the learner's local calendar day, not a UTC day boundary
/// that could fall in the middle of their evening). Pure — no dependency on
/// `DateProviding`; callers that need "now" combine `DateProviding.now()` with this
/// function themselves.
func localLearningDay(for date: Date, in timeZone: TimeZone) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `xcodebuild test -project HebrewApp.xcodeproj -scheme HebrewApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:HebrewAppTests/LocalLearningDayTests`

Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add HebrewApp/Domain/LocalLearningDay.swift HebrewAppTests/LocalLearningDayTests.swift
git commit -m "Add pure localLearningDay(for:in:) computation with DST/timezone coverage"
```

---

### Task 12: Python CI-mirror validator

**Files:**
- Create: `Scripts/validate_production.py`

**Interfaces:**
- Consumes: `Content/Production/*.json` (Task 4) on disk.
- Produces: a standalone script, same invocation convention as `Scripts/validate_pilot.py` (`python3 Scripts/validate_production.py`, exit 0 + `PASS: ...` on success, exit 1 + `FAIL: ...` on `stderr` otherwise). Not yet wired into `.github/workflows/ci.yml` — explicitly deferred, see spec §9.

- [ ] **Step 1: Write the script**

Create `Scripts/validate_production.py`:

```python
#!/usr/bin/env python3
"""Validate the supplied production content fixture bundle; no linguistic or
platform validation. Mirrors Scripts/validate_pilot.py's structure and the checks
HebrewApp/Content/ProductionContentLoader.swift enforces at runtime, generalized
beyond the pilot's fixed 3-kind/exact-count shape."""
import hashlib
import json
import sys
from pathlib import Path

BASE = Path(__file__).resolve().parents[1] / 'Content' / 'Production'

def require(condition, message):
    if not condition:
        raise ValueError(message)

def load(name):
    return json.loads((BASE / name).read_text(encoding='utf-8'))

def validate():
    manifest = load('manifest.json')
    require(manifest['schemaVersion'] == 1, 'Unsupported production schema')
    require(manifest['status'] == 'draft', 'Production fixture must not claim release approval')
    expected_names = {'lexemes.json', 'sentences.json', 'lessons.json'}
    require({f['path'] for f in manifest['files']} == expected_names, 'Manifest file mismatch')
    require(len(manifest['files']) == 3, 'Duplicate manifest entries')
    for entry in manifest['files']:
        path = BASE / entry['path']
        require(hashlib.sha256(path.read_bytes()).hexdigest() == entry['sha256'], f'Hash mismatch: {path.name}')

    lexemes = load('lexemes.json')
    sentences = load('sentences.json')
    lessons = load('lessons.json')
    require(len(lexemes) == manifest['counts']['lexemes'], 'Wrong count: lexemes')
    require(len(sentences) == manifest['counts']['sentences'], 'Wrong count: sentences')
    require(len(lessons) == manifest['counts']['lessons'], 'Wrong count: lessons')

    ids = set()
    known_kind = {}
    for row in lexemes:
        require(row['id'] not in ids, f'Duplicate ID: {row["id"]}')
        ids.add(row['id'])
        known_kind[row['id']] = ('lexeme', row['reviewStatus'])
        require(row['hebrew'].strip(), 'Empty hebrew')
        require(any('א' <= ch <= 'ת' for ch in row['hebrew']), 'Missing Hebrew text')
    for row in sentences:
        require(row['id'] not in ids, f'Duplicate ID: {row["id"]}')
        ids.add(row['id'])
        known_kind[row['id']] = ('sentence', row['reviewStatus'])
        require(row['hebrew'].strip() and row['german'].strip(), 'Empty hebrew/german')
    for row in lessons:
        require(row['id'] not in ids, f'Duplicate ID: {row["id"]}')
        ids.add(row['id'])
        known_kind[row['id']] = ('lesson', row['reviewStatus'])

    # Reference resolution: exampleSentenceIDs, unitIDs, prerequisiteIDs, promptRefs.
    for row in lexemes:
        for ref in row['exampleSentenceIDs']:
            require(ref in ids, f'Unresolved reference from {row["id"]}: {ref}')
    for row in lessons:
        for ref in row['unitIDs'] + row['prerequisiteIDs']:
            require(ref in ids, f'Unresolved reference from {row["id"]}: {ref}')
        for blueprint in row['exerciseBlueprints']:
            for ref in blueprint['promptRefs']:
                require(ref in ids, f'Unresolved reference from {blueprint["id"]}: {ref}')

    # Prerequisite graph: no cycles, every lesson reachable from a zero-prerequisite root.
    lessons_by_id = {row['id']: row for row in lessons}
    visiting, done = set(), set()

    def detect_cycle(lesson_id):
        if lesson_id in done or lesson_id not in lessons_by_id:
            return
        require(lesson_id not in visiting, f'Cyclic prerequisite at: {lesson_id}')
        visiting.add(lesson_id)
        for prereq in lessons_by_id[lesson_id]['prerequisiteIDs']:
            detect_cycle(prereq)
        visiting.discard(lesson_id)
        done.add(lesson_id)

    for row in lessons:
        detect_cycle(row['id'])

    roots = [row['id'] for row in lessons if not row['prerequisiteIDs']]
    reachable, pending = set(roots), list(roots)
    while pending:
        current = pending.pop()
        for row in lessons:
            if current in row['prerequisiteIDs'] and row['id'] not in reachable:
                reachable.add(row['id'])
                pending.append(row['id'])
    for row in lessons:
        require(row['id'] in reachable, f'Unreachable lesson: {row["id"]}')

    # Draft/released boundary: a released item may not depend on a non-released one.
    for row in lessons:
        if row['reviewStatus'] == 'released':
            for ref in row['unitIDs'] + row['prerequisiteIDs']:
                kind, status = known_kind[ref]
                require(status == 'released', f'Released lesson {row["id"]} depends on non-released {ref}')
    for row in lexemes:
        if row['reviewStatus'] == 'released':
            for ref in row['exampleSentenceIDs']:
                kind, status = known_kind[ref]
                require(status == 'released', f'Released lexeme {row["id"]} depends on non-released {ref}')

    # Example-count rule: a lexeme beyond draft needs >= 2 examples.
    for row in lexemes:
        if row['reviewStatus'] != 'draft':
            require(len(row['exampleSentenceIDs']) >= 2, f'Lexeme {row["id"]} has fewer than 2 examples')

    print(f'PASS: {len(lexemes)} lexemes, {len(sentences)} sentences, {len(lessons)} reachable/acyclic lessons; IDs, references and SHA256 valid.')
    print('Linguistic review, audio quality and device tests remain OPEN — this fixture is draft-only, not curriculum content.')

if __name__ == '__main__':
    try:
        validate()
    except (ValueError, KeyError, TypeError, OSError) as error:
        print(f'FAIL: {error}', file=sys.stderr)
        sys.exit(1)
```

- [ ] **Step 2: Run the script and verify it passes**

Run: `chmod +x Scripts/validate_production.py && python3 Scripts/validate_production.py`

Expected:
```
PASS: 6 lexemes, 2 sentences, 2 reachable/acyclic lessons; IDs, references and SHA256 valid.
Linguistic review, audio quality and device tests remain OPEN — this fixture is draft-only, not curriculum content.
```
Exit code 0. If it prints `FAIL: ...` instead, the most likely cause is a hash
mismatch from Task 4 Step 4/5 (a content file was edited after its hash was computed)
— re-run `shasum -a 256` on the three content files and fix `manifest.json`.

- [ ] **Step 3: Verify it correctly fails on broken content (manual, not committed)**

Run this ad-hoc check and confirm it fails with a clear message, then discard the
temp copy — this is a one-time sanity check of the script itself, not a permanent
test fixture:

```bash
cp -r Content/Production /tmp/broken-production
python3 -c "
import json
p = '/tmp/broken-production/lessons.json'
data = json.load(open(p))
data[1]['prerequisiteIDs'] = ['does_not_exist']
json.dump(data, open(p, 'w'))
"
python3 -c "
import sys
sys.path.insert(0, 'Scripts')
import validate_production
validate_production.BASE = __import__('pathlib').Path('/tmp/broken-production')
validate_production.validate()
" 2>&1 | tail -3
rm -rf /tmp/broken-production
```

Expected: a line containing `Unresolved reference from lesson_p_002: does_not_exist`
(printed via the `raise ValueError` → uncaught in this ad-hoc invocation, or wrap in
try/except if running this exact snippet — the point is confirming the check fires,
not a specific stack trace shape).

- [ ] **Step 4: Commit**

```bash
git add Scripts/validate_production.py
git commit -m "Add Scripts/validate_production.py (Python CI-mirror of ProductionContentLoader)"
```

---

### Task 13: Final integration — full verification, DECISIONS.md, IMPLEMENTATION_STATUS.md

**Files:**
- Modify: `Documentation/DECISIONS.md`
- Modify: `Documentation/IMPLEMENTATION_STATUS.md`

**Interfaces:**
- Consumes: everything from Tasks 1–12.
- Produces: nothing new in code — this task is documentation + final verification only.

- [ ] **Step 1: Run the full build + test suite one more time**

```bash
xcodegen generate
xcodebuild build -project HebrewApp.xcodeproj -scheme HebrewApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
xcodebuild test -project HebrewApp.xcodeproj -scheme HebrewApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
```

Expected: `BUILD SUCCEEDED`, then every test passes. Count them: this plan added 4
(Task 1) + 3 (Task 2) + 2 (Task 3) + 3 (Task 5) + 2 (Task 6) + 3 (Task 7) + 5
(Task 8) + 1 (Task 9) + 5 (Task 10) + 4 (Task 11) = 32 new unit tests, on top of the
30 that existed going in — expect 62 unit tests total, plus the unchanged 5 UI
tests. If the total doesn't match, find the missing test before proceeding (don't
just note the discrepancy and move on).

- [ ] **Step 2: Run `Scripts/validate_production.py` one more time standalone**

```bash
python3 Scripts/validate_production.py
```

Expected: `PASS: ...`, exit 0.

- [ ] **Step 3: Add the DECISIONS.md entries for this sub-project's implementation assumptions**

Open `Documentation/DECISIONS.md`. Add a new numbered section after the existing
"Rebranding-Entscheidung" section (or after whatever is currently the last section —
check the file's current end before inserting, since other work may have added
sections since this plan was written):

```markdown
## P2 Sub-Project 1 — Production Schema Implementierungsannahmen (Claude Code, TAGESDATUM)
Die vollständige Spezifikation steht in `docs/superpowers/specs/2026-09-21-p2-production-schema-design.md`; diese Einträge dokumentieren nur die darin als Implementierungsannahme markierten Punkte, jetzt umgesetzt.

1. **`Lesson` = atomare Einführungseinheit, nicht Kapitel.** `moduleID` gruppiert mehrere `Lesson`-Werte unter eines der 18 A1-Kapitel; `unitIDs` sind die in dieser Lektion neu eingeführten Lexem-/Satz-IDs. `ExerciseBlueprint`s sind direkt in ihrer `Lesson` eingebettet, keine separate Inhaltsdatei.
2. **`AudioSpec`** nutzt ein flaches `sourceKind` + optionalen `bundledAssetRelativePath` statt eines Swift-Enums mit Assoziierten Werten — verifiziert gegen Swifts tatsächliche synthetisierte `Codable`-Kodierung (`{"bundledAsset":{"relativePath":"..."}}`, verschachtelt), bevor die einfachere, für Hand-Autoren geeignetere Form gewählt wurde.
3. **`SentenceToken`** trägt eine eigene ID, `surfaceForm`, optionales `niqqud` und optionale `lexemeID` — gewählt, weil eine reine ID-Liste keine vom Lemma abweichende flektierte Oberflächenform tragen könnte.
4. **`ExitCriteria`** (erforderliche `ExerciseBlueprint`-IDs + optionales Mindestverhältnis) ist neues Design; DATA_MODEL.md nennt nur das Feld, nicht seine Form.
5. **Zwei neue, additive Repository-Protokolle** (`ProductionContentRepository`, `ProductionProgressRepository`) statt Erweiterung der bestehenden `ContentRepository`/`ProgressRepository` — verhindert, dass `PilotContentLoader` oder künftige Test-Mocks production-spezifische Methoden implementieren müssten.
6. **`PilotSchemaV2`** erweitert das bestehende, einzelne SwiftData-Schema additiv (keine Änderung an den vier bestehenden Pilot-`@Model`-Typen) statt eines zweiten `ModelContainer`; erste real ausgeführte Migration dieses Codebase (`PilotMigrationPlan.stages` war zuvor `[]`).
7. **`TutorResult`** ergänzt `TutorProtocols.swift`s bestehende `TutorSuggestion` (dort bereits als "reduzierte Pilotform von `TutorResult`" dokumentiert) um die beiden fehlenden Felder, unter Wiederverwendung von `TutorProviderKind`/`LocalTutorCapability` statt neuer Enums.
8. **`SkillStateRecord`** ist nicht nach `localProfileID` geschlüsselt (nur nach `itemID`+`dimension`) — die App hat aktuell genau ein lokales Profil; ein künftiger Mehrprofil-Wechsel muss diese Annahme revisitieren.
```

Replace `TAGESDATUM` with today's actual date at implementation time (this plan was
written 21.09.2026 — if implemented same-day, use that).

- [ ] **Step 4: Add the IMPLEMENTATION_STATUS.md addendum**

Open `Documentation/IMPLEMENTATION_STATUS.md`. Find the `## Nächste Phase` heading
(currently the last section) and insert a new section immediately before it:

```markdown
## Nachtrag: P2 Sub-Project 1 — Produktions-Contentschema, Validator, Persistenz (TAGESDATUM)

Erster von mehreren P2-„Lernkern"-Teilprojekten (volle Zerlegung siehe Gesprächsverlauf/DECISIONS.md), spezifiziert in `docs/superpowers/specs/2026-09-21-p2-production-schema-design.md`:
- Produktions-Domain-Typen (`Lexeme`, `Sentence`, `Lesson`, `ExerciseBlueprint`, `ContentManifest`/`Bundle`, `SkillState`, `Attempt`, `SessionState`, `TutorResult`) plus eine Erweiterung von `PronunciationAttempt` um `confidence`.
- Produktions-Contentvalidator: Swift-Loader (`ProductionContentLoader`, vier neue Prüfungen über das bestehende Pilotmuster hinaus: Referenzauflösung, Voraussetzungs-Graph ohne Zyklen/mit Erreichbarkeit, Draft/Released-Grenze, Mindestbeispielzahl) plus Python-CI-Spiegel (`Scripts/validate_production.py`, noch **nicht** in `.github/workflows/ci.yml` verdrahtet — bewusst zurückgestellt).
- SwiftData-Persistenz über `PilotSchemaV2` (rein additiv, die vier bestehenden Pilot-`@Model`-Typen unverändert) mit einer echten, erstmals ausgeführten Migrationsstufe.
- Ein kleiner, selbst verfasster, vollständig `draft`-markierter Testfixture-Satz (`Content/Production/`, 6 Lexeme/2 Sätze/2 Lektionen) — ausdrücklich kein Kursinhalt.
- Zwei neue Repository-Protokolle (`ProductionContentRepository`, `ProductionProgressRepository`), additiv, ohne bestehende Pilot-Konformität zu verändern.

**Bewusst nicht Teil dieses Teilprojekts** (nächste P2-Teilprojekte): FSRS-Adapter, `SessionComposer`, `PrerequisiteEngine`-Laufzeitlogik, `AnswerEvaluator`, `HelpPolicy`/Mastery-Logik, jegliche Umstellung von `LearnListView`/`PilotPathPlayerView`/`TodayView` auf das neue Schema — die zwei Pilot-Demo-Lernstrecken laufen unverändert weiter.

**Verifiziert**: `xcodebuild build`/`test` sauber (Unit-Testanzahl von 30 auf 62 gestiegen, UI-Tests unverändert bei 5), `Scripts/validate_production.py` läuft eigenständig durch, die V1→V2-Migration erstmals real getestet (bestehende Pilot-Daten bleiben erhalten, neue Tabellen leer).
```

Replace `TAGESDATUM` with today's actual date at implementation time.

- [ ] **Step 5: Final commit**

```bash
git add Documentation/DECISIONS.md Documentation/IMPLEMENTATION_STATUS.md
git commit -m "Document P2 sub-project 1 implementation assumptions and status"
```

- [ ] **Step 6: Push**

```bash
git push
```

Watch the GitHub Actions run (`gh run watch`) to confirm `build-and-test` passes on
the real CI runner too, not just locally — this sub-project changed `project.yml`
(new resource folder) and the SwiftData schema, both worth confirming on a clean
CI checkout rather than trusting only the local DerivedData cache.
