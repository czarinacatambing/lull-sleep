# Lull Notification Copy — Bedtime Prep

Reference for all bedtime prep notifications. Three layers per item:

1. **Primary** — fires at scheduled lead time (e.g. 75 min before bed for "Dim the lights").
2. **Follow-up** — fires ~15 min after the primary if item is still unchecked.
3. **Final nudge** (optional, per item) — fires ~5 min before the actual bedtime if still unchecked.

**Voice rules:**
- Calm older-sibling. Knowing, not naggy.
- Specific action + one short "why" > generic encouragement.
- No exclamation marks. No "let's do this." No "sleep like a baby."
- "You've got this" warmth is fine; "let's gooo" warmth is not.

---

## Per-item copy

### Dim the lights

| Layer | Title | Body |
|---|---|---|
| Primary | Dim the lights | Lamps only from here. Bright light tells your brain it's still daytime. |
| Follow-up | Still on the overhead? | Switch to lamps when you can. Your melatonin is waiting on the cue. |

### No screens (minimize, not eliminate)

You'll likely use Lull on your phone, so the copy frames this as *minimizing* screen time, not zero. Lull and an e-reader are fine; doomscrolling and email aren't.

| Layer | Title | Body |
|---|---|---|
| Primary | Wind down screen time | Blue light suppresses melatonin and tells your brain it's still daytime. Lull is fine — TikTok, email, and news aren't. Taper from here. |
| Follow-up | Still scrolling? | Blue light is keeping you in daytime mode. One last check, then put it down. |

### App blocking

| Layer | Title | Body |
|---|---|---|
| Primary | Lock the time-sinks | Tap done after you've blocked the apps you don't want pulling you in tonight. |
| Follow-up | Apps still open? | Future-you is counting on this. A quick lockdown and you're set. |

### Finish workouts

| Layer | Title | Body |
|---|---|---|
| Primary | Wrap your workout | Cortisol takes about three hours to settle. Cool down when you can. |
| Follow-up | Are you done with your workout? | The closer your last set is to bedtime, the harder wind-down gets. Try to land it soon so your nervous system has time to come down. |

### No heavy snacks

| Layer | Title | Body |
|---|---|---|
| Primary | Last call on heavy food | Big meals = restless sleep. A light snack is fine if you're hungry. |
| Follow-up | Mid-meal? | If it's heavy, save the rest for tomorrow. Your digestion gets a break and your sleep gets deeper. |

### No alcoholic drinks

| Layer | Title | Body |
|---|---|---|
| Primary | Last call on alcoholic drinks | Even one alcoholic drink fragments your deep sleep tonight. It's a real trade-off. |
| Follow-up | Pouring another? | One less drink tonight is one more clean sleep cycle. You've got this. |

### No caffeine

| Layer | Title | Body |
|---|---|---|
| Primary | Caffeine cutoff | Caffeine has a six-hour shadow. Stop now and you'll feel it tonight. |
| Follow-up | One more cup? | Make it the last. Even decaf has trace amounts — go with water from here. |

### Cold room prep

| Layer | Title | Body |
|---|---|---|
| Primary | Cool your room | Sweet spot is 65–68°F. Crack a window or drop the thermostat now and it'll be perfect by bedtime. |
| Follow-up | Room still warm? | Body temp needs to fall for sleep to come. A few degrees cooler tonight makes a real difference. |

### Warm shower or bath

| Layer | Title | Body |
|---|---|---|
| Primary | Warm shower time | A warm shower now triggers a body-temp drop that helps you fall asleep faster. |
| Follow-up | Shower still on the list? | 10 minutes is enough. Warm, not scalding. You'll feel the difference at lights-out. |

### Magnesium glycinate

| Layer | Title | Body |
|---|---|---|
| Primary | Take your magnesium | 200–400mg glycinate. Quiet, steady, no jitters. Take it with water. |
| Follow-up | Magnesium still in the bottle? | A few minutes to absorb is all it needs. Pop it now and settle in. |

### Herbal tea

| Layer | Title | Body |
|---|---|---|
| Primary | Brew your tea | Chamomile or rooibos. Steep it now, sip it slow. |
| Follow-up | Kettle cold? | Five minutes to steep, ten to drink. The ritual is half the point. |

> **Note:** Weighted blanket is part of the **wind-down ritual** (in-sequence), not bedtime prep — no reminder notification fires for it. Copy lives elsewhere when/if needed.

---

## Generic fallback (any future remedy without explicit copy)

```
Primary
  Title: <step.label>
  Body:  Quick reminder, this one's part of tonight's prep. Tap done when you've got it.

Follow-up
  Title: <step.label> — still on?
  Body:  Tap done when you've handled this one. You've got time.
```

---

## Wind-down start (transition from prep → ritual)

Fires at `typicalBedtime - <wind-down duration>` so starting the ritual now lands the user in bed right at their target bedtime. The follow-up fires 5 min later if the user still hasn't opened the nightly flow. Skipped entirely if the ritual is ≤5 min (no room for a follow-up).

Example: 9 PM bedtime, 10-min ritual → primary at 8:50 PM, follow-up at 8:55 PM.

| Layer | Title | Body |
|---|---|---|
| Primary | Wind-down time | Close to bedtime now. Tap to start tonight's ritual — Lull will guide you through to lights-out. |
| Follow-up | Bedtime's getting close | Wind-down takes about {N} minutes. Start now and you'll land in bed right on time. |

`{N}` is the dynamic total ritual length in minutes, computed from the sum of `NightlyStepKind.estimatedMinutes` over the user's wind-down steps.

**Tone notes:**
- "Tonight's ritual" frames it as something the user is *doing*, not a chore they're *getting through*.
- "Lull will guide you" sets expectation that they're not on their own — opening the app means a led sequence, not a blank page.
- The follow-up gives a concrete time cost ("about 20 minutes") so a hesitating user can decide if they have it.

**Implementation notes:**
- Category identifier `WIND_DOWN_START` with a primary action like `OPEN_RITUAL` (`options: [.foreground]`) so tapping the notification opens the app and starts the nightly flow.
- Identifier `wind_down_start_primary` and `wind_down_start_followup` for cancellation when the user starts the flow manually.
- Reuse `interruptionLevel = .timeSensitive` and `relevanceScore = 1.0` from the prep reminders.
- Cancel both when `state.showNightlyFlow` becomes `true` (i.e., the user has opened the wind-down sequence) so they don't fire mid-ritual.

---

## Bedtime summary (single notification at typical bedtime, if items remain)

| Items left | Title | Body |
|---|---|---|
| 1 | Bedtime — one item still open | One prep item left. Knock it out or skip tonight — both fine. |
| 2+ | Bedtime — a few items still open | {N} prep items still on the list. Skip tonight or knock them out in the next few minutes. |

If `N == 0`, suppress the summary entirely.

---

## Notes for implementation

- Reuse `interruptionLevel = .timeSensitive` and `relevanceScore = 1.0` from the primary on the follow-up and summary so they break through Focus modes consistently.
- Follow-up identifier should be `bedtime_prep_followup_<label>` so `togglePrepDone(_:)` can cancel it cleanly when the user checks the item.
- The summary fires once at `typicalBedtime` with identifier `bedtime_prep_summary`. Recompute its body each evening at scheduling time based on which items are still unchecked.
- Optional per-item final nudge (the "last 5 minutes before bed" layer) can be added later — start with primary + follow-up + summary.
