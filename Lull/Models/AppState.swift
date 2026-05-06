import SwiftUI
import Combine
import UserNotifications

class AppState: ObservableObject {

    // MARK: - Launch routing
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false

    // MARK: - Onboarding answers
    @Published var selectedSleepProblems: Set<Int> = []
    @Published var selectedWakes: Set<Int> = []
    @Published var sleepWindowMinutes: Int = 20         // minutes available to fall (back) asleep
    @Published var typicalBedtime: Date = {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: yesterday) ?? Date()
    }()
    @Published var typicalWakeTime: Date = {
        return Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    }()
    @Published var selectedPreBedActivities: Set<Int> = []
    @Published var selectedTriedThings: Set<Int> = []
    @Published var bedroomTempF: Double = 67
    @Published var lightsLevel: Int = 2                 // 0=Bright 1=Half-dim 2=Warm dim 3=Mostly dark

    // MARK: - Home / Dashboard
    @Published var showNightlyFlow = false
    @Published var showMidSleepMode = false
    @Published var showMorningCheckIn = false

    // MARK: - Routine data
    var historicalScores = [6, 7, 5, 8, 7, 9, 8, 7, 6, 8, 9, 8, 7, 9]

    var experimentStatus: ExperimentEngine.Status? {
        ExperimentEngine.evaluate(logs: sleepLogs, coreRoutine: coreRoutine)
    }
    var tonightVariable: String { experimentStatus?.variable ?? "No experiment running" }
    var variableNight:   Int    { experimentStatus?.night ?? 0 }
    var variableScore:   String { experimentStatus?.scoreDeltaString ?? "—" }
    @Published var coreRoutine: [RoutineStep] = [
        RoutineStep(order: 1, label: "Dim the lights", mode: .reminderOnly),
        RoutineStep(order: 2, label: "Brain dump", mode: .inSequence),
        RoutineStep(order: 3, label: "Boring story", mode: .inSequence),
        RoutineStep(order: 4, label: "Magnesium glycinate · 30 min before bed", mode: .experiment),
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
    }

    // MARK: - Nightly walkthrough state
    @Published var nightlyStep = 0          // index into nightlyFlowSteps
    @Published var selectedTemp = 1         // 0=cool 1=justright 2=warm 3=hot
    @Published var brainDumpSeconds = 0
    @Published var brainDumpRecording = false
    @Published var storyElapsedSeconds = 0
    @Published var breathingCycle = 2
    @Published var breathingPhase: BreathingPhase = .hold
    @Published var breathingSecondsRemaining = 7

    // MARK: - Morning check-in
    @Published var morningScore = 4         // 1–5
    @Published var selectedDotIndex: Int? = nil
    @Published var sleepLogs: [SleepLogEntry] = SleepLogEntry.placeholders

    func completeOnboarding() {
        hasCompletedOnboarding = true
    }

    // Saves today's morning score and advances the experiment if 5 nights are complete.
    func logMorningScore() {
        if let idx = sleepLogs.firstIndex(where: { $0.isToday }) {
            sleepLogs[idx].score    = morningScore
            sleepLogs[idx].variable = tonightVariable
        } else {
            sleepLogs.append(SleepLogEntry(date: Date(), score: morningScore, variable: tonightVariable))
        }
        advanceExperiment()
    }

    func changeExperimentVariable(to label: String) {
        coreRoutine.removeAll { $0.mode == .experiment }
        coreRoutine.append(RoutineStep(order: coreRoutine.count + 1, label: label, mode: .experiment))
    }

    func advanceExperiment() {
        guard let status = experimentStatus else { return }
        switch status.decision {
        case .keepTesting: return
        case .promote:
            // Graduate the experiment step into the core sequence
            if let idx = coreRoutine.firstIndex(where: { $0.mode == .experiment }) {
                coreRoutine[idx].mode = .inSequence
            }
        case .drop:
            coreRoutine.removeAll { $0.mode == .experiment }
        }
        // Queue the next candidate as the new experiment
        if let next = status.nextCandidate {
            coreRoutine.append(RoutineStep(order: coreRoutine.count + 1, label: next, mode: .experiment))
        }
    }

    // Schedules a mid-sleep check notification ~3 hours after bedtime.
    // Called at the end of the nightly wind-down flow.
    func scheduleMidSleepNotification() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["mid_sleep_check"])

        let content = UNMutableNotificationContent()
        content.title = "Still awake?"
        content.body = "Lull can help you drift back. One tap, no decisions."
        content.sound = .none
        content.categoryIdentifier = "MID_SLEEP_CHECK"

        // Fire 3 hours after bedtime
        let fireDate = Calendar.current.date(byAdding: .hour, value: 3, to: typicalBedtime) ?? typicalBedtime
        let comps = Calendar.current.dateComponents([.hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

        let request = UNNotificationRequest(identifier: "mid_sleep_check", content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - Canonical schedule
    // Single source of truth used by both Dashboard and My Routine.
    // reminderOnly steps use evidence-based lead times relative to bedtime.
    // inSequence steps are packed into the sleep-onset window before bedtime.

    static let prepLeadTimes: [String: Int] = [
        "Dim the lights":       90,
        "Dimming the lights":   90,
        "No screens":           60,
        "Warm shower":          90,
        "Warm shower or bath":  90,
        "Finish workouts":     180,
        "No heavy snacks":     120,
        "Magnesium":            60,
        "Reading (physical book)": 30,
    ]

    var scheduledRoutine: [ScheduledStep] {
        let cal = Calendar.current
        let bed = typicalBedtime

        // Pack inSequence steps backwards from bedtime within the sleep window
        let inSeq = coreRoutine.filter { $0.mode == .inSequence }
        var seqOffset = 0
        var seqSteps: [ScheduledStep] = inSeq.reversed().map { step in
            let dur = NightlyStepKind.forLabel(step.label)?.estimatedMinutes ?? 5
            seqOffset += dur
            let time = cal.date(byAdding: .minute, value: -seqOffset, to: bed) ?? bed
            return ScheduledStep(step: step, time: time, badge: "~\(dur) min")
        }.reversed()
        // If the sequence doesn't fill the window, shift start to match window
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

        // reminderOnly / experiment steps use evidence-based lead times
        let prepSteps: [ScheduledStep] = coreRoutine
            .filter { $0.mode == .reminderOnly || $0.mode == .experiment }
            .map { step in
                let mins = Self.prepLeadTimes[step.label] ?? 90
                let time = cal.date(byAdding: .minute, value: -mins, to: bed) ?? bed
                let badge = step.mode == .experiment ? "\(mins) min before bed" : "Reminder · \(mins) min before bed"
                return ScheduledStep(step: step, time: time, badge: badge)
            }

        return (prepSteps + seqSteps).sorted { $0.time < $1.time }
    }

    // Ordered list of interactive steps to run in the nightly flow, derived from coreRoutine.
    // avoidReminder steps (evening cutoff notifications) are excluded — they're not interactive.
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

    // Scheduled display time for a named step, e.g. "Brain dump" → "10:50".
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

struct RoutineStep: Identifiable {
    let id = UUID()
    var order: Int
    var label: String
    var mode: RoutineMode
}

enum RoutineMode {
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

struct SleepLogEntry: Identifiable {
    let id = UUID()
    var date: Date
    var score: Int           // 1–5
    var variable: String     // what was tested that night
    var notes: String = ""

    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    // 14 placeholder nights — last entry = today (no score yet)
    static let placeholders: [SleepLogEntry] = {
        let exp = "Magnesium glycinate · 30 min before bed"
        let variables = ["Dim the lights", "Dim the lights", "No screens", "Dim the lights",
                         "No screens", "Dim the lights", "Dim the lights", "Dim the lights",
                         "No screens", "Dim the lights", exp, exp, exp]
        let scores    = [6, 7, 5, 8, 7, 9, 8, 7, 6, 8, 8, 9, 9]
        let cal = Calendar.current
        var entries: [SleepLogEntry] = zip(scores, variables).enumerated().map { i, pair in
            let (score, variable) = pair
            let date = cal.date(byAdding: .day, value: -(scores.count - i), to: Date()) ?? Date()
            return SleepLogEntry(date: date, score: score, variable: variable)
        }
        // Today's entry — not yet rated
        entries.append(SleepLogEntry(date: Date(), score: 0, variable: exp))
        return entries
    }()
}
