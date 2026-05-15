import SwiftUI
import Combine
import UserNotifications

class AppState: ObservableObject {

    // MARK: - Launch routing
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false

    // MARK: - Onboarding answers
    @Published var testerName: String = ""
    @Published var selectedSleepProblems: Set<Int> = []
    @Published var selectedWakes: Set<Int> = []
    @Published var sleepWindowMinutes: Int = 20
    @Published var typicalBedtime: Date = {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: yesterday) ?? Date()
    }()
    @Published var typicalWakeTime: Date = {
        return Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    }()
    @Published var selectedPreBedActivities: Set<Int> = []
    @Published var selectedTriedThings: Set<Int> = []

    // MARK: - Home / Dashboard
    @Published var showNightlyFlow = false
    @Published var showMidSleepMode = false
    @Published var showMorningCheckIn = false

    private var brightnessBeforeShake: CGFloat = UIScreen.main.brightness

    func activateMidSleepFromShake() {
        brightnessBeforeShake = UIScreen.main.brightness
        UIScreen.main.brightness = 0.0
        showMidSleepMode = true
    }

    func restoreBrightnessAfterMidSleep() {
        UIScreen.main.brightness = brightnessBeforeShake
    }

    // MARK: - Routine data

    var remedyScores: [String: Int] {
        scoreRemedies(from: OnboardingAnswers(from: self))
    }

    var experimentStatus: ExperimentEngine.Status? {
        ExperimentEngine.evaluate(logs: sleepLogs, coreRoutine: coreRoutine, remedyScores: remedyScores)
    }
    var tonightVariable: String { experimentStatus?.variable ?? "No experiment running" }
    var variableNight:   Int    { experimentStatus?.night ?? 0 }
    var variableScore:   String { experimentStatus?.scoreDeltaString ?? "—" }

    var tonightRemedyId: RemedyID? {
        coreRoutine.first { $0.mode == .experiment }?.remedyId
    }

    @Published var coreRoutine: [RoutineStep] = [
        RoutineStep(order: 1, label: R.dimTheLights,  mode: .experiment,  remedyId: .dimTheLights),
        RoutineStep(order: 2, label: "Brightness check", mode: .inSequence),
        RoutineStep(order: 3, label: "Temperature check", mode: .inSequence),
        RoutineStep(order: 4, label: R.brainDump,     mode: .inSequence,  remedyId: .brainDump),
        RoutineStep(order: 5, label: R.boringStory,   mode: .inSequence,  remedyId: .boringStory),
    ]

    // MARK: - Generated routine (set during onboarding)
    @Published var generatedRoutine: GeneratedRoutine? = nil
    @Published var routineExplanation: String = ""
    @Published var routineShouldStartNow: Bool = false

    func applyGeneratedRoutine(_ routine: GeneratedRoutine) {
        generatedRoutine      = routine
        coreRoutine           = routine.toCoreRoutineSteps()
        routineExplanation    = routine.explanation
        routineShouldStartNow = routine.shouldStartImmediately
        persist()
        scheduleAllNotifications()
    }

    // MARK: - Nightly walkthrough state
    @Published var nightlyStep = 0
    @Published var selectedTemp = 1          // 0=cool 1=justright 2=warm 3=hot (transient UI state)
    @Published var brainDumpSeconds = 0
    @Published var brainDumpRecording = false
    @Published var storyElapsedSeconds = 0
    @Published var breathingCycle = 2
    @Published var breathingPhase: BreathingPhase = .hold
    @Published var breathingSecondsRemaining = 7

    // MARK: - Prep checklist
    @Published var prepDoneIds: Set<UUID> = []
    @Published var prepDoneDate: Date? = nil

    func togglePrepDone(_ id: UUID) {
        if prepDoneIds.contains(id) { prepDoneIds.remove(id) }
        else { prepDoneIds.insert(id) }
        prepDoneDate = Date()
        persist()
        scheduleBedtimePrepSummary()
    }

    func resetPrepIfNeeded() {
        guard let lastDate = prepDoneDate else { return }
        let cal = Calendar.current
        let wc = cal.dateComponents([.hour, .minute], from: typicalWakeTime)
        guard let todayWake = cal.date(bySettingHour: wc.hour ?? 7,
                                       minute: wc.minute ?? 0,
                                       second: 0, of: Date()) else { return }
        if Date() >= todayWake && lastDate < todayWake {
            prepDoneIds = []
            prepDoneDate = nil
            persist()
            scheduleBedtimePrepSummary()
        }
    }

    // MARK: - Morning check-in
    @Published var baselineScore: Int = 0       // set once during onboarding
    @Published var morningScore = 0
    @Published var morningHoursSlept: Double = 7.5
    @Published var selectedDotIndex: Int? = nil
    @Published var sleepLogs: [SleepLogEntry] = []

    // MARK: - Promotion celebration
    // Set when an experimental variable graduates into the core routine; cleared
    // when the user dismisses the big celebration screen. Persisted so it survives
    // a relaunch if the user logs the rating and quits before seeing the modal.
    @Published var pendingPromotion: PendingPromotion? = nil

    // Set after acknowledging a promotion — drives the "Recently promoted" pill
    // on the routine list for 7 days. Persisted.
    @Published var recentlyPromotedRemedyId: RemedyID? = nil
    @Published var recentlyPromotedAt: Date? = nil

    // Transient (not persisted) — triggers a brief amber pulse on the routine
    // list item right after the big celebration dismisses.
    @Published var routinePulseRemedyId: RemedyID? = nil

    // Transient — when set, HomeTabView snaps to this tab index, then clears.
    // Used by acknowledgePromotion() to route the user to the Routine tab.
    @Published var requestedTab: Int? = nil

    var lastNightEntry: SleepLogEntry? {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return sleepLogs.last { Calendar.current.isDate($0.date, inSameDayAs: yesterday) }
    }

    // One-time data migration: consolidates orphaned morning-rating entries
    // produced by the pre-1.0(4) logMorningScore bug. That bug created a new
    // entry on the *morning-after* date holding only the score, leaving the
    // *wind-down* entry on the night-before date unrated. This function detects
    // those pairs and merges the rating back onto the wind-down entry.
    //
    // Only call once on launch (gated by schemaVersion in init).
    func migrateOrphanedRatings() {
        var removed: [Int] = []

        for (bIndex, b) in sleepLogs.enumerated() {
            // The bug signature: a score-only entry with no completed flow data.
            guard b.score > 0,
                  b.completedNightlyFlow == false,
                  b.actualBedtime == nil,
                  (b.stepAttempts).isEmpty
            else { continue }

            // Pair it with the most recent prior unrated entry that *did* run the flow.
            guard let aIndex = sleepLogs.indices
                .filter({ idx in
                    idx != bIndex &&
                    sleepLogs[idx].score == 0 &&
                    sleepLogs[idx].completedNightlyFlow == true &&
                    sleepLogs[idx].date < b.date
                })
                .max(by: { sleepLogs[$0].date < sleepLogs[$1].date })
            else { continue }

            // Same "night" sanity check — within 36 hours.
            let hoursBetween = b.date.timeIntervalSince(sleepLogs[aIndex].date) / 3600
            guard (0..<36).contains(hoursBetween) else { continue }

            // Merge the rating onto the wind-down entry.
            sleepLogs[aIndex].score            = b.score
            sleepLogs[aIndex].actualWakeTime   = b.actualWakeTime
            sleepLogs[aIndex].hoursSlept       = b.hoursSlept
            if !b.notes.isEmpty { sleepLogs[aIndex].notes = b.notes }
            if let bRemedyId = b.variableRemedyId, sleepLogs[aIndex].variableRemedyId == nil {
                sleepLogs[aIndex].variableRemedyId = bRemedyId
            }

            removed.append(bIndex)
        }

        // Remove orphans in reverse order so indices stay valid.
        for idx in removed.sorted(by: >) {
            sleepLogs.remove(at: idx)
        }

        if !removed.isEmpty {
            print("[Migration] Consolidated \(removed.count) orphaned rating entr\(removed.count == 1 ? "y" : "ies").")
        }
    }

    // Most recent unrated entry from today or yesterday. Used by the morning
    // rating flow to attribute the score to *last night's* sleep rather than
    // creating a new entry dated today.
    var ratableEntryIndex: Int? {
        let cal = Calendar.current
        return sleepLogs.indices
            .filter { i in
                let d = sleepLogs[i].date
                return sleepLogs[i].score == 0 && (cal.isDateInYesterday(d) || cal.isDateInToday(d))
            }
            .max(by: { sleepLogs[$0].date < sleepLogs[$1].date })
    }

    // MARK: - Export

    @Published var isExporting = false
    @Published var lastExportDate: Date? = UserDefaults.standard.object(forKey: "lullLastExportDate") as? Date
    @Published var lastExportError: String? = nil

    var installId: String {
        let key = "lullInstallId"
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let new = UUID().uuidString
        UserDefaults.standard.set(new, forKey: key)
        return new
    }

    // Fires exportData() at most once per calendar day. Called opportunistically
    // on app foreground and after morning score logging — Lull is a daily-use
    // app so one of those triggers will fire reliably without needing BGTaskScheduler.
    func autoExportIfDue() {
        if let last = lastExportDate, Calendar.current.isDateInToday(last) { return }
        exportData()
    }

    func exportData() {
        guard !isExporting else { return }
        isExporting = true
        lastExportError = nil

        let snapshot = PersistedState(
            schemaVersion: 1,
            testerName: testerName,
            selectedSleepProblems: selectedSleepProblems,
            selectedWakes: selectedWakes,
            sleepWindowMinutes: sleepWindowMinutes,
            typicalBedtime: typicalBedtime,
            typicalWakeTime: typicalWakeTime,
            selectedPreBedActivities: selectedPreBedActivities,
            selectedTriedThings: selectedTriedThings,
            coreRoutine: coreRoutine,
            routineExplanation: routineExplanation,
            sleepLogs: sleepLogs
        )

        let id = installId
        Task { @MainActor in
            do {
                try await ExportService.send(installId: id, state: snapshot)
                let now = Date()
                lastExportDate = now
                UserDefaults.standard.set(now, forKey: "lullLastExportDate")
            } catch {
                lastExportError = error.localizedDescription
            }
            isExporting = false
        }
    }

    // MARK: - Init / Persistence

    init() {
        if let saved = PersistenceStore.shared.load() {
            _testerName               = Published(initialValue: saved.testerName)
            _selectedSleepProblems    = Published(initialValue: saved.selectedSleepProblems)
            _selectedWakes            = Published(initialValue: saved.selectedWakes)
            _sleepWindowMinutes       = Published(initialValue: saved.sleepWindowMinutes)
            _typicalBedtime           = Published(initialValue: saved.typicalBedtime)
            _typicalWakeTime          = Published(initialValue: saved.typicalWakeTime)
            _selectedPreBedActivities = Published(initialValue: saved.selectedPreBedActivities)
            _selectedTriedThings      = Published(initialValue: saved.selectedTriedThings)
            _coreRoutine              = Published(initialValue: saved.coreRoutine)
            _routineExplanation       = Published(initialValue: saved.routineExplanation)
            _sleepLogs                = Published(initialValue: saved.sleepLogs)
            _baselineScore            = Published(initialValue: saved.baselineScore)
            _prepDoneIds              = Published(initialValue: Set(saved.prepDoneIds))
            _prepDoneDate             = Published(initialValue: saved.prepDoneDate)
            _pendingPromotion         = Published(initialValue: saved.pendingPromotion)
            _recentlyPromotedRemedyId = Published(initialValue: saved.recentlyPromotedRemedyId)
            _recentlyPromotedAt       = Published(initialValue: saved.recentlyPromotedAt)

            // Run any pending data migrations once.
            if saved.schemaVersion < 2 {
                DispatchQueue.main.async {
                    self.migrateOrphanedRatings()
                    self.persist()  // saves with new schemaVersion (default = 2)
                }
            }

            // Reschedule on every launch so notifications stay current (e.g. after OS clears them)
            DispatchQueue.main.async { self.scheduleAllNotifications() }
        }
    }

    func persist() {
        let snapshot = PersistedState(
            testerName:               testerName,
            selectedSleepProblems:    selectedSleepProblems,
            selectedWakes:            selectedWakes,
            sleepWindowMinutes:       sleepWindowMinutes,
            typicalBedtime:           typicalBedtime,
            typicalWakeTime:          typicalWakeTime,
            selectedPreBedActivities: selectedPreBedActivities,
            selectedTriedThings:      selectedTriedThings,
            coreRoutine:              coreRoutine,
            routineExplanation:       routineExplanation,
            sleepLogs:                sleepLogs,
            baselineScore:            baselineScore,
            prepDoneIds:              Array(prepDoneIds),
            prepDoneDate:             prepDoneDate,
            pendingPromotion:         pendingPromotion,
            recentlyPromotedRemedyId: recentlyPromotedRemedyId,
            recentlyPromotedAt:       recentlyPromotedAt
        )
        PersistenceStore.shared.save(snapshot)
    }

    // Upserts today's SleepLogEntry and persists.
    func updateTodayLog(_ mutation: (inout SleepLogEntry) -> Void) {
        if let idx = sleepLogs.firstIndex(where: { $0.isToday }) {
            mutation(&sleepLogs[idx])
        } else {
            var entry = SleepLogEntry(date: Date(), variable: tonightVariable, score: 0)
            entry.variableRemedyId = tonightRemedyId
            mutation(&entry)
            sleepLogs.append(entry)
        }
        persist()
    }

    // Records a completed/skipped attempt for the current nightly step.
    func recordCurrentStepAttempt(status: StepStatus, durationSeconds: Int? = nil) {
        guard nightlyStep < nightlyFlowSteps.count else { return }
        let kind = nightlyFlowSteps[nightlyStep]
        let label = kind.displayLabel
        let attempt = StepAttempt(
            remedyId: RemedyID.fromLabel(label),
            labelSnapshot: label,
            status: status,
            durationSeconds: durationSeconds
        )
        updateTodayLog { $0.stepAttempts.append(attempt) }
    }

    @Published var initialTab: Int = 0

    func completeOnboarding() {
        initialTab = 0
        hasCompletedOnboarding = true
        persist()
    }

    func completeOnboardingToRoutine() {
        initialTab = 1
        hasCompletedOnboarding = true
        persist()
    }

    func logMorningScore() {
        if let idx = ratableEntryIndex {
            sleepLogs[idx].score            = morningScore
            sleepLogs[idx].variable         = tonightVariable
            sleepLogs[idx].variableRemedyId = tonightRemedyId
            sleepLogs[idx].actualWakeTime   = Date()
            sleepLogs[idx].hoursSlept       = morningHoursSlept
        } else {
            // No recent unrated entry — create one dated yesterday so the dot
            // lands on "last night," not today.
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            var entry = SleepLogEntry(date: yesterday, variable: tonightVariable, score: morningScore)
            entry.variableRemedyId = tonightRemedyId
            entry.actualWakeTime   = Date()
            entry.hoursSlept       = morningHoursSlept
            sleepLogs.append(entry)
        }
        // If score is logged before noon, cancel the pending fallback so it doesn't fire today.
        // It's a repeating daily trigger, so re-adding it resets it to fire from tomorrow onward.
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["morning_rating_noon"])
        scheduleMorningRatingNotifications()
        advanceExperiment()
        persist()
        autoExportIfDue()
    }

    func movePreWindDown(from source: IndexSet, to destination: Int) {
        var section = preWindDownSteps
        section.move(fromOffsets: source, toOffset: destination)
        coreRoutine = section + windDownSteps
        persist()
    }

    func moveWindDown(from source: IndexSet, to destination: Int) {
        var section = windDownSteps
        section.move(fromOffsets: source, toOffset: destination)
        coreRoutine = preWindDownSteps + section
        persist()
    }

    @AppStorage("variableIsOverridden") var variableIsOverridden: Bool = false

    func changeExperimentVariable(to label: String) {
        coreRoutine.removeAll { $0.mode == .experiment }
        coreRoutine.append(RoutineStep(
            order: coreRoutine.count + 1,
            label: label,
            mode: .experiment,
            remedyId: RemedyID.fromLabel(label)
        ))
        variableIsOverridden = true
        persist()
        scheduleBedtimePrepNotifications()
    }

    func resetToSuggestedVariable() {
        let routineWithoutExperiment = coreRoutine.filter { $0.mode != .experiment }
        guard let suggested = ExperimentEngine.suggestNextVariable(
            logs: sleepLogs,
            coreRoutine: routineWithoutExperiment,
            remedyScores: remedyScores
        ) else { return }
        coreRoutine.removeAll { $0.mode == .experiment }
        coreRoutine.append(RoutineStep(
            order: coreRoutine.count + 1,
            label: suggested,
            mode: .experiment,
            remedyId: RemedyID.fromLabel(suggested)
        ))
        variableIsOverridden = false
        persist()
        scheduleBedtimePrepNotifications()
    }

    func advanceExperiment() {
        guard let status = experimentStatus else { return }
        switch status.decision {
        case .keepTesting: return
        case .promote:
            if let idx = coreRoutine.firstIndex(where: { $0.mode == .experiment }) {
                // Capture promotion data BEFORE mutating the step, so the celebration
                // screen sees the right variable/remedyId/sparkline.
                pendingPromotion = buildPendingPromotion(forStep: coreRoutine[idx], status: status)
                coreRoutine[idx].mode = .inSequence
            }
        case .drop:
            coreRoutine.removeAll { $0.mode == .experiment }
        }
        if let next = status.nextCandidate {
            coreRoutine.append(RoutineStep(
                order: coreRoutine.count + 1,
                label: next,
                mode: .experiment,
                remedyId: RemedyID.fromLabel(next)
            ))
        }
        persist()
        scheduleBedtimePrepNotifications()
    }

    private func buildPendingPromotion(forStep step: RoutineStep,
                                       status: ExperimentEngine.Status) -> PendingPromotion {
        let promotedLabel = step.label
        let promotedRemedyId = step.remedyId

        // Last 7 rated entries, oldest first. Pad with empty bars at the start
        // so the sparkline always has 7 columns.
        let last7 = sleepLogs
            .filter { $0.score > 0 }
            .sorted { $0.date < $1.date }
            .suffix(7)
        var bars: [PendingPromotion.SparkBar] = last7.map { entry in
            let onExp: Bool = {
                if let eid = entry.variableRemedyId, let rid = promotedRemedyId { return eid == rid }
                return entry.variable == promotedLabel
            }()
            return PendingPromotion.SparkBar(score: entry.score, onExperiment: onExp)
        }
        while bars.count < 7 {
            bars.insert(PendingPromotion.SparkBar(score: 0, onExperiment: false), at: 0)
        }

        return PendingPromotion(
            variable: promotedLabel,
            remedyId: promotedRemedyId,
            nights: status.night,
            averageLift: status.scoreDelta,
            sparkline: bars,
            promotedAt: Date()
        )
    }

    // Called when the user dismisses the big celebration screen. Promotes the
    // variable visually (pill + brief pulse), routes to the Routine tab, and
    // clears the pending modal.
    func acknowledgePromotion() {
        guard let pending = pendingPromotion else { return }
        recentlyPromotedRemedyId = pending.remedyId
        recentlyPromotedAt = Date()
        routinePulseRemedyId = pending.remedyId
        pendingPromotion = nil
        requestedTab = 1
        persist()
        // Clear the pulse after a short delay so the animation only fires once.
        let pulseTarget = pending.remedyId
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            if self?.routinePulseRemedyId == pulseTarget {
                self?.routinePulseRemedyId = nil
            }
        }
    }

    func scheduleMidSleepNotification() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["mid_sleep_check"])

        let content = UNMutableNotificationContent()
        content.title = "Still awake?"
        content.body = "Lull can help you drift back. One tap, no decisions."
        content.sound = .none
        content.categoryIdentifier = "MID_SLEEP_CHECK"

        let fireDate = Calendar.current.date(byAdding: .hour, value: 3, to: typicalBedtime) ?? typicalBedtime
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

        let request = UNNotificationRequest(identifier: "mid_sleep_check", content: content, trigger: trigger)
        center.add(request)
    }

    // Per-item primary notification copy — see Docs/notification-copy.md
    private static let prepNotificationCopy: [String: (title: String, body: String)] = [
        R.dimTheLights: (
            "Dim the lights",
            "Lamps only from here. Bright light tells your brain it's still daytime."
        ),
        R.noScreens: (
            "Wind down screen time",
            "Blue light suppresses melatonin and tells your brain it's still daytime. Lull is fine — TikTok, email, and news aren't. Taper from here."
        ),
        R.appBlocking: (
            "Lock the time-sinks",
            "Tap done after you've blocked the apps you don't want pulling you in tonight."
        ),
        R.finishWorkouts: (
            "Wrap your workout",
            "Cortisol takes about three hours to settle. Cool down when you can."
        ),
        R.noHeavySnacks: (
            "Last call on heavy food",
            "Big meals = restless sleep. A light snack is fine if you're hungry."
        ),
        R.noAlcohol: (
            "Last call on alcoholic drinks",
            "Even one alcoholic drink fragments your deep sleep tonight. It's a real trade-off."
        ),
        R.noCaffeine: (
            "Caffeine cutoff",
            "Caffeine has a six-hour shadow. Stop now and you'll feel it tonight."
        ),
        R.coldRoomPrep: (
            "Cool your room",
            "Sweet spot is 65–68°F. Crack a window or drop the thermostat now and it'll be perfect by bedtime."
        ),
        R.warmShower: (
            "Warm shower time",
            "A warm shower now triggers a body-temp drop that helps you fall asleep faster."
        ),
        R.magnesium: (
            "Take your magnesium",
            "200–400mg glycinate. Quiet, steady, no jitters. Take it with water."
        ),
        R.herbalTea: (
            "Brew your tea",
            "Chamomile or rooibos. Steep it now, sip it slow."
        ),
    ]

    func scheduleBedtimePrepNotifications() {
        let center = UNUserNotificationCenter.current()
        // Match preWindDownSteps so experiment-mode prep items (e.g. "Dim the lights"
        // when it's tonight's variable) also get reminder notifications.
        let prepSteps = preWindDownSteps
        let oldIds = prepSteps.map { "bedtime_prep_\($0.label)" }
        center.removePendingNotificationRequests(withIdentifiers: oldIds)

        let cal = Calendar.current
        for step in prepSteps {
            let leadMins = Self.prepLeadTimes[step.label] ?? 90
            guard let fireDate = cal.date(byAdding: .minute, value: -leadMins, to: typicalBedtime) else { continue }
            var comps = cal.dateComponents([.hour, .minute], from: fireDate)
            comps.second = 0

            let copy = Self.prepNotificationCopy[step.label] ?? (
                title: step.label,
                body: "Quick reminder, this one's part of tonight's prep. Tap done when you've got it."
            )

            let content = UNMutableNotificationContent()
            content.title = copy.title
            content.body = copy.body
            content.sound = .default
            content.categoryIdentifier = "BEDTIME_REMINDER"
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 1.0

            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let request = UNNotificationRequest(
                identifier: "bedtime_prep_\(step.label)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }

        scheduleBedtimePrepSummary()
        scheduleWindDownStartNotifications()
    }

    // Fires 10 min before wind-down ritual starts (i.e. 40 min before typicalBedtime)
    // if there are still unchecked prep items. Reschedules whenever prep state changes
    // so the body's count stays current.
    func scheduleBedtimePrepSummary() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["bedtime_prep_summary"])

        let prepSteps = preWindDownSteps
        let uncheckedCount = prepSteps.filter { !prepDoneIds.contains($0.id) }.count
        guard uncheckedCount > 0 else { return }

        let cal = Calendar.current
        // Fire 10 min before wind-down start (which itself is at bedtime - duration).
        let offsetFromBedtime = windDownDurationMinutes + 10
        guard let fireDate = cal.date(byAdding: .minute, value: -offsetFromBedtime, to: typicalBedtime) else { return }
        var comps = cal.dateComponents([.hour, .minute], from: fireDate)
        comps.second = 0

        let content = UNMutableNotificationContent()
        if uncheckedCount == 1 {
            content.title = "Bedtime — one item still open"
            content.body = "One prep item left. Knock it out or skip tonight — both fine."
        } else {
            content.title = "Bedtime — a few items still open"
            content.body = "\(uncheckedCount) prep items still on the list. Skip tonight or knock them out in the next few minutes."
        }
        content.sound = .default
        content.categoryIdentifier = "BEDTIME_REMINDER"
        content.interruptionLevel = .timeSensitive
        content.relevanceScore = 1.0

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: "bedtime_prep_summary", content: content, trigger: trigger)
        center.add(request)
    }

    // Total estimated duration of tonight's in-sequence wind-down ritual.
    // Used to compute when to fire the "Wind-down time" notification and how to
    // word the follow-up body. Floors at 1 min so we never produce a negative offset.
    var windDownDurationMinutes: Int {
        let total = windDownSteps.reduce(0) { sum, step in
            sum + (NightlyStepKind.forLabel(step.label)?.estimatedMinutes ?? 5)
        }
        return max(1, total)
    }

    // Primary fires at typicalBedtime - <wind-down duration> so starting now lands
    // the user in bed right at bedtime. Follow-up fires 5 min later if still no
    // ritual. cancelWindDownStartNotifications() clears pending requests once the
    // user starts the ritual.
    func scheduleWindDownStartNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [
            "wind_down_start_primary", "wind_down_start_followup"
        ])

        let cal = Calendar.current
        let duration = windDownDurationMinutes
        let followupGap = 5

        if let primaryFire = cal.date(byAdding: .minute, value: -duration, to: typicalBedtime) {
            var comps = cal.dateComponents([.hour, .minute], from: primaryFire)
            comps.second = 0

            let content = UNMutableNotificationContent()
            content.title = "Wind-down time"
            content.body = "Close to bedtime now. Tap to start tonight's ritual — Lull will guide you through to lights-out."
            content.sound = .default
            content.categoryIdentifier = "WIND_DOWN_START"
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 1.0

            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let request = UNNotificationRequest(identifier: "wind_down_start_primary", content: content, trigger: trigger)
            center.add(request)
        }

        // Skip follow-up if duration <= followupGap — otherwise it'd land at or past bedtime.
        if duration > followupGap,
           let followupFire = cal.date(byAdding: .minute, value: -(duration - followupGap), to: typicalBedtime) {
            var comps = cal.dateComponents([.hour, .minute], from: followupFire)
            comps.second = 0

            let content = UNMutableNotificationContent()
            content.title = "Bedtime's getting close"
            content.body = "Wind-down takes about \(duration) minutes. Start now and you'll land in bed right on time."
            content.sound = .default
            content.categoryIdentifier = "WIND_DOWN_START"
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 1.0

            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let request = UNNotificationRequest(identifier: "wind_down_start_followup", content: content, trigger: trigger)
            center.add(request)
        }
    }

    func cancelWindDownStartNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
            "wind_down_start_primary", "wind_down_start_followup"
        ])
    }

    func scheduleMorningRatingNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["morning_rating_primary", "morning_rating_noon"])

        let cal = Calendar.current

        // Primary: 30 minutes after typical wake time, repeats daily
        if let primaryFire = cal.date(byAdding: .minute, value: 30, to: typicalWakeTime) {
            var comps = cal.dateComponents([.hour, .minute], from: primaryFire)
            comps.second = 0

            let content = UNMutableNotificationContent()
            content.title = "How did you sleep?"
            content.body = "Take 5 seconds to rate last night. It helps Lull improve your routine."
            content.sound = .default
            content.categoryIdentifier = "MORNING_CHECKIN"

            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let request = UNNotificationRequest(identifier: "morning_rating_primary", content: content, trigger: trigger)
            center.add(request)
        }

        // Fallback: noon reminder, repeats daily (dismissed by app when score is already logged)
        var noonComps = DateComponents()
        noonComps.hour = 12
        noonComps.minute = 0
        noonComps.second = 0

        let noonContent = UNMutableNotificationContent()
        noonContent.title = "Still time to log your sleep"
        noonContent.body = "A quick rating helps track what's working for you."
        noonContent.sound = .default
        noonContent.categoryIdentifier = "MORNING_CHECKIN"

        let noonTrigger = UNCalendarNotificationTrigger(dateMatching: noonComps, repeats: true)
        let noonRequest = UNNotificationRequest(identifier: "morning_rating_noon", content: noonContent, trigger: noonTrigger)
        center.add(noonRequest)
    }

    func scheduleAllNotifications() {
        print("[NotifDebug] scheduleAllNotifications() called. bedtime=\(typicalBedtime), windDownDuration=\(windDownDurationMinutes)min, prepSteps=\(preWindDownSteps.count), windDownSteps=\(windDownSteps.count)")

        // UNUserNotificationCenter.add silently drops requests until permission
        // is granted. If status is .notDetermined we have to request first,
        // then do the actual scheduling on the main queue after the prompt
        // resolves.
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { [weak self] settings in
            guard let self = self else { return }
            print("[NotifDebug] auth status: \(settings.authorizationStatus.rawValue) (0=notDetermined, 1=denied, 2=authorized, 3=provisional)")

            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    print("[NotifDebug] permission prompt resolved: granted=\(granted), error=\(error?.localizedDescription ?? "nil")")
                    guard granted else { return }
                    DispatchQueue.main.async { self.performScheduling() }
                }
            case .denied:
                print("[NotifDebug] permission denied — user must re-enable in Settings → Lull → Notifications")
            default:
                DispatchQueue.main.async { self.performScheduling() }
            }
        }
    }

    private func performScheduling() {
        scheduleBedtimePrepNotifications()
        scheduleMorningRatingNotifications()
        scheduleMidSleepNotification()
        scheduleWindDownStartNotifications()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.dumpPendingNotifications()
        }
    }

    // Diagnostic — prints the next fire date of every pending request so we can
    // verify scheduling without poking around in Settings.
    func dumpPendingNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { reqs in
            print("[NotifDebug] \(reqs.count) pending request(s):")
            for r in reqs.sorted(by: { ($0.identifier) < ($1.identifier) }) {
                let next = (r.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
                print("  • \(r.identifier) → \(next.map { "\($0)" } ?? "no next fire")")
            }
        }
    }

    // MARK: - Canonical schedule

    static var prepLeadTimes: [String: Int] { remedyLeadTimes }

    var scheduledRoutine: [ScheduledStep] {
        let cal = Calendar.current
        let bed = typicalBedtime

        let inSeq = coreRoutine.filter {
            !Self.hiddenFromRitualDisplay.contains($0.label) && (
                $0.mode == .inSequence ||
                ($0.mode == .experiment && allWindDownRemedies.contains($0.label))
            )
        }
        var seqOffset = 0
        var seqSteps: [ScheduledStep] = inSeq.reversed().map { step in
            let dur = NightlyStepKind.forLabel(step.label)?.estimatedMinutes ?? 5
            seqOffset += dur
            let time = cal.date(byAdding: .minute, value: -seqOffset, to: bed) ?? bed
            return ScheduledStep(step: step, time: time, badge: "~\(dur) min")
        }.reversed()
        if let firstSeq = seqSteps.first {
            let windowStart = cal.date(byAdding: .minute, value: -sleepWindowMinutes, to: bed) ?? bed
            if firstSeq.time > windowStart {
                let shift = Int(firstSeq.time.timeIntervalSince(windowStart) / 60)
                seqSteps = seqSteps.map { s in
                    ScheduledStep(step: s.step,
                                  time: cal.date(byAdding: .minute, value: -shift, to: s.time) ?? s.time,
                                  badge: s.badge)
                }
            }
        }

        let prepSteps: [ScheduledStep] = coreRoutine
            .filter {
                $0.mode == .reminderOnly ||
                ($0.mode == .experiment && !allWindDownRemedies.contains($0.label))
            }
            .map { step in
                let mins = Self.prepLeadTimes[step.label] ?? 90
                let time = cal.date(byAdding: .minute, value: -mins, to: bed) ?? bed
                let badge = step.mode == .experiment ? "\(mins) min before bed" : "Reminder · \(mins) min before bed"
                return ScheduledStep(step: step, time: time, badge: badge)
            }

        return (prepSteps + seqSteps).sorted { $0.time < $1.time }
    }

    var preWindDownSteps: [RoutineStep] {
        coreRoutine.filter {
            $0.mode == .reminderOnly ||
            ($0.mode == .experiment && !allWindDownRemedies.contains($0.label))
        }
    }

    private static let hiddenFromRitualDisplay: Set<String> = ["Brightness check", "Temperature check"]

    var windDownSteps: [RoutineStep] {
        coreRoutine.filter {
            !Self.hiddenFromRitualDisplay.contains($0.label) && (
                $0.mode == .inSequence ||
                ($0.mode == .experiment && allWindDownRemedies.contains($0.label))
            )
        }
    }

    var nightlyFlowSteps: [NightlyStepKind] {
        coreRoutine.compactMap { step in
            if let kind = NightlyStepKind.forLabel(step.label) {
                if case .avoidReminder = kind { return nil }
                return kind
            }
            guard step.mode == .inSequence || step.mode == .experiment else { return nil }
            return .existingHabit(label: step.label)
        }
    }

    var nightlyStepTotal: Int { nightlyFlowSteps.count }

    func scheduledTime(for label: String) -> String? {
        scheduledRoutine.first { $0.step.label == label }?.timeString
    }

    var sleepDurationString: String {
        var dur = typicalWakeTime.timeIntervalSince(typicalBedtime)
        if dur < 0 { dur += 86400 }
        let h = Int(dur) / 3600
        let m = (Int(dur) % 3600) / 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }
}

// MARK: - Supporting types

struct ScheduledStep: Identifiable {
    let id = UUID()
    var step: RoutineStep
    var time: Date
    var badge: String

    private static let fmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "h:mm"; return f
    }()

    var timeString: String { Self.fmt.string(from: time) }
}

struct RoutineStep: Identifiable, Codable {
    var id: UUID = UUID()
    var order: Int
    var label: String
    var mode: RoutineMode
    var remedyId: RemedyID? = nil
}

enum RoutineMode: String, Codable {
    case reminderOnly, inSequence, experiment

    var label: String {
        switch self {
        case .reminderOnly: return "REMINDER ONLY"
        case .inSequence:   return "IN SEQUENCE"
        case .experiment:   return "↑ THIS WEEK"
        }
    }
}

enum BreathingPhase {
    case inhale, hold, exhale
    var label: String {
        switch self { case .inhale: return "In"; case .hold: return "Hold"; case .exhale: return "Out" }
    }
    var seconds: Int {
        switch self { case .inhale: return 4; case .hold: return 7; case .exhale: return 8 }
    }
}

struct SleepLogEntry: Identifiable, Codable {
    var id: UUID = UUID()

    // Identity
    var date: Date
    var variable: String               // display snapshot of the experiment variable
    var variableRemedyId: RemedyID? = nil  // stable ID for experiment engine comparison

    // Morning check-in
    var score: Int                     // 1–5; 0 = not yet rated
    var notes: String = ""
    var actualWakeTime: Date? = nil
    var hoursSlept: Double? = nil      // user-reported, 0.5 hr increments

    // Per-night environment observations (captured during nightly flow)
    var lightsLevel: Int? = nil            // 0=Bright 1=Half-dim 2=Warm dim 3=Mostly dark
    var lightsLevelSource: LightsLevelSource? = nil
    var perceivedTemp: Int? = nil          // 0=cool 1=just-right 2=warm 3=hot

    // Per-night flow observations
    var actualBedtime: Date? = nil         // when nightly flow finished
    var brainDumpDurationSec: Int? = nil   // 0 = skipped, nil = step not in routine
    var brainDumpFilePath: String? = nil   // relative to Documents dir
    var completedNightlyFlow: Bool = false

    var brainDumpFileURL: URL? {
        guard let path = brainDumpFilePath else { return nil }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(path)
    }

    // Per-step execution log
    var stepAttempts: [StepAttempt] = []

    var isToday: Bool { Calendar.current.isDateInToday(date) }
}
