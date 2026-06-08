 Lull — Production-Grade Persistence & De-Hardcoding    

 Context

 Today, only hasCompletedOnboarding survives an app relaunch (via @AppStorage). Every other piece of state — sleep logs,
 the user's personalized routine, onboarding answers, experiment progress — lives in memory and is wiped when the user
 kills the app. This breaks the core product loop: the experiment engine reads sleepLogs to decide which variable to test
 next, so without persistence, the engine cannot function.

 A full production pass also requires removing every hardcoded user-facing value (15 found across the app — see Section 2)
 and deleting dead state (bedroomTempF and lightsLevel were left on AppState after the Environment Check screen was
 removed; nothing reads them). Persistence without these cleanups would freeze the wrong shape into the JSON schema and
 ship demo placeholder data to real users.

 The change is delivered in three phases, in this order, so persistence sees the final schema:

 1. De-hardcode — every literal user-facing string/number becomes dynamic.
 2. Schema cleanup — delete dead state, expand SleepLogEntry for per-night observations.
 3. Persistence — Codable + JSON, save/load wired into key transitions.

 ---
 Phase 1 — De-hardcode user-facing values

 Hardcoded times in the nightly flow header (5 values)

 Lull/Nightly/NightlyFlowView.swift lines 49, 163, 242, 307, 517 pass literal strings ("10:25 PM", "10:32 PM", "10:38 PM",
 "10:50 PM", "11:02 PM") to NightlyStepHeader(time:). The infrastructure already exists — AppState.scheduledTime(for:
 String) returns the formatted clock time for any step in scheduledRoutine.

 Fix: Each step view computes its time from state.scheduledTime(for: <step label>) and passes that. If a step isn't in the
 routine schedule (e.g. mid-sleep entry into breathing), pass nil and NightlyStepHeader already hides the time line.

 Hardcoded date/time strings (4 values)

 ┌──────────────────────────────────┬──────┬──────────────┬────────────────────────────────────────────────────────────┐
 │               File               │ Line │   Literal    │                        Replacement                         │
 ├──────────────────────────────────┼──────┼──────────────┼────────────────────────────────────────────────────────────┤
 │                                  │      │ "Tuesday ·   │ Date() formatted with "EEEE · h:mm a" (recomputed via      │
 │ Home/DashboardView.swift         │ 36   │ 10:14 PM"    │ Timer every minute, or just on appear — apps like this     │
 │                                  │      │              │ don't need second-level accuracy)                          │
 ├──────────────────────────────────┼──────┼──────────────┼────────────────────────────────────────────────────────────┤
 │ Morning/MorningCheckInView.swift │ 18   │ "WED · 6:42  │ Date() formatted with "EEE · h:mm a", evaluated once on    │
 │                                  │      │ AM"          │ view appear                                                │
 ├──────────────────────────────────┼──────┼──────────────┼────────────────────────────────────────────────────────────┤
 │ MidSleep/MidSleepModeView.swift  │ 34   │ "03:14"      │ Date() formatted with "HH:mm" on view appear               │
 ├──────────────────────────────────┼──────┼──────────────┼────────────────────────────────────────────────────────────┤
 │                                  │      │ "I'LL GENTLY │ Date().addingTimeInterval(20*60) formatted as "HH:mm".     │
 │ MidSleep/GetUpPromptView.swift   │ 61   │  BUZZ AT     │ Also schedule the actual UNNotificationRequest so the line │
 │                                  │      │ 03:49"       │  stops being a lie.                                        │
 └──────────────────────────────────┴──────┴──────────────┴────────────────────────────────────────────────────────────┘

 Hardcoded brightness in NightlyBrightnessView (hybrid sensor + self-report)

 NightlyFlowView.swift lines 93, 102, 105 hardcode progress: 0.78, "78%" (current), and "TARGET · 35%". iOS does not expose
  an ambient light sensor publicly, so we use AVCaptureDevice (back camera EV) with self-report swatches as fallback.

 New service: Lull/Services/AmbientLightService.swift
 - Spins up an AVCaptureSession with the back wide-angle camera, no preview layer attached
 - Waits ~400ms for auto-exposure to settle, then reads device.iso and device.exposureDuration
 - Computes a brightness proxy: ev = log2((iso / 100) / exposureDuration) — higher = darker scene (camera compensated more)
 - Maps ev to a 4-bucket lightsLevel via empirically-tuned thresholds (defaults provided, marked // TODO: calibrate)
 - Stops the session and returns (lightsLevel: Int, confidence: Confidence)
 - Runs on a background queue; surfaces result on @MainActor
 - Total wall time: 300-800ms

 Confidence rules (when to reject the sensor reading and fall back to swatches):
 - Camera permission not granted → .fallback
 - Session fails to start within a 1.5s timeout → .fallback
 - EV reading suggests the lens is blocked (extremely dark + extremely high ISO) → .lowConfidence, prompt user to confirm
 - Otherwise → .high, use sensor value but show swatches pre-selected so user can override

 UX in the brightness step:
 1. On view appear: kick off AmbientLightService.read(). Show a "Reading…" placeholder for up to 1.5s.
 2. Result returns:
   - .high → display "We detected: Warm dim" with the 4 swatches, the detected one pre-selected. Source recorded as
 .sensor.
   - .lowConfidence → display "Couldn't tell — what does it look like?" with the 4 swatches, none pre-selected. Source
 recorded as .selfReported once user picks.
   - .fallback → display the swatches directly with no detection message. Source recorded as .selfReported.
 3. The "Continue" CTA is enabled once a swatch is selected (or auto-confirmed on .high).
 4. On confirm: state.updateTodayLog { $0.lightsLevel = picked; $0.lightsLevelSource = source }.

 Permission handling:
 - Add NSCameraUsageDescription to Lull/Resources/Info.plist. Copy: "Lull briefly checks your room's lighting at the start
 of your wind-down. The camera is never recorded or shown on screen."
 - Request permission lazily — only when the user first reaches the brightness check step.
 - If the user denies, the service short-circuits to .fallback and we never ask again on subsequent nights (we cache the
 denial in-memory for the session; on next app launch we'll see the already-denied authorization status from
 AVCaptureDevice.authorizationStatus(for: .video) and skip the prompt).
 - No setting screen to retry permission in v1 — they can re-enable in iOS Settings if they want; the swatch fallback is
 fully functional without it.

 Hardcoded sleep score average

 Home/MyRoutineView.swift line 161 displays "AVG 7.2". Replace with computed average of scored entries:
 let scored = state.sleepLogs.filter { $0.score > 0 }
 let avg = scored.isEmpty ? nil : Double(scored.map(\.score).reduce(0, +)) / Double(scored.count)
 Display "AVG \(formatted)" if non-nil; hide the row otherwise (empty-state for new users).

 Hardcoded dashboard suggestion copy

 Home/DashboardView.swift lines 63, 72 hardcode "Brain-dump night —" and "Stress signal was high today. Tonight's leaning
 on cognitive offload before breath work.". Replace with values derived from state.experimentStatus:

 - Variable line: state.tonightVariable (already exists)
 - Insight copy: state.experimentStatus?.insightLine (already exists in ExperimentEngine.Status)

 If experimentStatus is nil (no experiment running), show a graceful empty-state: "No experiment running tonight. Tap to
 pick a variable to test."

 Hardcoded greeting

 Home/DashboardView.swift line 38 always says "Good evening,". Replace with time-of-day computation:
 - 5–11 → "Good morning"
 - 12–16 → "Good afternoon"
 - 17–22 → "Good evening"
 - 22–5 → "Hi" (no greeting feels natural at 3am)

 Demo placeholder sleep logs

 Lull/Models/AppState.swift lines 272-287: SleepLogEntry.placeholders injects 14 fake nights labelled with magnesium and
 dim-the-lights data. For a real user this is misleading. Delete SleepLogEntry.placeholders. Replace sleepLogs initialiser
 with []. Empty-state UI:

 - The 14-dot history grid in MyRoutineView shows however many real entries exist; pad with grey skeleton dots if count <
 14.
 - The experiment engine returns nil until 5 scored nights accumulate — already its correct behaviour, no change needed.

 ---
 Phase 2 — Schema cleanup

 Delete dead state

 The Environment Check onboarding screen was removed but its backing state was left behind. Nothing reads these — confirmed
  by audit:

 - Lull/Models/AppState.swift lines 23-24 — delete bedroomTempF and lightsLevel @Published properties.
 - Lull/Models/RoutineGenerator.swift lines 162-183 — remove bedroomTempF and lightsLevel from OnboardingAnswers struct and
  its init(from:).

 Expand SleepLogEntry for per-night observations

 Per-night environment data and flow observations belong on the log entry, not on global state. New shape:

 struct SleepLogEntry: Identifiable, Codable {
     var id: UUID = UUID()

     // Identity
     var date: Date
     var variable: String                  // experiment variable being tested

     // Morning check-in
     var score: Int                        // 1–5; 0 = not yet rated
     var notes: String = ""
     var actualWakeTime: Date? = nil

     // Per-night environment observations (captured during nightly flow)
     var lightsLevel: Int? = nil                       // 0=Bright 1=Half-dim 2=Warm dim 3=Mostly dark
     var lightsLevelSource: LightsLevelSource? = nil   // .sensor | .selfReported — engine weights .sensor higher
     var perceivedTemp: Int? = nil                     // 0=cool 1=just-right 2=warm 3=hot
                                                       // (replaces transient AppState.selectedTemp)

     // Per-night flow observations
     var actualBedtime: Date? = nil        // when nightly flow finished
     var brainDumpDurationSec: Int? = nil  // 0 = skipped, nil = step not in routine
     var completedNightlyFlow: Bool = false

     var isToday: Bool { Calendar.current.isDateInToday(date) }
 }

 enum LightsLevelSource: String, Codable {
     case sensor        // camera-derived EV
     case selfReported  // user picked a swatch
 }

 All new fields optional — old persisted records and skipped steps both decode cleanly with missing keys.

 Wire per-night capture

 Add a helper on AppState to mutate today's entry, creating it if missing:

 func updateTodayLog(_ mutation: (inout SleepLogEntry) -> Void) {
     if let idx = sleepLogs.firstIndex(where: { $0.isToday }) {
         mutation(&sleepLogs[idx])
     } else {
         var entry = SleepLogEntry(date: Date(), variable: tonightVariable, score: 0)
         mutation(&entry)
         sleepLogs.append(entry)
     }
     persist()
 }

 Wire calls:

 - NightlyBrightnessView (after the hybrid sensor + swatch flow resolves): state.updateTodayLog { $0.lightsLevel = picked;
 $0.lightsLevelSource = source }
 - NightlyTemperatureView: state.updateTodayLog { $0.perceivedTemp = state.selectedTemp }
 - NightlyBrainDumpView (in handleDone): state.updateTodayLog { $0.brainDumpDurationSec = Int(recorder.duration) }
 - End of NightlyFlowView (the else branch where nightlyStep >= steps.count): state.updateTodayLog { $0.actualBedtime =
 Date(); $0.completedNightlyFlow = true }
 - logMorningScore(): also write actualWakeTime = Date().

 AppState.selectedTemp becomes purely transient mid-flow UI state — fine to keep, since the persisted value lives on the
 log entry.

 ---
 Phase 3 — Persistence (Codable + JSON file)

 Approach

 Skip CoreData and SwiftData. Reasoning:

 - Data volume is tiny (<100KB after a year of logs)
 - No querying needs — engine iterates the array
 - No multi-device sync planned
 - ~80 LOC of Codable + a single JSON file is trivial to test and reason about

 If we later need iCloud sync or per-night detail streams (HRV, audio embeddings), CoreData/CloudKit becomes the right
 call. For v1, JSON wins.

 New files

 Lull/Persistence/
   PersistedState.swift     // Codable snapshot struct + schemaVersion
   PersistenceStore.swift   // Atomic load/save to Documents directory

 Snapshot shape

 struct PersistedState: Codable {
     var schemaVersion: Int = 1

     // Onboarding answers (stable, baseline preferences)
     var selectedSleepProblems: Set<Int>
     var selectedWakes: Set<Int>
     var sleepWindowMinutes: Int
     var typicalBedtime: Date
     var typicalWakeTime: Date
     var selectedPreBedActivities: Set<Int>
     var selectedTriedThings: Set<Int>

     // Routine (mutated by experiment engine over time)
     var coreRoutine: [RoutineStep]
     var routineExplanation: String

     // Per-night history
     var sleepLogs: [SleepLogEntry]
 }

 Codable conformance changes (Lull/Models/AppState.swift)

 - SleepLogEntry: add Codable. Change let id = UUID() → var id: UUID = UUID() so it round-trips.
 - RoutineStep: add Codable. Same let id → var id change.
 - RoutineMode: add : String, Codable — raw-string-backed enum tolerates renames if new cases are added later.

 Store

 final class PersistenceStore {
     static let shared = PersistenceStore()

     private let fileURL: URL = {
         FileManager.default
             .urls(for: .documentDirectory, in: .userDomainMask)[0]
             .appendingPathComponent("lull_state.json")
     }()

     func load() -> PersistedState? {
         guard let data = try? Data(contentsOf: fileURL) else { return nil }
         let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
         do { return try decoder.decode(PersistedState.self, from: data) }
         catch { print("PersistenceStore: decode failed — \(error)"); return nil }
     }

     func save(_ snapshot: PersistedState) {
         let encoder = JSONEncoder()
         encoder.dateEncodingStrategy = .iso8601
         encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
         guard let data = try? encoder.encode(snapshot) else { return }
         // Atomic write — write to .tmp then rename, so a mid-write crash can't corrupt.
         let tmp = fileURL.appendingPathExtension("tmp")
         try? data.write(to: tmp, options: .atomic)
         _ = try? FileManager.default.replaceItemAt(fileURL, withItemAt: tmp)
     }
 }

 Save / load wiring in AppState

 - init(): call PersistenceStore.shared.load(). If non-nil, hydrate every @Published field. If nil, leave defaults —
 including the now-empty sleepLogs: [] (placeholders deleted in Phase 1).
 - persist(): build a PersistedState from current fields and call PersistenceStore.shared.save(_:).
 - Call persist() at the end of:
   - completeOnboarding()
   - applyGeneratedRoutine(_:)
   - logMorningScore()
   - changeExperimentVariable(to:)
   - advanceExperiment()
   - updateTodayLog(_:) (defined in Phase 2)
 - In LullApp.swift, observe @Environment(\.scenePhase) and call state.persist() on .background as a safety-net save.

 Edge cases

 - First launch (no file): load() returns nil → defaults (empty sleepLogs, no routine). Onboarding flow fills it in.
 - Corrupt/old file: load() returns nil and logs the error → fall back to defaults rather than crash. Next save overwrites
 the bad file.
 - Schema migration: schemaVersion: 1 baked in. On future schema bumps, the loader checks the version and either migrates
 or wipes (with a log line).
 - Crash mid-write: atomic .tmp + replaceItemAt prevents half-written files.

 ---
 Known risks (called out, not solved here)

 - Label-string brittleness: persisted SleepLogEntry.variable and RoutineStep.label are display strings. Renaming a remedy
 in RoutineGenerator.R orphans every old log. Right long-term fix is stable IDs on RoutineStep and R cases — out of scope;
 flagged so we don't pretend it's solved.
 - EV-to-bucket thresholds need calibration. The initial mapping from camera EV to the 4 lights buckets is a defensible
 default, but real-world tuning will happen as we accumulate sensor + self-report pairs. The lightsLevelSource field is
 what makes that calibration possible later — engine and post-hoc analysis can compare paired readings.
 - Camera permission denied = swatches forever. Acceptable for v1; add a Settings deep-link prompt later if many users deny
  by accident.

 ---
 Critical files referenced

 ┌──────────────────────────────────────────┬──────────────────────────────────────────────────────────────────────────┐
 │                   File                   │                                   Why                                    │
 ├──────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────┤
 │                                          │ All @Published fields; RoutineStep, RoutineMode, SleepLogEntry           │
 │ Lull/Models/AppState.swift               │ definitions; methods to wire (logMorningScore, applyGeneratedRoutine,    │
 │                                          │ advanceExperiment, changeExperimentVariable); placeholder deletion       │
 ├──────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────┤
 │ Lull/Models/ExperimentEngine.swift       │ Reads sleepLogs and coreRoutine — verifies what must survive persistence │
 ├──────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────┤
 │ Lull/Models/RoutineGenerator.swift       │ OnboardingAnswers struct (remove dead temp/lights fields); R enum        │
 │                                          │ referenced for label-string risk                                         │
 ├──────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────┤
 │ Lull/Onboarding/OnboardingView.swift     │ Confirmed Environment Check screen already removed; only consumer of     │
 │                                          │ OnboardingAnswers                                                        │
 ├──────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────┤
 │                                          │ 5 hardcoded times in step headers; brightness gauge replacement;         │
 │ Lull/Nightly/NightlyFlowView.swift       │ per-night capture wiring (updateTodayLog calls in                        │
 │                                          │ Brightness/Temperature/BrainDump/end-of-flow)                            │
 ├──────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────┤
 │ Lull/Home/DashboardView.swift            │ Hardcoded "Tuesday · 10:14 PM", "Good evening", suggestion copy          │
 ├──────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────┤
 │ Lull/Home/MyRoutineView.swift            │ Hardcoded "AVG 7.2"                                                      │
 ├──────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────┤
 │ Lull/Morning/MorningCheckInView.swift    │ Hardcoded "WED · 6:42 AM"; actualWakeTime capture in logMorningScore     │
 │                                          │ callsite                                                                 │
 ├──────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────┤
 │ Lull/MidSleep/MidSleepModeView.swift     │ Hardcoded "03:14"                                                        │
 ├──────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────┤
 │ Lull/MidSleep/GetUpPromptView.swift      │ Hardcoded "03:49"; wire actual UNNotificationRequest                     │
 ├──────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────┤
 │ Lull/LullApp.swift                       │ Scene phase observation for safety-net save                              │
 ├──────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────┤
 │ Lull/Persistence/PersistedState.swift    │ Codable snapshot struct                                                  │
 │ (new)                                    │                                                                          │
 ├──────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────┤
 │ Lull/Persistence/PersistenceStore.swift  │ File I/O                                                                 │
 │ (new)                                    │                                                                          │
 ├──────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────┤
 │ Lull/Services/AmbientLightService.swift  │ AVCaptureDevice EV reading + confidence rules                            │
 │ (new)                                    │                                                                          │
 ├──────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────┤
 │ Lull/Resources/Info.plist                │ Add NSCameraUsageDescription for the brightness sensor                   │
 └──────────────────────────────────────────┴──────────────────────────────────────────────────────────────────────────┘

 ---
 Verification

 End-to-end test sequence (manual, on simulator):

 1. Fresh install: delete app, reinstall, complete onboarding. Confirm lull_state.json appears in the simulator's Documents
  directory.
 2. Empty state: before any morning check-in, My Routine history dots show grey/skeleton (no fake placeholder scores).
 experimentStatus is nil; Dashboard shows the empty-state suggestion copy.
     Documents directory.
     2. Empty state: before any morning check-in, My Routine history dots show grey/skeleton (no fake placeholder scores).
     experimentStatus is nil; Dashboard shows the empty-state suggestion copy.
     3. Score persistence: log a score for today, kill app, relaunch, confirm the dot still shows the saved score.
     4. Per-night capture (sensor path): grant camera permission on first nightly flow, complete the brightness step in a
     normally-lit room, then kill app, relaunch, open today's log detail — confirm lightsLevel is set and lightsLevelSource
     == .sensor.
     5. Per-night capture (fallback path): deny camera permission OR cover the rear camera lens. Brightness step should fall
      through to swatches without crashing. Pick a swatch, finish the flow. Confirm lightsLevelSource == .selfReported.
     6. Experiment promote/drop survives relaunch: hand-edit JSON to give an experiment 5+ scored nights with delta > 0.3,
     relaunch, confirm experimentStatus.decision == .promote and the next candidate is queued.
     7. Time-of-day greeting: change simulator time to 9am — Dashboard says "Good morning"; 8pm → "Good evening"; 3am →
     "Hi".
     8. Dynamic step times: open nightly flow and verify each header time matches the value shown for that step on the My
     Routine schedule.
     9. Crash safety: set a breakpoint after data.write(to: tmp, ...) but before replaceItemAt. Stop the process. Relaunch —
      previous valid file should still load.
     10. Corrupt file: overwrite lull_state.json with invalid JSON. Relaunch. App must not crash; log line printed; defaults
      restored.
     11. Get-up notification: open GetUpPromptView, confirm displayed time matches "now + 20 min", and that a real
     UNNotificationRequest is scheduled at that time (verify via
     UNUserNotificationCenter.current().getPendingNotificationRequests).

     Optional unit tests (would add when XCTest target exists):
     - Round-trip PersistedState through encode/decode; assert equality.
     - PersistenceStore.save → load preserves all SleepLogEntry fields including new optional observations.