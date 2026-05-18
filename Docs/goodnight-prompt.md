# Lull — Implement the "Good night" outro + mid-sleep activation fix

Reference design: `/Users/czarinacatambing/Downloads/Lull iOS Mockups-2.html` (the design canvas in this project).
The relevant artboards are in the **Nightly walkthrough (F2)** section:
- `05 · Good night · slow fade-out (animated, 14s loop)` — the animated transition
- `05 · Good night · mid-tip moment (still)` — the peak frame, frozen for reference
- The Tonight screen mid-sleep primer in **Today & routine** (`home-dash` / evening state)

The HTML/JSX in this repo is a **design reference**, not production code. Use the codebase's existing component library, design tokens, and state-management patterns. Match the visual fidelity of the mock (colors, type, motion timing) — but do not copy the JSX verbatim.

---

## Change 1 — Add a "Good night" outro screen at the end of the bedtime ritual

**Problem:** Today, the last step of the ritual (Brain Dump, or Boring Story, or the alternate 4·7·8 Breathing) ends abruptly — when the user taps "I'm done" or the audio finishes, the screen closes and they're dropped back into the app. There's no gentle handoff into actually-going-to-sleep, and no reminder that mid-sleep tools exist.

**Fix:** Insert a new screen — `NightlyGoodNight` — that plays automatically when the ritual's last step completes. It runs a ~14-second autoplaying animation, then the device naturally goes idle (no further interaction required).

### When it shows
- After the user completes the **final** step of their bedtime ritual. The final step depends on what they have configured — Brain Dump if that's last, Boring Story if that's last, 4·7·8 Breathing if it's the alternate, etc. Whatever step the routine ends on, this is the screen that follows.
- Also shows if the user taps "End early · I'm calm" on the breathing screen (it still counts as completing the ritual).

### What it does NOT do
- No CTA buttons. No "Done" or "Close" or "Sleep" button. The user is meant to set the phone down, not interact.
- No navigation chrome (no back arrow, no tab bar). It's a fullbleed quiet screen.
- The system back gesture / hardware back button is allowed but unencouraged — the screen will dim itself.

### Animation timeline

Total cycle: 14 seconds. After it completes, hold the final state — do NOT loop in production. (The mock loops only because it's a design preview.)

| Phase | Timing | What happens |
|---|---|---|
| 1 | 0 → 3.0s | "Good night," and "{Name}." fade in from 6px below, opacity 0 → 1. The kicker "ROUTINE COMPLETE" appears above. |
| 2 | 3.0 → 5.6s | Hero held at full opacity. The breathing ember (single amber dot, gentle scale pulse) is visible the whole time. |
| 3 | 5.6 → 8.4s | The mid-sleep tip ("IF YOU WAKE TONIGHT — Open the menu and tap mid-sleep mode to fall back asleep.") fades in from 4px below, opacity 0 → 1. |
| 4 | 8.4 → 10.9s | Both hero and tip held visible. |
| 5 | 10.9 → 14s | Dim phase: a near-black overlay fades in (final state: rgba(12,8,7,0.86)); the amber background glow fades down to ~18% opacity; hero text fades to opacity 0.04; tip text fades to opacity 0.06. The ember **stays** at full brightness — its glow becomes the only thing left on screen. |
| Final | 14s onward | Stay in the dimmed state. The ember keeps breathing. The phone is now a single glowing dot in a near-black field. Auto-Lock / iOS's own screen-off can take it from here. |

**Important about transforms:** All visibility changes are `opacity`-only. Never animate `height`, `display`, or position — the layout must not shift as elements fade. The mid-sleep tip's content block exists in the DOM from t=0 with opacity 0; it does not pop in via mount.

**Reduced motion:** With `prefers-reduced-motion: reduce`, skip the dim phase entirely — show the bright state (hero + ember + tip all at opacity 1) and just hold there. The ember pulse animation should be removed too. Auto-Lock alone handles the dimming.

### Visual spec (390×844 reference frame)

Three elements, fixed positions relative to the artboard top — do **not** flex-center them; layout must be predictable so the hero never gets clipped by safe-area / notch:

**Hero title** — absolute top:220, left:32, right:32, text-align:center:
- Kicker: `ROUTINE COMPLETE` — monospace 10px, letter-spacing 0.18em, uppercased, amber-soft tint.
- Line 1 (22px below kicker): `Good night,` — Fraunces serif, weight 300, 52px, line-height 1.05, letter-spacing -0.03em, ink-0 (off-white).
- Line 2 (4px below line 1): `{Name}.` — Fraunces serif, weight 300, **italic**, 52px, amber accent color, with an amber `text-shadow: 0 0 32px <amber-glow>` for the warm halo.
- `{Name}` is the user's first name. If the user has not given a name, fall back to `you` (so it reads `Good night, you.`). Truncate at 14 chars; if longer, just render `Good night.` (no comma, no name).

**Breathing ember** — absolute top:470, horizontally centered:
- 14×14 amber circle, border-radius:999.
- Glow: `box-shadow: 0 0 48px <amber-glow>, 0 0 14px <amber>`.
- Pulse: `transform: scale(1)` ↔ `scale(1.18)` over 4 seconds, ease-in-out, infinite (only animation that continues into the final dim state).
- Sits above the dim overlay (z-index higher), so it visually shines through the darkening.

**Mid-sleep tip** — absolute top:580, left:32, right:32, text-align:center:
- A small pill above the body copy: lavender chip (`background: rgba(180,160,220,0.08)`, `border: 1px solid rgba(180,160,220,0.20)`, padding 6px 12px, border-radius 999), containing a small moon glyph + the kicker `IF YOU WAKE TONIGHT` in monospace 9.5px, letter-spacing 0.14em, lavender tint (`#b9aedc`).
- 14px below the pill: body copy — Fraunces serif 16px, weight 300, line-height 1.55, ink-1 (warm off-white), max-width 290 centered:
  > Open the menu and tap *mid-sleep mode* to fall back asleep.
  - The phrase "mid-sleep mode" is italic and amber-colored (matches the brand active-accent treatment).

**Background**:
- Same warm dark `LULL.bg` linear gradient the rest of the app uses.
- A large amber radial wash centered at 50%/48%, ~560px diameter, opacity 0.55 — fades to 18% during the dim phase.

### State & navigation

- The screen is presented modally over whatever ritual step preceded it. No tab bar visible.
- Tapping anywhere is a no-op for the first 6 seconds (so the user can't accidentally dismiss the moment they tap "I'm done"). After 6s, a single tap dismisses to the home screen — but if the user does nothing, the screen stays in its dimmed state until Auto-Lock kicks in.
- Going back via system gesture (iOS edge swipe) dismisses without animation.
- The ritual's completion is logged at the **start** of this screen, not at dismiss — so even if the user immediately turns the phone face-down, the routine counts as completed.

### Lifecycle

The user's `name` is sourced from settings (the same field used by the Today screen's morning greeting). Default `'you'` if unset.

```
NightlyGoodNight {
  // Inputs
  userName: string | null            // user's first name; null → "you"
  ritualCompletedAt: timestamp        // logged on screen mount; used for stats

  // Outputs
  onDismiss(): void                   // called on user tap (after 6s) or back gesture
}
```

---

## Change 2 — Update the Today-screen mid-sleep primer

The Today screen (evening state) currently has a "Mid-sleep mode" primer card with TWO activation paths displayed as rows:

1. ~~Shake your phone 3 times — "Fastest · works with eyes closed"~~
2. Menu › Mid-sleep mode — "From any screen"

**Remove row 1.** Shake-to-open is not built yet and the copy is misleading.

**Update row 2** to be the single, prominent activation row with this exact copy:
- Label: `Tap menu › Mid-sleep mode`
- Hint: `From any screen, any time of night`

Keep the row's existing visual treatment (lavender icon tile, lavender chip styling — consistent with the brand mid-sleep palette). Don't add a second row in its place; one prominent row reads as the canonical answer.

The "Try it now · preview" button below the row stays unchanged.

When shake-to-open ships in a future ticket, the row will be reinstated with both options.

---

## Change 3 — Mid-sleep mention on the Good night outro

The mid-sleep tip copy on `NightlyGoodNight` (spec'd above) reads:
> Open the menu and tap *mid-sleep mode* to fall back asleep.

Verify this matches the navigation actually available in the app. If the menu path is different in the production build (e.g. "More" tab, or a kebab menu icon), update the copy to match. The key constraint: the instruction has to be a path the user can actually follow in production — do **not** ship copy that references a feature that doesn't work yet.

---

## Acceptance criteria

A reviewer should be able to verify, in order:

1. Complete a bedtime ritual (Brain Dump → Boring Story, or whatever the user's last step is) and tap "I'm done" / let it finish.
2. The screen transitions to `NightlyGoodNight` — no abrupt cut, no jump-back to home.
3. Over ~3 seconds, "Good night, {firstName}." fades in (italic amber on the name). The ember below pulses gently.
4. Around 6 seconds in, the "If you wake tonight — open the menu and tap mid-sleep mode" tip fades in below the ember.
5. Around 11 seconds in, the screen darkens to near-black. The hero and tip become essentially invisible. The ember stays glowing.
6. The screen does not auto-navigate. The user can set the phone down and Auto-Lock handles screen-off.
7. Tapping in the first 6 seconds does nothing. Tapping after 6 seconds dismisses to home.
8. On the Today screen evening state, the mid-sleep primer card shows ONE activation row labeled "Tap menu › Mid-sleep mode" with hint "From any screen, any time of night." The shake row is gone.
9. With `prefers-reduced-motion: reduce`, `NightlyGoodNight` holds the bright state (hero + tip + ember all visible) and never dims. The ember pulse is also suppressed.
10. The ritual is logged as completed in analytics at the **start** of the outro screen, not on dismiss.

---

## Out of scope (do not implement)

- Shake-to-open mid-sleep mode (separate ticket — once that ships, the primer card adds the shake row back).
- Custom haptics during the outro screen (intentionally none — the goal is sensory minimalism).
- Persisting "I want to skip the good-night screen" as a setting. Everyone gets it.
- Auto-playing white noise or audio during/after the outro.
