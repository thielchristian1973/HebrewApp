# P2 Lernkern, Sub-Project 1: Production Content Schema + Validator + Persistence

Status: approved framing, spec drafted 21.09.2026. First of several P2 sub-projects
(see chat log / DECISIONS.md for the full decomposition). Everything else in P2
(FSRS adapter, AnswerEvaluator, PrerequisiteEngine, HelpPolicy, SessionComposer,
LessonEngine, E01–E12, real Grammar/Review screens) depends on the types and
persistence introduced here and is explicitly out of scope for this spec.

## 1. Scope

In scope:
- Production Domain types for course content (`Lexeme`, `Sentence`, `Lesson`,
  `ExerciseBlueprint`, `ProductionContentManifest`, `ProductionContentBundle`) and
  progress (`Attempt`, `SkillState`, `SessionState`), per Documentation/DATA_MODEL.md's
  "Produktionsmodell" section.
- A production content validator: a Swift loader (`ProductionContentLoader`,
  extending `ContentRepository`) mirroring `PilotContentLoader`'s pattern, plus a
  Python CI-mirror (`Scripts/validate_production.py`, mirroring `validate_pilot.py`).
- SwiftData persistence for the new mutable types, added to the existing schema via
  a new versioned stage (`PilotSchemaV2`), with a real (if trivial) migration.
- A small set of original, `reviewStatus == .draft` test fixtures in the new schema
  shape, used only to exercise the loader/validator/persistence in tests — not real
  curriculum content.
- Unit/integration tests for all of the above, TDD'd.

Out of scope (explicitly, per IMPLEMENTATION_PLAN.md's P2 line and this repo's own
"noch keine unfreigegebene Massenproduktion" constraint):
- FSRS, SessionComposer, PrerequisiteEngine, AnswerEvaluator, HelpPolicy — these
  consume the types defined here but are separate sub-projects.
- Any real A0/A1 course content authoring.
- Rewiring `LearnListView`/`PilotPathPlayerView`/`TodayView` off the pilot path
  model — they keep working against `PilotLearningPath` exactly as today. That
  rewire is LessonEngine's job (a later sub-project), once SessionComposer exists
  to actually drive it.

## 2. Module placement

Everything here follows the layering already established and verified in P0/P1
(Documentation/ARCHITECTURE.md, confirmed unchanged by this session's research):

- **Domain** (`HebrewApp/Domain/`): new plain `Codable`/`Sendable` value types only.
  Foundation import only, no SwiftUI/SwiftData/Speech. New files:
  `ProductionContent.swift` (Lexeme/Sentence/Lesson/ExerciseBlueprint/manifest/bundle
  and their supporting enums), `SkillState.swift`, `ProductionAttempt.swift`,
  `SessionState.swift`. `RepositoryProtocols.swift` and `DomainErrors.swift` are
  extended in place, not replaced.
- **Content** (`HebrewApp/Content/`): new `ProductionContentLoader.swift`,
  implementing the extended `ContentRepository` protocol. Reads from a new bundle
  folder reference `Content/Production/` (repo root, resource-folder-referenced in
  `project.yml` exactly like `Content/Pilot/` is today — folder references keep only
  their own name at the bundle root, so the loader's `subdirectory` is
  `"Production"`).
- **Data** (`HebrewApp/Data/`): `PilotSwiftDataModels.swift` gets three new `@Model`
  types and a `PilotSchemaV2` + a real migration stage (both detailed in §5).
  `SwiftDataProgressRepository.swift` gets new method implementations for the new
  protocol methods.
- **Scripts/**: new `validate_production.py`, sibling to `validate_pilot.py`, same
  "no linguistic/platform validation, structural only" scope note in its docstring.

No new module/folder is introduced. This is deliberate — DATA_MODEL.md's
"Produktionsmodell" is additive to the existing layering, not a restructuring.

## 3. Domain types — content side (immutable, bundle JSON)

`ReviewStatus` already exists (`HebrewApp/Domain/PilotContent.swift`, 4 cases:
`draft` / `structurallyValidated` / `linguisticallyReviewed` / `released`) and is
reused as-is — no new review-status enum.

```swift
// HebrewApp/Domain/ProductionContent.swift

enum CourseLevel: String, Codable, Sendable, CaseIterable {
    case a0, a1, a2
}

enum PartOfSpeech: String, Codable, Sendable, CaseIterable {
    case noun, verb, adjective, adverb, pronoun, preposition, conjunction, interjection, numeral, particle
}

enum GrammaticalGender: String, Codable, Sendable { case masculine, feminine }
enum GrammaticalNumber: String, Codable, Sendable { case singular, plural, dual }

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
/// reviewed asset. `.bundledAsset` exists for the small set of items where a specific
/// rendering has been checked against the target voices (CONTENT_GUIDE.md's "Audio
/// auf Zielstimmen geprüft" pipeline stage) — most items stay `.systemTTS`, matching
/// this project's no-paid-audio-production constraint (CLAUDE.md).
enum AudioSourceKind: String, Codable, Sendable, Hashable {
    case systemTTS
    case bundledAsset
}

/// Flat `kind` + optional payload rather than a Swift associated-value enum: verified
/// Swift's synthesized `Codable` for `case bundledAsset(relativePath: String)` produces
/// `{"bundledAsset":{"relativePath":"..."}}` (nested, nonobvious to hand-author); this
/// shape — `{"sourceKind":"bundledAsset","bundledAssetRelativePath":"..."}` — is flat
/// and matches how a human or content-authoring tool would naturally write it.
/// `bundledAssetRelativePath` is expected non-nil exactly when `sourceKind ==
/// .bundledAsset` — a content-authoring convention, not validator-enforced in this
/// sub-project (kept out of scope deliberately; revisit if it causes real bugs).
struct AudioSpec: Codable, Sendable, Hashable {
    var sourceKind: AudioSourceKind
    var bundledAssetRelativePath: String?
    var targetVoiceIdentifiers: [String]
    var isVerifiedAgainstTargetVoices: Bool
}

struct Lexeme: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let hebrew: String
    /// Optional until editorially released (DATA_MODEL.md) — never auto-derived from
    /// bare text and presented as reviewed.
    var niqqud: String?
    let lemma: String
    var transliteration: String?
    var germanSenses: [GermanSense]
    var partOfSpeech: PartOfSpeech
    var gender: GrammaticalGender?
    var number: GrammaticalNumber?
    /// Hebrew root (שורש), where linguistically meaningful (mainly verbs/derived nouns).
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
    /// nil when this token doesn't map to a tracked lexeme yet (function word, punctuation).
    var lexemeID: String?
}

struct Sentence: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let hebrew: String
    var niqqud: String?
    let german: String
    var tokens: [SentenceToken]
    /// Free-form, editorially-assigned tags (e.g. "present-tense", "possessive") — not
    /// a closed enum, since no fixed tag vocabulary is specified anywhere yet.
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
    /// References a curated answer policy (accepted variants, normalization rules) —
    /// the policy's own shape belongs to AnswerEvaluator's sub-project, not this one.
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
/// A1 chapters. Documentation/CURRICULUM.md + DIDACTICS.md: chapters are containers,
/// each split into multiple sub-units capped at 3–6 new productive items and at most
/// one new grammar rule; `moduleID` is which chapter this unit belongs to.
struct Lesson: Codable, Sendable, Hashable, Identifiable {
    let id: String
    var moduleID: String
    var order: Int
    var objectives: [String]
    var prerequisiteIDs: [String]
    /// Hebrew grapheme identifiers that must already be introduced before this lesson's
    /// reading-type exercises may be attempted (DECISIONS.md #6, DIDACTICS.md).
    var graphemePrerequisites: [String]
    /// Lexeme/Sentence IDs newly introduced by this lesson.
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

**Implementation assumptions made here** (to be logged in DECISIONS.md per this
project's "Implementierungsannahmen als solche in DECISIONS dokumentieren" rule —
none of DATA_MODEL.md's field lists spell out internal Swift representations):
- `Lesson` = one atomic introduction sub-unit, not a chapter. `moduleID` is the
  chapter grouping; `unitIDs` are the Lexeme/Sentence IDs newly taught.
  `ExerciseBlueprint`s are embedded directly in their owning `Lesson` (no separate
  top-level exercise-blueprint content file), since a blueprint's `promptRefs`/
  `answerPolicyID` are lesson-specific, not shared library entries.
- `AudioSpec`/`AudioSource` shape (system-TTS default, bundled-asset opt-in) is new
  design, informed by the local-TTS-first constraint but not literally specified
  anywhere.
- `SentenceToken` (own id + surface form + optional niqqud + optional lexeme link)
  is how "tokenIDs/ordered tokens" gets represented — chosen because a raw ID list
  alone can't carry an inflected surface form distinct from its lemma.
- `ExitCriteria` (required-blueprint-IDs + optional minimum ratio) is new design —
  DATA_MODEL.md names the field, not its shape.
- `ProductionManifestCounts` (per-kind counts, checked against decoded array
  lengths) isn't in DATA_MODEL.md's summarized field list for `ContentManifest`,
  but mirrors `PilotManifest`'s existing, working `counts` field — kept for the same
  cheap sanity check it already provides, not because the doc mandates it.

## 4. Domain types — progress side (mutable, SwiftData-backed)

```swift
// HebrewApp/Domain/SkillState.swift

enum EvidenceStatus: String, Codable, Sendable {
    case notYetMeasured
    case helpAssistedOnly
    case independentEvidence
}

/// Per (profile, item, dimension) mastery state. `stability`/`difficulty`/`dueAt` stay
/// nil until real FSRS-adapter work populates them — nil must never be read as "bad"
/// (Documentation/DATA_MODEL.md).
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

```swift
// HebrewApp/Domain/ProductionAttempt.swift

/// itemID + dimension + taskVariant identifies one schedulable "card"
/// (Documentation/LEARNING_ENGINE.md).
struct CardKey: Codable, Sendable, Hashable {
    let itemID: String
    let dimension: CompetenceDimension
    let taskVariant: String
}

enum Correctness: String, Codable, Sendable { case correct, incorrect, unscored }

enum AssessmentSource: String, Codable, Sendable {
    case systemEvaluated
    case selfAssessed
}

/// The production Attempt contract — distinct from the pilot's deliberately-reduced
/// `PilotAttempt`. Both coexist: pilot flows keep recording `PilotAttempt`, real
/// lessons will record `Attempt`.
struct Attempt: Codable, Sendable, Hashable, Identifiable {
    let id: UUID
    let timestampUTC: Date
    /// e.g. "2026-09-21" — derived via a Clock abstraction (not yet in the codebase;
    /// needed by the FSRS sub-project, out of scope here beyond persisting the string).
    let localLearningDay: String
    /// Which timezone was used to derive `localLearningDay`, so it can be audited or
    /// re-derived later (DST/rollback handling lives in the FSRS sub-project).
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

```swift
// HebrewApp/Domain/SessionState.swift

struct SessionState: Codable, Sendable, Hashable, Identifiable {
    let id: UUID
    var lessonID: String
    var contentVersion: String
    var currentStepID: String?
    var completedAttemptIDs: [UUID]
    var pausedAt: Date?
}
```

`PronunciationAttempt` (`HebrewApp/Domain/PilotAttempt.swift`) already matches the
production contract almost exactly — it's evolved in place by adding one field:

```swift
struct PronunciationAttempt: Codable, Sendable, Hashable, Identifiable {
    // ...existing fields unchanged...
    /// ASR confidence, if available. Never surfaced to the user as a pronunciation
    /// or intelligibility score (DATA_MODEL.md, SPEECH_SPEC.md) — internal/debug only.
    let confidence: Double?
}
```

This is a source-breaking change to its memberwise `init` (new field). Since
`PronunciationAttempt` already has a custom `init` with defaults, add
`confidence: Double? = nil` as the last parameter — every existing call site keeps
compiling unchanged.

`TutorResult` — **resolved**: `HebrewApp/Domain/TutorProtocols.swift` already has
`TutorSuggestion` (`suggestedSentenceID`, `provider: TutorProviderKind`,
`elapsedTime`), explicitly documented in its own doc comment as "matches the shape
of DATA_MODEL.md's `TutorResult`, reduced to the pilot's needs" — the same
pilot-reduced-type pattern as `PilotAttempt`/`Attempt`. `TutorSuggestion` stays
unchanged (still used by `TutorProvider`/`DialogueEngine`); the new production type
adds the two missing fields and reuses two already-existing enums rather than
inventing new ones:

```swift
// HebrewApp/Domain/TutorResult.swift
struct TutorResult: Sendable, Hashable {
    var nextTurnID: String?
    var feedbackID: String?
    var provider: TutorProviderKind        // reused from TutorProtocols.swift
    var elapsedTime: TimeInterval
    var capabilityStatus: LocalTutorCapability  // reused from CapabilityStatus.swift
}
```

Not `Codable`: nothing in this sub-project persists a `TutorResult` (no
`TutorResultRecord` in §5) — it's an in-memory result value, like
`TutorSuggestion` today.

## 5. SwiftData persistence + migration

Three new `@Model` types, added to `HebrewApp/Data/PilotSwiftDataModels.swift`
alongside the existing four (which are unchanged):

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

    init(id: UUID, timestampUTC: Date, localLearningDay: String, timezoneIdentifier: String,
         itemID: String, dimensionRaw: String, taskVariant: String, response: String?,
         correctnessRaw: String, hintUse: Int, errorTags: [String], latency: Double?,
         assessmentSourceRaw: String, schemaVersion: Int) {
        // straight assignment, matching existing @Model init style
    }
}

@Model
final class SkillStateRecord {
    /// "\(localProfileID)|\(itemID)|\(dimensionRaw)" — SwiftData's `.unique` attribute
    /// needs a single value; composing the natural composite key into one string
    /// matches the simplest approach and avoids a multi-field uniqueness constraint
    /// that isn't straightforward to express with this SDK's `@Attribute` macro.
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

    init(...) { ... }
}

@Model
final class SessionStateRecord {
    @Attribute(.unique) var id: UUID
    var lessonID: String
    var contentVersion: String
    var currentStepID: String?
    var completedAttemptIDs: [UUID]
    var pausedAt: Date?

    init(...) { ... }
}
```

New schema version and migration stage (verified against the installed SDK's actual
`MigrationStage`/`VersionedSchema`/`SchemaMigrationPlan` API before writing this —
see §7):

```swift
enum PilotSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [
            PilotAttemptRecord.self, PronunciationAttemptRecord.self,
            DialogueSessionRecord.self, PathProgressRecord.self,
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

`.lightweight` is correct here (verified against `SwiftData.swiftinterface`): V2 only
*adds* new model types, it doesn't change the shape of any existing one, so no
`willMigrate`/`didMigrate` closures are needed. `ModelContainerFactory.swift` changes
its `Schema(...)` construction from `PilotSchemaV1.models` to `PilotSchemaV2.models`
(the migration plan handles the V1→V2 step on existing installs automatically); the
store name `"HebrewAppPilot"` and `cloudKitDatabase: .none` stay unchanged.

**Decision**: the four existing pilot record types are kept exactly as they are,
side by side with the new production ones, in the same evolving schema/store. This
was presented as the recommended approach against a separate-container alternative
and approved. Rationale restated: matches what `PilotSchemaV1`'s own doc comment
says it was scaffolded for, keeps the two demo pilot paths working unmodified
(`PILOT.md` requirement), and avoids doubling the persistence plumbing for no
stated requirement that calls for physical separation.

**Correction from an earlier draft of this spec**: rather than adding methods to the
existing `ContentRepository`/`ProgressRepository` protocols, this uses two new,
separate protocols. Reasoning: `ContentRepository` has an existing conformer
(`PilotContentLoader`) that has nothing to do with production content — adding a
required method to the protocol would force it (and any future test mock) to
implement production-loading too, for no reason. `ProgressRepository` currently has
only one conformer (`SwiftDataProgressRepository`, which this spec extends anyway),
so it happens to carry no immediate risk, but the same "additive, never touch pilot
surface" principle applies for consistency and future-proofing — a class can
conform to multiple protocols, so `SwiftDataProgressRepository` simply gains a
second conformance. `RepositoryProtocols.swift` additions (existing protocols and
`PilotContentLoader` are completely unchanged):

```swift
protocol ProductionContentRepository: Sendable {
    func loadProductionBundle() async throws(ContentLoadError) -> ProductionContentBundle
}

protocol ProductionProgressRepository: Sendable {
    func recordAttempt(_ attempt: Attempt) async throws(PersistenceError)
    func attempts(matching cardKey: CardKey) async throws(PersistenceError) -> [Attempt]

    func skillState(itemID: String, dimension: CompetenceDimension) async throws(PersistenceError) -> SkillState?
    func saveSkillState(_ state: SkillState) async throws(PersistenceError)

    func saveSessionState(_ state: SessionState) async throws(PersistenceError)
    func loadSessionState(id: UUID) async throws(PersistenceError) -> SessionState?
}
```

`ProductionContentLoader` (new type, §6) conforms to `ProductionContentRepository`.
`SwiftDataProgressRepository` gains `ProductionProgressRepository` as a second
conformance (`final class SwiftDataProgressRepository: ProgressRepository,
ProductionProgressRepository`), implementing the new methods following the exact
existing pattern (build a `Record`, `context.insert`/mutate, `try save()`; fetch via
`FetchDescriptor` + `#Predicate`, `PersistenceError.fetchFailed`/`.saveFailed` on
failure). `resetAllProgress()` (existing `ProgressRepository` method, unchanged
signature) is extended to also delete the three new record types — it must keep
deleting *only* progress, never content, which is already the existing contract.

## 6. Production content validator

**Swift** (`HebrewApp/Content/ProductionContentLoader.swift`, implementing the
extended `ContentRepository`): mirrors `PilotContentLoader` exactly for manifest
verification, SHA-256 checks, decoding, and count/uniqueness checks against
`Content/Production/manifest.json` + `lexemes.json`/`sentences.json`/`lessons.json`.
On top of that pattern, new checks specific to the production schema:

- **Reference resolution**: every `Lexeme.exampleSentenceIDs` entry, `Lesson.unitIDs`
  entry, `Lesson.prerequisiteIDs` entry, and `ExerciseBlueprint.promptRefs` entry
  must resolve to a real ID in the bundle. New error case
  `ContentLoadError.unresolvedReference(from:to:)`.
- **Prerequisite graph**: `Lesson.prerequisiteIDs` must form a DAG (no cycles) and
  every lesson must be reachable from some lesson with zero prerequisites — reusing
  the same reachable-from-start / can-reach-terminal graph-closure technique already
  proven in `PilotDialogue` validation, applied to the prerequisite graph instead of
  a dialogue graph. New error cases `ContentLoadError.cyclicPrerequisites(String)`
  and `.unreachableLesson(String)`.
- **Draft/released boundary** (TESTING.md's explicit requirement, never exercised by
  the pilot loader since pilot content is 100% draft): a `.released` item may not
  reference a dependency that is still `.draft` or below. Checked transitively
  (a released `Lesson` can't reference a draft `Lexeme` via `unitIDs`, a released
  `Sentence` can't reference a draft token's `lexemeID`, etc.). New error case
  `ContentLoadError.releasedItemHasDraftDependency(item:dependency:)`.
- **Example-count rule**: once a `Lexeme` is beyond `.draft`, it must have at least 2
  `exampleSentenceIDs` (CONTENT_GUIDE.md "mindestens zwei Beispiele pro fertigem
  Lexem"). New error case
  `ContentLoadError.insufficientExamples(lexemeID:found:required:)`.

**Python** (`Scripts/validate_production.py`, new file, sibling to
`validate_pilot.py`): mirrors the same checks structurally (manifest, hashes,
counts, unique IDs, reference resolution, prerequisite-graph reachability/no-cycles,
draft/released boundary), following `validate_pilot.py`'s exact style (flat
`require(condition, message)` helper, single `validate()` function, `PASS`/`FAIL`
stdout convention, non-zero exit on failure). Not yet wired into
`.github/workflows/ci.yml` — that's a one-line follow-up once this file exists,
noted in §9, not part of this sub-project's must-ship list.

## 7. Test fixtures

Since P2 explicitly excludes real content authoring, a small set of original
`reviewStatus == .draft` fixtures is authored purely to exercise the new
loader/validator/persistence — the same role `Content/Pilot/*.json` plays for P1.
Lives at `Content/Production/` (new repo-root folder, resource-folder-referenced in
`project.yml` exactly like `Content/Pilot`). Target size: small enough to write and
review by hand — a handful of lexemes (~8–10), a couple of sentences per lexeme
group, and 2–3 lessons wired together with real (if trivial) prerequisite
relationships, so the prerequisite-graph and reference-resolution checks have
something non-trivial to actually validate. Explicitly not curriculum content: no
claim of A0/A1 coverage, no claim of linguistic review.

## 8. Testing plan (TDD, RED before GREEN — matching this repo's established practice)

New test files under `HebrewAppTests/`, following the existing `@Suite`/`@Test`
(Swift Testing) convention:

- `ProductionContentTests.swift` — JSON decode shape for each new type (mirrors
  `PilotContentModelTests.swift`).
- `ProductionContentLoaderTests.swift` — bundle loads, counts match manifest, every
  reference resolves, prerequisite graph has no cycles and is fully reachable,
  missing-resource/hash-mismatch/duplicate-ID all throw the right typed error
  (mirrors `PilotContentLoaderTests.swift`), plus new cases specific to this schema:
  a deliberately-broken fixture (unresolved reference / cyclic prerequisite /
  released-item-with-draft-dependency / lexeme with <2 examples) throws the matching
  new error case.
- `SwiftDataProgressRepositoryProductionTests.swift` (or extend the existing
  persistence test file if one exists under this name pattern) — round-trip save/
  fetch for `Attempt`, `SkillState`, `SessionState`; `resetAllProgress()` clears the
  new tables too but leaves bundle content untouched (there is no bundle content to
  touch, but the test should assert the pilot's four existing tables are also still
  correctly clearable, i.e. no regression).
- Migration test: fresh `PilotSchemaV1`-shaped container populated with pilot data,
  then opened with `PilotMigrationPlan` (now including the V2 stage) — assert
  existing pilot data survives unchanged and the new tables exist and are empty.
  This is the first time any migration stage in this codebase is actually exercised;
  `PilotMigrationPlan.stages` has been `[]` since P1.

## 9. Explicit non-goals / deferred to later sub-projects

- FSRS adapter, `Scheduler` protocol, `SessionComposer`, `PrerequisiteEngine` (the
  runtime engine — this spec only defines the graph *data* it will walk),
  `AnswerEvaluator`, `HelpPolicy`/mastery-level *logic* (this spec only defines the
  `SkillState` it will read/write).
- **Correction from an earlier draft of this spec**: a time-injection abstraction
  already exists (`HebrewApp/Domain/Clock.swift`: `DateProviding` protocol +
  `SystemDateProvider`, named `DateProviding` rather than `Clock` to avoid
  colliding with `_Concurrency.Clock`) — this spec was wrong to describe it as not
  yet built. Nothing in this codebase creates a real `Attempt` yet (that's
  LessonEngine's job, a later sub-project), so `DateProviding` isn't wired into an
  attempt-recording call site here either. What *is* in scope: a small, pure
  `localLearningDay(for:in:)`-style Domain function deriving the calendar-day
  string from a `Date` + `TimeZone`, unit-tested including DST-transition and
  timezone-change cases (LEARNING_ENGINE.md requires exactly this), since it's
  cheap, self-contained, and directly de-risks the one open correctness question
  `Attempt.localLearningDay`/`timezoneIdentifier` raises. See the plan for the
  concrete task.
- Wiring `.github/workflows/ci.yml` to run `validate_production.py` — one line to
  add once the script exists, deliberately deferred so this spec's own CI run
  (build + existing test suite) stays the acceptance bar for this sub-project.
- Rewiring any Feature view off the pilot path model.
- `TutorResult`'s exact shape pending a check against `TutorProtocols.swift` (§4) —
  resolve during implementation, before writing that one type.

## 10. Acceptance for this sub-project

- `xcodebuild build` and `xcodebuild test` clean (existing 30 unit + 5 UI tests
  still green, plus every new test above).
- Every new type, error case, and file listed in §3–§8 exists and compiles.
- The migration test (§8) actually exercises `PilotSchemaV1 → PilotSchemaV2` for
  the first time in this codebase and passes.
- `Scripts/validate_production.py` runs standalone against `Content/Production/`
  and passes.
- New DECISIONS.md entries for every "Implementierungsannahme" called out in this
  spec (§3's four bullet points, plus whatever `TutorResult` resolution turns out
  to be).
