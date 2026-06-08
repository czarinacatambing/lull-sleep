# Paywall Design Brief — Night 5 Verdict & Premium Flow

---

## What this is

The Lull v1 paywall fires once: on the morning after a user completes night 5 of their first 5-night sleep experiment. The user has just submitted their morning rating; the app then walks them through a chronotype reveal, shows them a partially-blurred verdict card, and asks them to subscribe — or share to unlock — or stay free.

This brief covers all the screens in that flow plus a few supporting surfaces (the share-card image, Settings upgrade row, day-14 re-engagement). Everything should feel like the same restrained, data-card-not-mascot app the onboarding flow established.

---

## Brand recap (match exactly)

Reuse the tokens, typography, and voice from `Docs/onboarding-design-brief.md`. The short version:

- Dark mode only. `lullBg` `#0c0807` page background; warm-tinted card surfaces.
- **Fraunces** for headlines + numerals. **JetBrains Mono** for kickers + small data labels. System sans for body.
- `lullAmber` `#f0b96b` accent used sparingly. `AmberGlow` halos to draw the eye.
- Hedged voice ("most closely matches"), no exclamation marks, no emoji, no mascots, no horoscope language.
- Reference screens: `OnbRoutineReadyView`, `OnbBedtimeView`, `OnbBaselineRatingView`.

If any token decision conflicts with the onboarding brief, the onboarding brief wins.

---

## The flow at a glance

```
Morning of day 6 — user submits night-5 rating sheet
   ↓
Screen 1: Quiet transition (1.5s)
   ↓
Screen 2: Chronotype reveal — identity hook held back from onboarding
   ↓
Screen 3: Blurred verdict card — single CTA
   ↓
   [Unlock] → Screen 4: Pricing sheet (benefits + plans)
                 ↓
                 ├─ [Subscribe] → Apple payment → Screen 7a: Unlocked verdict (PREMIUM)
                 │                                            · Full verdict shown
                 │                                            · "Start tonight" CTA → experiment 2
                 │                                            · All premium features active
                 │
                 └─ [Not now]   → Screen 5: Share-to-unlock prompt
                                     ↓
                                     ├─ [Invite a friend] → Screen 5a: SMS compose (system)
                                     │                       ↓ .sent
                                     │                      Screen 7b: Unlocked verdict (SHARE-ONLY)
                                     │                                  · Full verdict shown
                                     │                                  · NO new experiment
                                     │                                  · NO premium features
                                     │                                  · "Subscribe to keep going" upsell
                                     │
                                     ├─ [Post publicly]  → Screen 5b: UIActivityViewController (system)
                                     │                       ↓ completed:true
                                     │                      Screen 7b: Unlocked verdict (SHARE-ONLY)
                                     │
                                     └─ [No thanks]    → Screen 8: Free-forever explainer
                                                          · Static routine, morning logging
                                                          · Verdict stays blurred forever
                                                          · No premium features

Note: negative-verdict variant of Screen 3 uses the same flow with reframed copy.

Outside the main flow:
Screen 9: Settings → "Upgrade to Lull Premium" row + sheet
Screen 10: Day-14 re-engagement prompt (for free-forever users only)
```

Ten screens total. Two are existing-system (Apple payment sheet, native share sheet) so they don't need design — they're called out so you know where they fit.

---

## Screens to design

### 1. Quiet transition (NEW)

**Position:** fires immediately after user taps "Submit" on the night-5 morning rating sheet. Auto-advances after ~2s. No interaction.

**Job:** raise the curtain. Tell the user "something different is happening" without saying it loudly.

**Content:**

```
[Full-screen dark background, soft amber glow centered]

[Mono caps, low contrast, fades in at ~0.3s]
                              NIGHT 5

[Brief pause, ~1s]

[Mono caps, second line fades in at ~1.5s]
                              YOUR VERDICT IS READY
```

**Feel:** stillness. No button, no progress indicator. The screen exists only to break the user out of the morning-routine pattern before the chronotype reveal lands. Same posture as the start of the onboarding 4-7-8 — quiet, deliberate, low-contrast.

**Don't:**
- Add a logo, loading spinner, or progress bar.
- Use motion beyond the slow fade-ins.
- Make the second line longer than four words.

---

### 2. (REMOVED — merged into Screen 3)

The earlier draft had a separate "Chronotype reveal" screen at this position. **It was merged into Screen 3** once the chronotype became gated. With the name no longer revealed for free, a dedicated screen for it was just pacing without payoff — the blurred chronotype lives on Screen 3 as the top section of the gated portion. The original screen numbering is preserved below so cross-references in the rest of the doc (and in the engineering plan) don't drift.

---

### 3. Blurred verdict card (NEW — the gravitational center)

**Position:** auto-follows the transition screen (Screen 1) directly.
**Job:** show the user enough that they're curious, blur the parts that drive the conversion. This is the paywall.

**Structure:** the card has two zones. The **top zone** holds information the user already knows from onboarding (so showing it isn't a tease — it's continuity). The **bottom zone** holds everything the user has earned by completing 5 nights but hasn't paid to see. The zones are visually separated; how that separation reads is a design decision.

**Screen title:** "Your 5-night verdict"

**Top zone (always visible — info the user already knows):**

| Element | Content |
|---|---|
| Diagnosis | "Pre-sleep rumination" *(the bottleneck revealed at onboarding)* |
| Diagnosis note | "Confirmed across 5 nights" |
| Experiment | "Brain Dump · 12 min before bed" *(the variable they actually ran)* |

The top zone exists so the user can immediately confirm: *"yes, this is mine — this is what I just spent 5 nights doing."* Continuity, not a tease.

**Bottom zone (all blurred):**

| Element | Free state | Subscriber sees |
|---|---|---|
| Sleep pattern (chronotype) | Blurred name | e.g. "Late Sleeper" |
| Result — score delta | Blurred | e.g. "Your wired-score shifted by +1.4" |
| Result — verdict word | Blurred | e.g. "Verdict: This worked for you." |
| How you compare (aggregate) | Blurred — *including the chronotype name embedded in the sentence, to prevent leaking it via this line* | e.g. "68% of Late Sleepers who tested Brain Dump also improved." |
| What to try next (recommendation) | Fully blurred | e.g. "Dim lights to <50 lux 60 min before bed for the next 5 nights." |

**CTA:**

- Label above the CTA: **"Unlock your verdict"** (or equivalent — designer call on exact phrasing if a cleaner version exists)
- Button: **"Unlock"**
- Tapping "Unlock" opens Screen 4 (the pricing sheet)
- **No second CTA on this screen.** Rejection happens on Screen 4, after the user has seen what they're declining.

**Per-outcome copy variant — one line appears between the bottom zone and the CTA:**

| Outcome | Line |
|---|---|
| Positive | "5 nights, one variable, one real answer. Unlock to see what worked." |
| Neutral | "Your data was close to the line. Unlock to see exactly where, and what to try next." |
| Negative | "Whether tonight worked or didn't, this is the data we'll use to pick your next experiment." |

Three voice tones, same structural card. The negative variant is the most important: it reframes "this didn't work" from a refund-feel into a diagnostic-value-feel. Paywalling negative results without this reframe torches trust.

**Blur content notes (not design directives):**

- Blurred numeric values should still suggest *that a number exists* — the user sees a measurement-shaped thing they can't read.
- Blurred phrases (e.g. the verdict word) should suggest *that a result exists* — sentence-shaped.
- The chronotype name embedded in the aggregate-comparison sentence must blur **the same way** as the standalone chronotype line. Otherwise the user could compare the two blur widths and reverse-engineer the name.

**Don't (content-level rules, not visual ones):**

- Don't add a second CTA, escape link, or back button. Rejection happens on Screen 4.
- Don't expose any blurred value as text the user can copy/inspect (engineering note — make sure the actual chronotype string isn't shipped to the device for free users; the blur must be real withholding, not a visual mask over readable data).

---

### 4. Pricing sheet (NEW)

**Position:** opens as a sheet (half-modal or full-screen on smaller devices) when the user taps "Unlock" on the blurred verdict card.
**Job:** present the two plans, let the user pick, hand off to Apple payment.

**Content:**

```
[Kicker, mono caps]            UNLOCK YOUR VERDICT

[Plan toggle — segmented control, full-width]
                               [ ANNUAL ]    [ MONTHLY ]
                               (annual selected by default, amber background)

[ANNUAL state shown]
[Serif, very large]            $99.99 / year
[Mono small]                   $8.33 / month · billed annually

[MONTHLY state, on toggle]
[Serif, very large]            $14.99 / month
[Mono small]                   $179.88 / year equivalent · save $80 with annual

[Hairline]

[Section label, mono caps]     LULL PREMIUM INCLUDES
[Bulleted list, sans]
  · Today's full verdict + sleep pattern reveal
  · A new experiment every 5 nights with recommended variable
  · How you compare to people like you (aggregate data)
  · Sleep sounds (7 ambient tracks)
  · App blocking during wind-down
  · Add or customize routine steps
  · Guided meditation (coming soon)

[Primary CTA]                  Subscribe · $99.99 / year
                                (button label updates with toggle)

[Ghost CTA, centered]          Not right now

[Ghost link, small, very low contrast]
                               Restore purchase

[Mono small, very low contrast, at bottom]
                               Cancel anytime. Renews at $99.99/year.
                               Terms · Privacy
```

**Design intent:** the toggle is the dominant interaction. Default to annual; make sure switching to monthly visibly *de-emphasizes* the savings (e.g., the "$80 saved" callout grays out or moves to a smaller line). The premium-includes list is bulleted, mono-bullet style, not iconized — feels like a spec sheet, not a marketing flyer.

**CTA hierarchy:**
- **Subscribe** (primary, filled, full-width) — handles the actual purchase via Apple's payment sheet
- **Not right now** (ghost, centered below) — dismisses the sheet AND routes the user directly to Screen 5 (Share-to-unlock prompt). This avoids the friction of "dismiss → back to Screen 3 → tap Not right now there." Pricing-sheet rejection and verdict-card rejection lead to the same place: Share-to-unlock.
- **Restore purchase** (tertiary ghost link, very low contrast, smallest text) — for returning subscribers. Should be findable but not visually weighted alongside the primary path.

**Two states to design:**
1. Annual selected (default)
2. Monthly selected

**Don't:**
- Add testimonials, star ratings, or social proof on this screen. The verdict card behind it already did that job — the blurred chronotype + blurred result are the curiosity hook driving conversion. Adding generic social proof here dilutes the specific-to-you mechanic.
- Add a "Most popular" badge on annual. It's already visually weighted; further pressure feels desperate.
- Add a third or fourth plan option. Two only.

---

### 5. Share-to-unlock prompt (NEW)

**Position:** opens when the user taps "Not now" on Screen 4 (Pricing sheet). The only entry into this screen — there is no "Not right now" on Screen 3 anymore. Users always see the pricing benefits before being offered the share path.
**Job:** offer two equal-weight share paths as the alternative to paying. The user picks their lane — invite a single friend via SMS (verified by iOS), or post publicly to social (best-effort verification). Both unlock identically.

**What sharing unlocks vs. what subscribing unlocks** — *the user needs to understand this implicitly, but don't beat them over the head with it*:

- **Sharing unlocks the verdict** (this one, just for tonight). Screen 7b is what they land on. No premium features, no new experiments.
- **Subscribing unlocks the platform** (verdict + new experiments + sleep sounds + app blocking + routine customization). Screen 7a.

The screen below frames sharing positively without selling premium against it. The upsell happens *after* the share completes (on Screen 7b), not here — sharing should feel like a genuinely good alternative in this moment, not like a consolation prize.

**Content:**

```
[Kicker, mono caps]            ONE MORE WAY

[Serif headline]               Share to unlock.

[Body, sans]                   Pick one — same result either way.

[Two stacked option cards, equal weight, full-width]

  ┌─────────────────────────────────────────────────┐
  │ [Kicker, mono caps]   INVITE A FRIEND           │
  │ [Sans]                Send a quick message via  │
  │                       iMessage or SMS. We'll    │
  │                       confirm with iOS when it  │
  │                       sends.                    │
  │ [Right-aligned chevron, amber]               →  │
  └─────────────────────────────────────────────────┘

  ┌─────────────────────────────────────────────────┐
  │ [Kicker, mono caps]   POST PUBLICLY             │
  │ [Sans]                Share your card to X,     │
  │                       Instagram, Threads, or    │
  │                       Reddit. We unlock once    │
  │                       the share opens.          │
  │ [Right-aligned chevron, amber]               →  │
  └─────────────────────────────────────────────────┘

[Preview thumbnail, centered, below the cards]
                               [Small render of the share-card image — Screen 6]
[Mono small, low contrast]     This is what gets shared either way.

[Ghost CTA, centered]          No thanks
```

**Feel:** generous, not begging. Two equally-weighted cards — neither is "primary." The chevron-arrow + amber accent on each card signals tap target without making them feel like a button (which would imply a primary choice). The preview thumbnail sits below both options because the same artifact is shared either way — single source of truth.

**Verification differences (informational, not displayed to user):**
- **Invite a friend (SMS)**: opens `MFMessageComposeViewController`. iOS calls back `.sent` when the user actually taps Send. Verification is system-confirmed.
- **Post publicly (social)**: opens `UIActivityViewController`. iOS calls back `completed: true` when the user picks a destination app, not necessarily when they finish posting. Verification is best-effort.

Both result in identical unlock behavior. The user doesn't see the verification asymmetry — they just pick their preferred channel.

**Don't:**
- Threaten or pressure ("Last chance!" / "Are you sure?")
- Make one option visually heavier than the other. They're equal-weight options, not primary+secondary.
- Show a feed of "other users who shared" — fake social proof at this moment is a trust-killer.
- Add platform-specific logos inside the "POST PUBLICLY" card. The system share sheet shows those. This card just stages the choice.

---

### 5a. SMS compose (system-provided — engineering reference, no design)

**Position:** opens when the user taps the "INVITE A FRIEND" card on Screen 5. This is the system-provided Apple Messages compose sheet — no custom UI.

**Engineering reference:**

- Framework: `MessageUI` / `MFMessageComposeViewController`
- Present modally over Screen 5 when the user taps the card
- Pre-fill the `body` property: **"I'm using Lull to help improve my sleep. Try it tonight. [App Store URL]"**
- Optionally attach the share-card image (Screen 6) via `addAttachmentData(_:typeIdentifier:filename:)` for richer messages — iOS handles iMessage rendering automatically
- Do NOT pre-fill `recipients` — let the user pick from their contacts
- Set self as `messageComposeDelegate`
- On `messageComposeViewController(_:didFinishWith:)`:
  - `.sent` → dismiss the sheet, mark verdict as unlocked, navigate to Screen 7
  - `.cancelled` or `.failed` → dismiss the sheet, stay on Screen 5
- Accept the leakage: the user could edit the body to remove the URL, send to themselves, or send to an invalid number. We can't see any of that. The check is "did iOS confirm a send action" — not "did a real friend receive a real Lull invite."

**Body copy rationale:**

The pre-filled text deliberately:
- Doesn't claim a result ("It worked!") — the sender hasn't unlocked their own verdict yet at this moment
- Uses friend-to-friend SMS tone, not promotional ad copy
- Has no exclamation marks (brand voice rule from `Docs/onboarding-design-brief.md`)
- Names what Lull does in one phrase ("help improve my sleep") so the recipient understands without clicking

The URL is required — without it the message is useless. If a user manually strips the URL before sending, they still get unlock credit (we can't tell). Accept that.

---

### 5b. Public share compose (system-provided — engineering reference, no design)

**Position:** opens when the user taps the "POST PUBLICLY" card on Screen 5.

**Engineering reference:**

- Framework: `UIKit` / `UIActivityViewController`
- Items: `[shareCardImage, "I'm using Lull to help improve my sleep. [App Store URL]"]`
- Excluded activities (optional): `.assignToContact`, `.print`, `.saveToCameraRoll`, `.addToReadingList` — these don't make sense for an invite
- Include: `.message`, `.mail`, `.postToTwitter`, `.postToFacebook`, plus the system extension points for Instagram / Threads / Reddit / etc.
- Set `completionWithItemsHandler`:
  - `completed: true` (any activity type) → mark verdict as unlocked, navigate to Screen 7
  - `completed: false` → stay on Screen 5

Same leakage caveat as SMS, but worse — `completed: true` fires when the user picks a destination, not when they actually post. A user who taps Instagram, sees the compose screen, and backs out still gets unlocked. This is the system's behavior, not something we can tighten.

---

### 6. Share card image (NEW — the share-able PNG asset)

**Position:** the actual image that gets attached when the user shares to X / IG / Messages. Lives at a fixed aspect ratio that works across platforms.
**Job:** be a piece of content that lands well *as a thing posted online*, independent of whether the recipient clicks through. Aesthetic IS its own value here.

**Recommended dimensions:** **1080 × 1350px** (4:5 portrait). Works on X (cropped to 16:9 preview), IG feed (native), IG stories (centered with padding), Threads, Reddit (image post), iMessage. Single asset, all platforms.

**Content:**

```
[Top band, mono caps]          A LULL SLEEP EXPERIMENT

[Serif headline, large]        Late Sleeper
                               with pre-sleep rumination

[Hairline]

[Section, mono caps]           NIGHTS 1–5
[Sans, large]                  Brain Dump · 12 min before bed

[Hairline]

[Section, mono caps]           RESULT
[Serif, very large]            +1.4
[Sans]                         wired-score improvement
                               vs my 7-night baseline

[Small sparkline / before-and-after chart]

[Hairline]

[Section, mono caps]           HOW I COMPARE
[Sans]                         68% of Late Sleepers who tested
                               Brain Dump also improved.

[Bottom band, sans, small]     Lull · lull.app
[Tiny mono URL or QR, optional]
```

**Design intent:** this is the single most-shared artifact Lull produces. It needs to look like a piece of editorial design — *Wired magazine sleep feature*, not *app screenshot*. The serif numerals (the +1.4) are the visual hook on the timeline. The sparkline gives a recipient something to scan-read at a glance.

**Variants to design:**

The share card is **fully unblurred** — even though the user is sharing *before* unlocking inside the app, the image they post shows their real result. The "to unlock" mechanic happens on Lull's side after they complete the share. (The user sees this card briefly in the preview thumbnail on Screen 5.)

| Outcome | Headline number | Sub-line |
|---|---|---|
| Positive | "+1.4" (in serif amber) | "wired-score improvement" |
| Neutral | "±0.3" (in serif neutral) | "minimal change either way" |
| Negative | "−0.8" (in serif neutral, NOT red) | "wired-score got worse" |

Critical: **the negative variant must not feel like a failure card.** Frame the headline neutrally; the body copy can lean into "now I know what doesn't work for me — onto experiment 2." Users sharing a negative result are doing it because the act of sharing has its own social value (transparency, biohacker authenticity). The card has to support that, not undercut it.

**Don't:**
- Include the user's name or personal data unless explicitly opted-in. Anonymized framing ("a Late Sleeper") works for everyone.
- Use red for the negative number. Negative isn't bad; it's data. Use a muted tone, not an alarm color.
- Stamp it with a watermark in the corner. The whole card *is* the brand asset.
- Use chart styles that look like Apple Health screenshots. Lull's chart language should be its own — more editorial, less clinical.

---

### 7. Verdict unlocked state (NEW) — TWO VARIANTS

**Important: sharing unlocks the verdict; subscribing unlocks the platform.** Two distinct unlock paths, two distinct post-unlock states. Same card, different bottom CTAs and (for share-unlocked) one extra clarifying line.

The split matters: **sharing gives the user a one-time peek at their verdict.** It does NOT entitle them to start a new experiment, doesn't unlock sleep sounds, app blocking, or routine customization. Premium features stay paid-only. The "Start tonight" hook only fires for subscribers.

---

#### 7a. Verdict unlocked — SUBSCRIBER variant

**Position:** appears after successful subscribe (any plan). Replaces the blurred Screen 3.
**Job:** deliver the payoff. Drop the blurs. Hook into experiment 2.

**Content:**

```
[Same card composition as Screen 3, but all blurs removed]

[Kicker]                       YOUR 5-NIGHT VERDICT

[SLEEP PATTERN — UNBLURRED]
[Mono caps]                    SLEEP PATTERN
[Serif]                        Late Sleeper

[Hairline]

[Section]                      Diagnosis: Pre-sleep rumination
                                Confirmed across 5 nights

[Hairline]

[EXPERIMENT]                   Brain Dump · 12 min before bed

[Hairline]

[RESULT — UNBLURRED]
[Serif large]                  Your wired-score shifted by +1.4
[Sans]                         Verdict: This worked for you.

[Hairline]

[HOW YOU COMPARE — UNBLURRED]
[Sans]                         68% of Late Sleepers who tested
                                Brain Dump also improved.
                                Median delta: +1.1 · Yours: +1.4

[Hairline]

[WHAT TO TRY NEXT — UNBLURRED]
[Serif]                        Dim lights to <50 lux 60 min
                                before bed for the next 5 nights.
[Sans, small]                  Late Sleepers who pair Brain Dump
                                with environmental experiments see
                                the largest cumulative gains.

[Primary CTA]                  Start tonight
[Ghost CTA]                    I'll come back to this
```

**Don't:**
- Show a confetti or "Success!" moment. Off-brand.
- Hide the "Start tonight" CTA below the fold. Premium-converters should be able to start the next experiment in one tap from this screen.

---

#### 7b. Verdict unlocked — SHARE-ONLY variant

**Position:** appears after successful share completion (SMS or public). Replaces the blurred Screen 3. Same card shape as 7a but DIFFERENT bottom section.
**Job:** deliver the verdict the user shared for, and convert the "Start tonight" moment into an upsell — since they don't have premium, they can't actually start a new experiment.

**Content:**

```
[Top of screen, mono small, dismissable]
                               Verdict unlocked. Thanks for sharing.

[Same card composition as 7a — all blurs removed]
[Identical sections through "WHAT TO TRY NEXT"]

[Hairline divider — visually heavier than the interior hairlines]

[Section label, mono caps]     KEEP GOING WITH LULL

[Body, sans, muted]            Tonight's verdict is yours. New
                               experiments, the variable recommendation
                               above, and Premium features (sleep sounds,
                               app blocking, routine customization) need
                               a subscription.

[Primary CTA]                  Subscribe to start your next experiment
[Ghost CTA]                    Maybe later
```

**Behavior:**
- **"Subscribe to start your next experiment"** → opens the pricing sheet (Screen 4) as a sheet. If they subscribe from here, they upgrade to 7a state and can "Start tonight."
- **"Maybe later"** → returns the user to home in **free-forever state with their verdict viewable.** They can re-open the verdict from home (via a "View your verdict" tile or Settings entry — engineering decision) but cannot start a new experiment.

**The "WHAT TO TRY NEXT" recommendation is visible but not actionable for share-unlocked users.** That's the upsell hook: they can see what Lull thinks they should try, but the only way to actually run that experiment is to subscribe. Don't blur or hide the recommendation in this variant — visibility *is* the conversion mechanic.

**Don't:**
- Use punitive copy ("You can't continue without Premium"). Frame the upsell positively — "Keep going with Lull" is the kicker, not "You're locked out."
- Re-blur the verdict card. They shared, they earned the view. The lock is on *the next experiment*, not *this one*.
- Show a confetti or "Success!" moment.

---

### Animation (applies to both 7a and 7b)

- Blur dissipates over ~1.2s — not instantly. The reveal should feel earned, slow enough that the eye registers the unveiling.
- Each blurred section unblurs in sequence (sleep pattern → result → comparison → recommendation) staggered ~0.3s apart. Builds rhythm; lets the eye land on each piece.
- For 7b, the upsell footer fades in *after* the unblur sequence completes — gives the user time to read their verdict before the upsell appears.

---

### 8. Free-forever explainer (NEW — one-time transition)

**Position:** shown once, immediately after the user taps "No thanks" on Screen 5. (This is the third and final rejection: they declined subscribe → declined share → declined to engage at all. Free-forever tier begins.)
**Job:** explain what happens next without making the user feel punished. Set up the quiet free-tier experience.

**Content:**

```
[Kicker, mono caps]            KEEPING YOUR ROUTINE

[Serif headline]               Your wind-down stays.
                               Premium pauses.

[Body, sans]                   Your 3-step routine works free, forever.
                               You'll keep logging your sleep each
                               morning — we still use that data to
                               keep our aggregate stats honest.

[Hairline divider]

[Section label, mono caps]    PREMIUM YOU'RE PASSING ON
[Bulleted list, sans, muted]
  · Your night-5 verdict + sleep pattern reveal
  · A new experiment every 5 nights with recommended variable
  · Sleep sounds (7 ambient tracks)
  · App blocking during wind-down
  · Add or customize routine steps
  · Guided meditation (coming soon)

[Primary CTA]                  Got it
[Ghost link, small]            Actually, unlock it now
```

**Feel:** calm closing — but transparent. The two-line headline is the emotional payload. The bulleted list below is the *transparency* — explicitly tells the user what they're declining, no buried features. The list MUST match the pricing-sheet (Screen 4) list exactly. Single source of truth for the premium bundle.

**Why list the features here, after they've already declined?**

Two reasons:
1. **Transparency.** The user has a right to see what they're giving up in plain language. Hiding the bundle here would feel manipulative — and the audience reads that tactic.
2. **Future re-engagement.** The list seeds the day-14 re-engagement prompt (Screen 10) and the Settings entry (Screen 9). A user who later thinks "wait, what was included in premium again?" has a quiet reference point in their memory.

**Don't:**
- Add a countdown ("you can change your mind in 24 hours").
- Re-show the pricing numbers here. The "Unlock it now" ghost link routes back to Screen 4 if they change their mind.
- Show a "we'll miss you" line. It's manipulative for this audience.
- List MORE features than the pricing sheet shows. If lists diverge, the bundle isn't coherent — single source of truth.

After tap, app returns to home. The blurred verdict card does NOT persist on the home screen — see "Where premium prompts appear" below.

---

### 9. Settings → Upgrade to Premium (NEW)

**Position:** one row in the Settings list. Tapping opens a sheet identical to the pricing sheet (Screen 4) but accessed from a calmer context.
**Job:** make Premium discoverable for free users without surfacing it elsewhere in the app.

**Content (the Settings row):**

```
[Settings list row, full-width tap target]
[Left, sans]                   Upgrade to Lull Premium
[Right, mono caps small]       $99/yr →
```

**Content (the sheet — same as Screen 4 with one change):**

Replace the kicker "UNLOCK YOUR VERDICT" with "LULL PREMIUM" — since at this entry point, there isn't a specific verdict in the user's face. The plan options, feature list, and CTAs are identical.

**Don't:**
- Add a "trial" or "limited time" badge to the Settings row. It's a quiet entry point on purpose.
- Make this the only place premium is discoverable — the verdict card flow is still the primary entry. This is the secondary one.

---

### 10. Day-14 re-engagement prompt (NEW)

**Position:** appears once, full-screen, when a free-forever user opens the app on the day they hit ~14 logged nights post-rejection. Auto-dismisses if not interacted with, never shows again for 30 days minimum.
**Job:** offer the user a way back into the experiment loop without re-onboarding. Tied to their *new* sleep data, not their original verdict.

**Content:**

```
[Kicker, mono caps]            14 NIGHTS LATER

[Serif headline]               You've logged 19 nights of sleep.
                               Want to see what they tell us?

[Body, sans]                   We can take a fresh read of your last
                               5 nights and start a new experiment
                               tonight — built on the data you've
                               already given us.

[Primary CTA]                  See my next verdict
[Ghost CTA]                    Not yet
```

**Feel:** earned, not pleading. The number (19 nights) should be the user's actual logged count, calculated at runtime. Generic version ("you've been logging") falls flat — specificity is what makes this not feel like spam.

**Behavior:**
- Tap "See my next verdict" → user enters the same subscribe / share / decline flow as Screen 3, but seeded with their last 5 logged nights as the experiment data
- Tap "Not yet" → returns to home, 30-day cooldown before the prompt fires again
- After 3 dismissals (~90 days total), the prompt stops appearing entirely. Settings row remains.

**Don't:**
- Show this on day 7 or earlier. Two weeks of *new* data is the minimum to make the offer feel earned.
- Use generic copy ("you've been using Lull a lot"). Specificity is the entire mechanic.

---

## Where premium prompts appear, and where they don't

Be deliberate about restraint. Free users see premium nudges in only **three** places:

1. **The night-5 verdict flow** — Screens 1–8 above (the original paywall moment)
2. **Settings → Upgrade row** — Screen 9 (passive, discoverable)
3. **Day-14 re-engagement prompt** — Screen 10 (one-time, well-earned, 30-day cooldown)

Premium does NOT appear on:

- The home screen
- The morning check-in flow
- The nightly routine screens
- The 4-7-8 tool
- Any banner, sticky bar, or system notification

The respectful free experience is load-bearing for long-term conversion. The optimizer audience torches dark patterns; quiet free-tier wins them over weeks.

---

## Design deliverables

For each new screen, please produce:

1. **Static mockups** at iPhone 15 Pro size (393×852pt logical, 1179×2556px @ 3×)
2. **Dark mode only** (the app is dark-only)
3. **States to cover:**
   - Quiet transition: single state
   - Chronotype reveal: single state (the blurred name is uniform across classifier outputs — no per-chronotype variants needed)
   - Blurred verdict card: 3 outcome variants (positive / neutral / negative)
   - Pricing sheet: 2 states (annual selected, monthly selected)
   - Share-to-unlock prompt: single state (two-option layout)
   - Share card image (the PNG): 3 outcome variants (positive / neutral / negative), exported at 1080×1350px
   - Verdict unlocked state: **2 variants** — 7a (Subscriber, with "Start tonight" CTA) and 7b (Share-only, with "Subscribe to start your next experiment" upsell footer + small "Verdict unlocked. Thanks for sharing." top banner)
   - Free-forever explainer: single state
   - Settings row + sheet: single state for row, reuse pricing sheet
   - Day-14 prompt: single state
4. **Animation specs** for:
   - Chronotype reveal (the two-beat headline reveal)
   - Blurred verdict card (no animation in/out — fades in cleanly)
   - Unblur sequence (post-subscribe / post-share) — staggered timing across sections
5. **Annotated copy file** (markdown) listing the exact strings, including all 3 outcome-variant copy lines
6. **Spec strip** at the bottom of each frame: font sizes, colours by token name, spacing

---

## Process notes

- **Reuse existing components** from `Lull/Components/LullComponents.swift` (Kicker, PrimaryCTA, GhostButton, AmberGlow, Ember, BrandMark) wherever possible.
- **The share-card PNG is its own design surface.** Don't treat it as a screenshot of an in-app screen — it's an editorial asset meant to live outside the app. Different composition rules apply. Consider it more "magazine spread" than "app card."
- **Time budget per screen:** each in-app screen should feel like ~5–15 seconds of attention. The verdict flow as a whole, from rating submission to unlock CTA, should be navigable in under 30 seconds (excluding the chronotype reveal animation, which is intentionally slow).
- **Animation philosophy:** restrained. The blurred-chronotype-placeholder scale-up (Screen 2) and the unblur sequence (Screen 7) are the only major motions. Everything else fades quietly.

---

## Voice / copy notes

The brand voice from `Docs/onboarding-design-brief.md` applies in full. Specific additions for paywall copy:

- **No urgency manipulation.** No "Limited time", "Last chance", "Only X spots left." This audience reads those as tells.
- **No fake social proof.** No "Join 50,000 users" or testimonial carousels in the pricing flow.
- **The reframe on negative-verdict copy is load-bearing.** "Whether tonight worked or didn't, this is the data we'll use to pick your next experiment." Don't soften this line further.
- **"Unlock" is the active verb.** Not "subscribe," not "upgrade," not "go premium" — except where contextually required (the Settings row uses "Upgrade").
- **CTAs are commands, not invitations.** "Unlock my verdict" (not "Want to unlock?"). "Share to unlock" (not "Maybe share?"). "Start tonight" (not "Ready to start?").

---

## Out of scope for this brief

- The verdict-card data itself (chart styles, score derivation, etc.) — engineering owns the data layer
- Apple's native payment sheet (system-provided)
- Apple's native share sheet (system-provided)
- Friend referral / deep-link mechanics (deferred from v1)
- Family Sharing pricing tier (defer)
- A/B testing of pricing or discount offers (no $49 second-chance tier in v1)
- Wellness stipend / B2B receipt download (deferred)
- The routine customization UI (premium feature, but its UI is a separate brief)
- Sleep sounds player UI (premium feature, separate brief — for this brief, just list "Sleep sounds" as a bullet on the pricing sheet)

---

## Questions to flag back before designing

If during design you bump into any of these, raise them — don't silently decide:

1. **Blur treatment:** should the blur reveal character-width hints (so "Brain Dump worked." blurs to something the eye can almost-but-not-quite read), or should it be a fully obfuscated solid bar that suggests *only* length? Test both — character-hint blur tends to create stronger curiosity but can backfire if hints feel readable.
2. **Chronotype reveal pacing:** the spec calls for ~3.5s of staged animation revealing a blurred phrase. Is that too slow for users on their 6th open of the app, or right? A slower version feels more cinematic; a faster one keeps tempo with onboarding.
3. **Share card aspect ratio:** 1080×1350 (4:5) is the recommendation. Some platforms (TikTok-leaning users) might want a 9:16 variant. Worth two variants, or stick with one?
4. **Pricing sheet — sticky or scrollable CTAs?** On smaller iPhones the full content + 7-item premium-includes list may push the Continue CTA below the fold. Sticky bottom is the safer pattern but loses some elegance.
5. **Day-14 prompt — full-screen or sheet?** Full-screen lands harder but feels more interruptive. A sheet is gentler but easier to dismiss reflexively. Lean toward sheet, but flag.
6. **Negative-verdict share card — does this need user-facing confirmation?** ("You're about to share a result that didn't work — sure?") I lean *no* — your audience values authenticity and the act of sharing transparency is itself shareable. But it's a values call worth flagging.
7. **Share-to-unlock screen (Screen 5) — should there be a tooltip or info-icon explaining WHY iOS verifies SMS differently from public shares?** Most users won't care, but the transparency might earn trust with the audience that does. Default: no tooltip, keep the screen clean. Flag if you have a strong reason to add one.
8. **SMS compose (Screen 5a) — should we attach the share-card image to the message body, or send text + URL only?** Attaching the image makes the message richer in iMessage but may degrade in carrier SMS (image gets stripped or compressed). Text-only is universally readable. Recommendation: attach the image, accept SMS-fallback degradation. But flag for design + engineering alignment.
9. **Screen 7b upsell — full-screen or stuck-bottom footer?** The share-only verdict screen needs to show the unlocked verdict prominently AND surface the "Subscribe to keep going" upsell. Two layout options: **(a) the upsell sits below the verdict card and scrolls with it** — feels natural, but on small screens the upsell may not be visible without scrolling. **(b) The upsell sticky-bottoms** — always visible, more aggressive. Recommendation: (b) sticky-bottom, but use low-contrast styling so it doesn't visually dominate the verdict. Flag if you have a stronger view.
10. **Screen 7b — should the "WHAT TO TRY NEXT" recommendation be displayed as plain text or as a tappable element that opens the pricing sheet?** Plain text is honest (it shows what's available without forcing interaction). A tappable element ("Tap to start this experiment → opens paywall") is more conversion-focused but might feel like a trap. Lean plain text; flag if you'd rather make it a paywall trigger.
