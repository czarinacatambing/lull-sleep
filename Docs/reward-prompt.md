Implement two distinct celebration moments with different intensity. Reference @/Users/czarinacatambing/Downloads/midsleep-2.jsx : see MorningReward (mini), RoutinePromoted (big), and the shared Confetti component which takes a variant prop.

## When each fires
1. Mini celebration — fires inside the Morning check-in reward state, only when today.score > yesterday.score (compares today vs. yesterday, not the long-term baseline). Steady (=) and off-night (▼) show the same screen layout with no confetti.
2. Big celebration — fires as a standalone full-screen moment the first time the user opens the app after an experimental variable graduates into their core routine. Promotion criteria (already defined elsewhere in your system): N successful test nights with positive lift. After dismissal, the variable shows in the routine list with a "Recently promoted" pill for a week.

## Confetti behavior — shared component, two variants
Both originate bottom-center of their container and pop upward with a fan-shaped spread. Difference:
|                | **Mini**                          | **Big**                                      |
|----------------|-----------------------------------|----------------------------------------------|
| Pieces         | ~22                               | ~90                                          |
| Fan angle      | ±55° from vertical                | ±70°                                         |
| Peak distance  | 60–110px                          | 240–460px                                    |
| Duration       | 1.4–2.0s                          | 3.2–5.2s                                     |
| Container      | Inside the score card (overflow: hidden) | Full screen, falls past viewport        |
| After peak     | Brief settle + fade out in place  | Continues falling 130vh with horizontal drift |
| Loop           | Yes, restarts per cycle           | Yes, continuous                              |

Colors: amber, coral, mint, lavender, sky, soft cream — mixed. Shapes: rects, circles, thin streaks. Each piece has a soft same-color glow. Honor prefers-reduced-motion (replace with a static colored bloom + slow opacity pulse).

## Mini celebration screen — Morning reward layout
Replaces the existing "improved/flat/worse" copy with a single layout driven by today vs yesterday:

Kicker (top): "Better than yesterday" / "Logged · steady" / "Logged · off-night".
Centered score card (this is where the mini confetti lives):
Big serif: {score}/5
Pill below: ▲ +{delta} vs yesterday (amber) / = same as yesterday (muted) / ▼ {delta} vs yesterday (cool grey).
Headline (italic accent):
improved: "That's better than yesterday."
steady: "Steady night. Two more like it and we'll promote a variable."
off: "Off-night happens. We'll keep testing."
Caption row (mono): YESTERDAY {y} · TODAY {t} · BASELINE {b}
"Tonight's experiment" card: which variable is being tested, night X of 5.
Primary CTA: See tonight's plan. Ghost: Add a note · woke at 4am.
Top-right ↻ RE-RATE chip (only available before noon).
## Big celebration screen — RoutinePromoted
Standalone screen with full-bleed confetti. Layout (top to bottom):

Header: brand mark + dismiss ✕ (top-right).
Kicker: "Promoted to your routine"
Hero medallion: 88px amber radial-gradient circle with a star glyph and big amber glow.
Headline: "{variable name}" (italic amber) + "earned its place."
Body: "{N} test nights. Average lift +{lift} on your sleep score. It's now part of your core routine."
Evidence card — amber-bordered: kicker "Evidence · last {N} nights", right-aligned chip "+{lift} AVG", and a 7-column bar sparkline of the recent score history with promoted nights filled amber and glowing.
Primary CTA: Lock it in (with glow). Ghost: Keep testing for another week.
## Behavior
Mini celebration is a state inside the morning flow — never blocks navigation. Score persists immediately on tap, confetti is decorative.
Big celebration is a one-time modal screen queued by the promotion system. On dismiss or "Lock it in", route to the routine screen and pulse the promoted item briefly.
Both screens are skippable (any tap on a CTA or the dismiss closes them).
## Styling
Use existing tokens; no new colors. Match the spec exactly — keep the confetti's bottom-up trajectory (it's the brand feel of "lifting" sleep). Don't fall-from-top.