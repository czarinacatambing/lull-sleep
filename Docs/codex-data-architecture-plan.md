# Production Data Architecture Plan

This plan assumes that prototype/demo values in the current app should either become real product data, derived runtime state, static product catalog data, or explicit demo-only fixtures.

## Guiding Principle

The production app should remember what it recommended, what the user actually did, what happened overnight, how the user rated the next morning, and how that evidence changes the next recommendation.

The current code often uses display strings as identity. Production data should use stable IDs for remedies, routines, experiments, and sessions, then derive display copy from those IDs.

## Data Categories

### Real Production Data

This data belongs to the user and should persist across launches.

- User profile and onboarding completion state
- Baseline sleep preferences from onboarding
- Onboarding answers
- Active routine and routine history
- Nightly routine sessions
- Step completion and skip events
- Room temperature feeling and brightness observations
- Mid-sleep mode usage
- Morning sleep ratings
- Text notes and voice-note metadata
- Active and historical experiments
- Per-remedy scores and score snapshots

### Static Product Catalog

This data defines how the app works. It can initially live in Swift code or bundled JSON.

- Remedy definitions
- Remedy categories
- Default lead times
- Default estimated durations
- Whether a remedy is interactive
- Whether a remedy is experiment-eligible
- Onboarding answer to remedy scoring mappings
- Difficulty ranking for wind-down methods
- Explanation templates

Static catalog data is allowed to be hardcoded when it represents product rules rather than user-specific runtime data.

### Demo-Only Fixtures

This data should not appear in production startup unless the app is deliberately running in demo mode.

- Placeholder sleep logs
- Fake brightness values
- Hardcoded showcase dates and times
- Canned routine history
- Example sleep scores

## Proposed Core Models

### Remedy

Remedies should be first-class product concepts. The app should not use labels like `"Magnesium glycinate"` as database identity.

```swift
enum RemedyID: String, Codable {
    case dimTheLights
    case noScreens
    case appBlocking
    case finishWorkouts
    case noHeavySnacks
    case noAlcohol
    case noCaffeine
    case coldRoomPrep
    case warmShower
    case magnesium
    case herbalTea
    case weightedBlanket
    case brainDump
    case boringStory
    case breathing478
    case gratitudeJournal
    case gentleStretching
    case progressiveMuscleRelaxation
    case readingBook
}
```

Recommended fields:

- `id`
- `displayName`
- `category`
- `defaultLeadTimeMinutes`
- `defaultEstimatedDurationMinutes`
- `isInteractive`
- `isExperimentEligible`
- `difficultyRank`

### UserProfile

Stores durable user-level state.

- `id`
- `hasCompletedOnboarding`
- `createdAt`
- `updatedAt`

### UserSleepBaseline

Stores baseline preferences or typical sleep context from onboarding. These should not be confused with nightly observations.

- `typicalBedtime`
- `typicalWakeTime`
- `sleepWindowMinutes`
- `preferredBedroomTempF`
- `preferredLightsLevel`

### OnboardingResponse

Stores the user's selected onboarding answers.

- `selectedSleepProblems`
- `selectedWakes`
- `selectedPreBedActivities`
- `selectedTriedThings`
- `capturedAt`

### RemedyScoreSnapshot

Stores the result of scoring remedies at a point in time.

- `id`
- `createdAt`
- `source`
- `remedyId`
- `score`
- `reasons`

This lets the app explain why a routine was generated and avoids recalculating past decisions with newer rules.

### Routine

Stores a generated or active routine.

- `id`
- `isActive`
- `explanation`
- `shouldStartImmediately`
- `createdAt`
- `archivedAt`

### RoutineStep

Stores one step inside a routine.

- `id`
- `routineId`
- `remedyId`
- `displayLabelSnapshot`
- `mode`
- `order`
- `leadTimeMinutes`
- `estimatedDurationMinutes`

`mode` should remain explicit:

- `reminderOnly`: scheduled reminder, not an interactive wind-down screen
- `inSequence`: part of the active wind-down flow
- `experiment`: the current variable being tested

### NightlySession

Stores what happened during one night's routine.

- `id`
- `date`
- `routineId`
- `startedAt`
- `endedAt`
- `completionStatus`
- `brightnessLevel`
- `brightnessTarget`
- `roomTempFeeling`
- `midSleepModeStarted`
- `midSleepModeStartedAt`

### RoutineStepAttempt

Stores whether each step was actually done.

- `id`
- `nightlySessionId`
- `routineStepId`
- `remedyId`
- `status`
- `startedAt`
- `completedAt`
- `skippedAt`
- `durationSeconds`

Recommended statuses:

- `notStarted`
- `started`
- `completed`
- `skipped`

### MidSleepSession

Stores use of mid-sleep mode separately from the main wind-down flow.

- `id`
- `nightlySessionId`
- `startedAt`
- `endedAt`
- `selectedIntervention`
- `completed`

### MorningCheckIn

Stores the user's next-morning outcome.

- `id`
- `sleepDate`
- `score`
- `createdAt`
- `noteText`
- `hasVoiceNote`
- `voiceNoteLocalPath`

Voice-note content should remain local unless a future privacy design explicitly says otherwise.

### Experiment

Stores the lifecycle of a tested remedy.

- `id`
- `remedyId`
- `status`
- `startedAt`
- `endedAt`
- `onboardingScoreAtStart`
- `baselineAverageAtStart`
- `finalScoreDelta`

Recommended statuses:

- `active`
- `promoted`
- `dropped`

### ExperimentNight

Connects one experiment to one night of actual usage and morning outcome.

- `id`
- `experimentId`
- `nightlySessionId`
- `remedyId`
- `wasRecommended`
- `wasActuallyCompleted`
- `morningScore`

This lets the app distinguish a remedy being scheduled from a remedy actually being tried.

## Current Logic To Preserve

The existing initial routine generation should be preserved, but moved toward stable IDs.

Current behavior:

- Onboarding answers map to remedy scores.
- Screen 1 and 2 selections add 1 point to mapped remedies.
- Pre-bed activity selections add 2 points to mapped remedies.
- `Dim the lights` receives an additional boost.
- Existing positive habits can receive a kept-habit bonus.
- Initial bedtime prep includes `Dim the lights` and at most one additional prep remedy.
- Initial wind-down includes brightness check, temperature check, kept habits, or one new wind-down method.

The existing next-variable logic should also be preserved, but persisted more explicitly.

Current formula:

```text
totalScore = historicalScore * 0.7
           + onboardingScore * 0.2
           + smartAdjustments
```

Production persistence should store the score snapshot and the actual experiment exposure so the app knows whether a remedy was recommended, started, completed, skipped, rated, promoted, or dropped.

## Implementation Phases

### Phase 1: Stabilize Identity

- Add `RemedyID`.
- Create a remedy catalog.
- Convert routine and experiment logic away from display-string identity.
- Keep display labels as presentation data or label snapshots.

### Phase 2: Add Local Persistence

- Create an `AppDataStore`.
- Persist real product data.
- Remove placeholder sleep logs from production startup.
- Keep demo data behind an explicit demo mode or fixture loader.

### Phase 3: Record Nightly Evidence

- Add `NightlySession`.
- Add `RoutineStepAttempt`.
- Record completed and skipped steps.
- Record temperature feeling and brightness observations.
- Record mid-sleep mode usage.

### Phase 4: Separate Morning Outcomes

- Replace the current all-purpose `SleepLogEntry` with `MorningCheckIn` plus linked nightly session data.
- Persist text notes and voice-note metadata.
- Ensure sleep score scale remains consistent at 1-5.

### Phase 5: Persist Experiment History

- Add `Experiment`.
- Add `ExperimentNight`.
- Store per-remedy score snapshots.
- Use actual completion data when evaluating whether a remedy worked.

### Phase 6: Choose Storage Backend

Start with a storage abstraction so the app is not tightly coupled to one backend.

Reasonable first backend:

- JSON or plist snapshots for fast iteration

Reasonable production backend:

- SwiftData or Core Data once entities and relationships are stable

The important part is to avoid baking the current string-based prototype model into the database.

## Recommended Next Step

Do not begin by designing tables around the current `AppState` exactly as-is. First, introduce stable remedy identity and separate runtime UI state from durable product data.

Recommended first implementation sequence:

1. Add `RemedyID` and a remedy catalog.
2. Update `RoutineStep` to store `remedyId` plus a display label snapshot.
3. Add `Codable` conformance for durable models.
4. Add `AppDataStore`.
5. Load empty real sleep history in production instead of placeholder logs.
6. Add nightly session and step attempt tracking.

