Plan: Score-Based Routine Generation & Smart Next-Variable Suggestion                                                 
                                                                                                                       
 Context                                                                                                               
                                                                                                                       
 The current RoutineGenerator.swift uses hard-coded if/else profile rules (brain races → Brain Dump, anxiety → 4-7-8,
 etc.) with no actual scoring. The current ExperimentEngine.swift picks the next variable from a flat ordered
 candidate pool. Neither references the CSV remedy mapping.

 The goal is to replace both with the spec in Docs/scoring-initial-routine.md, using
 Docs/sleep-remedies-onboarding.csv as the source of truth for which remedies each onboarding answer maps to.

 ---
 Part 1 — Initial Routine Generation

 Scoring algorithm

 1. Build a [String: Int] remedy score dictionary.
 2. For each selected Screen 1 answer (sleepProblems): add +1 to every mapped remedy.
 3. For each selected Screen 2 answer (wakingFactors): add +1 to every mapped remedy.
 4. For each selected Screen 5 answer (preBedActivities, treated as 2x "Screen 4"): add +2 to every mapped remedy.
 5. Always add +3 to "Dim the lights" (permanent boost, regardless of selections).
 6. Identify up to 2 "kept habits" from preBedActivities with positive sleep value (shower, dim lights, physical
 book). Add +2 to each kept habit's remedy.

 Remedy → onboarding mapping (from CSV)

 Encode as a static [AnswerKey: [String]] dictionary in the generator. AnswerKey is a struct with (screen: Int, index:
  Int).

 ┌────────┬───────┬───────────────────┬───────────────────────────────────────────────────────────────────────────┐
 │ Screen │ Index │    Option text    │                              Mapped remedies                              │
 ├────────┼───────┼───────────────────┼───────────────────────────────────────────────────────────────────────────┤
 │ 1      │ 0     │ Struggle to fall  │ Dim the lights, No screens, Warm shower, 4-7-8 Breathing, Brain Dump,     │
 │        │       │ asleep            │ Boring Story                                                              │
 ├────────┼───────┼───────────────────┼───────────────────────────────────────────────────────────────────────────┤
 │ 1      │ 1     │ Brain races       │ Dim the lights, No screens, Gratitude Journal, Brain Dump, 4-7-8          │
 │        │       │                   │ Breathing, Progressive Muscle Relaxation, Boring Story                    │
 ├────────┼───────┼───────────────────┼───────────────────────────────────────────────────────────────────────────┤
 │ 1      │ 2     │ Wakes at night    │ Cold room prep, Herbal tea, Weighted blanket, 4-7-8 Breathing, Brain Dump │
 ├────────┼───────┼───────────────────┼───────────────────────────────────────────────────────────────────────────┤
 │ 1      │ 3     │ Wakes unrefreshed │ Cold room prep, Warm shower, Magnesium glycinate, Weighted blanket        │
 ├────────┼───────┼───────────────────┼───────────────────────────────────────────────────────────────────────────┤
 │ 2      │ 0     │ New parent        │ Dim the lights, Herbal tea, Gentle stretching, Warm shower, Brain Dump,   │
 │        │       │                   │ 4-7-8 Breathing                                                           │
 ├────────┼───────┼───────────────────┼───────────────────────────────────────────────────────────────────────────┤
 │ 2      │ 1     │ Shift work        │ Cold room prep, Dim the lights, No caffeine, Magnesium glycinate, Boring  │
 │        │       │                   │ Story                                                                     │
 ├────────┼───────┼───────────────────┼───────────────────────────────────────────────────────────────────────────┤
 │ 2      │ 2     │ Founder /         │ Dim the lights, No screens, Brain Dump, 4-7-8 Breathing, Progressive      │
 │        │       │ high-stress       │ Muscle Relaxation                                                         │
 ├────────┼───────┼───────────────────┼───────────────────────────────────────────────────────────────────────────┤
 │ 2      │ 3     │ ADHD / racing     │ Dim the lights, No screens, Brain Dump, 4-7-8 Breathing, Progressive      │
 │        │       │ mind              │ Muscle Relaxation, Boring Story                                           │
 ├────────┼───────┼───────────────────┼───────────────────────────────────────────────────────────────────────────┤
 │ 2      │ 4     │ Anxiety           │ Dim the lights, Herbal tea, 4-7-8 Breathing, Brain Dump, Progressive      │
 │        │       │                   │ Muscle Relaxation                                                         │
 ├────────┼───────┼───────────────────┼───────────────────────────────────────────────────────────────────────────┤
 │ 2      │ 5     │ Physical          │ Cold room prep, Warm shower, Gentle stretching, Progressive Muscle        │
 │        │       │ discomfort        │ Relaxation, Weighted blanket                                              │
 ├────────┼───────┼───────────────────┼───────────────────────────────────────────────────────────────────────────┤
 │ 5      │ 0     │ Phone / scroll    │ Dim the lights, No screens, Brain Dump, App blocking                      │
 ├────────┼───────┼───────────────────┼───────────────────────────────────────────────────────────────────────────┤
 │ 5      │ 1     │ Watch TV /        │ Dim the lights, No screens, Reading physical book, Boring Story, App      │
 │        │       │ screens           │ blocking                                                                  │
 ├────────┼───────┼───────────────────┼───────────────────────────────────────────────────────────────────────────┤
 │ 5      │ 2     │ Read physical     │ Reading physical book (keep — positive habit)                             │
 │        │       │ book              │                                                                           │
 ├────────┼───────┼───────────────────┼───────────────────────────────────────────────────────────────────────────┤
 │ 5      │ 3     │ Talk / socialize  │ (no mapping — skip)                                                       │
 ├────────┼───────┼───────────────────┼───────────────────────────────────────────────────────────────────────────┤
 │ 5      │ 4     │ Dim the lights    │ Dim the lights (keep — positive habit)                                    │
 ├────────┼───────┼───────────────────┼───────────────────────────────────────────────────────────────────────────┤
 │ 5      │ 5     │ Shower or bath    │ Warm shower (keep — positive habit)                                       │
 ├────────┼───────┼───────────────────┼───────────────────────────────────────────────────────────────────────────┤
 │ 5      │ 6     │ Evening exercise  │ Finish workouts                                                           │
 ├────────┼───────┼───────────────────┼───────────────────────────────────────────────────────────────────────────┤
 │ 5      │ 7     │ Eat / snack       │ No heavy snacks, Herbal tea                                               │
 ├────────┼───────┼───────────────────┼───────────────────────────────────────────────────────────────────────────┤
 │ 5      │ 8     │ Nothing specific  │ Dim the lights, Brain Dump, 4-7-8 Breathing, Boring Story                 │
 └────────┴───────┴───────────────────┴───────────────────────────────────────────────────────────────────────────┘

 Remedy categories

 Bedtime Prep (reminderOnly — passive, fire earlier in evening)

 ┌─────────────────────┬──────────────────────┐
 │    Remedy label     │ Lead time before bed │
 ├─────────────────────┼──────────────────────┤
 │ No alcohol          │ 180 min              │
 ├─────────────────────┼──────────────────────┤
 │ No caffeine         │ 360 min              │
 ├─────────────────────┼──────────────────────┤
 │ No screens          │ 75 min               │
 ├─────────────────────┼──────────────────────┤
 │ App blocking        │ 75 min               │
 ├─────────────────────┼──────────────────────┤
 │ Finish workouts     │ 180 min              │
 ├─────────────────────┼──────────────────────┤
 │ No heavy snacks     │ 120 min              │
 ├─────────────────────┼──────────────────────┤
 │ Dim the lights      │ 75 min               │
 ├─────────────────────┼──────────────────────┤
 │ Cold room prep      │ 90 min               │
 ├─────────────────────┼──────────────────────┤
 │ Warm shower or bath │ 90 min               │
 ├─────────────────────┼──────────────────────┤
 │ Magnesium glycinate │ 45 min               │
 ├─────────────────────┼──────────────────────┤
 │ Herbal tea          │ 45 min               │
 ├─────────────────────┼──────────────────────┤
 │ Weighted blanket    │ 30 min               │
 └─────────────────────┴──────────────────────┘

 Wind Down (inSequence — interactive, at bedtime, max 4 steps after the two mandatory ones)

 Fixed first two (always included regardless of profile):
 1. Brightness Check
 2. Temperature Log

 Scored candidates (top scorers fill remaining slots, easiest → hardest):

 ┌───────────────────────────────┬────────────────────────────────────┬──────────────┬─────────────────┐
 │         Remedy label          │          NightlyStepKind           │ Est. minutes │ Difficulty rank │
 ├───────────────────────────────┼────────────────────────────────────┼──────────────┼─────────────────┤
 │ Boring Story                  │ .boringStory                       │ 20           │ 1 (easiest)     │
 ├───────────────────────────────┼────────────────────────────────────┼──────────────┼─────────────────┤
 │ Reading physical book         │ .existingHabit                     │ 20           │ 2               │
 ├───────────────────────────────┼────────────────────────────────────┼──────────────┼─────────────────┤
 │ Gratitude Journal             │ .gratitudeJournal (new)            │ 3            │ 3               │
 ├───────────────────────────────┼────────────────────────────────────┼──────────────┼─────────────────┤
 │ Brain Dump                    │ .brainDump                         │ 2            │ 4               │
 ├───────────────────────────────┼────────────────────────────────────┼──────────────┼─────────────────┤
 │ Gentle stretching             │ .gentleStretching (new)            │ 5            │ 5               │
 ├───────────────────────────────┼────────────────────────────────────┼──────────────┼─────────────────┤
 │ 4-7-8 Breathing               │ .fourSevenEightBreathing           │ 5            │ 6               │
 ├───────────────────────────────┼────────────────────────────────────┼──────────────┼─────────────────┤
 │ Progressive Muscle Relaxation │ .progressiveMuscleRelaxation (new) │ 5            │ 7 (hardest)     │
 └───────────────────────────────┴────────────────────────────────────┴──────────────┴─────────────────┘

 ▎ Wind Down max 4 steps total (including the 2 mandatory). So only 2 scored candidates are added after Brightness
 ▎ Check + Temperature Log.

 Easiest → hardest sorting

 Use the difficulty rank table above. Lower rank = shown first within the Wind Down section.

 Explanation string

 Same approach as current: one sentence per kept habit, one per added wind-down step, one per bedtime prep reminder —
 tied to the reason that earned the score.

 ---
 Part 2 — Next Variable Suggestion

 Replaces the flat candidatePool in ExperimentEngine.swift.

 Candidate set

 All Wind Down remedies + all Bedtime Prep remedies not already in coreRoutine, deduplicated.

 Scoring formula for each candidate

 totalScore = (historicalScore × 0.7) + (onboardingScore × 0.2) + smartAdjustments

 historicalScore (0–10 scale):
 - Look up past SleepLogEntry records where variable == candidate.label.
 - Compute expAvg − baseline (same as current ExperimentEngine logic).
 - Normalize to 0–10: min(10, max(0, delta * 2 + 5)) — so delta 0 = 5, delta +2.5 = 10, delta -2.5 = 0.
 - If no history: historicalScore = 0 (falls back entirely to onboarding match).

 onboardingScore (0–10 scale):
 - Use the raw remedy score from Part 1 scoring (accumulated +1/+2 points from onboarding answers).
 - Normalize to 0–10: min(10, rawScore).

 smartAdjustments (flat additive points):
 - +3 if remedy is "Dim the lights" or "Cold room prep" (evidence-based universal boost).
 - −10 if remedy is already in coreRoutine or is currently being tested (hard exclude).
 - +2 if remedy is a Bedtime Prep type AND sleepLogs.count < 15 (easier to adopt early on, lower friction).

 Result

 Pick the candidate with the highest totalScore. Surface in the UI identically to current (variable card in My
 Routine, insight card in Morning Check-In).

 ---
 New Screens Required

 Three new NightlyStepKind cases + three new SwiftUI views (static for now):

 1. NightlyGratitudeJournalView

 - Short prompt: "Three things that went okay today."
 - Text input or voice (reuse pattern from Brain Dump but shorter — 1 min timer).
 - "Done" → advance.

 2. NightlyGentleStretchingView

 - Static screen: show 2–3 stretch cues (legs up the wall, neck rolls, seated forward fold).
 - 5-minute countdown timer.
 - "Done" or "Skip" → advance.
 - Placeholder for animation — static illustration text for now.

 3. NightlyProgressiveMuscleRelaxationView

 - Step through 5 muscle groups (feet → calves → thighs → torso → shoulders/face).
 - 20s per group (same pattern as MidSleepBodyScanView which already exists).
 - Reuse the body scan countdown timer logic.
 - Placeholder for animation — static text for now.

 ---
 Files to Modify

 ┌────────────────────────────────────┬────────────────────────────────────────────────────────────────────────────┐
 │                File                │                                   Change                                   │
 ├────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────┤
 │ Lull/Models/RoutineGenerator.swift │ Full rewrite: remedy mapping table, scoring function, Bedtime Prep / Wind  │
 │                                    │ Down split, easiest→hardest sort, updated explanation builder              │
 ├────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────┤
 │ Lull/Models/ExperimentEngine.swift │ Replace flat candidatePool + evaluate() with weighted scoring              │
 │                                    │ suggestNextVariable()                                                      │
 ├────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────┤
 │ Lull/Nightly/NightlyFlowView.swift │ Add 3 new NightlyStepKind cases to the switch                              │
 ├────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────┤
 │ Lull/Models/AppState.swift         │ Add new remedy labels to prepLeadTimes; add new NightlyStepKind cases to   │
 │                                    │ nightlyFlowSteps filter                                                    │
 └────────────────────────────────────┴────────────────────────────────────────────────────────────────────────────┘

 Files to Create

 ┌───────────────────────────────────────────────────────────┬─────────────────────────────────────────────────────┐
 │                           File                            │                      Contents                       │
 ├───────────────────────────────────────────────────────────┼─────────────────────────────────────────────────────┤
 │ Lull/Nightly/NightlyGratitudeJournalView.swift            │ New Wind Down step                                  │
 ├───────────────────────────────────────────────────────────┼─────────────────────────────────────────────────────┤
 │ Lull/Nightly/NightlyGentleStretchingView.swift            │ New Wind Down step                                  │
 ├───────────────────────────────────────────────────────────┼─────────────────────────────────────────────────────┤
 │ Lull/Nightly/NightlyProgressiveMuscleRelaxationView.swift │ New Wind Down step (reuses body scan timer pattern  │
 │                                                           │ from MidSleepBodyScanView)                          │
 └───────────────────────────────────────────────────────────┴─────────────────────────────────────────────────────┘

 ---
 Key Assumptions

 - "Screen 4" in the spec/CSV = Screen 5 in code (preBedActivities) — the pre-bed habits screen. The arc clock screen
 has no multi-select answers so it's excluded from scoring.
 - "Talk or socialize" (preBedActivities index 3) has no CSV mapping — it gets 0 remedy points, no avoidReminder.
 - "Reading physical book" uses existingHabit(label: "Reading (physical book)") — the existing generic step screen is
 sufficient, no dedicated screen needed.
 - Wind Down cap of 4 total steps means: Brightness Check + Temperature Log (fixed) + 2 highest-scoring candidates.
 - New user with no sleep log history: historicalScore = 0, suggestion driven by onboarding match + smart adjustments
 only.
 - Smart adjustments are additive flat points, not a percentage weight.

 ---
 Verification

 1. Run through onboarding with 2–3 distinct profiles (anxious/founder, new parent, shift worker) and confirm the
 generated routine matches expected remedy rankings.
 2. Check the Routine Ready payoff screen shows correct Bedtime Prep and Wind Down steps with correct scheduled times.

 - "Screen 4" in the spec/CSV = Screen 5 in code (preBedActivities) — the pre-bed habits screen. The arc clock screen
 has no multi-select answers so it's excluded from scoring.
 - "Talk or socialize" (preBedActivities index 3) has no CSV mapping — it gets 0 remedy points, no avoidReminder.
 - "Reading physical book" uses existingHabit(label: "Reading (physical book)") — the existing generic step screen is
 sufficient, no dedicated screen needed.
 - Wind Down cap of 4 total steps means: Brightness Check + Temperature Log (fixed) + 2 highest-scoring candidates.
 - New user with no sleep log history: historicalScore = 0, suggestion driven by onboarding match + smart adjustments
 only.
 - Smart adjustments are additive flat points, not a percentage weight.

 ---
 Verification

 1. Run through onboarding with 2–3 distinct profiles (anxious/founder, new parent, shift worker) and confirm the
 generated routine matches expected remedy rankings.
 2. Check the Routine Ready payoff screen shows correct Bedtime Prep and Wind Down steps with correct scheduled times.
 3. Log 5 morning scores for a test variable; confirm suggestNextVariable() returns the next highest-scoring
 candidate.
 4. Confirm new Wind Down screens (PMR, stretching, gratitude) appear correctly in the nightly flow when included in a
  generated routine.
 5. Confirm MorningCheckInView and MyRoutineView variable card still display correctly with the new engine output.