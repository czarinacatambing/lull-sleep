# TenThirty Sleep-Contract Regression Specification

This is the Phase 0 behavioral contract for the current TenThirty app. TenThirty is a sleep-contract app. The retired sleep-experimentation and generated-routine experience is not part of the product surface and must not reappear during cleanup.

The companion [safety baseline matrix](safety-baseline-matrix.md) maps every behavior below to an automated test or a named manual device check. A cleanup change is safe only when all automated baseline tests pass and the affected manual checks pass on a real iPhone.

## Product boundary

The supported user journey is:

1. Welcome.
2. Seven-step contract onboarding: sleep thief, sleep rules, sleep window, contract preview, app-blocking explanation, app-blocking commitment, trial/paywall.
3. The subscribed app shell with `Today`, `Rules`, and `Trends`.
4. Mid-sleep tools, settings, subscription management, notifications, and Screen Time enforcement as supporting surfaces.

The following must not be surfaced by ordinary navigation: `Routine`, `Insights`, experiment selection/results, a generated-routine editor, the legacy nightly card deck, research export, or Live Activities.

## Safety invariants

### Launch and onboarding

- A fresh install shows the welcome screen and no main tabs.
- `Help me sleep` opens the current sleep-thief onboarding screen.
- A completed user opens the current three-tab shell on Today.
- Completing onboarding activates a sleep contract, preserves the selected rules, and does not launch the legacy nightly flow.
- App blocking may be explained/configured in onboarding, but Screen Time authorization and selection must remain user initiated.

### Today and contract enforcement

- Contract dates work for overnight and same-day sleep windows.
- Only selected rules are generated. Rules whose first due time already passed at activation begin on the next applicable contract day.
- Rule availability, due time, grace period, completion, slip, cooldown, and lock state remain deterministic for a supplied clock value.
- Multiple overdue rules remain actionable; completing one cannot silently resolve another.
- A late completion unlocks without adding a cooldown. A slip produces the current ten-minute cooldown.
- `Ready for sleep` is the final in-bed checkpoint and becomes visible only after unresolved pre-bed rules leave the queue.
- Every actionable rule remains visible on Today. An unresolved rule that currently owns a rule lock must remain visible, become the hero, and expose its completion action even when `Ready for sleep` or another presentation state overlaps it. A rule explicitly slipped into cooldown is resolved and does not expose a completion action during that cooldown.
- Morning Sun is hidden before its configured availability, but remains visible from availability until it is completed or slipped, including after its deadline.
- The hold gesture completes the visible hero rule. A normal tap or an incomplete hold must not complete it.
- Completing the contract records one all-clear event and does not mark the retired nightly routine complete.
- The firefly reward requires the in-bed confirmation after the other commitments are cleared.

### Rules and app blocking

- Rules displays the selected contract rules, times, grace state, blocked-app configuration, and emergency-access affordance.
- Editing the sleep window keeps the app-blocking window in sync where the current behavior requires it.
- Hard blocking is entitlement gated and requires enabled state, selected Screen Time targets, and an active schedule.
- Rule-time editing is atomic: scrolling hour, minute, or AM/PM wheels must not persist, reschedule monitoring, or change shielding until the user explicitly saves the final value. Cancelling leaves the existing time unchanged.
- Editing a rule time starts that rule's configured grace from the new due time. Replacing its Device Activity schedule must not reuse stale interval state or shield during the new grace period.
- Disabling blocking, removing targets, leaving the window, a valid bypass, or an active emergency-access session must prevent/clear shielding.
- Daily lock/unlock boundaries must continue after TenThirty is backgrounded, suspended, terminated, or left unopened for more than 48 hours.
- Temporary emergency access, gentle bypass, and the ten-minute slip cooldown must reconcile at their exact semantic end even when TenThirty is not running; reconciliation callbacks must never create a lock by themselves.
- Emergency access records its reason and duration and is inactive at the exact end time.
- Shield extension behavior and FamilyControls authorization must be verified on a real device; simulator-only success is insufficient.

### Trends and rewards

- Trends uses the calendar meadow scene, not the Today firefly cluster.
- Contract all-clear and lock events drive the current statistics/calendar.
- Empty or insufficient data must show the current empty state and must not fabricate progress.
- Existing firefly/reward visuals and reduced-motion behavior must remain visually unchanged.

### Mid-sleep, audio, settings, and subscription

- Mid-sleep entry presents breathing, story, sounds, and get-up tools according to current entitlement rules.
- Premium story/sound actions do not open when entitlement is absent; the paywall opens instead.
- Bundled audio starts, pauses, resumes, switches, and stops without continuing unexpectedly after leaving its owning surface.
- Purchase, restore, customer-center, entitlement loss, and trial-expiry paths preserve their current routing and access rules.
- Settings retains notification, subscription, legal, and account/support actions currently surfaced.

### Notifications, routing, and persistence

- Only unresolved contract items are eligible for contract notifications; the in-bed checkpoint does not schedule a rule-lock notification.
- Notification taps and supported deep links route to the current Today or Mid-sleep surface, never to legacy tabs.
- Contract selections, configurations, completions, slips, lock/all-clear events, emergency access, app blocking, subscription state, and onboarding state survive persistence.
- A persisted state created before sleep-contract fields existed decodes with safe empty/default contract values.
- Foreground and timezone refreshes do not duplicate completion/all-clear events or re-enable expired access.

## Negative regression requirements

Phase 0 protects not only what the app does, but what it must not do:

- no `Routine` or `Insights` tab;
- no experiment or legacy nightly flow after current onboarding;
- no unselected or resolved rule in the actionable queue or notification plan;
- no in-bed notification lock;
- no duplicate all-clear event;
- no mismatch where an unresolved rule-lock banner names a rule whose completion card is hidden or displaced by a later rule;
- no early completion before a rule is available;
- no shield outside its valid conditions;
- no persistence, schedule replacement, or shield change from an intermediate rule-time picker value;
- no stale shield from a replaced rule schedule, including while the edited rule is in grace;
- no emergency access at or after its end timestamp;
- no premium tool access after entitlement loss;
- no loss or crash when decoding pre-contract persisted data.

## Baseline commands

Run against a booted iOS simulator, substituting its device identifier:

```sh
xcodebuild -quiet -scheme Lull -project TenThirty.xcodeproj \
  -destination 'platform=iOS Simulator,id=<DEVICE_ID>' \
  -derivedDataPath /tmp/tenthirty-safety-baseline \
  test -only-testing:LullTests

xcodebuild -quiet -scheme Lull -project TenThirty.xcodeproj \
  -destination 'platform=iOS Simulator,id=<DEVICE_ID>' \
  -derivedDataPath /tmp/tenthirty-safety-baseline \
  test -only-testing:LullUITests/NavigationSmokeUITests \
       -only-testing:LullUITests/HoldToConfirmUITests
```

Then execute every real-device check marked `Required` in the safety baseline matrix. Record device, iOS version, build/commit, date, tester, and pass/fail evidence.

## Cleanup gate

Before deleting a candidate symbol or file:

1. Map it to a product behavior in the safety baseline matrix.
2. If mapped, preserve it and its tests unless the user explicitly changes the product requirement.
3. If unmapped, prove it is unreachable from the current roots and not referenced by an app extension, notification/deep-link route, persistence migration, asset lookup, or test fixture.
4. Remove the smallest coherent slice.
5. Run the automated baseline and the manual checks affected by that slice.

Phase 0 creates the baseline only. It does not authorize deletion of legacy implementation.
