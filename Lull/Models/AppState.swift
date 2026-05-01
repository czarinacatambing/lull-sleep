import SwiftUI
import Combine

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

    // MARK: - Routine data (simulated)
    var todaysSuggestion = "Dim the lights 30 min before bed."
    var tonightVariable = "Dim the lights 30 min before bed."
    var variableNight = 3
    var variableScore = "+0.6"
    var historicalScores = [6, 7, 5, 8, 7, 9, 8, 7, 6, 8, 9, 8, 7, 9]
    @Published var coreRoutine: [RoutineStep] = [
        RoutineStep(order: 1, label: "Dim the lights", mode: .reminderOnly),
        RoutineStep(order: 2, label: "Brain dump", mode: .inSequence),
        RoutineStep(order: 3, label: "Boring story", mode: .inSequence),
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
    @Published var nightlyStep = 0          // 0=brightness 1=temp 2=braindump 3=boringstory
    @Published var useBreathingInstead = false
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

    // MARK: - Canonical schedule
    // Single source of truth used by both Dashboard and My Routine.
    // reminderOnly steps use evidence-based lead times relative to bedtime.
    // inSequence steps are packed into the sleep-onset window before bedtime.

    static let prepLeadTimes: [String: Int] = [
        "Dim the lights":   90,
        "No screens":       60,
        "Warm shower":      90,
        "Finish workouts": 180,
        "No heavy snacks": 120,
        "Magnesium":        60,
    ]

    var scheduledRoutine: [ScheduledStep] {
        let cal = Calendar.current
        let bed = typicalBedtime

        // Pack inSequence steps backwards from bedtime within the sleep window
        let inSeq = coreRoutine.filter { $0.mode == .inSequence }
        let seqDurations: [String: Int] = [
            "Brain dump":   2,
            "Boring story": 20,
        ]
        var seqOffset = 0
        var seqSteps: [ScheduledStep] = inSeq.reversed().map { step in
            let dur = seqDurations[step.label] ?? 5
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
                let badge = step.mode == .experiment ? "This week ↑" : "Reminder · \(mins) min before bed"
                return ScheduledStep(step: step, time: time, badge: badge)
            }

        return (prepSteps + seqSteps).sorted { $0.time < $1.time }
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
        let variables = ["Dim the lights", "Dim the lights", "No screens", "Dim the lights",
                         "No screens", "Dim the lights", "Magnesium", "Dim the lights",
                         "No screens", "Dim the lights", "Magnesium", "No screens", "Dim the lights"]
        let scores    = [6, 7, 5, 8, 7, 9, 8, 7, 6, 8, 9, 8, 7]
        let cal = Calendar.current
        var entries: [SleepLogEntry] = zip(scores, variables).enumerated().map { i, pair in
            let (score, variable) = pair
            let date = cal.date(byAdding: .day, value: -(scores.count - i), to: Date()) ?? Date()
            return SleepLogEntry(date: date, score: score, variable: variable)
        }
        // Today's entry — not yet rated
        entries.append(SleepLogEntry(date: Date(), score: 0, variable: "Dim the lights"))
        return entries
    }()
}
