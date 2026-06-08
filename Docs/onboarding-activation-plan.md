# Onboarding Activation Plan

**Goal:** Lift install → completed-5-night-experiment from today's ~30% (8 of 15 beta installs logged zero nights) toward ~55%+ by reshaping onboarding into a felt-experience + perceived-personalization sequence ending in a concrete commitment.

This is the load-bearing fix for the activation problem identified in the May 15–18 beta data. The blurred-verdict mechanic planned elsewhere only captures value for users who finish 5 nights — this plan is what gets them there.

---

## Problem

From the May 2026 beta export (15 unique installs over 4 days):

- **8 of 15 installs (~53%) never logged a single sleep entry.** They completed onboarding but never started night 1.
- Engaged users trimmed routine length from default 5 → 2–4 nights, suggesting the default routine feels too long.
- No felt-experience moment exists in the current onboarding — users leave with a routine description but no proof anything works.

The activation gap is between *finished onboarding* and *started night 1*, not mid-experiment.

---

## New onboarding sequence

```
0. WELCOME                     ← NEW: single CTA "Help me sleep tonight"
                                 No name, no quiz, no signup. One tap.
1. 4-7-8 BREATHING (60s)       ← NEW: felt-experience first. Voice-led.
                                 AHA moment within ~5 seconds of opening the app.
2. TRANSITION                  ← NEW: "Feel that shift? That tool is yours now.
                                 Let's build the routine that gets you to great
                                 sleep in the first place."
3. Name (existing)
4. Sleep problems              ← chronotype + bottleneck input
5. Situation                   ← chronotype + bottleneck input
6. Baseline rating
7. CURRENT sleep window        ← arc-clock: "On an average night right now,
                                 when do you actually fall asleep / wake up?"
                                 → drives chronotype classification
                                 (arc clock snaps to 10-min increments — see UX note)
8. TARGET sleep window         ← arc-clock (duplicate of step 7's component):
                                 "What sleep window do you want?"
                                 → drives commitment-moment default time + the
                                   nightly notification schedule
─── classify (chronotype + bottleneck classified silently; only bottleneck surfaced) ───
9. BOTTLENECK REVEAL           ← NEW: data-card screen showing the diagnostic
                                 (e.g. "Pre-sleep rumination") and how the routine
                                 targets it. Chronotype is computed here but NOT
                                 displayed — it's reserved for the night-5 verdict.
10. Pre-bed activities         ← variable-priming
─── generate routine ───
11. METHODOLOGY / FOUNDER NOTE ← NEW: replaces existing 3-second orb loading
                                 screen. Establishes credibility for the protocols
                                 Lull uses. Generation runs in background while
                                 user reads.
12. ROUTINE REVEAL             ← existing OnbRoutineReadyView (orb intro removed),
                                 with bottleneck-keyed one-liners on each step
                                 (NOT chronotype-keyed — see below)
13. COMMITMENT                 ← NEW: specific time, specific notification.
                                 Defaults to (TARGET bedtime - 30 min wind-down).
                                 No foreshadow of the night-5 verdict — the
                                 paywall mechanic depends on the reveal landing
                                 as a surprise.
```

**Critical reordering:** the 4-7-8 felt experience moves to position 1, *before* the quiz. The user feels something work in their body within seconds of opening the app — *then* consents to the configuration quiz. Applies Nikita Bier's "demonstrate value in 3 seconds" rule to a category (sleep apps) that has historically failed this test because real value is delivered hours later, while the user is unconscious. The breath is the only thing in this product that can be felt instantly.

**Chronotype reveal moves to night 5 (NOT in onboarding) — AND is gated within the night-5 paywall.** Earlier drafts of this plan revealed the chronotype label ("Late Sleeper" / etc.) on a dedicated screen mid-onboarding. We moved it out for two reasons:

1. By night 5 the classifier has 5 nights of real sleep data to validate against, not just a heuristic. The reveal lands with stronger evidence behind it.
2. Stacking the chronotype onto the night-5 paywall card produces a single artifact — *identity + diagnosis + experiment result + aggregate comparison* — that's the share-worthy unit the marketing strategy depends on.

**The chronotype is now gated, not freely revealed at night 5.** Free users see a blurred placeholder ("a ▮▮▮▮ ▮▮▮▮▮▮▮") on the night-5 verdict card; only paid users (or users who unlock via verified share/invite) see the actual chronotype name. See `Docs/paywall-design-brief.md` Screens 2–3 for the gating treatment. Free-forever users will not see their chronotype name unless they later subscribe or unlock via share/invite — this is the price of the harder paywall mechanic.

The chronotype IS still classified at onboarding (the routine generator and bottleneck reveal use it internally). It just doesn't surface to the user at any point unless they convert.

Three payoff moments in onboarding: felt breath, bottleneck reveal, routine. Plus a foreshadow on the commitment screen that previews the night-5 verdict. One behavioral commitment (time-bound notification).

**Wearable connect deferred to v2.** The HealthKit/Oura backend isn't ready, and adding a sixth screen for an identity ask before the user has any data of their own is the wrong order. Ship onboarding without it; add it after night 1 logging exists, framed as "now that you have data, want to upgrade the precision?"

**Friend invite deferred to post-night-1.** The strongest version of the share — "doing this with a friend makes it stick, want them to start at the same time tonight?" — still requires the user to have *something to share*. Move it to the morning of day 1 (or end of night 1 logging), where the user has a result and the friend gets paired into a future 5-night experiment. Out of scope for this plan; tracked as a separate follow-up.

**Time budget:** entire flow <3 minutes of quiz time (the 60s 4-7-8 sits on top). If it pushes past 3:30 of quiz time, cut a question — not the breathing, not the reveals.

---

## Bottleneck reveal screen (onboarding)

This screen does the *diagnostic* job — it justifies the routine the user is about to see. The chronotype is computed silently in the background; only the bottleneck is shown.

Splitting the reveals this way:

- **Bottleneck at onboarding** = diagnosis (justifies the routine). The user understands *why* their routine targets what it targets.
- **Chronotype at night 5** = identity (becomes the headline of the share-worthy verdict card). Stacks with experiment result + aggregate comparison.

Both signals are still derived from the same onboarding answers; we just delay the chronotype surface to where it does the most psychological work — the moment the user has evidence to attach to it.

Layout intent (onboarding step 9):

> **Your biggest leak right now:** Pre-sleep rumination
> *(based on: racing-mind at lights-out, 12:30 AM bedtime, high-stress role)*
>
> Your routine for the next 5 nights targets this directly with a *Brain Dump* experiment.

No foreshadow line. Earlier drafts included a mono caption ("Your full sleep pattern + verdict comes at night 5.") to preview the night-5 reveal. Removed because: the night-5 verdict is now gated, and any foreshadow implicitly promises an unveiling the paywall then partially withholds. Better to remove the preview entirely so the night-5 paywall arrives without prior expectation — Glam Up's model doesn't foreshadow either; the surprise *is* the mechanic.

Visual language: data-card. Monospaced for the input-derivation line, Fraunces serif for the bottleneck phrase. No mascots, no emoji. Aesthetic should match the existing `OnbRoutineReadyView`.

The five bottleneck phrases:
- *Pre-sleep rumination*
- *Fragmented sleep*
- *Insufficient deep sleep*
- *Short sleep window*
- *Inconsistent rhythm*

All read as diagnostic, not horoscope. They earn the user's trust precisely because they're not flattering.

### Chronotype classifier (heuristic, no new questions)

The four pattern names — **Early Sleeper**, **Steady Sleeper**, **Late Sleeper**, **Drifter** — are descriptive labels derived from (but renamed away from) Breus's 4-type framework. Original framework: Lion / Bear / Wolf / Dolphin. We dropped the animal names because they read as horoscope-y to the optimizer audience and clash with the "data-card not mascot" brand voice. The classification logic is unchanged; only the surface labels differ.

Mapping for anyone porting in Breus-era logic or copy:

| Breus name | Lull name | Quick description |
|---|---|---|
| Lion | Early Sleeper | Wakes early, sleeps early. Front-loaded day. |
| Bear | Steady Sleeper | Follows the sun. Most common pattern. |
| Wolf | Late Sleeper | Night-shifted. Peak energy after sunset. |
| Dolphin | Drifter | Fragmented or irregular sleep. Hardest to type. |

Frame descriptively in copy: "*your sleep pattern most closely matches a Late Sleeper.*" Never "*you are a Late Sleeper.*"

```
midSleep    = midpoint(currentBedtime, currentWakeTime)   // NOT targetBedtime
duration    = currentWakeTime - currentBedtime
racingMind  = Q1 contains "brain races" OR "struggle to fall asleep"
fragmented  = Q1 contains "wake during night" OR "unrefreshed"
neuroLean   = Q2 contains "ADHD" OR "high-stress" OR "anxiety"
situational = Q2 contains "new parent" OR "shift work"

if fragmented AND (duration < 7h OR Q2 contains "anxiety"):
    → Drifter
elif midSleep ≤ 2:30 AM:
    → Early Sleeper
elif midSleep ≥ 4:00 AM OR (racingMind AND neuroLean):
    → Late Sleeper
else:
    → Steady Sleeper

if situational:
    append note: "your sleep pattern is provisional — we'll re-check
                  after 2 weeks of real data."
```

**Codex implementation hint:** model the chronotype as a Swift `enum Chronotype: String { case earlySleeper, steadySleeper, lateSleeper, drifter }` with a `displayName: String` computed property ("Early Sleeper", "Steady Sleeper", "Late Sleeper", "Drifter") and a `pluralDisplayName: String` for routine-justification copy ("Early Sleepers with this leak…"). Keep raw case names in code distinct from display strings so we can rename labels in the future without touching logic.

Implementation: ~20 lines in `AppState` or a new `ChronotypeClassifier.swift`. Pure function.

**Validate before launch** against the two beta power users (`7B8E26B4`, `AFD1BE59`) using their export data. If the result feels obviously wrong, tune.

### Bottleneck classifier (heuristic, no new questions)

Same input set, different output. Pure function alongside the chronotype classifier in `ChronotypeClassifier.swift` (or a separate `BottleneckClassifier.swift` — implementer's call).

```
if Q1 contains "brain races" OR "struggle to fall asleep":
    → "Pre-sleep rumination"
elif Q1 contains "wake during night":
    → "Fragmented sleep"
elif Q1 contains "unrefreshed":
    → "Insufficient deep sleep"
elif (currentWakeTime - currentBedtime) < 7h:
    → "Short sleep window"
else:
    → "Inconsistent rhythm"  // fallback
```

Priority order matters — a user can select multiple Q1 options; the classifier picks the first match in the order above. That order reflects which bottleneck the routine generator can do the most about.

**Bottleneck → suggested experiment variable** (confirm against `RoutineGenerator.swift` before shipping):

| Bottleneck | Suggested variable |
|---|---|
| Pre-sleep rumination | Brain Dump |
| Fragmented sleep | Dim the lights (environmental) |
| Insufficient deep sleep | Temperature / cool-down |
| Short sleep window | Earlier wind-down |
| Inconsistent rhythm | Fixed bedtime anchor |

The mapping isn't part of routine generation today — the reveal screen surfaces it as *narrative justification* for whatever the generator picks. If the generator picks a different variable, the reveal copy should match what the generator chose, not what the table above says. The table is the *direction* the generator should be evolving toward over time.

---

## Arc clock UX: snap to 10-minute increments

The `SleepArcClock` in `OnbBedtimeView` currently snaps to the nearest minute (see `snapDate(frac:ref:)` in `OnboardingView.swift:401`). Two problems:

- **Fiddly precision**: dragging a 30px handle on a 260px clock to set "10:42 PM" vs "10:43 PM" is impossible and meaningless. Users overshoot, correct, overshoot again. Small-but-real friction at one of the most-touched onboarding screens.
- **False precision pollutes the chronotype classifier**: midpoint-of-sleep thresholds (2:30 AM, 4:00 AM) shouldn't be sensitive to whether the user landed on 12:31 or 12:34.

**Change:** snap bedtime and wake-time handles to 10-minute increments.

Implementation (one-line change in `snapDate`):

```swift
private func snapDate(frac: Double, ref: Date) -> Date {
    let raw = Int(frac * 24 * 60)
    let mins = ((raw + 5) / 10 * 10) % (24 * 60)  // round to nearest 10
    return Calendar.current.date(bySettingHour: mins / 60,
                                  minute: mins % 60,
                                  second: 0,
                                  of: ref) ?? ref
}
```

Add a light haptic (`UIImpactFeedbackGenerator(style: .light)`) on each snap so the user feels the increments — turns the friction into tactile feedback.

This is a self-contained micro-improvement; ship it with the rest of the revamp or as a standalone PR — implementer's call.

---

## Sleep window: current vs. target (two separate screens)

The existing `OnbBedtimeView` (arc-clock) currently asks a single sleep-window question. **Split this into two consecutive arc-clock screens.** Same component, same interaction, different question and different downstream use.

### Step 7 — CURRENT sleep window

**Copy:**
> "On an average night right now, when do you actually fall asleep and wake up?"

**Use:** input to the chronotype classifier. Reflects the user's *biological reality* — what their body is currently doing, not what they wish it did. Asking the target question here would corrupt the classifier (a Late Sleeper who *wishes* they were a Steady Sleeper shouldn't be classified as a Steady Sleeper).

**Stored as:** `state.currentBedtime`, `state.currentWakeTime`.

**Default arc position:** sensible neutral (e.g., 11:30 PM → 7:00 AM). Do **not** pre-populate from any previously entered value — this is the first time we're asking.

### Step 8 — TARGET sleep window

**Copy:**
> "What sleep window do you want?"
> *Sub-copy (sans, muted):* "Your routine will aim you toward this."

**Use:**
- Sets the default time on the Commitment screen (step 13): `defaultRoutineStart = targetBedtime - 30 min`.
- Feeds the nightly notification schedule.
- Stored alongside chronotype so future routine-generator versions can use the *delta* between current and target as a difficulty signal (e.g., a user trying to shift bedtime 90 min earlier needs a gentler ramp than one shifting 15 min).

**Stored as:** `state.targetBedtime`, `state.targetWakeTime`.

**Default arc position:** pre-populate with the *current* values the user just entered on step 7. Most users won't have a dramatically different target — making them re-set the arc from scratch is friction. They drag from there if they want to shift.

### Implementation notes for Codex

- **Reuse `SleepArcClock`** — do not fork the component. Both screens render the same arc with different bound state and different headline copy.
- **`OnbBedtimeView` becomes parameterized** (or split into two thin views that both wrap the same arc-clock component). Pass in: `question`, `subcopy`, `initialBedtime`, `initialWakeTime`, binding targets on `AppState`.
- **`AppState`** gains four properties: `currentBedtime`, `currentWakeTime`, `targetBedtime`, `targetWakeTime`. Persist all four. The existing single bedtime/wake fields, if any, should be migrated — `current*` is the closest semantic match for legacy data.
- **`ChronotypeClassifier`** reads `currentBedtime` / `currentWakeTime` only. Never reads the target fields.
- **Commitment screen** reads `targetBedtime` to compute the default routine-start time.
- **Visual differentiation between the two screens:** they need to feel like a *progression*, not a copy-paste. Suggestions: subtle kicker change ("STEP 1 OF 2 — RIGHT NOW" → "STEP 2 OF 2 — WHAT YOU WANT"), or a small mono note showing the user their step-7 entry as context on step 8 ("Right now: 12:30 AM → 7:00 AM"). Design will handle the visual treatment; engineering just needs to support both headlines and an optional context line.

### Why this split matters

It would be tempting to ask one question ("when do you want to sleep?") and use that for both jobs. Two reasons not to:

1. **Classifier corruption** — a user's *aspiration* doesn't match their biology. The Late Sleeper who wants to be a Steady Sleeper is still a Late Sleeper, and their routine should reflect that. Using target data would push the classifier toward the user's wishful self-image.
2. **Coaching signal** — the gap between current and target is the *real* job-to-be-done. A user with a 90-min gap needs a different routine cadence than one with a 10-min gap. Even if v1 doesn't use this delta, capturing it now means we don't have to re-prompt later.

---

## 4-7-8 framing

**Critical:** position as a **free-standing tool the user owns**, not as "step 1 of tonight's routine."

The original draft framed 4-7-8 as the opening step of the generated routine. That framing breaks because **4-7-8 is not in every generated routine** — the routine generator only includes it for certain bottlenecks (primarily rumination-driven users). Promising "this is step 1 of your routine" and then producing a routine that doesn't start with 4-7-8 is a credibility break in the first 3 minutes of the app.

Reframe as: 4-7-8 is a universally-available **mid-sleep + pre-sleep tool** that every user gets, regardless of what their generated routine looks like. It happens to be the perfect opening felt-experience because it works in 60 seconds and requires nothing else from the user.

Welcome screen (step 0):

> [Single CTA] **Help me sleep tonight**

That's the entire screen. No name field, no signup, no quiz preamble. One tap and they're in.

4-7-8 screen (step 1):

> "Try this with me. 60 seconds."
> [60-second voice-led 4-7-8 with orb animation]

Transition (step 2):

> "Feel that shift? That tool is yours now.
> Let's build the routine that gets you to great sleep in the first place."
> [Next]

The transition copy does three jobs:
1. Acknowledges the felt sensation (anchors the aha).
2. Hands the tool over ("yours now") — establishes ownership separate from the routine.
3. Sets expectation for the quiz that follows — a *routine builder*, not a tax.

The original 3am-mid-sleep utility line ("anytime you wake up at 3am, this same exercise is one tap away") moves to **end of onboarding or first morning check-in**, where the user has the context to appreciate the durability of the tool they were given.

Psychological levers (unchanged from original):
- **Effort justification** — 60s of focused effort raises perceived value of what comes next
- **Endowed progress** — they've already completed *something* before the quiz starts
- **Self-efficacy** — felt change in body > cognitive belief
- **Ownership transfer** — "yours now" is doing real work; keep that wording

---

## Wearable connect — deferred to post-launch

Originally planned to sit between the routine reveal and the commitment moment. **Cut from v1.**

Two reasons:

1. **Backend isn't ready.** HealthKit / Oura data integration is a separate workstream and would block this entire activation plan if we waited for it.
2. **Wrong order even when ready.** Asking for wearable data before the user has any of their own data is a pure ask. The natural moment is *after* night 1 logging, when the user has produced something themselves and the wearable becomes an upgrade: "now that you have data, want to upgrade the precision?"

When the integration lands, design and ship it as a post-onboarding prompt — likely on the morning of day 1 (right after the first morning check-in) or on the home screen as a dismissible card. The design brief still includes the screen spec for that future placement; do not insert it into the onboarding flow.

Connect-rate remains a useful leading indicator of wedge-audience fit, just measured against post-onboarding traffic instead of onboarding completion.

---

## Commitment moment

Don't ask "are you committed?" Ask for a specific time:

> "Your routine starts at **10:42 PM** tonight. Want a reminder?"
> [Yes, remind me] [Choose a different time]

This is an *implementation intention* (Gollwitzer 1999): specific time + specific action → 2–3x higher follow-through. The optimizer audience already thinks in calendar blocks, so this lands.

The notification permission prompt fires here, not earlier.

**No foreshadow of the night-5 verdict.** Earlier drafts of this plan included a mono caption ("At the end of 5 nights, you'll see your sleep pattern + what actually worked.") as a foreshadow. Removed. Reason: the night-5 verdict is now gated (chronotype + result both blurred for free users; unlock via subscribe / SMS invite / public share). Any foreshadow implicitly promises a free reveal that the paywall then breaks. Better to remove the preview entirely so the verdict moment lands as a surprise — that's the Glam Up mechanic the marketing strategy is based on, and it only works if the user didn't see it coming.

---

## Files involved

**New:**
- `Lull/Onboarding/OnbWelcomeView.swift` — new step 0; single "Help me sleep tonight" CTA, no other input
- `Lull/Onboarding/Onb478PracticeView.swift` — new step 1; voice-led 60s 4-7-8 with breathing orb. Framed as a free-standing tool, **not** as "step 1 of tonight's routine"
- `Lull/Onboarding/OnbTransitionView.swift` — new step 2; "Feel that shift?" handoff into the quiz. Could alternatively be a final state of `Onb478PracticeView` rather than its own view — implementer's call
- `Lull/Onboarding/OnbBottleneckRevealView.swift` — new bottleneck-only reveal screen between sleep-window and pre-bed activities. **Does not display the chronotype label** — that's reserved for the night-5 verdict card (separate workstream). The chronotype is still computed in `AppState` here, just not surfaced.
- `Lull/Onboarding/OnbMethodologyView.swift` — new founder-note / methodology screen between Q "tried before" and routine reveal; covers routine generation in background
- `Lull/Onboarding/OnbCommitmentView.swift` — new screen at end
- `Lull/Models/ChronotypeClassifier.swift` — pure-function chronotype + bottleneck classifiers (or split into two files; implementer's call)

**Modified:**
- `Lull/Onboarding/OnboardingView.swift` — extend coordinator to ~13 steps (welcome → 4-7-8 → transition → existing questions → reveal → methodology → routine → commitment). Also update `SleepArcClock.snapDate` to 10-minute increments + add light haptic
- `Lull/Models/AppState.swift` — store `chronotype`, `bottleneck`, `committedRoutineTime`, plus the new sleep-window fields: `currentBedtime`, `currentWakeTime`, `targetBedtime`, `targetWakeTime` (migrate any pre-existing single bedtime/wake fields into the `current*` slots)
- `Lull/Onboarding/OnbBedtimeView.swift` — parameterize to support both the CURRENT-window (step 7) and TARGET-window (step 8) variants. Reuse the same `SleepArcClock` component for both; only headline copy, sub-copy, initial arc values, and binding targets differ. Step 8 pre-populates with the step 7 values
- `Lull/Onboarding/OnbRoutineReadyView.swift` — remove the 3-second orb intro (now handled by the methodology screen); add **bottleneck-keyed** one-line *why* on each step (e.g. "Targets your pre-sleep rumination" — phrased around the bottleneck, not the chronotype, since chronotype is not yet visible to the user at this point in the flow)
- `Lull.xcodeproj/project.pbxproj` — target membership for new files

**Not in this plan (deferred):**
- `Lull/Onboarding/OnbWearableConnectView.swift` — ships post-onboarding when HealthKit/Oura backend lands; not part of the activation flow
- Friend-pairing share / "do this with me tonight" — moves to post-night-1 morning check-in; tracked separately

---

## Caveats

1. **Pop-science, not clinical.** Breus's 4 types isn't peer-reviewed sleep medicine. Use descriptive language ("matches a Late Sleeper") not diagnostic ("you are a Late Sleeper"). Safe for positioning; do not claim scientific backing.
2. **Situational sleepers (new parents, shift workers) will pollute the classifier.** Detect via Q2, flag the reveal as provisional, re-evaluate after 2 weeks of logged data.
3. **4-7-8 is now load-bearing, not optional.** In this revised flow, 4-7-8 is the aha moment — pulling it removes the entire reason for the new sequence. If a control test is needed, A/B against an *easier* breath (box breathing, 4 cycles instead of 8), not against removing it.
4. **The welcome screen is a single tap.** Resist the temptation to add anything — no logo intro, no "Welcome to Lull" hero, no preamble. The screen exists only as a deliberate gesture before the breath, so the user isn't dropped into 4-7-8 with zero context.
5. **Don't bloat onboarding.** If overall completion drops by >10% post-launch, cut a quiz screen (Situation or Baseline rating, in that order). Never cut the welcome, the breath, the transition, or the reveals.

---

## Success criteria

Measure within 10 days of shipping:

- **Welcome → 4-7-8 completion** — % of users who tap the welcome CTA and then complete (don't skip) the 60s 4-7-8. This is the new "did the aha happen" metric. Target: >80%.
- **4-7-8 → quiz-start** — % who continue from the transition screen into the name/quiz. If users feel the breath then bail, the transition copy is wrong or the quiz preamble feels heavy. Target: >90%.
- **Onboarding completion rate** — baseline vs new (must not drop more than 10%)
- **Night-1 logging within 24h of finishing onboarding** — the primary activation metric. Target: from today's ~50% to >70%.
- **5-night completion rate** — the lagging metric the whole plan is for. Target: from ~30% to >55%.

If both onboarding completion and night-1 logging drop, the flow is over-stuffed — revert and try shipping the changes individually. If 4-7-8 completion is high but night-1 logging stays flat, the felt-experience hypothesis is wrong (the aha doesn't transfer to behavior) and we need to revisit the bridge between the breath and the routine commitment.

---

## Out of scope

- **Wearable / Health integration entirely** — connect prompt is now deferred to post-night-1, not part of onboarding. Backend remains a separate workstream and still blocks the verdict card.
- **Friend pairing / "do this with me tonight" share** — moves to post-night-1 morning check-in. Strongest version uses the user's actual first-night result + commitment time as the share message ("Slept better on Lull last night, want to do tonight's routine together at 10:42 PM?"). Tracked as a separate plan.
- **The night-5 verdict card** — the chronotype reveal, experiment result, baseline delta, aggregate comparison, and next-experiment recommendation all live there. Separate plan, builds on this one. The only obligation this plan has to the verdict card is the **foreshadow line** on the commitment screen so night 5 doesn't arrive unannounced. See `Docs/marketing-strategy.md` for the share-or-pay mechanic the verdict card is meant to power.
- Reworking the routine generator itself
- New chronotype-specific routines (chronotype currently used only for *framing*, not for picking different experiment variables — that's a future extension)
- Voice / TTS asset production for the 4-7-8 narration (design + voice script ships with the screen; recording / Eleven Labs synthesis is a separate task)
