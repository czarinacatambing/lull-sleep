# Onboarding Design Brief — New Screens

**For:** Claude Design (or any designer doing the visuals)
**See also:** `Docs/onboarding-activation-plan.md` for engineering details (logic, file paths). This file is just for design.

---

## What Lull is

A SwiftUI iOS sleep app in TestFlight. Half our beta users finish onboarding and never log a single night. These new screens are designed to fix that. They need to feel like part of the existing app.

---

## Who you're designing for

See `Docs/audience-profile.md` for the full picture. Quick version:

- Adults 28–40: founders, ADHD women in tech, biohackers, new parents
- They already wear an Oura or Apple Watch
- They trust data. They distrust wellness clichés.

**Avoid:**
- Mascots, pastel colors, animal emoji
- Motivational copy, exclamation marks
- "Awaken your vitality" language
- Gamified contracts

**Aim for:**
- Calm, restrained, dark, warm
- Monospaced labels for data
- Hedged language ("most likely" not "definitely")
- The vibe of Oura or Eight Sleep, not a meditation app

---

## Brand tokens (existing — match these exactly)

**Palette** (from `Lull/Theme/LullTheme.swift`):

| Token | Hex | Use |
|---|---|---|
| `lullBg` | `#0c0807` | Page background — near-black, warm-tinted |
| `lullBg1–3` | `#120c0a` → `#231612` | Card/elevated surfaces (darker → warmer as elevation increases) |
| `lullInk0` | `#f5e7d7` | Primary text |
| `lullInk1` | `#e5d3bf` | Secondary text |
| `lullInk2` | `#b9a691` | Tertiary text / captions |
| `lullInk3` | `#8a7a68` | Quaternary / muted labels |
| `lullInk4` | `#5c4f42` | Disabled / very muted |
| `lullAmber` | `#f0b96b` | The accent. Used sparingly — buttons, key glyphs, highlights |
| `lullAmberSoft` | `#d99a4a` | Hover/secondary amber |
| `lullAmberDeep` | `#a66a2a` | Pressed amber, deep glows |
| `lullAmberGlow` | `#f0b96b` @ 45% | Soft halos behind orbs / cards |
| `lullLine` | warm white @ 8% | Hairline dividers |
| `lullLineStrong` | warm white @ 14% | Card borders |
| `lullBgDeep` | `#1a0d06` | Text colour on amber buttons |

**Typography**:

- **Fraunces** (serif, light + light-italic) — for headlines, names, big numbers
- **JetBrains Mono** — for small labels, data, timestamps, kickers
- **System sans** — for body copy and captions

Existing screens use `serif(28–38)` for reveal headlines and `mono(9–11)` for small caps labels (letter-spacing 1.2–1.6).

**Spacing**: 24pt horizontal padding, 22pt card radius, 56pt button height, fully rounded buttons.

**Atmosphere**: a soft amber glow sits behind dark content on most screens (`AmberGlow`). Position it to draw the eye to whatever matters most on that screen.

---

## Reference screens (look at these first)

The new screens should feel like they belong to the same app. Look at these existing ones:

| Screen | Why |
|---|---|
| `OnbRoutineReadyView` | The orb and the routine card. Best example of how reveals feel in this app. |
| `OnbBedtimeView` + `SleepArcClock` | The data-card pattern. Use as a reference whenever a screen needs to feel precise. |
| `OnbBaselineRatingView` | Clean, minimal selector. |
| `Lull/Components/LullComponents.swift` | Existing reusable components: Kicker, ChoiceRow, PrimaryCTA, GhostButton, AmberGlow, BrandMark, Ember, StepProgress, OnbTopBar. Use these instead of making new ones when you can. |

---

## Screens to design

Six new screens + light modifications to one existing screen. Listed in flow order.

The flow has been reordered since the previous version of this brief. **The 4-7-8 felt-experience moves to position 1**, before the quiz, applying Nikita Bier's "demonstrate value in 3 seconds" rule. The user should feel something physical happen in their body before being asked a single question. The reveal and methodology screens still sit later in the flow as configuration payoffs, but the *aha* now happens up front.

### 1. Welcome (NEW)

**Where it goes:** step 0. First screen after app install / launch.
**What it does:** a single, deliberate gesture into the felt experience that follows. Nothing else.

**Content:**

```
[Brand mark, small, top-centre]

[Serif headline, large, centred]    Trouble sleeping?
                                    Try this 60-second thing
                                    before we ask you anything.

[Primary CTA]                       Help me sleep tonight

[Sans, muted, very small, below CTA]
                                    No signup. No quiz yet.
```

**Feel:** spare. One headline, one button, one whisper of reassurance. The screen exists only so the 4-7-8 doesn't start cold — the user takes a deliberate action to enter. The amber glow sits centred behind the headline (not behind the CTA), so the eye is pulled to the *promise*, not the button.

**Don't:**
- Add an explainer paragraph about Lull, sleep science, or what comes next.
- Add a "Sign in" link (returning users should resume from where they left off, not pass through this screen).
- Use a hero image, illustration, or animated logo intro. The screen is content-light by design.

**Interaction:** tap CTA → immediate transition to 4-7-8 screen (no loading state, no animation longer than a fade).

---

### 2. 4-7-8 Practice (NEW — was previously planned post-routine; now moves to position 1)

**Position:** immediately after Welcome.
**Job:** the AHA moment. The user should feel a physical shift within ~5 seconds of opening the app for the first time.

**Critical reframing from the previous version of this brief:** 4-7-8 is **no longer** framed as "step 1 of tonight's routine." Reason: the routine generator does not include 4-7-8 in every routine, so promising it as the first step would create a credibility break minutes later. Instead, frame 4-7-8 as a **free-standing tool the user receives early**, separate from whatever routine gets built.

**Content + interaction:**

```
[Kicker]               TRY THIS WITH ME

[Serif headline]       60 seconds.
                       That's all this takes.

[CENTRE: animated orb that expands on inhale, holds on hold, contracts on exhale.
 Use the same orb material as OnbRoutineReadyView.orbIntro — radial gradient
 amber sphere with offset highlight, soft amberGlow halo behind it.]

[Beneath orb, mono]   INHALE 4   /   HOLD 7   /   EXHALE 8
[Below that, serif numeral]   countdown timer per phase

[Voice-led narration plays alongside the animation —
 see Voice / copy notes for the script.]

[Primary CTA]          I'm done
[Ghost CTA]            Skip this for now
```

**Design intent:** the orb is the centerpiece. The breathing is *meditative* but in a data-card frame — no soft pastel meditation-app vibes. Numerals on screen reinforce the precision feel. The phase label sits in mono caps; the seconds-remaining sits in serif numerals (~serif(48)).

**Animation:**
- Inhale (4s): orb scales from 0.9 → 1.25, brightens slightly
- Hold (7s): orb stays at 1.25
- Exhale (8s): orb scales 1.25 → 0.9
- Run 2 full cycles minimum, then enable "I'm done" CTA

**Skip CTA presence:** important. Forcing it would annoy a subset of users. The skip button is small (ghost), unbolded — present but not advertised. Users who skip should go directly to the Transition screen (step 3) — they don't get a "you missed out" interstitial.

**Don't:**
- Use a generic "meditation" aesthetic (lotus, calming greens, etc.).
- Animate text in any flashy way. The orb does the motion; everything else stays still.
- Show a step counter on this screen. This is a moment, not a step.

---

### 3. Transition (NEW)

**Position:** immediately after 4-7-8 completion (or 4-7-8 skip).
**Job:** convert the felt sensation into consent to continue. Hand the tool over. Set expectation for the quiz.

This can ship as a brief full-screen state of `Onb478PracticeView` rather than a separate view — implementer's call. From a design perspective, treat it as its own moment with its own composition.

**Content:**

```
[Serif headline, centred]    Feel that shift?
                             That tool is yours now.

[Body, sans, muted]          Let's build the routine that gets you
                             to great sleep in the first place.

[Primary CTA]                Next
```

**Design intent:** post-breath, dwell-on-stillness. The screen should feel like the user just exhaled. Use generous vertical whitespace; resist the urge to add a small graphic. The amber glow sits low on the screen behind the CTA, not behind the headline — opposite of the Welcome screen.

**Skip variant:** if the user skipped the breath, replace headline with `That tool is here when you want it.` and keep everything else the same. Don't punish skippers; just continue.

**Don't:**
- Repeat the orb animation. The breath moment is over.
- Add congratulatory copy ("Great job!"). Off-brand and patronizing.

---

### 4. Bottleneck Reveal (NEW)

**Where it goes:** after the TARGET sleep-window screen (step 8), before pre-bed activities (step 10).
**What it does:** shows the user we read their answers — and gives them a *diagnostic* (their sleep bottleneck) that justifies the routine that's about to be built.

**Important change from earlier drafts:** the **chronotype label is no longer revealed at onboarding**. It's reserved for the night-5 verdict card, where it stacks with the experiment result for a much stronger share artifact. This screen now displays bottleneck only.

**Content:**

```
[Kicker]              YOUR BIGGEST LEAK

[Serif headline]      Pre-sleep
                      rumination.

[Mono caption]        Based on:
                        · racing mind at lights-out
                        · 12:30 AM bedtime
                        · high-stress role

[Hairline divider]

[Body, sans]          Your routine for the next 5 nights
                      targets this directly with a Brain Dump
                      experiment.

[Primary CTA]         Continue
```

**Feel:** quiet, clinical, a little flattering-by-precision. The user is being *seen*, not categorized. The hairline divider separates the diagnostic (top) from the prescription (bottom).

**No foreshadow of the night-5 reveal.** Earlier drafts of this brief included a small muted line at the bottom of this screen ("Your full sleep pattern + verdict comes at night 5.") to preview the verdict moment. That line is now removed. Reason: the night-5 verdict is gated behind a paywall (see `Docs/paywall-design-brief.md`), and foreshadowing implicitly promises a free reveal the paywall then partially withholds. The verdict mechanic depends on landing as a surprise — Glam Up's model doesn't foreshadow either; the surprise *is* the mechanic. Onboarding ends without previewing what's at night 5.

**Don't:**
- Reveal the chronotype name (Early Sleeper / Steady Sleeper / Late Sleeper / Drifter). That's a different screen entirely (the night-5 verdict — separate brief at `Docs/paywall-design-brief.md`).
- Make the routine-justification copy chronotype-flavored ("Late Sleepers with this leak…"). Phrase it around the bottleneck only ("People with pre-sleep rumination…").
- Preview the night-5 verdict in any way. No foreshadow line, no "what to expect after 5 nights" copy, no countdown elements. The verdict mechanic depends on surprise.
- Add a skip button. This screen is not optional.

**Variants:** five bottleneck phrases — *Pre-sleep rumination*, *Fragmented sleep*, *Insufficient deep sleep*, *Short sleep window*, *Inconsistent rhythm*. Add a small "provisional" tag if the user said they're a new parent or shift worker.

---

### 5. Methodology / Founder's Note (NEW — replaces the existing 3-second orb loading screen)

**Position:** after "tried before" (step 10), before the routine reveal
**Job:** establish credibility for the protocols Lull uses. Frame Lull as a delivery mechanism for proven science, not as a novel intervention.

**Content:**

```
[Kicker]              A NOTE FROM CZARINA, LULL'S FOUNDER

[Serif headline]      Lull isn't a new
                      sleep method.

[Body, sans]          It's a way to test which evidence-based
                      protocols actually work for your brain.

[Section label, mono] YOUR ROUTINE IS BUILT ON

[Citation block ×4, structured as label + mono caption]
  • CBT-I (Cognitive Behavioral Therapy for Insomnia)
    Outperforms sleep medication at 12-month follow-up
    in meta-analyses (Trauer et al., 2015)

  • Sleep restriction + stimulus control
    70–80% response rate across 14 RCTs (Morin et al., 2006)

  • 4-7-8 breathing
    Reduces pre-sleep cognitive arousal via vagal activation
    (Jerath et al., 2015)

  • Chronotype framing
    Breus (2016), validated against the MEQ (Horne & Östberg, 1976)

[Hairline divider]

[Body, sans, slightly muted]
  What Lull adds: turning these into a 5-night experiment
  you can actually run — and see your own data on.

[Sign-off, serif italic]   — Czarina, founder

[Primary CTA]          Show me my routine
```

**Design intent:** feels like a serious thing. Like the methodology section of a research paper, restyled for warmth. Citation lines are mono (data voice); the founder voice is serif (human voice). The contrast between the two does the lifting.

**Loading behavior:** while this screen is being read, the routine is being generated in the background. CTA only enables when generation completes (typically <500ms; gate behind state if it ever runs slow). If generation is instant, leave a 2.5–3s minimum dwell so the user actually reads the citations.

**Don't:**
- Include a photo of the founder unless we're sure it doesn't read as cringe. Test it. Signature line alone is the safer default.
- Cite stats you can't back. Every line above is a real, citable study. Do not embellish.
- Mention Lull's own user numbers here. We don't have n.

**Optional accent:** a small mono "v1" or build number at the bottom signals "this is shipped science, not marketing." Borrowed from Whoop / Oura release-note culture.

---

### 6. Routine Reveal (MODIFY existing `OnbRoutineReadyView`)

**Position:** after methodology screen
**Job:** unchanged — but now needs to feel like the *payoff* the methodology earned.

**Changes to make:**

- Each routine step gets a **bottleneck-keyed** one-line *why* below the step label. Mono, muted. **Not chronotype-keyed** — the chronotype is not visible to the user at this point in the flow (reserved for the night-5 verdict). Example:
  ```
  10:15 PM  ✶  Brain Dump            6 min
              ↳ Discharges racing thoughts before
                 lights-out — your biggest leak
  ```
- The "Tonight's plan, built for your brain" headline stays as-is, but consider tightening the italic phrase if it competes with the routine card visually.

**Don't:**
- Add the methodology citations here. They're already established on the previous screen — repeating them dilutes both screens.

---

### 7. Commitment Moment (NEW)

**Position:** final screen of onboarding, before the app's home view
**Job:** convert intent into a time-bound implementation intention. Notification permission ask lives here.

**Content:**

```
[Kicker]               YOUR ROUTINE STARTS TONIGHT

[Serif headline]       10:42 PM

[Body, sans]           That's when step 1 begins.
                       Want a reminder?

[Two action rows, mono]
  • YES, REMIND ME      [amber chevron]
  • CHOOSE A DIFFERENT TIME   [muted chevron]

[Hairline]

[Body, sans, muted, small]
  We'll send one quiet notification at this time. No daily
  spam, no nudges — just the start of your routine.
```

**Design intent:** the entire screen is built around the *time*. Serif(48 or larger) for "10:42 PM" — bigger than any other typography in onboarding. It's the visual claim on a specific moment.

**Interaction:**
- Default time = `state.typicalBedtime - 30 minutes` (the routine wind-down start)
- Tap "Yes, remind me" → triggers the iOS notification permission prompt → schedules the actual notification
- Tap "Choose a different time" → wheel picker (10-min increments, matching the arc clock change) → returns to same screen with updated time
- After permission granted → confirmation micro-state (~1.5s) showing the time set, then continue to home

**Don't:**
- Show generic "Notifications help you sleep better" copy. The audience hates push-permission pleading.
- Use multiple notification ask UI. One quiet ask, one time, done.

---

## Design deliverables

For each new screen, please produce:

1. **Static mockup** at iPhone 15 Pro size (393×852pt logical, 1179×2556px @ 3×)
2. **Dark mode only** (the app is dark-only)
3. **States covered:**
   - Welcome: default (only one state)
   - 4-7-8: idle state + mid-breathing state (inhale + hold + exhale frames) + completion-ready state
   - Transition: completed-breath variant + skipped-breath variant
   - Bottleneck reveal: 5 bottleneck variants (Pre-sleep rumination / Fragmented sleep / Insufficient deep sleep / Short sleep window / Inconsistent rhythm) + 1 "provisional" badge variant for situational users
   - Methodology: default (only one state); confirm citation block scales gracefully if a citation line wraps
   - Commitment: default-time + custom-time-picker open + confirmation state
4. **Annotated copy file** (markdown or doc) listing the exact strings, so engineering doesn't have to read from your mockups
5. **Spec strip** at the bottom of each frame: font sizes, colours used (by token name, not hex), spacing values

**Wearable connect screen is not part of this delivery.** It is deferred to post-night-1 placement and will be briefed separately when the HealthKit/Oura integration lands. Do not include it in mockups for this round.

---

## Process notes

- **Use existing components when possible** (Kicker, ChoiceRow, PrimaryCTA, GhostButton, AmberGlow, Ember, StepProgress, OnbTopBar). Inventing new components is a tax on engineering. If you must invent, justify briefly.
- **Step counter visibility:** existing onboarding shows `StepProgress(step: 1, total: 6)`. The new flow is ~13 steps. Recommendation: **hide the step counter for the entire pre-quiz prelude** (welcome → 4-7-8 → transition) so it reads as a continuous "moment" rather than a numbered sequence. Reveal the step counter starting at the Name screen, and count only the quiz screens (so the counter reads `1/6`, `2/6`, etc. for the user — even though they're already at app-screen 4). Drop the counter again on the reveal / methodology / routine / commitment screens (those are moments, not steps). This protects the perceived length of the flow.
- **Time budget:** the entire onboarding flow needs to feel <3 minutes. Don't add visual content that makes individual screens feel weighty enough to slow the user — every screen should feel like 10–20 seconds of attention max.
- **Animation philosophy:** restrained. The orb expanding is the only major motion. Everything else fades, doesn't slide; settles, doesn't bounce.

---

## Voice / copy notes

The brand voice (already established in existing screens):

- **Hedged, not certain.** "Most closely matches" not "you are." "Typically improves" not "will improve."
- **Lowercase serif headlines** with strategic italic accent (see `OnbRoutineReadyView`: "*built for your brain.*").
- **Mono caps for kickers** with kerning ~1.2–1.6. Always short — 2–4 words.
- **Sans body** for explanation. Never marketing-y. Read like a thoughtful friend, not a coach.
- **No exclamation marks anywhere.** This is the easiest tell of off-brand copy.
- **No emoji except where it's already established** (e.g., `Ember`, `moon.fill`, `sun.max.fill`).

### Voice script for 4-7-8 narration (step 1)

The breath needs a calm, low-volume voice-over guiding pace. Draft script for two cycles (~38s of audio over the 60s screen):

> *(soft)* "Breathe in through your nose, four counts."
> *(pause — 4s inhale)*
> "Hold, seven."
> *(pause — 7s hold)*
> "Out through your mouth, eight."
> *(pause — 8s exhale)*
> "Again. In, four."
> *(pause — 4s)*
> "Hold."
> *(pause — 7s)*
> "Out, eight."
> *(pause — 8s)*
> *(silence to end)*

No "great," no "wonderful," no coach voice. Calm, neutral, almost clinical-warm. Same voice that narrates the existing TTS routines.

---

## Out of scope for design

- The existing question screens (Q1–Q6 unchanged visually)
- The Sleep Arc Clock visual treatment (only the snap behavior changes; logic is engineering)
- The verdict card / share artifact (separate brief, comes later)
- The home / today / nightly flow screens (not part of onboarding)
- Marketing / website / App Store screens

---

## Questions to flag back before designing

If during design you bump into any of these, raise them — don't silently decide:

1. Should the Welcome screen show the Lull brand mark, or be totally unbranded (just the headline + CTA)? Argument for unbranded: removes any "marketing" feel and makes the first tap feel like a personal commitment, not a product entry. Argument for branded: builds recognition for repeat opens. Test both.
2. Should the 4-7-8 orb animation match the existing `OnbRoutineReadyView.orbIntro` orb exactly, or be a calmer / slower-pulsing variant suited to a breathing exercise? (The existing orb's pulse cadence is decorative; a breath orb needs to move on the actual 4/7/8 timing.)
3. Should the Transition screen be a true separate screen or a final state of the 4-7-8 view that fades in over the orb? Design the second; engineering may collapse them.
4. Should the methodology screen show the founder's actual photo, a stylized illustration, or signature only?
5. Should the commitment moment's time picker be a wheel, a slider, or text entry? (Wheel is iOS-default and probably right; flag if you have a strong reason for something else.)
6. Is the bottleneck phrase strong enough as text alone, or does it need a subtle visual signature (e.g., a small mono symbol or a sparkline showing the diagnosed pattern)? Test both. (Chronotype identity treatment is a separate question for the night-5 verdict brief, not for this onboarding round.)
7. Should "skip" affordances on optional screens be uniform-looking or vary by screen?
