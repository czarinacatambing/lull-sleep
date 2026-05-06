# Lull — Feature & Flow Reference

## Overview

Lull is a sleep-coaching iOS app built in SwiftUI. It personalizes a nightly wind-down routine from onboarding answers, guides the user through that routine each night, runs a lightweight experiment engine to find what actually improves their sleep, and logs a morning score each day to close the loop.

---

## Features

### 1. Welcome Screen
A full-screen branded splash — the amber dot and "lull" wordmark fade in, then a "Get started" button appears. First-time users land here; returning users go straight to the Dashboard.

### 2. Onboarding (7 screens + payoff)

Collects everything needed to generate a personalized routine. All screens support a Back button except the first.

| Screen | What it collects |
|--------|-----------------|
| 1 — Sleep Problem | Multi-select: can't fall asleep / brain races / wakes at night / unrefreshed. "All of the above" shortcut. |
| 2 — Your Situation | Multi-select lifestyle factors: new parent, shift work, founder, ADHD, anxiety, physical discomfort, suspected medical issue. |
| 3 — Sleep Window | Single-select: how long the user typically has to fall asleep (< 10 min / 10–20 / 20–30 / 30+ min). Maps to a numeric `sleepWindowMinutes` that controls routine length. |
| 4 — Sleep Schedule | Interactive arc clock — drag moon/sun handles to set typical bedtime and wake time. Live duration display. |
| 5 — Pre-Bed Activities | Multi-select: what the user does the hour before bed (phone, TV, book, socialising, dim lights, shower, exercise, eat, nothing). |
| 6 — What You've Tried | Multi-select: prior sleep interventions (melatonin, meditation, CBT-I, journaling, etc.). Seeds the experiment engine's exclusion list. |
| 7 — Environment Check | Bedroom temperature (60–75°F, custom drag slider) + current light level (4 swatches: Bright → Mostly dark). |
| 8 — Routine Ready (payoff) | Shows the generated routine as a timed schedule. Widget nudge ("Add the lock-screen widget"). Two CTAs: "Start Routine Now" (if bedtime is within an hour) or "Try it tonight" / "Customize first". |

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

A forward-only full-screen walkthrough. Step count and step types are dynamically determined from the user's `coreRoutine` (set during onboarding or as the experiment engine runs). Steps auto-advance; there is no back button.

#### Step: Brightness Check
- Displays a hardcoded simulated brightness reading (78% now, 35% target).
- Radial glow visualizer + arc progress indicator.
- **"I've dimmed them"** → advance. **"Skip · keep them bright"** → also advance.

#### Step: Temperature Log
- 4-option selector: Cool / Just right / Warm / Hot.
- Selected option stored in `AppState.selectedTemp`.
- **"Continue"** → advance (always enabled; a selection is pre-set).

#### Step: Lights Off *(defined but not currently wired into the dynamic step list)*
- Full-screen moon icon, instruction to turn off lights.
- **"Lights are off"** or **"Skip · leave them on"** → advance.

#### Step: Brain Dump (voice recorder)
- Mic permission checked on appear.
- **Tap mic** to start recording; mic button shows a live pulse animation.
- **Pause/Resume** button while recording.
- **"I'm done"** or tapping the stop icon → stops recording, shows "It's recorded." confirmation for 3 seconds, then auto-advances.
- **"Continue →"** button after confirmation also advances immediately.

#### Step: Boring Story (TTS)
- 2-second delay before audio starts.
- 4 bundled stories chained (from `BundledStories`) to fill ~20 min.
- Elapsed time display + progress bar (0–20:00).
- **Pause/play** and **dismiss (×)** controls.
- Closing or finishing the step advances the flow.

#### Step: 4-7-8 Breathing
- 4 full cycles (inhale 4s → hold 7s → exhale 8s) with an animated pulsing orb.
- Countdown timer visible inside the orb.
- Phase chips at the bottom highlight the active phase.
- Completes automatically after 4 cycles; **"End early · I'm calm"** skips to the next step at any time.

#### Step: Existing Habit (generic)
- Displays a custom label from the user's routine.
- **"Done"** or **"Skip"** → advance.

#### Flow completion
- After the last step, `scheduleMidSleepNotification()` fires (schedules a "Still awake?" notification 3 hours after the user's typical bedtime), `nightlyStep` resets to 0, and the sheet dismisses.

---

### 5. My Routine (Routine tab)

A persistent view of the user's current routine and experiment state.

- **Start Tonight's Routine** button — launches the Nightly Flow (same as Dashboard CTA).
- **Tonight's Variable card** — shows the active experiment step, night count (e.g. "Night 3 of 5"), and score delta so far. Swap button (↻) to change the variable.
- **Pre-Wind Down section** — `reminderOnly` and `experiment` steps with their scheduled time badges.
- **Wind Down section** — `inSequence` steps numbered in order, each labeled "IN SEQUENCE".
- **Last 14 nights** — a row of 14 dots. Dot opacity reflects score; today's dot is highlighted amber with a glow ring. Unrated today shows "·". Tapping any dot opens the Sleep Log Detail sheet.

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

Accessible from the Dashboard hamburger menu (or via a lock-screen notification at 3 hours past bedtime). Designed for minimal friction when the user wakes at night.

- Clock readout (hardcoded "03:14" in current build).
- Copy: "You're awake. That's okay."
- Three options:
  - **4·7·8 breath** (featured) → jumps directly into the Nightly Flow at the breathing step.
  - **Boring story** → opens `MidSleepBoringStoryView`: ~8-min version (2 stories), same TTS controls as the nightly version.
  - **Body scan** → opens `MidSleepBodyScanView`: 8 body areas, 20s per area auto-advancing, manual "Next area →" button, completion screen "Scan complete. Let yourself drift."
- **"Try the get-up protocol →"** link at the bottom — dismisses Mid-Sleep Mode (get-up flow not yet implemented).

---

### 9. Experiment Engine

Pure logic layer (`ExperimentEngine.swift`) that runs on every morning log.

- **Candidate pool** (in priority order): Magnesium glycinate, No caffeine after 2pm, Cold room (65°F), Consistent wake time, White noise, Journaling, No alcohol, Morning sunlight.
- Compares average score on experiment nights vs. baseline nights.
- After 5 scored nights: promotes (delta > 0.3) → graduates the step from `experiment` to `inSequence`; or drops → removes it and queues the next candidate.
- Fewer than 5 nights: returns `keepTesting`.

---

### 10. Push Notifications (simulator-driven)

Six canned notification payloads in `Scripts/Notifications/`:

| File | Title | Action |
|------|-------|--------|
| `01-dim-the-lights.json` | Dim the lights | Mark done |
| `02-warm-shower.json` | Warm shower | Mark done |
| `03-lights-off.json` | Lights off | Mark done |
| `04-brain-dump.json` | Brain dump | Mark done |
| `05-boring-story.json` | Boring story | Mark done |
| `06-rate-your-sleep.json` | Rate your sleep | Log it → opens Morning Check-In |

A mid-sleep check notification is also scheduled programmatically (3 hours after bedtime, category `MID_SLEEP_CHECK`).

---

## How the Initial Routine Is Built

When the user taps **Build my routine** on onboarding screen 7, `generateStartingRoutine(from:)` runs synchronously and returns a `GeneratedRoutine`. Here is every decision it makes, in order.

### Step 1 — Decide whether bedtime is imminent

`timeToTargetBedtimeMinutes` computes how many minutes remain until the user's typical bedtime (treating anything within the last 30 min as "now"). If that value is ≤ 60:

- Environmental steps (brightness check, temperature log) are added to the front of the sequence — they're only useful if the user is about to go to bed.
- The Routine Ready payoff CTA changes to **"Start Routine Now"** instead of "Try it tonight".

### Step 2 — Score pre-bed habits and keep the good ones

Every habit the user selected on screen 5 is scored:

| Habit | Score | Reasoning |
|-------|-------|-----------|
| Dim the lights | +3 | Proven melatonin anchor |
| Physical book | +3 | Excellent cognitive off-ramp |
| Warm shower / bath | +3 | Triggers core-temperature drop |
| Socialising | +1 | Fine if calm |
| Evening exercise | −1 | Cortisol takes 2–3h to clear |
| Snack / eating | −1 | Digestion raises core temp |
| Phone / scrolling | −2 | Blue light + mental stimulation |
| TV / screens | −2 | Same as phone |
| "Nothing specific" | 0 | No concrete anchor |

Habits with a **positive score** are ranked highest-first and the top 2 are kept as `existingHabit` steps in the routine — the things the user already does well that Lull keeps rather than replaces.

Habits with a **negative score** are not kept; instead they generate **avoid reminder** steps (see step 4).

### Step 3 — Choose the primary wind-down step

One highest-impact step is chosen based on the user's profile signals:

| Condition | Primary step chosen |
|-----------|-------------------|
| Brain races (screen 1) **or** ADHD (screen 2) **or** Founder/high-stress (screen 2) | **Brain Dump** — empties the cognitive queue before sleep |
| Anxiety (screen 2) | **4-7-8 Breathing** — direct nervous-system downshift |
| None of the above | **Boring Story** — occupies the narrative mind without stimulating it |

### Step 4 — Add a secondary wind-down (if the sleep window allows)

If `sleepWindowMinutes ≥ 10`, a complementary second step is added:

| Primary | Secondary |
|---------|-----------|
| Brain Dump | Boring Story |
| 4-7-8 Breathing | Boring Story |
| Boring Story + brain races / ADHD | Brain Dump |
| Boring Story (no racing mind) | Nothing |

### Step 5 — Trim to fit the stated time window

| Window | Max steps kept |
|--------|---------------|
| Under 10 min | 3 |
| 10–20 min | 4 |
| 20+ min | All steps |

Steps are trimmed from the end (least-essential last).

### Step 6 — Build avoid-reminder steps

Harmful habits from screen 5 become **pre-wind-down reminder** steps that fire earlier in the evening, not during the bedtime sequence itself:

| Habit selected | Reminder label | Lead time | Why |
|----------------|---------------|-----------|-----|
| Phone / scrolling | No screens | 60 min | Blue light delays melatonin ~30–60 min |
| TV / screens | No screens | 60 min | Same (deduplicated — one "No screens" even if both selected) |
| Evening exercise | Finish workouts | 180 min | Cortisol takes 2–3h to clear |
| Snack / eating | No heavy snacks | 120 min | Digestion raises core temp |

These steps get `mode = .reminderOnly` and appear in the **Pre-Wind Down** section of My Routine. They do not appear in the nightly flow sequence.

### Step 7 — Generate the plain-English explanation

A narrative explanation is assembled sentence-by-sentence:
- One sentence per kept habit: "We kept your [habit] — you already do this well."
- One sentence per added wind-down step, tied to the profile signal that triggered it.
- One sentence per avoid reminder, citing the lead time and the science behind it.

This text is shown on the Routine Ready payoff screen and stored in `AppState.routineExplanation`.

### How the schedule is computed

`AppState.scheduledRoutine` is a computed property that converts `coreRoutine` into a sorted list of `ScheduledStep` with clock times:

- **inSequence steps** are packed backwards from the user's typical bedtime, each step offset by its estimated duration (Brain Dump = 2 min, Boring Story = 20 min, 4-7-8 = 5 min, etc.). If the total sequence is shorter than `sleepWindowMinutes`, the whole block is shifted earlier to fill the window.
- **reminderOnly / experiment steps** use a fixed lead-time lookup (`AppState.prepLeadTimes`) — e.g. "Dim the lights" fires 90 min before bed, "No screens" fires 60 min before bed.
- All steps are then sorted by time ascending. This sorted list is what both the Dashboard "What's coming" list and the My Routine view display.

---

## How the Next Experiment Variable Is Recommended

Lull runs a rolling A/B-style experiment: one variable is tested at a time for 5 scored nights, then either promoted to the core routine or dropped, and the next candidate is automatically queued.

### The candidate pool

Variables are pre-ranked by expected impact (evidence-based ordering). Any variable already in the user's `coreRoutine` is automatically skipped when picking the next candidate.

```
1. Magnesium glycinate · 30 min before bed
2. No caffeine after 2 pm
3. Cold room · target 65°F
4. Consistent wake time
5. White noise
6. Journaling · 10 min
7. No alcohol
8. Morning sunlight · 10 min
```

### How a night is scored

Each morning, the user rates their sleep 1–5. `logMorningScore()` saves that score against the current date and tags it with `tonightVariable` (the label of the active experiment step). This is the raw data the engine reads.

### Evaluation logic (ExperimentEngine.evaluate)

Runs every time `logMorningScore()` is called. It:

1. Finds the active experiment step in `coreRoutine` (the one with `mode == .experiment`).
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

### What happens on promote

- The experiment step's `mode` changes from `.experiment` to `.inSequence`.
- It moves from the Pre-Wind Down section to the Wind Down sequence in My Routine.
- The next untested candidate from the pool becomes the new experiment step (`mode = .experiment`).

### What happens on drop

- The experiment step is removed from `coreRoutine` entirely.
- The next untested candidate from the pool becomes the new experiment step.
- If the pool is exhausted (all candidates either in-routine or already tested), no new experiment step is added and the Tonight's Variable card shows "No experiment running".

### Where the experiment state surfaces in the UI

| Surface | What's shown |
|---------|-------------|
| My Routine — variable card | Active variable, "Night N of 5", score delta so far |
| My Routine — Pre-Wind Down list | Experiment step with an amber "↑ THIS WEEK" badge |
| Morning Check-In — insight card | Variable name + insight line ("3 more nights of data before we decide." / "Scores up +0.8…" / "No benefit detected…") + promotion/drop announcement |
| Sleep Log Detail — past entry | "VARIABLE TESTED" label shows what was being tested that night |

### Manual override

The user can swap the variable at any time via the ↻ button on the My Routine variable card. If a test is in progress (at least 1 night logged), a confirmation alert warns that switching loses the accumulated data. Confirming opens the Candidate Picker sheet, which lists all pool candidates not already in the routine. Selecting one immediately replaces the experiment step and resets the night counter.

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
1. Unlock phone → tap lock-screen widget or notification.
2. Mid-Sleep Mode opens.
3. Tap **Boring story** → ~8-min audio plays; tap × when ready to try sleeping again.
4. Or tap **Body scan** → advance through 8 areas (20s each) → "Scan complete. Let yourself drift." → tap Close.

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
- After 5 scored nights with delta > 0.3: the experiment step's `mode` changes from `.experiment` to `.inSequence`. It moves from the Pre-Wind Down section to the Wind Down section in My Routine. The next candidate from the pool becomes the new experiment step.

#### Experiment conclusion — drop
- After 5 scored nights with delta ≤ 0.3: the experiment step is removed from `coreRoutine`. The next candidate is queued. If the pool is exhausted, no new experiment step is added and the Tonight's Variable card shows "No experiment running".

#### Mid-Sleep Mode — "4·7·8 breath" option
- Taps into the Nightly Flow at the `fourSevenEightBreathing` step by setting `state.nightlyStep` to that index. If the step isn't in `nightlyFlowSteps`, index defaults to 0 and the user starts the flow from the beginning.

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
