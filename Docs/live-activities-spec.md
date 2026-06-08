# Lull — Implement the "Sleep Companion" Live Activity

Reference design: `'/Users/czarinacatambing/Downloads/Lull Live Activity.html'` (the design canvas in this project).
The relevant artboards are organized as three rows × four render sizes:

- **01 · Sleeping** — `sleep-lock`, `sleep-expanded`, `sleep-compact`, `sleep-minimal`
- **02 · Wake / Rate** — `wake-lock`, `wake-expanded`, `wake-compact`, `wake-minimal`
- **03 · Confirmation** — `confirm-lock`, `confirm-expanded`, `confirm-compact`, `confirm-minimal`

Plus reference cards: `Color`, `Type`, `Spacing & shape`, the rationale card for the ghost-numbered rating dots, and the motion-note card.

The HTML/JSX in this repo is a **design reference**, not production code. Build the real thing with `ActivityKit` + `WidgetKit` + SwiftUI. Match the visual fidelity of the mock (colors, type, spacing, motion) — but do not copy the JSX verbatim.

---

## What you're building
was
A single `Activity<LullSleepAttributes>` that runs from the user starting their sleep window through the morning rating confirmation. The Activity transitions through three `ContentState` cases — `sleeping`, `awaitingRating`, and `rated` — and each renders distinctly on the Lock Screen and in all three Dynamic Island presentations.

```swift
struct LullSleepAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        enum Phase: String, Codable { case sleeping, awaitingRating, rated }
        var phase: Phase
        var bedtime: Date            // when sleep window started
        var wakeTime: Date           // expected/actual wake time
        var rating: Int?             // 1...5, nil until phase == .rated
        var score: Double?           // composite sleep score, set with phase == .rated
        var deltaVsBaseline: Double? // e.g. +0.6 vs the user's recent baseline
        var experimentLabel: String? // e.g. "Weighted blanket · night 2 of 5"
    }
    // Static attrs set at start time
    var startedAt: Date
}
```

Lifecycle:
1. App starts the Activity at bedtime with `phase = .sleeping`. ActivityKit handles the countdown — use `Text(timerInterval:countsDown:)` so the iOS system updates the time without push.
2. At wake time (or when the user taps a "I'm awake" affordance elsewhere in the app), the app pushes an update flipping `phase = .awaitingRating`.
3. When the user taps a rating dot (anywhere — Lock Screen, DI expanded, in-app), the app writes the rating, computes the score, and pushes `phase = .rated`.
4. After ~6 seconds in `.rated`, the app calls `Activity.end(...)` with `dismissalPolicy: .after(Date.now + 4s)` so the confirmation lingers briefly then dismisses.

---

## Design tokens

Add a `LullLiveActivity` enum to your design tokens module (or extend the existing `LULL` palette if it already exists in Swift). Hex values match the mock exactly — do not eyeball.

```swift
enum LullLA {
    // Card fills (use ultraThinMaterial behind these for the Lock Screen blur)
    static let cardSleeping  = Color(hex: 0x0C0C12, alpha: 0.92)
    static let cardWake      = Color(hex: 0x1A120C, alpha: 0.96)
    static let cardConfirm   = Color(hex: 0x1A120C, alpha: 0.96) // same as wake, deeper closure feel via content
    // Ink
    static let ink0 = Color(hex: 0xF5E7D7) // primary
    static let ink1 = Color(hex: 0xE5D3BF) // secondary
    static let ink2 = Color(hex: 0xB9A691) // tertiary
    static let ink3 = Color(hex: 0x8A7A68) // mono labels
    static let ink4 = Color(hex: 0x5C4F42) // hairlines, dimmest text
    // Amber
    static let amber       = Color(hex: 0xF0B96B)
    static let amberSoft   = Color(hex: 0xD99A4A)
    static let amberDeep   = Color(hex: 0xA66A2A)
    static let amberGlow   = Color(hex: 0xF0B96B, alpha: 0.45)
    // Lines
    static let hairline    = Color(white: 1.0, opacity: 0.08)
}
```

Typography — register the fonts in `Info.plist` and the widget extension's `Info.plist`:

| Role | Font | Weight | Size |
|---|---|---|---|
| Countdown / score (display) | Fraunces Italic | 300 | 30 (Lock) / 22 (DI expanded) |
| DI compact value | Fraunces Italic | 400 | 14 |
| Prompt ("How did you sleep?") | Fraunces Italic | 300 | 22 |
| Body / button | Inter | 400 / 500 | 12.5–13 |
| Micro label ("WAKES IN", "GOOD MORNING") | JetBrains Mono | 500 | 9.5 with `.tracking(0.18 * .em)`, UPPER |

For the serif italic, use `Font.custom("Fraunces-Light", size: ...).italic()` (or wire to the variable axis if the font is installed as variable).

Spacing:

| Surface | Value |
|---|---|
| Lock card corner radius | 22 pt |
| Lock card padding | 16 pt |
| Lock card max height | 160 pt (hard cap — keep content under this) |
| DI expanded padding | 14 / 18 / 16 (top / sides / bottom) |
| Section divider | 12 pt above, 10 pt below, 1pt hairline |
| Rating button hit target | 44 × 44 pt (visible disc is 30 pt) |
| Rating row gap | 4 pt |

---

## State 1 — `sleeping` (the long state)

Visual mood: dim, restful, glanceable. The user may look at this at 3 AM — it should not jolt them.

### Lock Screen (`sleep-lock`)

A single rounded card.

- **Header row** (HStack, space-between):
  - Left: amber ember dot (`Circle().frame(width: 7).foregroundStyle(LullLA.amberSoft)` with a soft `.shadow(color: amberGlow, radius: 4)`) + the wordmark `lull` (Fraunces italic 300, 13 pt, `ink2`).
  - Right: monospace micro label `BEDTIME · 11:24` (use the user's actual bedtime). Never wrap — set `.lineLimit(1)`.
- **Body** (HStack, spacing 14):
  - 42 pt amber-tinted circle containing the moon glyph (SF Symbol `moon.fill` rotated -20° works; or ship a Lull-custom asset).
  - Right side: kicker `WAKES IN`, then the live countdown.
    - Use `Text(timerInterval: state.bedtime...state.wakeTime, countsDown: true)` — ActivityKit will tick this without us pushing. Style as Fraunces Italic 300 / 30 pt, `ink0`.
    - Below the countdown, mono 10 pt label with the wake time string (`6:48 AM`).
- **Footer row** (separated by 1 pt `hairline` top border, 12 pt above / 10 pt below):
  - Left: "Can't sleep?" label, 12.5 pt body, `ink3`.
  - Right: a small pill button titled "Mid-Sleep mode" that triggers `LullOpenMidSleepIntent` (see App Intents below). 32 pt tall, amber-tinted (`amber` @ 10% bg, `amber` @ 22% border), `ink1` text.

Card background should be `LullLA.cardSleeping` over `.ultraThinMaterial`. Add a faint amber radial glow in the top-right corner (`RadialGradient` from `amber @ 10%` → clear).

### Dynamic Island expanded (`sleep-expanded`)

ActivityKit splits expanded into `leading`, `trailing`, `center`, and `bottom` regions. Use:

- **`expandedLeading`**: 32 pt amber-tinted circle with moon glyph, then `VStack` of kicker `SLEEPING` (mono micro) and the `lull` wordmark.
- **`expandedTrailing`**: kicker `WAKES IN` over the countdown (Fraunces Italic 300 / 22 pt). Right-aligned.
- **`expandedBottom`**: HStack (space-between) — `"Awake at 3am?"` (12 pt, `ink3`) and the Mid-Sleep button (same intent as Lock).

Do **not** use `center` — the bottom row reads better when the countdown isn't competing with a center element.

### Dynamic Island compact (`sleep-compact`)

- **`compactLeading`**: moon glyph at 18 pt, amber.
- **`compactTrailing`**: the countdown as `Text(timerInterval: ..., countsDown: true)`, Fraunces Italic 400 / 14 pt, `ink0`. iOS will truncate to fit — that's OK, the canonical render is `6h 42m`.

### Dynamic Island minimal (`sleep-minimal`)

- **`minimal`**: just the moon glyph at 16 pt in `amber`. Nothing else fits.

---

## State 2 — `awaitingRating` (warmer, inviting)

Visual mood: gently brighter, warmer wash, not "morning energy" loud.

### Lock Screen (`wake-lock`)

- **Header row**: sunrise glyph (SF Symbol `sun.horizon.fill` in `amber` works, or ship a Lull-custom asset) next to the wordmark; right side mono label `GOOD MORNING · 6:48`.
- **Headline**: `"How did you sleep?"` in Fraunces Italic 300 / 22 pt, `ink0`. 10 pt top margin.
- **Rating row** — the primary action. **Ghost-numbered amber dots.** Five `Button`s, each 44 × 44 hit area. Visual disc is 30 pt, with the numeral `1`–`5` rendered in Fraunces Italic 400 / 13 pt inside.
  - Unfilled: clear background, 1.4 pt border in `amber @ 35%`, numeral in `amberSoft`.
  - Filled (when `idx < rating`): amber fill, 1 pt `amberSoft` border, numeral in `#1A0D06` (the on-amber ink), soft amber glow shadow.
  - The whole row is a `radiogroup` for VoiceOver; each button is `.accessibilityLabel("Rate \(n) of 5: \(label)")` where labels are `Wrecked, Rough, OK, Good, Great`.
- **Anchor labels**: below the dots, two mono 8 pt labels `ROUGH` (left-aligned) and `RESTED` (right-aligned), `ink3`.

### Dynamic Island expanded (`wake-expanded`)

- **`expandedLeading`**: 32 pt amber-tinted circle with sunrise glyph + `VStack`(`GOOD MORNING` kicker, "rate last night" in Fraunces italic 15 pt).
- **`expandedTrailing`**: `SLEPT` kicker + the elapsed sleep duration (e.g. `7h 24m`) in Fraunces italic 16 pt.
- **`expandedBottom`**: the rating row. Important: **here the dots are BARE** (no numerals). The user has already opened the activity to get to this row — discoverability is no longer the constraint, and numerals would crowd the row at DI width. Visual disc 22 pt, 44 pt hit area.

### Dynamic Island compact (`wake-compact`)

- **`compactLeading`**: sunrise glyph 18 pt.
- **`compactTrailing`**: `Rate` in Fraunces italic 13 pt + ` 1–5` in mono 10 pt, `amber`. Tappable — opens the app to the in-app rating sheet (we don't try to fit five buttons in the trailing pill).

### Dynamic Island minimal (`wake-minimal`)

- **`minimal`**: sunrise glyph at 16 pt.

---

## State 3 — `rated` (closure, dismisses)

Visual mood: closure, satisfaction. Shown for ~6 seconds, then the Activity dismisses.

### Lock Screen (`confirm-lock`)

- **Header**: wordmark on the left, mono label `SAVED · 6:51 AM` on the right.
- **Body** (HStack, 14 pt spacing):
  - 42 pt amber-tinted circle containing a checkmark inside an amber ring (custom view — see `CheckGlyph` in the mock).
  - Right side: a single line of body copy `"Thanks — your score is ready"` (14 pt, `ink1`), then a baseline-aligned HStack:
    - `Text(score, format: .number.precision(.fractionLength(1)))` in Fraunces italic 22 pt.
    - The delta in mono 10 pt, `amberSoft`: `+0.6 VS WED` (sign + value + the day-name of the comparison baseline).

No footer row, no buttons.

### Dynamic Island expanded (`confirm-expanded`)

- **`expandedLeading`**: 28 pt check glyph + `VStack`(`SCORE READY` kicker, "thanks — saved" in Fraunces italic).
- **`expandedTrailing`**: the score in Fraunces italic 26 pt, with the delta in mono 9 pt `amberSoft` below.

### Dynamic Island compact (`confirm-compact`)

- **`compactLeading`**: check glyph 18 pt.
- **`compactTrailing`**: score in Fraunces italic 14 pt + delta in mono 9 pt `amberSoft`.

### Dynamic Island minimal (`confirm-minimal`)

- **`minimal`**: check glyph 16 pt.

---

## App Intents (the only interactivity)

iOS 17+ Live Activities accept `AppIntent`s on Button taps. Add two:

```swift
struct LullOpenMidSleepIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Open Mid-Sleep mode"
    // Use openAppWhenRun = true; we want the app foregrounded for the
    // mid-sleep tools (breathing, boring story, body scan).
    static var openAppWhenRun: Bool = true
    func perform() async throws -> some IntentResult {
        // Deep-link to /midsleep on launch. App handles the route.
        return .result()
    }
}

struct LullRateSleepIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Rate last night"
    @Parameter(title: "Rating") var rating: Int
    // Run in-place — do NOT foreground the app for taps 1–5.
    // We want the rating to feel like it happens on the Lock Screen.
    static var openAppWhenRun: Bool = false
    func perform() async throws -> some IntentResult {
        // 1. Persist the rating via the shared app-group container.
        // 2. Kick off a background task that computes the score and
        //    pushes the .rated update to the Activity.
        return .result()
    }
}
```

Two important details:

- `LullRateSleepIntent` **must not** open the app. The "tap once, glance at confirmation, go make coffee" loop is the entire interaction. If iOS opens the app, the loop is broken.
- The score computation may take a moment. Render the tapped state immediately (filled dots up to `n`) by updating the Activity content state to a transient `.awaitingRating` snapshot with `rating: n` set, then push `.rated` once the score is ready. The mock's "300ms confirmation crossfade" assumes the score is ready by the time the dots have finished filling.

---

## Motion

Live Activity updates animate via `numericText()`, `contentTransition`, and the implicit cross-fade ActivityKit does when content state changes. Aim for these effects:

| Transition | Effect | Timing |
|---|---|---|
| `sleeping` → `awaitingRating` | Card tint warms `#0C0C12` → `#1A120C`. Moon glyph crossfades to sunrise glyph (both anchored at the same 32 pt circle). Countdown crossfades to the prompt. Rating row fades up from 0 underneath. | 900 ms ease-in-out |
| Rating tap | Dots 1..n fill with amber. The tapped dot scales to 1.06 then back to 1.0. | 220 ms ease-out per dot, staggered 30 ms |
| `awaitingRating` → `rated` | The five dots collapse into a single filled dot at the rating position. That dot morphs into the check circle. The score cross-fades in from the right where the countdown used to live. | 400 ms ease-out |
| Auto-dismiss | After 6 s in `.rated`, fade entire card to 0. | 600 ms ease-in |

For `prefers-reduced-motion`, replace all of the above with a plain 200 ms opacity crossfade and drop the scale-on-tap. No springs anywhere — Lull's motion is always slower than the user expects.

---

## Acceptance criteria

A reviewer should be able to verify, in order:

1. **Starting the Activity** at the user's bedtime puts a card on the Lock Screen that matches `sleep-lock` pixel-for-pixel within ±2 pt. The countdown ticks once per minute without any push from the server (it's using `Text(timerInterval:)`).
2. **Long-pressing** the Dynamic Island in any state opens the expanded view; the leading/trailing/bottom regions match the corresponding `*-expanded` artboards.
3. **Compact + minimal** renders match their artboards. The minimal slot is just a single 16 pt glyph and nothing else.
4. **Wake transition**: at wake time, the card warms in place, the moon→sunrise crossfade plays, and the prompt `How did you sleep?` appears with five ghost-numbered amber dots. No layout shift, no slide, no spring.
5. **Tap dot 4 on the Lock Screen**: dots 1–4 fill with amber in a 30 ms-staggered sweep, the rating is persisted, the app is **not** foregrounded.
6. **`rated` state appears** within 400 ms of the tap, showing the score (Fraunces italic) and the delta (`+0.6 VS WED`). The card auto-dismisses 6 s later.
7. **Mid-Sleep button** on `sleep-lock` and `sleep-expanded` foregrounds the app and routes to `/midsleep`.
8. **VoiceOver**: each rating dot is announced as `"Rate 3 of 5: OK"` etc. The five-dot row is a single `radiogroup` labeled "How did you sleep?".
9. **`prefers-reduced-motion`**: all crossfades are replaced with opacity transitions; no scale-on-tap, no glow pulse.
10. **Both color schemes**: Lock Screen card stays warm-dark in both Light Mode and Dark Mode (Live Activities do not auto-invert, and the warm dark holds up over light wallpapers).

---

## Out of scope (do not implement)

- Push-based remote updates for the wake transition — the app handles transitions locally for v1 (the user's phone knows their wake time). Remote updates are a follow-up ticket.
- A "snooze the rating" affordance. If the user dismisses the wake-state card without rating, the Activity ends silently and the rating is captured the next time the user opens the app.
- The full in-app rating sheet that opens from the DI compact `Rate` tap — that lives in the existing `MorningRateHero` component on the Today screen.
- Lull-branded custom glyphs for moon / sunrise / check beyond what SF Symbols can provide. We'll polish the glyphs in a follow-up once the core flow is shipping.
- watchOS / iPad complications. iPhone Lock Screen + Dynamic Island only for v1.
