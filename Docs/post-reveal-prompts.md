 Engineering prompt (for Codex)

  Implement the Day-5 Verdict Reveal for Lull — the share-worthy artifact that
  fires when a user finishes their first 5-night experiment.

  CONTEXT
  Read these before starting:
  - Docs/onboarding-activation-plan.md (defines chronotype + bottleneck classifiers,
    and the foreshadow line that promises this reveal)
  - Docs/marketing-strategy.md (defines the share-or-pay mechanic the card powers)
  - Docs/FEATURES.md §9 Experiment Engine (the verdict computation already exists)
  - Docs/claude-data-architecture.md (SleepLogEntry shape + persistence)

  The verdict card stacks four things in order:
    1. Identity — chronotype reveal (held back from onboarding for this moment)
    2. Diagnosis recap — the bottleneck shown at onboarding
    3. Experiment verdict — delta vs baseline + promote/drop decision
    4. Research-backed comparison — cited line per variable (NOT cohort data;
       we don't have n yet)

  GOAL
  Trigger the reveal exactly once per completed experiment. Compute its data
  from existing AppState + a small literature lookup table. Persist that the
  user has seen it. Build the view + a shareable PNG export. Wire it into the
  morning check-in flow.

  SCOPE

  1. Models
     - Lull/Models/ChronotypeClassifier.swift (NEW) — pure function returning
       Chronotype enum from currentBedtime/currentWakeTime/Q1/Q2. Spec lives
       in onboarding-activation-plan.md; implement exactly as written.
       enum Chronotype: String, Codable { case earlySleeper, steadySleeper,
         lateSleeper, drifter; var displayName: String; var pluralDisplayName:
  String }
     - Lull/Models/BottleneckClassifier.swift (NEW) — same shape, returns
       Bottleneck enum (preSleepRumination, fragmentedSleep, insufficientDeep,
       shortWindow, inconsistentRhythm).
     - AppState gains stored: chronotype, bottleneck (computed once at end of
       onboarding, persisted). Add to PersistedState. Migrate cleanly when
       missing on load (recompute from existing answers).

  2. Verdict data assembly
     - New struct Lull/Models/VerdictCard.swift:
         struct VerdictCard {
           let chronotype: Chronotype
           let bottleneck: Bottleneck
           let variable: String           // e.g. "Brain Dump"
           let baselineAvg: Double
           let experimentAvg: Double
           let delta: Double
           let decision: ExperimentDecision  // .promote / .drop
           let researchLine: ResearchCitation  // looked up by variable
           let generatedAt: Date
         }
     - Add VerdictCard.build(from: AppState) — reuses ExperimentEngine.evaluate
       for delta/decision; pulls chronotype + bottleneck from AppState; looks
       up researchLine from a hardcoded table (see below).

  3. Research citation table
     - Lull/Models/ResearchCitations.swift (NEW) — static dictionary keyed by
       variable label, value is:
         struct ResearchCitation {
           let claim: String        // "Brain dumps reduce pre-sleep cognitive
  arousal"
           let evidence: String     // "70–80% response rate, CBT-I meta-analysis"
           let citation: String     // "Morin et al., 2006"
         }
     - Seed with citations for at least the 5 most likely variables: Brain Dump,
       4-7-8 Breathing, Dim the lights, Cold room prep, Warm shower. Fall back
       to a generic CBT-I line if variable is unmapped (do NOT crash).
     - Every line must be a real, citable study. If you can't find one, flag
       it back to me rather than inventing.

  4. Trigger logic
     - In AppState.logMorningScore(), after advanceExperiment() runs, check:
       did this score complete a 5-night experiment (i.e. ExperimentEngine
       returned .promote or .drop)? If yes AND hasSeenVerdictFor[experimentId]
       is false → set pendingVerdictCard = VerdictCard.build(from: self).
     - Add @Published var pendingVerdictCard: VerdictCard? to AppState.
     - Persist hasSeenVerdictFor: [String: Date] (keyed by variable label +
       completion date; label brittleness is acknowledged in the data arch doc).

  5. Presentation
     - Lull/Morning/VerdictCardView.swift (NEW) — full-screen cover, presented
       from ContentView when pendingVerdictCard != nil. Dismissal sets seen
       flag, clears pendingVerdictCard, persists.
     - Show AFTER the morning rating sheet, not before — the user logs night 5,
       dismisses MorningRewardView, THEN the verdict appears. Don't stack
       modals; chain them.

  6. Share export
     - Add VerdictCardView.exportPNG() using ImageRenderer (iOS 16+, we're on 17).
       Renders a dedicated VerdictShareCard view (square or 4:5; design will
       spec) at @3x. Hand the resulting UIImage to UIActivityViewController via
       a "Share" button on the verdict screen.
     - No PII on the share card. Anonymized identity ("a 34-yo founder with ADHD"
       style) is fine if computed from existing onboarding answers; do not
       include name.

  7. Foreshadow consistency
     - The commitment screen (or bottleneck reveal — implementer's call per
       onboarding plan) promises "Your full sleep pattern + what worked comes
       at night 5." The verdict card MUST deliver all three: chronotype label,
       bottleneck recap, variable verdict. Don't ship if any are missing.

  OUT OF SCOPE
  - The share-or-pay paywall mechanic itself (blurred-verdict + forced choice).
    That's a separate plan. For now: card is unlocked by default, share button
    is visible, paywall is NOT inserted between night 5 and the reveal. We
    ship the artifact first, layer the paywall on top later.
  - Cohort aggregate data ("43 founders tried this"). We do not have n yet.
  - Friend invite / pairing.
  - Re-running the same experiment (verdict shows once per experiment instance).

  SUCCESS CRITERIA
  - Fresh user completes onboarding → logs 5 nights with scores → on the 5th
    morning rating, after dismissing the rating sheet, the verdict card appears.
  - Card shows correct chronotype, bottleneck, variable, delta, decision, and
    a real research citation matched to the variable.
  - "Share" produces a clean PNG that has no PII and renders correctly on iMessage.
  - Killing and relaunching the app does NOT re-fire the verdict for the same
    experiment.
  - Logging night 5 of the NEXT experiment (after the engine picks a new
    variable) fires a fresh verdict card.

  FILES TO TOUCH
  New: ChronotypeClassifier.swift, BottleneckClassifier.swift, VerdictCard.swift,
       ResearchCitations.swift, VerdictCardView.swift, VerdictShareCard.swift
  Modified: AppState.swift (chronotype/bottleneck storage, pendingVerdictCard,
            trigger logic, hasSeenVerdictFor persistence), PersistedState.swift
            (new fields + schema bump if needed), ContentView.swift (present
            verdict full-screen cover), project.pbxproj (target membership).

  I'm in plan mode. Produce a plan first; do not write code until I approve.

  ---
  Design prompt (for Claude Design)

  Design the Day-5 Verdict Reveal for Lull — the share-worthy artifact a user
  sees after completing their first 5-night sleep experiment.

  CONTEXT
  Read these before designing:
  - Docs/onboarding-design-brief.md (brand tokens, voice, reference screens —
    match these exactly)
  - Docs/audience-profile.md (founders, ADHD biohackers, new parents — distrust
    wellness clichés, trust data)
  - Docs/marketing-strategy.md (this card is the share-worthy unit the whole
    marketing flywheel depends on)

  The card stacks four things in this order:
    1. Identity — chronotype reveal (the user has NOT seen this label before;
       it was held back from onboarding for this moment)
    2. Diagnosis recap — the bottleneck shown at onboarding, now confirmed
    3. Experiment verdict — score delta + promote/drop decision
    4. Research-backed line — cited study tied to the variable tested

  This is the first moment in the product where chronotype is named to the user.
  It's a payoff moment, not a config moment. Treat it like the routine reveal —
  slow, deliberate, weighted.

  WHAT TO DESIGN

  1. In-app verdict screen (full-screen cover)
     - Triggered after the night-5 morning rating sheet dismisses.
     - Single scrollable screen, all four sections visible without scrolling
       on iPhone 15 Pro if at all possible.
     - Brand voice: hedged ("most closely matches" not "you are"), serif headlines,
       mono caps for kickers, no exclamation marks, no emoji except established
       ones.
     - Reference: OnbRoutineReadyView is the closest existing pattern — the
       orb, the staged reveal, the data-card composition.

     Section composition (suggested, design owns final layout):

     ┌─────────────────────────────────────────┐
     │ [Kicker, mono caps]  NIGHT 5 · VERDICT  │
     │                                         │
     │ [Serif headline, large]                 │
     │   Your sleep pattern most closely       │
     │   matches a Late Sleeper.               │
     │                                         │
     │ [Mono caption block]                    │
     │   Computed from: 12:30 AM bedtime,      │
     │   7:00 AM wake, racing-mind signal,     │
     │   high-stress role                      │
     │                                         │
     │ [Hairline]                              │
     │                                         │
     │ [Section label, mono] YOUR BOTTLENECK   │
     │ [Serif, smaller] Pre-sleep rumination   │
     │ [Sans, muted] Confirmed by 5 nights of  │
     │   data — your worst-rated nights tracked│
     │   with racing thoughts at bedtime.      │
     │                                         │
     │ [Hairline]                              │
     │                                         │
     │ [Section label, mono] EXPERIMENT VERDICT│
     │ [Big serif numeral] +0.8                │
     │ [Mono caption] VS BASELINE              │
     │ [Sans body] Brain Dumps moved your      │
     │   score from 2.4 → 3.2 over 5 nights.   │
     │   Verdict: keep it.                     │
     │                                         │
     │ [Hairline]                              │
     │                                         │
     │ [Section label, mono] WHAT THE RESEARCH │
     │                       SHOWS             │
     │ [Sans body, slightly muted]             │
     │   Brain dumps reduce pre-sleep          │
     │   cognitive arousal — 70–80% response   │
     │   rate across CBT-I trials.             │
     │ [Mono, tertiary] Morin et al., 2006     │
     │                                         │
     │ [Primary CTA]  Share my verdict         │
     │ [Ghost CTA]    See what's next          │
     └─────────────────────────────────────────┘

     Atmosphere: amber glow sits low behind the verdict numeral — that's the
     payoff moment, eye should land there.

  2. Share card (PNG export — separate composition)
     - Renders at iPhone screen-width square OR 4:5 portrait (designer's call —
       test which reads better on X timeline + IG story).
     - Must be legible at small sizes (timeline thumbnails).
     - Single artifact, no scroll.
     - Anonymized identity allowed: "a 34-yo founder with ADHD" — derived from
       onboarding answers, no name.
     - Headline = chronotype + verdict ("Late Sleeper · Brain Dumps worked").
     - Sub-headline = the delta ("+0.8 vs baseline, 5 nights").
     - One-line research citation for credibility.
     - Small "lull" wordmark + "lull.app" footer (no QR codes, no aggressive
       watermarking — your audience hates this).
     - Dark palette consistent with the app.

  3. States to deliver

     In-app screen:
     - Default (unlocked) — what's specced above.
     - Verdict variants: PROMOTE (positive delta, "keep it") vs DROP (neutral/
       negative delta, "drop it, try X next"). Same layout, different verdict
       copy + numeral color (amber for promote, muted ink for drop — don't go
       red; we don't punish).
     - Chronotype variants: 4 (Early Sleeper / Steady Sleeper / Late Sleeper /
       Drifter). Same layout, different identity copy + computed-from line.
     - Bottleneck variants: 5 (per onboarding-design-brief.md).
     - Provisional badge: small mono tag if the user is a new parent / shift
       worker (their classification is provisional).

     Share card:
     - Promote variant + drop variant.
     - 4 chronotype variants for the identity headline.
     - The 20 combinations (4 chronotypes × 5 bottlenecks) don't all need full
       mockups — produce 3–4 representative ones and a clear template.

  4. NOT designing yet (separate brief later)
     - The blurred/share-or-pay state (when we layer the paywall on top).
     - Cohort aggregate line ("43 founders like you tried this") — we don't have
       the data yet; v1 uses cited research instead.
     - The "what's next" experiment-selection screen the ghost CTA leads to.
     - Friend pairing share.

  CONSTRAINTS
  - Match brand tokens exactly (Docs/onboarding-design-brief.md §"Brand tokens").
  - Use existing components (Kicker, PrimaryCTA, GhostButton, AmberGlow, hairline
    dividers) wherever possible.
  - No mascots, no gamification badges, no "Great job!" copy.
  - Hedged language: "most closely matches" not "you are."

  DELIVERABLES
  - Static mockups @ iPhone 15 Pro (393×852pt), dark mode only.
  - In-app screen: promote + drop variants, 4 chronotype identity blocks, 5
    bottleneck blocks (mix-and-match shown via 3–4 full compositions).
  - Share PNG: promote + drop variants, 4 chronotype headers.
  - Annotated copy file listing all strings.
  - Spec strip at bottom of each frame: font sizes, colour tokens, spacing.

  QUESTIONS TO FLAG BACK
  1. Should the chronotype identity line use a small visual signature (sparkline,
     sun/moon glyph) or stay text-only? Test both.
  2. Share card aspect ratio: square (universal) vs 4:5 portrait (better on IG/
     X mobile)? Strong opinion welcome.
  3. The verdict numeral — serif numeral (matches OnbBedtimeView) or mono
     numeral (matches data-card voice)? Probably serif, but confirm.
  4. Should the "drop" verdict show what's coming next inline ("Trying Cold Room
     prep starting tomorrow") or stay reveal-only and push that to the ghost
     CTA's destination? Affects layout density.