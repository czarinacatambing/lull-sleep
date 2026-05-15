# Lull — Implement two changes from the design mockup

Reference design: @'/Users/czarinacatambing/Downloads/Lull iOS Mockups.html' (the design canvas in this project).
The relevant screens are in the **Today & routine** section, artboards:
- `Today · EVENING · pre-bed` (existing baseline)
- `Today · MORNING · rate hero (RECOMMENDED)` (new)
- `Today · MORNING · after rating · +1 vs yesterday` (new)

The HTML/JSX in this repo is a **design reference**, not production code. Use the codebase's existing component library, design tokens, and state-management patterns. Match the visual fidelity of the mock (colors, type, spacing, motion) — but do not copy the JSX verbatim.

---

## Change 1 — Rename "Tonight" → "Today" in the bottom tab bar

**Where:** The bottom navigation has two tabs. The first tab is currently labeled "Tonight." Rename it to **"Today"**.

**Keep:**
- The crescent-moon icon (Lull's sleep mark — works regardless of time of day).
- The active-tab color treatment (amber glow on the icon + label).
- Order: `Today` first, `Routine` second.

**Update everywhere the user-facing string appears:**
- Tab label
- Any deep-link or analytics event names referring to "tonight tab" → rename to `today_tab` (or equivalent in your naming convention)
- Any push-notification copy that says "Open Tonight" → "Open Today"

**Rationale:** "Tonight" reads as evening-only. The screen is now time-of-day aware (morning rating + evening wind-down both live there), so the label needs to span the full day.

---

## Change 2 — Morning state on the Today screen, with a rate-last-night hero

The Today screen currently lands evening users on a "Good evening, let's wind down" view (prep checklist, tonight's ritual, ritual sequence). Add a **morning state** with a different layout.

### When to show the morning state

Show morning state if **both** are true:
1. Current local time is between user's wake time and `wakeTime + 4 hours` (default wake time = 7:00 AM if user hasn't set one).
2. The user has not yet rated last night's sleep (no rating row exists with `date = today` in local time).

If either condition is false, render the existing evening state.

Edge case: if a rating already exists for today (user woke up earlier and rated), still render morning state until `wakeTime + 4h`, but show the "rated" variant of the hero (with the result chip — see below). After that 4-hour window, fall through to the evening state.

### Morning state layout (top → bottom)

1. **App chrome** — same brand mark + hamburger as the evening state.
2. **Greeting block:**
   - Kicker (small caps, monospace): the current day-name + time. e.g. `SUNDAY · 6:42 AM`.
   - Headline (serif, light, 32px, line-height 1.1):
     `Good morning,` newline `<em>how did you sleep?</em>` (the italic phrase is the lighter secondary text color).
3. **`MorningRateHero` card** (the primary action — see component spec below).
4. **`TonightPreviewCard`** (a quieter card showing what's set up for tonight — see spec below).
5. **Bottom tab bar** (same as evening; "Today" tab is the active one).

The evening state's prep checklist, ritual hero, ritual sequence card, and mid-sleep mode primer are **not rendered** in morning state.

---

### Component: `MorningRateHero`

A single elevated card. Amber-themed (matches the brand's warm tone). Two visual states: **unrated** and **rated**.

**Props:**
- `wakeTime: string` (e.g. `"6:42 AM"`)
- `yesterday: number | null` — yesterday's rating (1–5)
- `rating: number | null` — today's rating
- `onRate(n: number): void`

**Layout (unrated):**
- Padding: 20px sides, 20px top, 18px bottom.
- Border-radius: 24px.
- Background: warm amber radial gradient — top edge ~16% amber tint fading to ~2% at bottom.
- Border: 1px solid amber at ~42% opacity.
- Drop shadow: large soft shadow + inset highlight on top edge for tactility.
- A pulsing radial glow positioned top-right of the card (220px circle, 4.5s ease-in-out pulse, amber).

**Card header row** (flex, space-between, baseline-aligned):
- Left: small amber-disc icon (24px circle, sun glyph inside, amber glow) + the kicker text `GOOD MORNING` in the amber-soft tint.
- Right: monospaced wake-time string (e.g. `6:42 AM`), uppercased, letter-spaced 0.14em.

**Headline:** Serif, 26px, weight 400. Copy:
- Unrated: `How did last night go?`
- Rated: `Logged — <em>nice.</em>` (the italic word is amber)

**Supporting text** (unrated only): 13px body color, "One tap. We'll show you how it compares to yesterday."

**The dot row — the actual rating control:**
- 5 buttons, evenly spaced flex row, gap ~8px.
- Each: 44×44 circle. Border 1.5px. Numeric label `1`–`5` in serif 15px inside.
- Unselected state: dark fill (rgba(12,8,7,0.4)), border in amber-tinted offwhite at increasing opacity from dot 1 (0.22) → dot 5 (0.42) so the row visually slopes from "muted" to "bright."
- Selected/in-range state (dot `n ≤ rating`): radial amber-fill gradient, glowing amber shadow, dark text. The currently-tapped dot also scales to 1.06.
- Hit target: full 44×44.

**Scale labels:** below the dot row, monospace 9.5px, letter-spaced 0.14em, ink-3 color, justified left and right: `WRECKED` … `GREAT`.

**Result chip (rated state only):** A horizontal mini-card below the dots:
- Background: rgba(12,8,7,0.45), border in default line color, 14px radius, 12×14 padding.
- Left: 36×36 rounded square with up/down arrow glyph in amber.
- Body: a sentence based on `rating - yesterday`:
  - `>0`: `+N vs yesterday — the weighted blanket might be working.`
  - `=0`: `Same as yesterday. Two more nights to call it.`
  - `<0`: `-N vs yesterday. We'll watch this trend.`
- Footnote (monospace, amber-soft, 9.5px, uppercased): `NIGHT 2 OF 5 · WEIGHTED BLANKET TEST` — this is the active experiment context; pull from the user's current experiment.

**Behavior:**
- Tapping a dot calls `onRate(n)` and immediately fills dots 1..n with the amber gradient (no submit step).
- The rating is persisted to the backend on tap (optimistic UI; revert on failure).
- The card morphs into "rated" state with the result chip in a 250ms fade. No layout shift outside the chip area.
- Re-tapping a different dot updates the rating.
- After a rating exists, the card stays in "rated" form for the rest of the morning window.

**Accessibility:**
- Each dot has `aria-label="Rate <n> of 5: <label>"` where labels are `Wrecked, Rough, OK, Good, Great`.
- The whole rating row has `role="radiogroup"` with the headline as its label.
- Visible focus ring on keyboard nav.
- Honors `prefers-reduced-motion`: kill the pulsing radial glow and the scale-on-tap animation.

---

### Component: `TonightPreviewCard`

A muted, informational card that sits beneath the rate hero. Tells the user "tonight is already taken care of" so they're not anxious about planning at 6:42 AM.

**Props:**
- `rated: boolean` — bumps opacity from 0.85 → 1.0 once they've rated (subtle reward).

**Layout:**
- Background: ~2.5% warm-tinted white over the page background (rgba(255,220,190,0.025)).
- Border: default line color.
- Border-radius: 18px.
- Padding: 16×18.

**Header row** (flex, space-between):
- Left: small kicker `TONIGHT IS ALREADY SET UP`.
- Right: monospace `STARTS 8:14 PM`, ink-3.

**Title:** Serif 18px. `Weighted blanket <em>· night 2 of 5</em>` (the italic suffix is the secondary text color). Pull the experiment name and night-progress from the user's active experiment.

**Schedule rows:** A 3-row vertical list, gap 6px. Each row has:
- A 38px-wide monospaced timestamp (`7:34`, `8:14`, `8:16`)
- An ember dot (3px solid amber disc — already in the design system as `<Ember size={3} />`)
- The label text (`Weighted blanket out`, `Brain dump · 2 min`, `Boring story · AI · ~8 min`)

The schedule data is the user's routine for tonight. The shown rows are the first three actionable items in chronological order.

**Footer row** (separated by a 1px top border, flex space-between):
- Left, monospace 10px: `We'll remind you at 7:34 PM` (uses the first row's time).
- Right, monospace 10px amber-soft text button: `EDIT IN ROUTINE →` — taps over to the Routine tab.

---

### State / data requirements

The Today screen needs:
- **Current local time** — to pick morning vs evening state.
- **User's wake time** — settings field. Default 7:00 AM.
- **Today's sleep rating** — query rows where `date = today (local)`. If present, hero is in "rated" state; if missing, "unrated."
- **Yesterday's sleep rating** — to compute the delta chip.
- **Active experiment** — current variable being tested (e.g. "Weighted blanket") and its progress (e.g. night 2 of 5). Used in the rate-hero result chip and the tonight-preview title.
- **Tonight's routine** — list of routine steps with timestamps, used by `TonightPreviewCard`.

Submitting a rating:
- POST to the ratings endpoint with `{ date: today, value: n, experiment_id }`.
- Optimistic UI update. On failure, revert and toast an error.

---

### Acceptance criteria

A reviewer should be able to verify, in order:

1. The bottom tab labeled "Tonight" now says "Today." Active-state styling is unchanged. Tapping it still routes to the same screen.
2. Opening the app at 6:42 AM (with wake time set to 6:30 AM and no rating recorded for today) shows the morning state: greeting reads "Good morning, how did you sleep?", `MorningRateHero` is visible with 5 large tappable dots, no prep checklist or ritual hero is shown.
3. Tapping dot 4 fills dots 1–4 with the amber gradient, dot 4 scales briefly, the result chip appears reading `+1 vs yesterday — the weighted blanket might be working.` (when yesterday was 3). A rating row is written to the database with `date = today, value = 4`.
4. Reloading the app (still inside the morning window) renders the morning state in its rated variant, with the same delta chip.
5. Opening the app at 9:00 PM (outside the morning window) renders the existing evening state.
6. With `prefers-reduced-motion: reduce`, the pulsing glow on the hero is static and the dot-tap scale animation is removed.
7. Keyboard users can Tab into the dot row, arrow-key between dots, and Space/Enter to submit. `aria-label`s are announced correctly by VoiceOver.

---

### Out of scope (do not implement)

- Push notification scheduling for the morning prompt (separate ticket).
- The Routine-screen variants of the rating UI (`pulseDot`, `inlineStep3`, `morningHero`) — those are alternate explorations from the mock and were rejected in favor of the Today-screen approach.
- The "BIG celebration" promotion screen — separate flow.