# TenThirty Regression Test Specification

This document is the behavioral contract for TenThirty/Lull. It describes what the app does, what each user action should produce, and what should be covered by unit, integration, and end-to-end tests before adding new features.

The current app is adding XCTest/XCUITest coverage from this spec. Treat this document as the behavioral contract tests should map back to.

## Core Terms

- **Sleep window**: the user's configured wall-clock bedtime through wake time.
- **Bedtime day**: the calendar day the sleep window starts. Morning ratings must attach to this day, even if the user rates after midnight or the next morning.
- **Wake anchor**: today's date combined with `typicalWakeTime`.
- **Morning rating window**: `wakeAnchor <= now < next prep start after wake`.
- **Prep step**: a reminder/checklist item scheduled before bed using a lead time.
- **Ritual step**: an in-app step completed from the nightly card deck or its opened tool surface.
- **Firefly**: visual reward for completing a guided wind-down night.

## Test Environments

- **Unit tests**: pure Swift tests for `AppState`, routine generation, scheduling/date logic, and small view-model style helpers.
- **Integration tests**: tests with fakes for notification scheduling, persistence, app blocking settings, and audio bundle lookup.
- **E2E/UI tests**: XCUITest flows using deterministic fixture state and controllable clocks where possible.
- **Manual device checks**: still required for FamilyControls picker, local notification delivery, Live Activities, and actual audio output.

## Launch And Routing

| ID | Expected behavior | Actions | Expected outputs |
| --- | --- | --- | --- |
| APP-001 | First launch before onboarding shows the welcome screen. | Open app with `hasCompletedOnboarding = false`. | Welcome copy and `Help me sleep` CTA are visible. Main tabs are not visible. |
| APP-002 | Returning users skip welcome. | Open app with `hasCompletedOnboarding = true`. | Main tab shell opens. Today tab is selected unless `requestedTab` says otherwise. |
| APP-003 | Notification/deep-link routes can bypass welcome. | Set `requestedTab != nil` or `showMidSleepMode = true` before `ContentView` appears. | Welcome is hidden and the requested surface opens. |
| APP-004 | App foreground refreshes operational state. | Move app to active. | Subscription info refreshes, trial status evaluates, timezone changes reschedule notifications, app blocking refreshes, prep Live Activity refreshes, pending Live Activity toggles/ratings are ingested. |
| APP-005 | Notification taps route to the correct surface. | Tap a notification in each category. | `MORNING_CHECKIN` and `BEDTIME_REMINDER` route to Today. `WIND_DOWN_START` routes to Today and cancels wind-down start notifications. `MID_SLEEP_CHECK` opens Mid-sleep mode. |

## Onboarding

| ID | Expected behavior | Actions | Expected outputs |
| --- | --- | --- | --- |
| ONB-001 | Onboarding appears as a fixed sequence. | Start onboarding. | Screens appear in this order: sleep problem, baseline rating, promise, bedtime, pre-bed, methodology, routine ready, commitment, trial paywall. App blocking is not part of onboarding. |
| ONB-002 | Bedtime selection seeds the operating schedule. | Complete bedtime screen. | `targetBedtime`, `targetWakeTime`, `currentBedtime`, `currentWakeTime`, `typicalBedtime`, and `typicalWakeTime` align with selected times. |
| ONB-003 | Routine is generated before routine-ready payoff. | Enter routine-ready generation screen. | `applyGeneratedRoutine(generateStartingRoutine(...), scheduleNotifications: false)` runs; generated routine and explanation are available. |
| ONB-004 | App blocking is not requested during onboarding. | Complete onboarding. | No FamilyControls picker or app-blocking commitment screen appears. App blocking may be recommended later after the first completed night. |
| ONB-005 | Completing onboarding starts the app experience. | Finish onboarding / start ritual. | `hasCompletedOnboarding = true`, trial starts if needed, notifications schedule if commitment exists, and Today opens. |

## Routine Generation And Scheduling

| ID | Expected behavior | Actions | Expected outputs |
| --- | --- | --- | --- |
| ROUTINE-001 | Generated routines are based on onboarding answers. | Call `generateStartingRoutine(from:)` with answer fixtures. | Output includes wind-down steps, prep reminders, explanation, remedy IDs, backlog, intro order, and enforcement modes. |
| ROUTINE-002 | Warm shower is favored in starter routines. | Generate a starter routine. | `warmShower` appears first unless category enforcement changes ordering. |
| ROUTINE-003 | `No screens` can have enforcement metadata. | Generate routine from screen-heavy habits. | Routine uses `R.noScreens` with `RemedyEnforcementMode`, not a separate legacy app-blocking label. |
| ROUTINE-004 | Schedule packs ritual steps backward from bedtime. | Given ritual steps with estimated durations and bedtime. | `scheduledRoutine` assigns times backward from bedtime, shifted earlier if needed to fill `sleepWindowMinutes`. |
| ROUTINE-005 | Prep steps schedule by lead time. | Given prep steps and bedtime. | Prep times equal `typicalBedtime - resolvedLeadTimeMins`; badges include reminder/lead copy. |
| ROUTINE-006 | Schedule output is chronological. | Mix prep and ritual steps. | `scheduledRoutine` is sorted ascending by time. |
| ROUTINE-007 | Editing routine reschedules prep reminders and Live Activity surfaces. | Add, edit, remove, reorder, or change experiment variable. | App persists the routine and calls the routine-surface reschedule path. |

## Main Navigation

| ID | Expected behavior | Actions | Expected outputs |
| --- | --- | --- | --- |
| NAV-001 | Bottom tabs are Today, Trends, Routine. | Open main shell. | Visible tab labels are exactly `Today`, `Trends`, `Routine`. |
| NAV-002 | Trends tab shows the insights/calendar surface. | Tap `Trends`. | Selected tab is index `1`; Trends content is visible. |
| NAV-003 | Routine tab shows routine management. | Tap `Routine`. | Selected tab is index `2`; `MyRoutineView` is visible. |
| NAV-004 | Mid-sleep mode is a hidden route, not a visible tab. | Set `showMidSleepMode = true` or open mid-sleep link. | Selected tab becomes hidden index `3`; tab bar remains custom and visible state restores on exit. |
| NAV-005 | Sleep sounds mini-player reserves space above tabs. | Start sleep sound playback. | Mini-player appears above tab bar; content receives bottom inset. |

## Today Screen State Machine

| ID | Expected behavior | Actions | Expected outputs |
| --- | --- | --- | --- |
| TODAY-001 | Firefly greeting follows phone clock, not sleep window. | Set current time to morning/afternoon/evening/night. | Greeting is `Good Morning`, `Good Afternoon`, `Good Evening`, or `Good Night` based only on hour. |
| TODAY-002 | Morning rating card appears at wake. | Completed night exists for bedtime day with `score = 0`; set `now = wakeAnchor`. | Rating card is visible immediately. |
| TODAY-003 | Morning rating card is hidden before wake. | Same completed night; set `now < wakeAnchor`. | Rating card is not visible. |
| TODAY-004 | Morning rating card is hidden after rating. | Same night, then rate 1-5. | Rating card eases/fades down and disappears; score persists to bedtime day. |
| TODAY-005 | Morning rating card remains available until next prep starts. | Unrated completed night; set `wakeAnchor < now < nextPrepStartAfterMorningWake`. | Rating card remains visible. |
| TODAY-006 | Morning rating card stops when the next routine begins. | Unrated completed night; set `now >= nextPrepStartAfterMorningWake`. | Today's deck/routine state takes priority. |
| TODAY-007 | Today deck appears at prep start for the next visible sleep window. | Set `now >= firstPrepStartForNextVisibleDeck`, unfinished routine. | Prep/ritual card deck is visible. |
| TODAY-008 | After wake and no card/deck, Today shows next reminder copy. | Set `now >= wake`, rated or no ratable night, before next prep. | Text says `First reminder should show up at <time>`. |
| TODAY-009 | Today refreshes on foreground. | Open app from a notification around wake time. | `currentDate` refreshes immediately; card visibility is recomputed without waiting for the minute timer. |
| TODAY-010 | First-firefly coachmark sits below deck card and above controls. | First onboarding handoff in deck window. | Reward text does not overlap the card or swipe hints. |

## Morning Rating

| ID | Expected behavior | Actions | Expected outputs |
| --- | --- | --- | --- |
| RATE-001 | User rates with one tap. | Tap rating dot 1-5. | Selected rating is displayed optimistically. |
| RATE-002 | Rating persists to the correct sleep window. | Rate in the morning after an overnight sleep window. | `SleepLogEntry` for the prior bedtime day receives the score, actual wake time, variable, and hours slept if present. |
| RATE-003 | Same-day test windows use the same bedtime-day rule. | Bedtime and wake occur on same calendar day; rate after wake. | Rating attaches to the sleep window's start day, not a broad today/yesterday fallback. |
| RATE-004 | Ratable entry preference favors real nightly data. | A score-only ghost entry and an unrated completed-flow entry exist. | Rating applies to the completed-flow entry. |
| RATE-005 | Rating clears current morning notifications. | Rate sleep. | Delivered and pending morning rating notifications are removed; future notifications reschedule with `skipToday = true`. |
| RATE-006 | Rating animation is gentle. | Tap a rating. | Card eases/fades down before state fully resolves; no abrupt disappearance. |
| RATE-007 | Missing routine completion is still ratable. | Wake after an incomplete routine. | Card can show `Routine wasn't completed - still want to log how you slept?`; rating still logs. |

## App Blocking Recommendation Card

| ID | Expected behavior | Actions | Expected outputs |
| --- | --- | --- | --- |
| ABO-001 | Offer appears after the first completed wind-down night. | User has `No screens`, completed at least one guided wind-down, no configured app targets, and has not dismissed offer. | App blocking offer is visible in morning queue. |
| ABO-002 | Offer stays after rating. | Offer and rating card are both visible; user rates sleep. | Rating card exits; app blocking offer remains and moves up into the open slot. |
| ABO-003 | X is the persistent dismissal. | Tap X on the app blocking offer. | `hasDismissedAppBlockingOffer = true`; offer remains hidden on future days unless storage is reset. |
| ABO-004 | Add starts setup but does not dismiss. | Tap `Add app blocking`. | If eligible for hard blocking, app blocking step is added if needed, Routine tab opens to edit/setup; dismissed flag remains false. |
| ABO-005 | Added app blocking step does not hide the offer by itself. | Tap Add, but do not select apps/categories. | Offer remains eligible on return because no app targets are configured. |
| ABO-006 | Configured targets hide the offer. | Select application/category targets and save app blocking. | `hasConfiguredAppBlockingTargets = true`; offer no longer appears. |
| ABO-007 | Premium gating applies. | Non-premium user taps Add. | RevenueCat paywall appears; offer is not dismissed by the tap. |

## Prep Deck And Ritual Deck

| ID | Expected behavior | Actions | Expected outputs |
| --- | --- | --- | --- |
| DECK-001 | Deck contains prep then ritual tasks. | Enter deck window. | Cards reflect `preWindDownSteps` and `windDownSteps` with scheduled time and lead labels. |
| DECK-002 | Swipe right completes active card. | Swipe/right action on active task. | Prep IDs or ritual IDs update; progress advances; first interaction dismisses first-firefly prompt. |
| DECK-003 | Swipe down skips active card. | Swipe/down action. | Task is marked skipped for the session and deck advances. |
| DECK-004 | Swipe left/back returns to previous card. | Swipe/back action. | Deck index moves back when possible. |
| DECK-005 | Swipe up undo restores prior state. | Swipe/up action. | Most recent completion/skip can be undone. |
| DECK-006 | Completing all ritual cards completes routine. | Finish all ritual tasks from the card deck. | Ritual IDs make routine done; firefly reward can animate. |
| DECK-007 | Add button routes to Routine tab. | Tap plus under deck. | Selected tab changes to Routine. |

## Nightly Cards And Tool Surfaces

| ID | Expected behavior | Actions | Expected outputs |
| --- | --- | --- | --- |
| NIGHT-001 | Primary nightly experience is the card deck. | Enter the evening routine window. | Cards appear for prep and ritual tasks; user can swipe back, undo, skip, or complete rather than being forced through a linear flow. |
| NIGHT-002 | Completing a ritual card records completion. | Swipe right/done on a ritual card. | Ritual ID is marked done and persisted. |
| NIGHT-003 | Skipping a ritual card records session skip state. | Swipe down/skip on a ritual card. | Card advances without marking the ritual done. |
| NIGHT-004 | Brightness and temperature cards can open their tool surfaces when needed. | Open brightness or temperature card controls. | Selected values are stored on the bedtime-day log. |
| NIGHT-005 | Brain dump supports record/skip completion. | Use brain dump card/tool. | File path/duration are saved when recorded; skipped duration/status are tracked when skipped. |
| NIGHT-006 | 4-7-8 breathing has audio controls. | Open breathing card/tool. | Play/pause button, speed minus/plus, rate label, progress, cycle bar, and `End early` are available. |
| NIGHT-007 | Sleep sounds play immediately. | Open sleep sounds card/tool with configured sound. | Audio store starts playback immediately, uses bundled m4a lookup, and shows playback controls. |
| NIGHT-008 | Other ritual tools complete or skip consistently. | Complete/skip boring story, gratitude, stretching, PMR, body scan, generic habit. | Completion/skips update the card deck state and persist where applicable. |
| NIGHT-009 | Completing all required ritual cards produces the night reward. | Finish the ritual card deck. | Routine is treated as complete for the night; firefly reward can animate. |

## Trends

| ID | Expected behavior | Actions | Expected outputs |
| --- | --- | --- | --- |
| TRENDS-001 | Trends tab uses the shared meadow/calendar backdrop. | Open Trends. | Calendar/firefly scene appears with routine stats overlay. |
| TRENDS-002 | Stats panel and calendar do not collide. | Routine chips wrap to 1-2+ rows. | Calendar top inset adapts; clear spacing remains between stats panel and calendar. |
| TRENDS-003 | Better habits count reflects completed wind-down nights this month. | Seed logs with completed flow. | Count and detail text match completed-night total. |
| TRENDS-004 | Morning rating summary requires ratings. | No scored logs. | Shows `--` and `Not enough ratings yet`. |

## Routine Tab

| ID | Expected behavior | Actions | Expected outputs |
| --- | --- | --- | --- |
| ROUTINETAB-001 | Routine tab shows prep and bedtime ritual sections. | Open Routine. | Prep steps and ritual steps render in their sections. |
| ROUTINETAB-002 | Routine steps can be reordered. | Drag/reorder prep or ritual steps. | Order persists, schedule surfaces reschedule. |
| ROUTINETAB-003 | Routine steps can be added, edited, removed. | Use step library/editor. | `coreRoutine` updates, order normalizes, persistence writes, notifications refresh. |
| ROUTINETAB-004 | App blocking editor hydrates current state. | Open app blocking step editor. | Existing selection, enabled state, times, grace period, and enforcement mode populate controls. |
| ROUTINETAB-005 | Saving app blocking config applies shield if currently in window. | Configure targets and save. | Selection persists, analytics logs, ManagedSettings shield updates if within active window. |
| ROUTINETAB-006 | Gentle bypass lasts until wake. | Tap bypass in gentle mode. | Bypass end is today's wake if before wake, otherwise tomorrow's wake; shield refreshes. |

## Mid-Sleep Mode

| ID | Expected behavior | Actions | Expected outputs |
| --- | --- | --- | --- |
| MID-001 | Mid-sleep mode detects sleep window from wall clock. | Open during/after sleep window. | Education copy and preview labels match in-window vs preview state. |
| MID-002 | Clock is live. | Wait one minute. | Clock/awake minutes update. |
| MID-003 | 4-7-8 tool opens breathing. | Tap breathing. | Breathing full-screen opens in mid-sleep mode; exit returns/dismisses. |
| MID-004 | Boring story is premium-gated. | Non-entitled user taps boring story. | Upgrade paywall opens. Entitled user opens story view. |
| MID-005 | Sleep sounds are premium-gated. | Non-entitled user taps sleep sounds. | Upgrade paywall opens. Entitled user opens mid-sleep sound view. |
| MID-006 | Get-up protocol is available. | Tap footer action. | Get-up prompt full-screen opens; science sheet can open. |
| MID-007 | Down swipe exits. | Swipe down. | Mid-sleep mode exits and brightness restores when leaving hidden tab. |

## Sleep Sounds

| ID | Expected behavior | Actions | Expected outputs |
| --- | --- | --- | --- |
| SOUND-001 | Audio store resolves bundled sound files. | Request URL for a sound. | Lookup checks flat bundle, `sleep`, `Audio/sleep`, then scans m4a resources. |
| SOUND-002 | Playback config starts audio. | Call `play(config:)` with sound ID. | Audio session activates, player loops, `isPlaying = true`, remaining time updates unless infinite. |
| SOUND-003 | Missing file reports an error. | Use a config with missing sound. | `lastPlaybackError` describes missing bundled audio; no crash. |
| SOUND-004 | Changing sound crossfades. | Play one sound, then another. | New sound starts; previous player fades/stops. |
| SOUND-005 | Mini-player appears while audio is playing. | Start sound outside full-screen player. | Mini-player is visible above tabs and opens sound UI when tapped. |
| SOUND-006 | Nightly/mid-sleep sound surfaces autoplay. | Open sound step/tool. | Active sound starts immediately, no delayed silence. |

## Notifications

| ID | Expected behavior | Actions | Expected outputs |
| --- | --- | --- | --- |
| NOTIF-001 | App registers notification categories on launch. | Start app. | Categories: `BEDTIME_REMINDER`, `MORNING_CHECKIN`, `MID_SLEEP_CHECK`, `WIND_DOWN_START`. |
| NOTIF-002 | Full schedule rebuild clears stale requests. | Call `scheduleAllNotifications()` with permission. | All pending requests are removed, then prep, morning, mid-sleep, and wind-down requests are scheduled. |
| NOTIF-003 | Prep reminders schedule for each prep step. | Given prep steps and bedtime. | Requests named `bedtime_prep_<label>` repeat daily at `bedtime - lead`. |
| NOTIF-004 | Prep summary schedules only when unchecked prep remains. | Prep items unchecked. | `bedtime_prep_summary` fires `windDownDuration + 10` minutes before bed with singular/plural body. |
| NOTIF-005 | Wind-down start notifications schedule around ritual duration. | Given wind-down steps. | Primary fires at committed time or `bedtime - duration`; follow-up fires 5 minutes later only if duration > 5. |
| NOTIF-006 | Morning primary fires when rating card is visible. | Unrated sleep window exists. | Primary rating notification fires exactly at wake anchor, not before. |
| NOTIF-007 | Morning notifications are not scheduled for already-rated windows. | Sleep window entry has score > 0. | No primary/noon request is added for that window. |
| NOTIF-008 | Noon fallback is inside visible rating window only. | Same-day or overnight schedules. | Noon fallback requires `noon >= wakeAnchor` and `noon < ratingWindowEnd`. |
| NOTIF-009 | Rating notification tap opens visible card. | Tap `MORNING_CHECKIN` at/after wake. | Today tab opens and clock refresh makes rating card visible if still unrated. |
| NOTIF-010 | Mid-sleep notification fires 3 hours after bedtime. | Schedule mid-sleep notification. | One-time `mid_sleep_check` request uses title `Still awake?`; tapping opens Mid-sleep mode. |

## App Blocking

| ID | Expected behavior | Actions | Expected outputs |
| --- | --- | --- | --- |
| BLOCK-001 | Default block window is bedtime to wake time. | Use default app blocking times. | Start equals `typicalBedtime`, end equals `typicalWakeTime`. |
| BLOCK-002 | Shield applies only with step, enabled state, targets, active window, and no bypass. | Configure permutations. | ManagedSettings shield applies only when all conditions are true. |
| BLOCK-003 | Active window handles overnight and same-day windows. | Test start < end, start > end, start == end. | Same-day uses inclusive start/exclusive end; overnight spans midnight; equal means always active. |
| BLOCK-004 | Next boundary refresh is scheduled. | Configure active app blocking. | Work item schedules just after next start/end boundary. |
| BLOCK-005 | Clearing conditions clears shield. | Disable, remove targets, leave window, or bypass. | `appBlockingStore.clearAllSettings()` is called. |

## Persistence And Data

| ID | Expected behavior | Actions | Expected outputs |
| --- | --- | --- | --- |
| DATA-001 | Persisted state round-trips. | Save then load app state fixture. | Core routine, logs, schedules, paywall state, app blocking config, and onboarding fields survive. |
| DATA-002 | Timezone changes re-anchor wall-clock times. | Change timezone. | Bedtime/wake/target/block times preserve local wall-clock intent; notifications reschedule. |
| DATA-003 | Orphaned rating migration merges score-only entries. | Seed legacy score-only morning entry and unrated completed prior entry. | Rating moves to completed wind-down entry; ghost is removed/ignored. |
| DATA-004 | Brain dump deletion cleans log references. | Delete a recording file. | Matching `brainDumpFilePath` and duration fields are cleared. |

## Paywall And Entitlements

| ID | Expected behavior | Actions | Expected outputs |
| --- | --- | --- | --- |
| PAY-001 | Subscription manager applies entitlement. | RevenueCat active entitlement changes. | `paywallState.tier` becomes subscribed; premium surfaces unlock. |
| PAY-002 | Premium-only tools route to paywall when locked. | Free user opens sleep sounds, boring story library, or hard app blocking setup. | RevenueCat paywall appears; requested action is not completed. |
| PAY-003 | Entitlement loss falls back cleanly. | Active subscription becomes inactive. | Tier falls back to trial/free based on trial state; gated features lock. |

## Suggested Unit Test Suites

### `RoutineGeneratorTests`

- `testStarterRoutineIncludesExpectedCategories`
- `testNoScreensUsesEnforcementMode`
- `testGeneratedRoutineIsDeterministicForFixtureAnswers`
- `testWarmShowerBiasDoesNotDuplicateWarmShower`
- `testBacklogExcludesSelectedRemedies`

### `AppStateDateLogicTests`

- `testBedtimeDateOvernightBeforeWakeReturnsPreviousDay`
- `testBedtimeDateSameDayWindowReturnsSameDay`
- `testBedtimeDateForWakeTimeTiesRatingToWindowStart`
- `testResetPrepIfNeededClearsAfterWake`
- `testIsWithinAppBlockingWindowSameDay`
- `testIsWithinAppBlockingWindowOvernight`
- `testIsWithinAppBlockingWindowEqualTimesAlwaysActive`

### `ScheduledRoutineTests`

- `testPrepStepsUseLeadTimes`
- `testRitualStepsPackBackwardFromBedtime`
- `testShortRitualShiftsEarlierToFillSleepWindow`
- `testScheduledRoutineSortsChronologically`
- `testRoutineEditsTriggerRescheduleHook` with an injectable scheduler spy.

### `MorningRatingTests`

- `testRatableEntryPrefersUnratedCompletedFlowOverScoreOnlyGhost`
- `testLogMorningScoreUpdatesExistingRatableEntry`
- `testLogMorningScoreCreatesBedtimeDayEntryWhenNeeded`
- `testLogMorningScoreClearsAndReschedulesMorningNotifications`
- `testRatingWindowStartsAtWake`
- `testRatingWindowEndsAtNextPrepStart`

### `AppBlockingOfferTests`

- `testOfferRequiresNoScreensCompletedNightAndNoTargets`
- `testOfferDoesNotRequireAbsenceOfAppBlockingStep`
- `testDismissFlagHidesOffer`
- `testAddAppBlockingDoesNotSetDismissFlag`
- `testConfiguredTargetsHideOffer`

### `NotificationSchedulingTests`

Use a `NotificationScheduling` protocol/fake instead of calling `UNUserNotificationCenter` directly.

- `testMorningPrimarySchedulesAtWakeAnchor`
- `testMorningPrimaryDoesNotScheduleBeforeNow`
- `testMorningNotificationSkippedForRatedWindow`
- `testNoonFallbackRequiresAfterWakeAndBeforeNextPrep`
- `testPrepSummarySkipsWhenNoUncheckedItems`
- `testWindDownFollowupSkippedWhenDurationAtOrBelowFiveMinutes`

### `SleepSoundsTests`

- `testSoundURLResolvesKnownBundledFile`
- `testMissingSoundSetsPlaybackError`
- `testPlaySetsCurrentConfigAndIsPlaying`
- `testTimedPlaybackSetsRemainingSeconds`
- `testInfinitePlaybackHasNoEndDate`

## Suggested Integration Tests

| ID | Flow | Assertions |
| --- | --- | --- |
| INT-001 | Generate routine -> schedule notifications. | Routine exists, scheduled routine rows exist, notification fake receives prep/wind-down/morning/mid-sleep requests. |
| INT-002 | Complete nightly flow -> wake -> rate. | Completed entry has `completedNightlyFlow = true`; wake shows rating; rating updates same entry and hides card. |
| INT-003 | First night app blocking offer. | After rating, offer remains visible; X hides it; Add routes to Routine without dismissal. |
| INT-004 | Configure app blocking. | Selection persists, shield fake applies during sleep window and clears outside it. |
| INT-005 | Audio while navigating. | Start sleep sound, mini-player appears, entering Mid-sleep stops/keeps audio only where intended by current app behavior. |
| INT-006 | Timezone change. | Times re-anchor and notifications reschedule once. |

## Suggested E2E Tests

### E2E-001: First-Run To Routine

1. Launch fresh install.
2. Tap `Help me sleep`.
3. Complete onboarding screens with fixture answers.
4. Finish/paywall path as test entitlement allows.

Expected:
- Main app opens.
- Today tab is selected.
- Routine exists.
- Tabs show `Today`, `Trends`, `Routine`.

### E2E-002: First Night Completion And Firefly

1. Seed/onboard user with routine.
2. Move clock to first prep start.
3. Complete prep/ritual cards from the deck.
4. Reach Good night screen.

Expected:
- Night log for bedtime day has `completedNightlyFlow = true`.
- Firefly reward/handoff appears as designed.
- Ritual done state is persisted.

### E2E-003: Morning Rating Queue

1. Seed completed unrated night.
2. Move clock to wake time.
3. Open app from morning notification or foreground.
4. Rate sleep.

Expected:
- Rating card is visible at wake.
- Rating card eases away.
- App blocking offer remains and moves up if eligible.
- Score persists to bedtime day.

### E2E-004: App Blocking Offer Lifecycle

1. Seed user with `No screens`, one completed night, no app targets, dismissed flag false.
2. Verify offer visible.
3. Tap Add.
4. Return without selecting apps.
5. Tap X.

Expected:
- Add routes to Routine/setup and does not dismiss.
- Offer remains eligible until targets are configured or X is tapped.
- X hides offer on future app launches.

### E2E-005: Notification Reliability

1. Seed upcoming sleep window and grant notifications.
2. Inspect pending notifications.
3. Advance to wake.
4. Tap morning notification.

Expected:
- Morning primary is scheduled at wake.
- No premature notification opens an empty Today screen.
- Tap opens Today with rating card visible.

### E2E-006: Mid-Sleep Tools

1. Seed user and move clock inside sleep window.
2. Open Mid-sleep via Today swipe up or notification.
3. Open breathing.
4. Open sleep sounds with entitlement fixture.
5. Open get-up prompt.

Expected:
- Mid-sleep mode displays current clock.
- Breathing has play/pause/speed controls.
- Sleep sounds play.
- Down swipe exits and restores normal app state.

### E2E-007: Trends Layout

1. Seed logs, routine chips, and ratings.
2. Open Trends on several screen sizes.

Expected:
- Stats card does not collide with calendar.
- Calendar remains visible with correct month label.
- Bottom tab says `Trends`.

## Testability Refactors Needed

These changes should be done before writing the full test suite:

1. Add a `LullTests` unit-test target and a `LullUITests` UI-test target to `project.yml` and the active Xcode project.
2. Inject a clock into `AppState` and Today view models so wake windows can be tested without real time.
3. Wrap `UNUserNotificationCenter` behind a protocol and fake scheduler.
4. Wrap `ManagedSettingsStore` behind a protocol/fake for app blocking tests.
5. Move Today state predicates into an internal testable helper, for example `TodaySurfaceState`.
6. Move app-blocking offer eligibility into a small pure helper if it grows beyond `AppState`.
7. Add deterministic fixture builders for onboarding answers, routine steps, sleep logs, and app blocking selections.
8. Add launch arguments for UI tests: reset storage, seed fixture state, override clock, force entitlement state, and disable animations when needed.

## Required Regression Gate Before Feature Work

Before merging a new feature:

1. Unit tests pass.
2. Integration tests pass.
3. E2E smoke tests pass on at least one compact and one large iPhone simulator.
4. Manual checks pass for local notifications, FamilyControls picker, Live Activities, and real audio playback.
5. `xcodebuild -quiet -project Lull.xcodeproj -scheme Lull -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build` passes.
