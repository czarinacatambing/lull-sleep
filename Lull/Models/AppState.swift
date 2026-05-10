import SwiftUI
import Combine
import UserNotifications

class AppState: ObservableObject {

    // MARK: - Launch routing
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false

    // MARK: - Onboarding answers
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
        }
    }

    // MARK: - Morning check-in
    @Published var morningScore = 0
    @Published var selectedDotIndex: Int? = nil
    @Published var sleepLogs: [SleepLogEntry] = []

    // MARK: - Init / Persistence

    init() {
        if let saved = PersistenceStore.shared.load() {
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
            _prepDoneIds              = Published(initialValue: Set(saved.prepDoneIds))
            _prepDoneDate             = Published(initialValue: saved.prepDoneDate)
            // Reschedule on every launch so notifications stay current (e.g. after OS clears them)
            DispatchQueue.main.async { self.scheduleAllNotifications() }
        }
    }

    func persist() {
        let snapshot = PersistedState(
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
            prepDoneIds:              Array(prepDoneIds),
            prepDoneDate:             prepDoneDate
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

    func completeOnboarding() {
        hasCompletedOnboarding = true
        persist()
    }

    func logMorningScore() {
        if let idx = sleepLogs.firstIndex(where: { $0.isToday }) {
            sleepLogs[idx].score         = morningScore
            sleepLogs[idx].variable      = tonightVariable
            sleepLogs[idx].variableRemedyId = tonightRemedyId
            sleepLogs[idx].actualWakeTime = Date()
        } else {
            var entry = SleepLogEntry(date: Date(), variable: tonightVariable, score: morningScore)
            entry.variableRemedyId = tonightRemedyId
            entry.actualWakeTime   = Date()
            sleepLogs.append(entry)
        }
        // If score is logged before noon, cancel the pending fallback so it doesn't fire today.
        // It's a repeating daily trigger, so re-adding it resets it to fire from tomorrow onward.
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["morning_rating_noon"])
        scheduleMorningRatingNotifications()
        advanceExperiment()
        persist()
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

    func scheduleBedtimePrepNotifications() {
        let center = UNUserNotificationCenter.current()
        let prepSteps = coreRoutine.filter { $0.mode == .reminderOnly }
        let oldIds = prepSteps.map { "bedtime_prep_\($0.label)" }
        center.removePendingNotificationRequests(withIdentifiers: oldIds)

        let cal = Calendar.current
        for step in prepSteps {
            let leadMins = Self.prepLeadTimes[step.label] ?? 90
            guard let fireDate = cal.date(byAdding: .minute, value: -leadMins, to: typicalBedtime) else { continue }
            var comps = cal.dateComponents([.hour, .minute], from: fireDate)
            comps.second = 0

            let content = UNMutableNotificationContent()
            content.title = step.label
            content.body = "\(leadMins) minutes before your target bedtime."
            content.sound = .default
            content.categoryIdentifier = "BEDTIME_REMINDER"

            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let request = UNNotificationRequest(
                identifier: "bedtime_prep_\(step.label)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
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
        scheduleBedtimePrepNotifications()
        scheduleMorningRatingNotifications()
        scheduleMidSleepNotification()
    }

    // MARK: - Canonical schedule

    static var prepLeadTimes: [String: Int] { remedyLeadTimes }

    var scheduledRoutine: [ScheduledStep] {
        let cal = Calendar.current
        let bed = typicalBedtime

        let inSeq = coreRoutine.filter {
            $0.mode == .inSequence ||
            ($0.mode == .experiment && allWindDownRemedies.contains($0.label))
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

    var windDownSteps: [RoutineStep] {
        coreRoutine.filter {
            $0.mode == .inSequence ||
            ($0.mode == .experiment && allWindDownRemedies.contains($0.label))
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

    // Per-night environment observations (captured during nightly flow)
    var lightsLevel: Int? = nil            // 0=Bright 1=Half-dim 2=Warm dim 3=Mostly dark
    var lightsLevelSource: LightsLevelSource? = nil
    var perceivedTemp: Int? = nil          // 0=cool 1=just-right 2=warm 3=hot

    // Per-night flow observations
    var actualBedtime: Date? = nil         // when nightly flow finished
    var brainDumpDurationSec: Int? = nil   // 0 = skipped, nil = step not in routine
    var completedNightlyFlow: Bool = false

    // Per-step execution log
    var stepAttempts: [StepAttempt] = []

    var isToday: Bool { Calendar.current.isDateInToday(date) }
}
