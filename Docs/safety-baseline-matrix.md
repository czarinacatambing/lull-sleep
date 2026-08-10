# Phase 0 Safety Baseline Matrix

This matrix is the cleanup traceability source of truth. `Automated` names an exact XCTest/XCUITest. `Device` names a check in the device checklist below. `Gap` means the behavior is identified but Phase 0 still needs a deterministic seam or an executed device result before deletion affecting it is safe.

## Traceability matrix

| ID | Current behavior to preserve | Positive proof | Negative proof | Baseline status |
| --- | --- | --- | --- | --- |
| LAUNCH-01 | Fresh install shows Welcome and enters current onboarding | `NavigationSmokeUITests.testFreshInstallShowsWelcomeThenCurrentOnboarding` | Same test asserts Today, Routine, and Insights are absent | Automated |
| LAUNCH-02 | Completed user opens Today/Rules/Trends | `NavigationSmokeUITests.testMainTabsShowTrendsInsteadOfInsights` | Same test asserts Routine and Insights are absent | Automated |
| ONB-01 | Current onboarding collects sleep thief, rules, window, contract, blocking commitment, and trial | D-01 | D-01 verifies no experiment/generated-routine/nightly screens | Required device |
| ONB-02 | Completion activates the contract and opens Today | `AppStateRegressionTests.testCompletingOnboardingStartsContractAppWithoutLegacyNightlyFlow` | Same test asserts legacy nightly flow is false | Automated |
| CONTRACT-01 | Overnight and same-day contract-day calculation | `testBedtimeDateForOvernightWindowBeforeWakeUsesPreviousDay`, `testBedtimeDateForSameDayWindowUsesCurrentDay`, `testBedtimeDateForSameDayWindowRollsForwardAfterWake` | Same-day roll-forward test prevents reuse of the prior cycle | Automated |
| CONTRACT-02 | Same-day windows show the next cycle after wake | `testSameDaySleepWindowShowsNextCycleRulesAfterWake` | Asserts stale prior-cycle actionability is absent | Automated |
| CONTRACT-03 | Only selected rules appear in preview | `testSleepContractPreviewShowsOnlySelectedRules` | Same test asserts an unselected rule is excluded | Automated |
| CONTRACT-04 | Rules already past when onboarding activates begin tomorrow | `testPastRuleAfterOnboardingActivationStartsTomorrow`, `testOnboardingActivationAfterMorningSunWindowDoesNotLockImmediately` | No immediate stale lock after activation | Automated |
| CONTRACT-05 | Multiple overdue rules remain actionable and earliest rule locks | `testMultipleOverdueRulesRemainActionableAndEarliestLocks` | One overdue rule does not erase another | Automated |
| CONTRACT-06 | Late completion unlocks directly | `testLateCompletionUnlocksWithoutCooldown`, `testSleepWindowAppliesAfterLateCompletion` | No cooldown is introduced by late completion | Automated |
| CONTRACT-07 | Slip starts exactly the current ten-minute cooldown | `testSlippedRuleCreatesTenMinuteCooldownWithoutEarlySleepWindow`, `testCooldownSnapshotUsesExactNowAndTenMinuteDeadline` | Sleep window does not begin early | Automated |
| CONTRACT-08 | Post-midnight enforcement stays on the prior contract day | `testPostMidnightSleepWindowUsesPreviousContractDayItems` | `testPostMidnightOnboardingSuppressesPriorEveningRules` prevents pre-activation carryover | Automated |
| TODAY-01 | Ready for sleep is final and actionable after pre-bed rules clear | `testReadyForSleepCanBeCompletedBeforeSleepWindowWhenVisible`, `testReadyForSleepRemainsActionableDuringSleepWindowAfterRulesAreCleared` | `testReadyForSleepIsHiddenUntilEarlierHabitsAreCleared` | Automated |
| TODAY-02 | Current queue suppresses Morning Sun while Ready-for-sleep/sleep-window presentation owns Today | `testReadyForSleepPresentationHidesMorningSunFromTodayQueue`, `testSleepWindowHidesMorningSunBeforeWake` | `testMorningSunRemainsActionableButIsHiddenWhileReadyForSleepIsVisible` proves engine state is not silently resolved | Automated/current behavior |
| TODAY-03 | Hold-to-confirm completes the visible hero | `HoldToConfirmUITests.testHoldToConfirmHeroShowsRequiredControls` proves the current control is surfaced; `testHoldConfirmUITestFixtureShowsActionableHero` proves the state transition | D-02 verifies the real three-second gesture completes while tap/short hold does not | Automated state/surface + required device gesture |
| TODAY-04 | Contract reward requires final in-bed confirmation | `testContractFireflyRequiresInBedConfirmationAfterRulesAreCleared` | No reward before in-bed confirmation | Automated |
| TODAY-05 | All-clear records once without mutating retired routine completion | `testContractAllClearDoesNotMarkOldRoutineComplete` | Duplicate call returns no second event; legacy `completedNightlyFlow` remains false | Automated |
| RULES-01 | Rules screen shows and edits current rule/window configuration | D-03 | D-03 verifies locked/disabled controls cannot mutate state | Required device / Gap for UI automation |
| RULES-02 | Sleep-window edits keep blocking window synchronized | `testSleepWindowEditKeepsAppBlockingWindowInSync` | No stale blocking boundary remains | Automated |
| BLOCK-01 | Blocking window handles overnight and same-day ranges | `testAppBlockingWindowHandlesOvernightAndSameDayRanges` | Outside-window cases are false | Automated |
| BLOCK-02 | App target selection, authorization, schedule, shield, and extension enforcement work | `testDailyBlockingWindowRemainsActiveAfterAppHasBeenClosedForDays`, `testBlockingPlanUsesRecurringBaseWindowAndEmergencyReconciliation`; D-04, D-05 | `testDailyBlockingWindowDoesNotActivateBeforeItsEffectiveStart`, `testReconcileWindowNeverActsAsASecondShieldWindow`, `testShortOneTimeMonitorIsPaddedToDeviceActivityMinimum`; D-05 verifies disabled/no-target/outside-window/emergency conditions do not shield | Automated schedule logic + required device enforcement |
| BLOCK-03 | App-blocking offer remains until real targets are configured | `testAppBlockingOfferStaysEligibleAfterAddingStepUntilTargetsConfigured` | Merely adding setup does not dismiss the offer | Automated (legacy-named state still surfaced where applicable) |
| EMERGENCY-01 | Emergency access records a reason/duration and expires, with base monitors retained for restoration while the app is suspended | `testEmergencyAccessIsActiveOnlyUntilSelectedDurationEnds`, `testBlockingPlanUsesRecurringBaseWindowAndEmergencyReconciliation` | Exact end and later are inactive; reconciliation never acts as a shield window | Automated; D-05 verifies actual shield removal/restoration |
| NOTIF-01 | Only unresolved contract rules are eligible for notifications | `testCompletedSleepRuleIsNotEligibleForLockNotifications` | `testSlippedSleepRuleIsNotEligibleForLockNotifications` | Automated |
| NOTIF-02 | In-bed checkpoint never schedules a rule-lock notification | `testInBedCheckpointDoesNotScheduleRuleLockNotifications` | In-bed rule is excluded | Automated |
| NOTIF-03 | Permission, delivery timing, copy, and tap routing work | D-06 | D-06 verifies taps never route to Routine/Insights/nightly flow | Required device / Gap for scheduler fake |
| TRENDS-01 | Trends uses the shared calendar scene rather than the Today cluster | `NavigationSmokeUITests.testTrendsUsesSharedFireflyCalendarScene` | Cluster scene is absent on Trends | Automated |
| TRENDS-02 | Stats/calendar reflect contract events and empty states | D-07 | D-07 verifies unresolved/duplicate events do not inflate totals | Required device / Gap for extracted metrics tests |
| REWARD-01 | Firefly meadow, animation, handoff, and reduced-motion states remain visually correct | D-08 | Reduced Motion has no required motion and no lost content | Required device |
| MIDSLEEP-01 | Mid-sleep entry and breathing/get-up tools work | D-09 | Exit restores the app without exposing a hidden legacy tab | Required device / Gap for UI fixture |
| MIDSLEEP-02 | Stories and sounds follow entitlement gates | D-09, D-10 | Free/lapsed users receive paywall and cannot enter premium tool | Required device |
| AUDIO-01 | Bundled sound playback starts, controls, switches, and stops correctly | D-10 | Missing/ended/dismissed playback does not crash or continue unexpectedly | Required device / Gap for injectable audio engine |
| PAY-01 | Entitlement loss removes premium access and blocking | `testSubscriptionLapseClearsPremiumAccessAndAppBlocking`, `testDebugSimulateCancelledTrialExpiredDowngradesAccess` | No premium access remains after lapse/expiry | Automated |
| PAY-02 | Purchase, restore, and customer center update current routing | D-11 | Cancel/failure leaves entitlement and navigation unchanged | Required sandbox/device |
| SETTINGS-01 | Current settings, legal, notification, and subscription actions work | D-12 | No experiment/research-export control is surfaced | Required device |
| DATA-01 | Contract state survives encoding/decoding | `testPersistedStateRoundTripsSleepContractFields` | Contract fields are not dropped | Automated |
| DATA-02 | Pre-contract persisted data decodes safely | `testPreContractPersistedStateDefaultsContractFieldsSafely` | Missing contract keys do not crash or invent rules/events | Automated |
| ROUTE-01 | Foreground, notification, URL, and timezone routes refresh current surfaces | D-13 | No supported route opens retired UI or duplicates all-clear/completion | Required device / Gap for routing seam |
| REVIEW-01 | First morning rating queues one native review request | `testFirstMorningScoreQueuesNativeReviewRequestOnce` | `testLaterMorningScoresDoNotQueueNativeReviewRequestAgain`, `testConsumedNativeReviewRequestDoesNotQueueAgain` | Automated |

## Required real-device checklist

Record evidence for every check affected by a cleanup slice.

| Check | Procedure and pass condition |
| --- | --- |
| D-01 Current onboarding | Install clean; traverse all seven current steps; verify chosen rules/window carry into Today and Rules; verify no experiment, generated-routine editor, or nightly deck appears. |
| D-02 Today interactions | Exercise visible hero complete, short hold/tap, slip, cooldown, late completion, final in-bed confirmation, and all-clear. Only the full hold completes; each transition occurs once. |
| D-03 Rules editing | Edit every surfaced rule time/grace and sleep window; relaunch and verify persistence. During any locked state, verify controls marked unavailable cannot change configuration. |
| D-04 Screen Time setup | Deny then allow FamilyControls authorization; choose apps/categories; save and relaunch. Denial is recoverable; selection persists only after save. |
| D-05 Shield and lifecycle | With a selected real app, test before/start/during/end boundaries; enabled/disabled; targets/no targets; a ten-minute slip cooldown; gentle bypass; and every emergency duration. During active locks and temporary access, background, force-quit, and leave TenThirty unopened for more than 48 hours. Locks/unlocks must occur at their semantic boundaries without reopening TenThirty; temporary access must restore shielding at exact expiry; verify shield extension copy/actions. |
| D-06 Notifications | On a physical device grant/deny permission; verify due/grace delivery, resolved-rule cancellation, category copy, and tap routing. Denial must not block ordinary app use. |
| D-07 Trends | Seed/perform no-clear, lock, slip, and all-clear days; compare stats/calendar to source events; relaunch. Empty data stays empty and duplicate refreshes do not inflate counts. |
| D-08 Firefly visuals | Verify onboarding handoff, Today meadow/reward, Trends calendar scene, background/foreground, and Reduce Motion on/off. No overlap, missing content, or unexpected animation. |
| D-09 Mid-sleep | Enter during and outside the sleep window; run breathing and get-up flows; test story/sound locked and entitled states; exit each surface. No hidden legacy navigation appears. |
| D-10 Audio | Play, pause, resume, change, background/foreground, lock device, and dismiss for every surfaced audio entry. Audio state and controls agree; leaving a stopping surface stops playback. |
| D-11 RevenueCat sandbox | Test purchase success, cancel, failure, restore success/no purchase, entitlement expiry, and customer center. Access changes only on verified entitlement. |
| D-12 Settings/legal | Exercise every visible settings row, notification toggle, legal URL, support/account action, and subscription action. Verify no research export or experiment setting is visible. |
| D-13 Routing/lifecycle | Test cold/warm notification taps, supported `tenthirty://` routes, foreground refresh, timezone change, midnight, and app termination/relaunch. Route only to current surfaces; no duplicate events. |

## Phase 0 execution record

| Baseline | Environment | Result |
| --- | --- | --- |
| Compile | iPhone 17 Pro, iOS 26.5 simulator; 2026-08-08 | Passed |
| Unit | 58 `LullTests`; iPhone 17 Pro, iOS 26.5 simulator; 2026-08-08 | Passed |
| UI smoke | 4 tests in `NavigationSmokeUITests` and `HoldToConfirmUITests`; iPhone 17 Pro, iOS 26.5 simulator; 2026-08-08 | Passed |
| Device checklist | Physical iPhone / Screen Time / notification / RevenueCat sandbox | Not executed in this workspace |

The matrix intentionally exposes remaining seams instead of claiming universal automation. Any Phase 1 deletion touching a `Gap` row requires either the named device evidence or a new deterministic automated test first.
