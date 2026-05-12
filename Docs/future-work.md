# Future Work

Features parked until the core experiment loop is validated with 5+ testers completing 14 nights.

---

## Live Activities (Dynamic Island + Lock Screen)

**What:** Persistent activity card that appears on the Lock Screen and Dynamic Island (iPhone 14 Pro+) — the kind of card that shows up next to the time in the screenshot of competitor apps showing water-bottle and fire-icon Live Activities.

**Highest-leverage use case:** the 20-minute mid-sleep get-up timer. User puts phone down, gets out of bed, glances at Lock Screen to see "12 min left" without unlocking — keeps them in wind-down mode. Eliminates the need to open the app at all during the get-up window.

**Secondary use cases (do later):**
- Boring story playback (current chapter + elapsed time)
- 4-7-8 breathing cycle counter
- Nightly flow current step + step number

**Technical scope:**
- New Widget Extension target in `Lull.xcodeproj`
- `ActivityAttributes` struct for the get-up timer state
- `ActivityConfiguration` widget bundle with 4 size states: compact leading, compact trailing, expanded, Lock Screen
- App Group entitlement so main app and extension share state
- `Activity.request / update / end` calls in `GetUpPromptView.scheduleGetUpNotification()`
- `NSSupportsLiveActivities = YES` in Info.plist
- Testing requires real device (simulator support is partial)

**Effort estimate:** ~1 full day for the get-up timer; subsequent activities ~half a day each because the extension scaffold is reused.

**Why deferred:** Live Activities are polish, not core. Won't move retention before the loop is proven. Premium feel is only valuable when there's a working experiment loop underneath.

**Trigger to revisit:** 5+ testers consistently completing 14-night cycles, OR a tester explicitly asks why the timer doesn't appear on their Lock Screen.
