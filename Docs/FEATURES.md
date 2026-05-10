# Lull — Feature & Flow Reference

## Overview

Lull is a sleep-coaching iOS app built in SwiftUI. It personalizes a nightly wind-down routine from onboarding answers, guides the user through that routine each night, runs a lightweight experiment engine to find what actually improves their sleep, and logs a morning score each day to close the loop.

---

## Features

### 1. Welcome Screen
A full-screen branded splash — the amber dot and "lull" wordmark fade in, then a "Get started" button appears. First-time users land here; returning users go straight to the Dashboard.

### 2. Onboarding (6 screens + payoff)

Collects everything needed to generate a personalized routine. All screens support a Back button except the first.

| Screen | What it collects |
|--------|-----------------|
| 1 — Sleep Problem | Multi-select: can't fall asleep / brain races / wakes at night / unrefreshed. "All of the above" shortcut. |
| 2 — Your Situation | Multi-select lifestyle factors: new parent, shift work, founder, ADHD, anxiety, physical discomfort, suspected medical issue. |
| 3 — Sleep Window | Single-select: how long the user typically has to fall asleep (< 10 min / 10–20 / 20–30 / 30+ min). Maps to a numeric `sleepWindowMinutes` that controls routine length. |
| 4 — Sleep Schedule | Interactive arc clock — drag moon/sun handles to set typical bedtime and wake time. Live duration display. |
| 5 — Pre-Bed Activities | Multi-select: what the user does the hour before bed (phone, TV, book, socialising, dim lights, shower, exercise, eat, nothing). |
| 6 — What You've Tried | Multi-select: prior sleep interventions (melatonin, meditation, CBT-I, journaling, etc.). Seeds the experiment engine's exclusion list. "Build my routine" CTA on this screen triggers routine generation. |
| 7 — Routine Ready (payoff) | Shows the generated routine as a timed schedule. Brightness check and Temperature check are hidden from this list. Two CTAs: "Start Routine Now" (if bedtime is within an hour) or "Try it tonight". |

**Routine generator logic (RoutineGenerator.swift):**
- Positive pre-bed habits (book, dim lights, shower) are kept as "existing habit" steps (up to 2).
- Harmful habits (screens, late exercise, eating) become "avoid reminder" steps with evidence-based lead times (60–180 min before bed).
- Primary wind-down is chosen by profile: brain races / ADHD / founder → Brain Dump; anxiety → 4-7-8 Breathing; default → Boring Story.
- Secondary wind-down added if the sleep window allows it.
- Total steps trimmed to fit the stated window.
- A plain-English "Gentle Reset" explanation is generated and shown on the payoff screen.

---

### 3. Dashboard (Home tab)

The main screen shown after onboarding completes.

- **Greeting** — time-of-day salutation (hardcoded "Good evening, let's wind down." in the current build).
- **Tonight's routine card** — shows sleep window length, a short contextual reason for tonight's focus (e.g. "Stress signal was high today"), and a **Start routine** CTA that launches the Nightly Flow.
- **What's coming** — ordered list of tonight's scheduled steps with times and mode badges (derived from `AppState.scheduledRoutine`).
- **Hamburger menu** — top-right button opens a small overlay with a **Mid-Sleep Mode** shortcut.

---

### 4. Nightly Flow

The nightly flow is forward-only and intentionally short during the first 5 nights.
Typical Night 1 Sequence (3–4 steps):

Brightness Check (mostly automatic / quick confirmation)
Temperature Log
(Optional) One core Wind Down method — Brain Dump (for racing mind) or 4-7-8 Breathing (for anxiety)
Boring Story (only if the user has a longer sleep window)

The flow is designed to feel achievable even when the user is exhausted. After the first 5 nights, more steps may be added based on experiment results.

---

### 5. My Routine (Routine tab)

My Routine is the command center of the app.

Start Tonight’s Routine button (prominent)
Tonight’s Variable card — shows the active 5-night experiment (if any)
Prep Checklist section — passive reminders that fire earlier in the evening (e.g. Dim the lights 75 min before, Warm shower, No screens, etc.). Experiment steps that are prep-type remedies (anything with a lead time) appear here with an amber "THIS WEEK" badge.
Bedtime Ritual section — the short sequential in-app flow (Brightness Check, Temperature Log, + 0–2 active steps). Experiment steps that are ritual-type remedies (e.g. Weighted blanket — done in bed, no lead time) appear here instead.

This clear separation helps users understand what happens when vs. what they do right before bed.

#### Candidate Picker Sheet
- Opens when the user taps the swap button on the variable card.
- If a test is in progress (> 0 nights), an alert first asks "Change experiment?" with "Keep testing" / "Yes, change it" options.
- Sheet shows all experiment candidates not already in the routine.
- Selecting a candidate replaces the current experiment step immediately.

---

### 6. Sleep Log Detail

Opens as a sheet from the 14-night history dots. Behavior differs by whether the dot is today or a past date.

**Today (unrated):**
- Score circles 1–5 (growing sizes, WRECKED → FANTASTIC).
- Variable Tested label shows tonight's experiment step.
- Notes section: choose **Type** (TextEditor) or **Voice** (records to a temp .m4a file using AVAudioRecorder, stores "Voice note recorded" placeholder on stop).
- **"Log this morning"** CTA (disabled until a score is selected) → saves score + notes, dismisses.
- **"Skip for now"** → dismisses without saving.

**Past date (already rated):**
- Score circles display the saved score (non-interactive).
- Variable Tested label shows what was tested that night.
- Notes shown read-only if they exist.
- **"Done"** → dismisses.

---

### 7. Morning Check-In

Opens as a full-screen cover, triggered by tapping a notification or via `AppState.showMorningCheckIn`.

- Identical score UI to Sleep Log Detail (1–5 circles).
- Experiment insight card — shows the current variable, night count, insight line (e.g. "3 more nights of data before we decide."), and promotion/drop status if the experiment concluded.
- **"Log this morning"** → calls `state.logMorningScore()`, which saves the score, attaches the current variable, then calls `advanceExperiment()` to check if the 5-night test is complete. Dismisses.
- **"Add a note · woke at 4am"** ghost button — present but currently no-op (UI placeholder).

---

### 8. Mid-Sleep Mode

Accessible three ways: Dashboard hamburger menu, a lock-screen notification at 3 hours past bedtime, or by **shaking the phone** (shake dims the screen to 0 brightness immediately and opens the mode; brightness is restored when the sheet is dismissed). Designed for minimal friction when the user wakes at night.

- Clock readout (live, shows actual current time).
- Copy: "You're awake. That's okay."
- Three options:
  - **4·7·8 breath** (featured) → opens a dedicated mid-sleep breathing screen (full-screen cover). Animated orb expands on inhale and shrinks on exhale, timed to the audio. No countdown numbers. Tapping **"End early · I'm calm"** immediately dismisses back to Mid-Sleep Mode (unlike the nightly-flow version which advances to the next step).
  - **Boring story** → opens `MidSleepBoringStoryView`: ~8-min version (2 stories), same TTS controls as the nightly version.
  - **Body scan** → opens `MidSleepBodyScanView`: 8 body areas, 20s per area auto-advancing, manual "Next area →" button, completion screen "Scan complete. Let yourself drift."
- **"Try the get-up protocol →"** link at the bottom — dismisses Mid-Sleep Mode (get-up flow not yet implemented).

---

### 9. Experiment Engine

The experiment engine only begins suggesting new variables after the first 5 nights.

It runs a lightweight one-variable test at a time.
After 5 scored nights, it decides to promote (meaningful improvement) or drop the variable.
New suggestions are chosen using a combination of:
Historical performance (average sleep score improvement)
Onboarding signals (with Screen 4 = 2x weight)
Smart rules (prefer Bedtime Prep early on, avoid repeats)


This creates a true “personal sleep scientist” experience that evolves with the user over weeks and months.

---

### 10. Local Notifications

All notifications are scheduled via `UNUserNotificationCenter` using `UNCalendarNotificationTrigger`. Permission is requested on first launch (`LullApp.init`). Three notification categories are registered: `BEDTIME_REMINDER`, `MORNING_CHECKIN`, `MID_SLEEP_CHECK`.

#### Bedtime Prep Reminders

Scheduled by `AppState.scheduleBedtimePrepNotifications()`. One notification per `reminderOnly` step in `coreRoutine`, firing at `typicalBedtime − leadTimeMins` on a daily repeating schedule.

| Example | Lead time | Fire time (10 PM bed) |
|---------|-----------|----------------------|
| Dim the lights | 75 min | 8:45 PM |
| No screens | 75 min | 8:45 PM |
| Warm shower or bath | 90 min | 8:30 PM |
| No heavy snacks | 120 min | 8:00 PM |
| No caffeine | 360 min | 4:00 PM |

Category: `BEDTIME_REMINDER` with a "Mark done" action. Notifications are re-scheduled whenever the routine changes (`applyGeneratedRoutine`, `changeExperimentVariable`, `advanceExperiment`).

#### Sleep Rating Reminders

Scheduled by `AppState.scheduleMorningRatingNotifications()`. Two daily repeating notifications:

1. **Primary** — fires 30 minutes after `typicalWakeTime`. Title: "How did you sleep?"
2. **Noon fallback** — fires at 12:00 PM every day. Title: "Still time to log your sleep." Only relevant if the user hasn't logged a score yet.

When the user logs a morning score via `logMorningScore()`, the pending noon notification is cancelled and immediately rescheduled (so it resets to tomorrow).

Category: `MORNING_CHECKIN` with a "Log it" foreground action that opens Morning Check-In.

#### Mid-Sleep Check

Scheduled by `AppState.scheduleMidSleepNotification()` as a one-time notification firing 3 hours after `typicalBedtime`. Title: "Still awake?" Category: `MID_SLEEP_CHECK` with an "Open Lull" action that opens Mid-Sleep Mode.

#### Scheduling Lifecycle

- Notifications are scheduled after onboarding completes (`applyGeneratedRoutine`).
- On every app launch, if a saved routine exists, all notifications are rescheduled (in case the OS cleared them).
- Bedtime Prep notifications are rescheduled whenever the `coreRoutine` changes.
- Morning rating notifications are rescheduled whenever a score is logged.

> Legacy test payloads in `Scripts/Notifications/` are kept for manual simulator testing only and are not used by the app at runtime.

---

## How the Initial Routine Is Built

Routine Generator Logic — "Gentle Reset"
The generator is intentionally very conservative for the first 5 nights to maximize completion rate and build trust.
Core Rules for Night 1–5:

Bedtime Prep (background reminders): Max 2 items total (including the universal “Dim the lights”).
Wind Down Ritual (interactive sequential flow): Max 3 steps total, which always includes:
Brightness Check
Temperature Log
At most 1 core wind-down method (Brain Dump or 4-7-8 Breathing)


A core Wind Down method is only added if the user has very few existing habits and strong signals from Screen 1 or 2 (e.g. racing mind, anxiety).
Scoring Logic (still runs):

Every selected onboarding answer adds points to relevant remedies.
Screen 4 answers (current habits) get 2x weight.
“Dim the lights” gets a permanent +3 boost.
Up to 2 existing habits from Screen 4 are kept and boosted.
Remedies are then sorted Easiest → Hardest within each section.

After the first 5 nights, the Improvement Engine gradually introduces more variables through the experiment loop.

### How the schedule is computed

`AppState.scheduledRoutine` is a computed property that converts `coreRoutine` into a sorted list of `ScheduledStep` with clock times:

- **inSequence steps** are packed backwards from the user's typical bedtime, each step offset by its estimated duration (Brain Dump = 2 min, Boring Story = 20 min, 4-7-8 = 5 min, etc.). If the total sequence is shorter than `sleepWindowMinutes`, the whole block is shifted earlier to fill the window.
- **reminderOnly steps** use a fixed lead-time lookup (`AppState.prepLeadTimes`, which delegates to `remedyLeadTimes` in RoutineGenerator.swift) — e.g. "Dim the lights" fires 75 min before bed, "No screens" fires 75 min before bed.
- All steps are then sorted by time ascending. This sorted list is what both the Dashboard "What's coming" list and the My Routine view display.

---

## How the Next Experiment Variable Is Recommended

Lull runs a rolling A/B-style experiment: one variable is tested at a time for 5 scored nights, then either promoted to the core routine or dropped, and the next candidate is automatically queued.

### The candidate pool

Experiment candidates are drawn from two groups:

- **Bedtime Prep remedies** (11 passive-reminder items with scheduled lead times): No alcohol, No caffeine, No screens, App blocking, Finish workouts, No heavy snacks, Dim the lights, Cold room prep, Warm shower or bath, Magnesium glycinate, Herbal tea. When one of these is the active experiment, it appears in the **Prep Checklist** section of My Routine with a scheduled reminder time.
- **Bedtime Ritual experiment candidates** (passive, done in bed, no lead time): currently **Weighted blanket**. When this is the active experiment, it appears in the **Bedtime Ritual** section of My Routine (alongside inSequence steps) — no lead-time badge, no prep notification.

Any candidate already in `coreRoutine` is hard-excluded (−10 score penalty).

### Scoring formula

`ExperimentEngine.suggestNextVariable()` scores every candidate with a weighted formula:

```
totalScore = (historicalScore × 0.7) + (onboardingScore × 0.2) + smartAdjustments
```

**historicalScore** (0–10 scale):
- Looks up past `SleepLogEntry` records where `variable == candidate.label`.
- Computes `expAvg − baseline` (same experiment vs. baseline split used in `evaluate()`).
- Normalizes to 0–10: `min(10, max(0, delta × 2 + 5))` — delta 0 → score 5, delta +2.5 → score 10, delta −2.5 → score 0.
- If the candidate has never been tested: historicalScore = 0 (selection falls back entirely to onboarding match + adjustments).

**onboardingScore** (0–10 scale):
- Uses the raw remedy score accumulated during onboarding scoring (Step 1 of routine generation).
- Normalizes: `min(10, Double(rawScore))`.

**smartAdjustments** (flat additive):

| Condition | Adjustment |
|-----------|-----------|
| Candidate is "Dim the lights" or "Cold room prep" | +3 (evidence-based universal benefit) |
| Candidate already in `coreRoutine` | −10 (hard exclude) |
| Bedtime Prep candidate AND fewer than 15 sleep logs on record | +2 (lower friction — easier to adopt early) |

### How a night is scored

Each morning, the user rates their sleep 1–5. `logMorningScore()` saves that score against the current date and tags it with `tonightVariable` (the label of the active experiment variable). This is the raw data the engine reads.

### Evaluation logic (ExperimentEngine.evaluate)

Runs every time `logMorningScore()` is called. It:

1. Finds the active experiment variable from `tonightVariable` in `AppState`.
2. Splits the full sleep log into two groups:
   - **Experiment nights** — entries where `variable == currentExperimentLabel` and `score > 0`.
   - **Baseline nights** — all other scored entries.
3. Computes:
   - `baseline` = average score on baseline nights (0 if no baseline yet).
   - `expAvg` = average score on the most recent 5 experiment nights.
   - `delta` = `expAvg − baseline`.
4. Applies the decision rule:
   - Fewer than 5 experiment nights → **Keep testing** (no change).
   - 5+ nights, `delta > 0.3` → **Promote** (meaningful positive impact).
   - 5+ nights, `delta ≤ 0.3` → **Drop** (neutral or negative).
5. On any terminal decision (promote or drop), calls `suggestNextVariable()` to pick and queue the next highest-scoring candidate.

### What happens on promote

- The experiment step's `mode` changes from `.experiment` to `.reminderOnly` (it becomes a permanent Bedtime Prep reminder).
- It remains in the Pre-Wind Down section of My Routine with a scheduled time instead of an "EXPERIMENT" badge.
- The next highest-scoring untested candidate becomes the new experiment variable.

### What happens on drop

- The experiment step is removed from `coreRoutine` entirely.
- The next highest-scoring untested candidate becomes the new experiment variable.
- If no scoreable candidates remain (all are in-routine or exhausted), no new experiment is queued and the Tonight's Variable card shows "No experiment running".

### Where the experiment state surfaces in the UI

| Surface | What's shown |
|---------|-------------|
| My Routine — variable card | Active variable, "Night N of 5", score delta so far |
| My Routine — Pre-Wind Down list | Experiment step with an amber "EXPERIMENT" badge |
| Morning Check-In — insight card | Variable name + insight line ("3 more nights of data before we decide." / "Scores up +0.8…" / "No benefit detected…") + promotion/drop announcement |
| Sleep Log Detail — past entry | "VARIABLE TESTED" label shows what was being tested that night |

### Manual override

The user can swap the variable at any time via the ↻ button on the My Routine variable card. If a test is in progress (at least 1 night logged), a confirmation alert warns that switching loses the accumulated data. Confirming opens the Candidate Picker sheet, which lists all Bedtime Prep candidates not already in the routine. Selecting one immediately replaces the experiment variable and resets the night counter.

---

## Flows

### Happy Paths

#### First-time onboarding → routine generated
1. Launch app → splash fades in → tap **Get started**.
2. Work through screens 1–7, making at least one selection on each required screen.
3. Tap **Build my routine** on screen 7 → payoff screen shows timed schedule + explanation.
4. Tap **Try it tonight** (or **Start Routine Now** if bedtime is < 60 min away) → onboarding marked complete, lands on Dashboard.

#### Nightly wind-down
1. From Dashboard or My Routine, tap **Start routine**.
2. Step through each screen in sequence (steps vary by routine).
3. On Brain Dump: tap mic → talk → tap stop → "It's recorded." confirmation → auto-advance after 3s, or tap "Continue →" immediately.
4. On Boring Story: audio begins after 2s, play until done or tap × to skip.
5. On 4-7-8 Breathing: orb pulses through 4 cycles automatically, or tap "End early" to skip.
6. After last step: mid-sleep notification scheduled, flow dismisses.

#### Morning check-in via notification
1. Background the app → push `06-rate-your-sleep.json` (or wait for the real morning notification).
2. Long-press banner → tap **Log it** → Morning Check-In opens.
3. Tap a score circle → tap **Log this morning** → score saved, experiment evaluated, sheet dismisses.

#### Reviewing sleep history
1. Open **My Routine** tab.
2. Tap any past dot → Sleep Log Detail opens read-only (score + variable tested + notes if any).
3. Tap **Done** to close.

#### Changing the experiment variable
1. Open **My Routine** tab → tap ↻ on the Tonight's Variable card.
2. If no nights logged yet → Candidate Picker opens immediately.
3. Select a candidate → variable replaced, night counter resets.

#### Mid-Sleep Mode (woke up at 3am)
1. Unlock phone → **shake the phone** (screen dims to black instantly + Mid-Sleep Mode opens), OR tap lock-screen notification.
2. Tap **4·7·8 breath** → animated orb guides breathing; tap "End early · I'm calm" to return to Mid-Sleep Mode.
3. Or tap **Boring story** → ~8-min audio plays; tap × when ready to try sleeping again.
4. Or tap **Body scan** → advance through 8 areas (20s each) → "Scan complete. Let yourself drift." → tap Close.
5. Dismiss Mid-Sleep Mode → screen brightness restores to previous level.

---

### Non-Happy Paths / Edge Cases

#### Onboarding — skipped selections
- Screens 1, 2, 5, 6: **Continue** is disabled until at least one option is selected. No way to advance without a choice.
- Screen 3 (window): has a default pre-selected, so Continue is always enabled.
- Screen 4 (clock): always enabled; bedtime defaults to 11pm yesterday, wake to 7am today.
- Screen 7 (environment): two CTAs — **Build my routine** (required path) and **Ask me again at bedtime** (ghost button, currently no-op).

#### Onboarding — "Ask me again at bedtime"
- Ghost button on screen 7 is wired but currently does nothing (empty closure). The user stays on screen 7.

#### Brain Dump — microphone permission denied
- If the user has denied mic access, the step shows a `MicPermissionDeniedView` with a mic-slash icon and an **Open Settings** button that deep-links to `UIApplication.openSettingsURLString`.
- The Pause/Resume and "I'm done" buttons are hidden in this state.
- The user cannot advance the flow without granting permission or dismissing the entire nightly flow.

#### Boring Story — TTS unavailable or empty
- `BundledStories.all` is always non-empty (bundled at compile time), so story content should always be available.
- No explicit error state for TTS failure; audio simply won't play, but the timer still ticks and the user can tap × to advance.

#### Morning Check-In — no score selected
- **"Log this morning"** CTA is disabled (0.45 opacity) until a score circle is tapped. The user can still tap **"Skip for now"** (Sleep Log Detail) or close the full-screen check-in without logging.

#### Sleep Log Detail — today's dot, no prior score
- Score is initialized to 0 (no selection shown). The "Log this morning" CTA stays disabled until a score is chosen.
- Tapping **Skip for now** dismisses without persisting anything.

#### My Routine — no experiment running
- If `coreRoutine` has no `.experiment` step, `ExperimentEngine.evaluate` returns `nil`.
- `tonightVariable` displays "No experiment running", `variableNight` = 0, `variableScore` = "—".
- The ↻ button still opens the Candidate Picker (no in-progress alert since night count is 0).

#### My Routine — changing a variable mid-experiment
- If `variableNight > 0`, tapping ↻ shows a confirmation alert: "You've only tested X for N nights. Switching now means losing that data."
- "Keep testing" dismisses; "Yes, change it" opens the Candidate Picker.

#### Experiment conclusion — promote
- After 5 scored nights with delta > 0.3: the experiment step's `mode` changes from `.experiment` to `.inSequence` (for ritual-type) or `.reminderOnly` (for prep-type). It stays in whichever section (Prep Checklist or Bedtime Ritual) it was already displayed in, but the "THIS WEEK" badge is replaced by a permanent scheduled time. The next candidate from the pool becomes the new experiment step.

#### Experiment conclusion — drop
- After 5 scored nights with delta ≤ 0.3: the experiment step is removed from `coreRoutine`. The next candidate is queued. If the pool is exhausted, no new experiment step is added and the Tonight's Variable card shows "No experiment running".

#### Mid-Sleep Mode — "4·7·8 breath" option
- Opens `NightlyBreathingView` in a full-screen cover with `isMidSleep: true`. Tapping "End early · I'm calm" calls `dismiss()` to return to Mid-Sleep Mode. When the audio finishes naturally it also dismisses (does not advance `nightlyStep`, which would be incorrect outside of the nightly flow).

#### Mid-Sleep Mode — shake trigger
- Shake is detected via `ShakeViewController` (a `UIViewControllerRepresentable` in the `HomeTabView` background). A 3-second throttle prevents a single physical shake from firing twice. Guard: if mid-sleep is already open, the shake is ignored.
- `AppState.activateMidSleepFromShake()` saves current `UIScreen.main.brightness`, sets it to `0.0`, then sets `showMidSleepMode = true`. `restoreBrightnessAfterMidSleep()` is called `onDismiss` of the sheet to restore the saved level.
- The shake path bypasses the notification system entirely — no notification is generated or shown.

#### Mid-Sleep Mode — "Try the get-up protocol →"
- Tapping dismisses Mid-Sleep Mode (`state.showMidSleepMode = false`). The get-up protocol screen (`GetUpPromptView`) exists as a file but is not yet wired into navigation.

#### Body Scan — auto-advance timer
- Each area auto-advances after 20s if the user doesn't tap "Next area →". On the last area, the timer fires `advance()` which increments `currentStep` past the array bounds, showing the completion screen. The timer is invalidated at that point.

#### Voice note recording — AVAudioSession error
- `try?` is used for both `setCategory` and `AVAudioRecorder` init, so errors are silently swallowed. If recording fails to start, `isRecording` is still set to `true` and the "Recording…" label shows. Stopping will set `draftNotes` to "Voice note recorded" regardless of whether audio was actually captured.

#### Returning user — onboarding already complete
- `@AppStorage("hasCompletedOnboarding")` persists across launches. `ContentView` routes directly to `HomeTabView` (Dashboard + My Routine tabs), skipping the splash and onboarding entirely.

#### Sleep log data — no "today" entry
- `logMorningScore()` checks for an existing today entry by date; if none exists (edge case where the placeholder array didn't include today), it appends a new `SleepLogEntry`. The 14-dot display shows however many entries exist, up to 14.
