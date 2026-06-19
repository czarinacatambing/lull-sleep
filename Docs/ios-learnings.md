# Top 50 iOS Build Learnings — Lull

Distilled from our Claude Code conversation transcripts across the build. Grouped by area, ordered roughly by how much pain each one saved.

## Live Activities & Widgets

1. **Use `.borderless`, never `.plain`, for Live Activity buttons.** `.plain` suppresses the intent dispatch so taps silently do nothing; `.borderless` is the correct interactive style on iOS 17+.
2. **`widgetURL()` / `Link(destination:)` beats `openAppWhenRun` for tap-to-open.** `openAppWhenRun = true` is flaky at foregrounding the app from the Dynamic Island; the first-class widget-tap mechanism is reliable.
3. **`await activity.update(...)` must finish before `openAppWhenRun` fires**, or the foregrounding preempts the state update and the Lock Screen card never reflects the change. Set `openAppWhenRun = false` and use `widgetURL()`.
4. **Live Activities are a separate Widget Extension target** with its own sandbox/process — they can't touch the app's `@Observable`/`@EnvironmentObject`; share state via App Group only.
5. **`ContentState` must be `Codable & Hashable` — prefer primitives.** Use `String` UUIDs and `[String]` over `UUID`/`Set<UUID>` for reliable encoding across the process boundary; optional non-Codable fields crash on state transition.
6. **Drive live countdowns with `Text(timerInterval:)`, not animations.** The system renders it locally (battery-cheap, no app wake); standard SwiftUI animations don't run in Live Activity views.
7. **Guard `Text(timerInterval:)` ranges against going invalid.** Once `Date()` crosses `wakeTime` the range flips and you get "Invalid frame dimension (NaN)" warnings — switch views via an `effectivePhase` before the range inverts.
8. **8-hour active window, ~12h with `staleDate`.** After the active window you can't push updates, but a `Date.now`-aware view still re-renders correctly. Push-to-start (17.2+, needs a backend) is the only way to spawn from a force-quit app.
9. **`NSSupportsLiveActivities = YES` goes in the *main app's* Info.plist**, not the extension. No user permission prompt — it's on by default in Settings.
10. **Test Live Activities on a physical device.** The Simulator renders Dynamic Island layout/animations unreliably; Lock Screen cards are closer but still not trustworthy.

## App Groups & cross-process IPC

11. **Add a ~0.3s delay before reading App Group values on foreground.** An extension's write may not have flushed when the app reads on `scenePhase.active` — you get stale values. (This bit us repeatedly.)
12. **App Group entitlement must be byte-identical on both targets.** A mismatch disables container sharing *silently* with no build error.
13. **Extension writes flag → app ingests on `scenePhase.active`.** Intent/button handlers run outside the app context, so direct state mutation doesn't persist — round-trip through App Group `UserDefaults`.
14. **`.onChange` won't fire for a flag set before the view mounts** (cold launch behind a splash). Add `.onAppear` as a safety net to pick up pre-existing flag state.
15. **Custom fonts must be registered in the extension's *own* Info.plist** via `UIAppFonts`, with the TTF added to the extension's build phase — they won't render otherwise.

## Persistence & Codable

16. **A Codable property with a default value is still required at decode time.** Synthesized `init(from:)` throws `keyNotFound` on old JSON — write a custom `init(from:)` using `decodeIfPresent` with fallbacks for every newly added field.
17. **Add a `schemaVersion: Int` from day one** and fall back to defaults on decode failure — never crash on bad/old data.
18. **Codable struct IDs must be `var`, not `let`** (`var id: UUID = UUID()`) so they round-trip on decode.
19. **Atomic writes prevent corruption:** write to `…json.tmp`, then rename. A crash mid-write keeps the previous good file.
20. **Ship stable enum IDs *before* persistence.** Matching steps/remedies by display-string is a silent breaking change the moment users have old logs referencing old labels (this is why `RemedyID` exists).
21. **Codable is fine over CoreData for small data** (<~365 entries): `JSONEncoder` + `.iso8601`, atomic write. `.prettyPrinted` to Documents + logging the path makes state inspectable without a debugger.
22. **`installId` in `UserDefaults` regenerates on reinstall** (UserDefaults is wiped on delete). Use Keychain for identifiers that must survive deletion.

## Notifications

23. **Request notification permission *after* onboarding, not in `App.init()`.** Prompting before the user gets the app tanks accept rates and can fire before the UI is stable.
24. **`UNCalendarNotificationTrigger` needs `DateComponents`, not a `Date`** — and respects the user's local time zone automatically. Include `.day` (not just hour/minute) for a one-time fire; omit it to repeat daily.
25. **Add an in-app `willPresent` handler** in the notification delegate or foreground notifications are silently suppressed.
26. **Notification actions need `options: [.foreground]`** to bring the app forward; with `[]` they run in the background and don't open the app.
27. **Hoist deep-link presentation to `ContentView`.** A `fullScreenCover` scoped inside one tab won't present when a notification is tapped from another tab — use `.onOpenURL` at the top level and force tab navigation.
28. **Don't reschedule notifications in both `Done` and `onDisappear`** — it fires twice. Pick one (Done).
29. **Schedule a noon fallback** alongside the wake-time + 30min morning notification so a missed window gets a second chance.

## SwiftUI patterns & gotchas

30. **`.sheet` attached directly to a `Button` can eat the tap.** Move the sheet modifier to a parent container.
31. **`.contentShape()` to expand hit areas.** A 42pt circle only has a 42pt tap target; set `.contentShape(Circle())` on the parent and a `minHeight` so the whole strip/cell is tappable. Keep targets ≥44pt.
32. **`onChange(of:)` is the two-argument form on iOS 17+:** `{ oldValue, newValue in }`. The single-arg form is deprecated.
33. **Confetti/animated overlays belong in `.overlay()` applied *before* `.clipShape()`,** not `.background()` — otherwise particles get clipped and `onAppear` timing is unreliable.
34. **`withAnimation` inside `onAppear` gets swallowed by a parent transition** (e.g., sheet slide-up). Use `TimelineView` + `Canvas` with frame-based timing for guaranteed rendering during transitions.
35. **Put derived state in computed properties on the state object,** not inline in views — reusable, testable, no duplication.
36. **Keep transient UI flags out of global `AppState`.** Breathing cycle / current step / morning score are mid-interaction scaffolding — keep them local; reserve `@Published` for real shared state.
37. **Make `DateFormatter` a `static let`** — initialization is expensive and recreating it every render is a real cost.
38. **`@Environment(\.dismiss)` works in sheet, fullScreenCover, and navigationDestination** — pass an `isMidSleep` flag to decide between "dismiss" vs "advance to next step."
39. **Save/restore `UIScreen.main.brightness` via `onChange`, not `onDismiss`.** `onDismiss` is unreliable when the sheet closes via tab switch or other navigation.
40. **`firstIndex(of:) ?? 0` silently shows the wrong screen** when the item isn't in the routine. Check for nil explicitly and present directly via `fullScreenCover`.

## Concurrency

41. **Don't slap `@MainActor` on a service called synchronously from an intent handler** — it causes a compiler/isolation error. ActivityKit doesn't require the main actor; drop it or dispatch explicitly. Methods spinning up `Task.detached` capturing `self` should be `nonisolated`.

## Build, Xcode & distribution

42. **Use `$(CURRENT_PROJECT_VERSION)` / `$(MARKETING_VERSION)` in Info.plist, never a hardcoded literal** — a literal `CFBundleVersion` overrides the build setting and pins you to one number across TestFlight uploads.
43. **With xcodegen, set the version in `project.yml`** — regenerating `project.pbxproj`/Info.plist reverts hardcoded values to defaults.
44. **Widget extension `CFBundleVersion` must match the parent app's** or App Store rejects the build; the extension also needs its own `CFBundleDisplayName` (error 90360).
45. **`ITSAppUsesNonExemptEncryption = false` in Info.plist permanently skips the export-compliance prompt** for HTTPS-only apps.
46. **Portrait-only iPhone still must declare all four orientations for iPad** via `UISupportedInterfaceOrientations~ipad`, or App Store flags missing multitasking support.
47. **Git push ≠ TestFlight build.** Pushing to GitHub does nothing to the distributed build — you must re-Archive in Xcode. Xcode-installed and TestFlight installs are separate; delete and reinstall to test latest.
48. **SourceKit "Cannot find type" across files in the same module are usually false positives** — trust the actual build, not the editor squiggles.

## Audio, sensors & UX

49. **Derive audio cue timing from the real recording (Whisper word-level timestamps), not planned targets** — and poll `AVAudioPlayer.currentTime` (~0.1s) to drive visuals. Math-based "14s per cycle" clocks drift audibly from narration.
50. **`UIScreen.main.brightness` is the phone's brightness, not the room's.** iOS doesn't expose the ambient light sensor; reading camera EV via `AVCaptureDevice` works but fails silently when the phone is face-down — always provide a manual swatch fallback. (Private sensor APIs get App Store rejected.)
