# Lull — Demo Guide

## Screens Built

| Screen | How to reach |
|---|---|
| **Welcome / logo** | App launch → amber dot + "lull" fades in → "Get started" button |
| **Onboarding** (7 screens) | Tap "Get started" |
| **Dashboard** | After onboarding completes |
| **Nightly flow** (5 steps) | "Start routine" on Dashboard |
| → Brightness check | Step 1/5 |
| → Temperature log | Step 2/5 |
| → Lights off | Step 3/5 — tap "Lights are off" or skip |
| → Brain dump | Step 4/5 — tap stop button or "I'm done" |
| → Boring story | Step 5/5 — 20 min, deep male voice, 2s delay before starting |
| **My Routine** | Tab bar → Routine tab |
| → Sleep log detail (today) | Tap today's dot → rate 1–5, add text or voice note |
| → Sleep log detail (past) | Tap any older dot → read-only: score, variable tested, notes |
| **Morning check-in** | Via notification tap |

---

## Notification Demo (Simulator)

Make sure the app is running, then **background it** (`Cmd+Shift+H`). Run from the `lull-sleep-app/` directory:

### Bedtime prep — push one at a time while narrating

```bash
xcrun simctl push booted Scripts/Notifications/01-dim-the-lights.json
xcrun simctl push booted Scripts/Notifications/02-warm-shower.json
xcrun simctl push booted Scripts/Notifications/03-lights-off.json
xcrun simctl push booted Scripts/Notifications/04-brain-dump.json
xcrun simctl push booted Scripts/Notifications/05-boring-story.json
```

### Morning check-in

```bash
xcrun simctl push booted Scripts/Notifications/06-rate-your-sleep.json
```

> **Tip:** Long-press any notification banner to reveal the action button ("Mark done" or "Log it").

---

## Suggested Demo Script

1. **Open app** → logo fades in → tap **Get started**
2. **Onboarding** → speed through (selections don't matter for demo)
3. Land on **Dashboard** → show the "Start routine" CTA card
4. Switch to terminal → push `01-dim-the-lights.json` → notification appears → long-press to show **Mark done**
5. Continue pushing notifications to walk through each bedtime prep step
6. Back in app → tap **Start routine** → walk through all 5 nightly flow steps
7. Switch to **My Routine** tab → tap **today's dot** → rate sleep → add a note
8. Tap an **older dot** → show historical log (score + variable tested)
9. Background app → push `06-rate-your-sleep.json` → tap **Log it** → morning check-in opens
