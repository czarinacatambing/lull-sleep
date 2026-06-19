# Things I Wish I Knew Before Building an iOS App

A field guide of gotchas — the stuff that costs you an afternoon until someone tells you. Roughly grouped, no particular app required.

## Persistence & data

1. **A Codable property with a default value is still *required* at decode time.** The compiler-synthesized `init(from:)` throws `keyNotFound` on any older saved JSON that's missing the key — even though you gave it a default. Write a custom `init(from:)` using `decodeIfPresent(...) ?? default` for every field you add after launch.
2. **Add a `schemaVersion: Int` to your saved models from day one.** When decode fails, log it and fall back to defaults — never crash on old or corrupt data. Migrations are vastly easier when you can branch on a version number.
3. **Don't identify saved records by their display string.** Matching on label text ("Dim the lights") is a silent breaking change the moment you rename anything and users already have old data on disk. Give records stable enum/UUID IDs *before* you ship persistence — retrofitting is painful.
4. **Write files atomically: write to `file.tmp`, then rename.** A crash mid-write otherwise corrupts your only copy. The rename is atomic; the half-written temp file is harmless.
5. **You don't need Core Data for small data.** For a few hundred records, `Codable` + `JSONEncoder` (with `.iso8601` dates) + an atomic write is simpler and debuggable. Pretty-print it and log the file path so you can just open the JSON.
6. **`UserDefaults` is wiped when the app is deleted.** Anything that must survive a reinstall (install IDs, license tokens) belongs in the Keychain, which persists across deletion.
7. **`Codable` struct IDs should be `var`, not `let`** if you want them to round-trip cleanly through encode/decode.

## SwiftUI gotchas

8. **`onChange(of:)` changed signature in iOS 17** — it's now the two-argument closure `{ oldValue, newValue in }`. The single-argument form is deprecated.
9. **A `.sheet` attached directly to a `Button` can swallow the button's tap.** Move the sheet modifier to a parent container.
10. **Tap targets are exactly the visual size unless you say otherwise.** A 40pt circle has a 40pt hit area. Use `.contentShape(...)` on the parent (and a `minHeight`) to make the whole row/cell tappable, and keep targets ≥44pt — Apple's minimum.
11. **`withAnimation` inside `onAppear` gets swallowed by a parent transition** (e.g. a sheet sliding up). For animations that must run during a presentation transition, use `TimelineView` + `Canvas` with time-based frames instead of state-driven SwiftUI animation.
12. **Overlays that "burst" (confetti, particles) get clipped by `.clipShape()`.** Put them in `.overlay()` applied *before* the clip, not `.background()` — and `onAppear` timing is more reliable there too.
13. **`array.firstIndex(of:) ?? 0` silently shows you the wrong thing** when the item isn't found. Handle the `nil` explicitly instead of defaulting to index 0.
14. **`DateFormatter` is expensive to create — make it a `static let`.** Instantiating one per view render is a real, measurable cost.
15. **Keep derived state in computed properties on your model, not inline in the view.** Reusable, testable, and avoids the same filter/transform drifting out of sync across two screens.
16. **Keep transient UI state local; reserve a global `@Published` store for genuinely shared state.** Mid-interaction scaffolding (current step, in-progress input) doesn't belong in app-wide state.
17. **`@Environment(\.dismiss)` works the same in `sheet`, `fullScreenCover`, and `navigationDestination`** — it dismisses the current presentation layer regardless of how it was presented.
18. **Restore things like screen brightness via `onChange`, not the sheet's `onDismiss`.** `onDismiss` doesn't fire reliably when the view goes away through other navigation paths (tab switch, deep link).

## Concurrency

19. **Don't reflexively annotate everything `@MainActor`.** A service called synchronously from a background context (e.g. an App Intent handler) will hit an isolation error. Only main-isolate what actually touches UIKit/SwiftUI; dispatch explicitly when you need to.

## Notifications

20. **Ask for notification permission *after* onboarding, not on first launch.** Prompting before the user understands the value tanks your opt-in rate — and the dialog can fire before your UI is even ready.
21. **`UNCalendarNotificationTrigger` takes `DateComponents`, not a `Date`,** and uses the device's local time zone automatically. Include the `.day` component for a one-time fire; omit it for "repeat daily at this time."
22. **Foreground notifications are suppressed by default.** Implement the delegate's `willPresent` to show banners while the app is open.
23. **A notification action needs `options: [.foreground]` to open the app.** With empty options it runs in the background and the app never comes forward.
24. **Handle deep-link/notification presentation at the *root* of your view tree.** A `fullScreenCover` scoped inside one tab won't present when the user taps a notification from a different tab.

## App Extensions, Widgets & Live Activities

25. **Widgets and Live Activities run in a separate process** with no access to your app's in-memory state (`@Observable`, `@EnvironmentObject`). The only bridge is a shared App Group container.
26. **App Group entitlements must be identical across both targets** (app + extension). A mismatch disables sharing *silently* — no build error, it just doesn't work.
27. **Reads from a shared App Group right after the extension wrote can come back stale.** The cross-process write may not have flushed. A small delay (a few hundred ms) on foreground, or an explicit signal, avoids acting on old values.
28. **Live Activity buttons need the `.borderless` button style.** `.plain` silently suppresses the tap/intent dispatch — the button looks fine and does nothing.
29. **For tap-to-open from a Live Activity, prefer `widgetURL()`/`Link` over `openAppWhenRun`.** The latter is unreliable at foregrounding from the Dynamic Island, and it can preempt an in-flight `activity.update(...)` so your state change never shows.
30. **A Live Activity's `ContentState` must be `Codable & Hashable`, and you should keep it primitive.** Prefer `String` over `UUID`, `[String]` over `Set<UUID>`; an optional non-Codable field can crash the activity on a state transition.
31. **Drive live countdowns with `Text(timerInterval:)`, not animations.** The system renders the ticking text locally without waking your app (cheap on battery); ordinary SwiftUI animations don't run in Live Activity views at all.
32. **Guard any `Text(timerInterval:)` range so start ≤ end.** Once "now" passes the end time the range inverts and you get `Invalid frame dimension (NaN)` warnings — switch the view out before that happens.
33. **Live Activities last ~8 hours active (up to ~12 with a `staleDate`).** After that you can't push updates; a time-aware view checking the current date still re-renders. Spawning one from a *force-quit* app requires push-to-start — i.e. a backend.
34. **`NSSupportsLiveActivities = YES` goes in the main app's Info.plist,** not the extension's. There's no user permission prompt — it's a Settings toggle, on by default.
35. **Custom fonts must be registered in the *extension's own* Info.plist** (`UIAppFonts`) with the font file added to that target's build phase. The main app registering them isn't enough.
36. **Test Live Activities and Dynamic Island on a real device.** The Simulator renders their layout and animations unreliably.

## Build, signing & distribution

37. **Don't hardcode `CFBundleVersion`/`CFBundleShortVersionString` as literals in Info.plist.** Use the `$(CURRENT_PROJECT_VERSION)` / `$(MARKETING_VERSION)` build variables, or a literal will override your build settings and pin every upload to the same number.
38. **If you generate your project (XcodeGen/Tuist), set the version in the generator config,** not the generated files — regeneration reverts hand-edits to defaults.
39. **An app extension's `CFBundleVersion` must match the parent app's,** or App Store Connect rejects the upload. Extensions also need their own `CFBundleDisplayName` (missing it is error 90360).
40. **`ITSAppUsesNonExemptEncryption = false` in Info.plist permanently skips the export-compliance question** for apps that only use standard HTTPS. Saves a manual answer on every single upload.
41. **A portrait-only iPhone app still must declare all four orientations for iPad,** or App Store review flags missing iPad multitasking support.
42. **Pushing to git does nothing to your TestFlight build.** Distribution comes from an Xcode Archive, full stop. Also: the build you side-load from Xcode and the build from TestFlight are separate installs — delete and reinstall to be sure you're testing the latest.
43. **Editor errors aren't build errors.** SourceKit frequently shows "Cannot find type X" for symbols defined elsewhere in the same module. If the build succeeds, the code is correct — don't chase the red squiggles.

## Sensors, media & misc

44. **`UIScreen.main.brightness` is the *screen's* brightness setting, not ambient room light.** iOS doesn't expose the ambient light sensor. You can read camera exposure via `AVCaptureDevice`, but it fails silently when the phone is face-down or covered, so always offer a manual fallback. (Reaching for private sensor APIs gets you rejected.)
45. **To sync visuals to audio, poll the player's actual `currentTime`** (~0.1s cadence) rather than running a parallel math clock. Independent timers drift audibly against narration within seconds.
46. **Camera/mic/photo permission prompts appear on first *use*, not launch** — but the matching `NS...UsageDescription` string must already be in Info.plist or the app crashes when you ask. Missing usage strings for any linked SDK can also trip App Store warnings even if you never call the API.

---

*45-ish gotchas, learned the slow way so you don't have to. The recurring theme: iOS fails silently a lot — extensions, App Groups, Codable, and entitlements will all quietly do nothing rather than error, so when something "just doesn't work," suspect those first.*
