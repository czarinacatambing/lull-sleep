import Foundation

// MARK: - Onboarding Answer Mapping

struct OnboardingAnswers {
    // Screen 1 — sleep problems: 0=can't fall asleep, 1=brain races, 2=wakes at night, 3=unrefreshed
    let sleepProblems: Set<Int>
    // Screen 2 — waking factors: 0=new parent, 1=shift, 2=founder, 3=ADHD, 4=anxiety, 5=physical, 6=medical, 7=none
    let wakingFactors: Set<Int>
    // Screen 3 — window in minutes: 7, 15, 25, 35
    let mainWindowMinutes: Int
    // Screen 4 — bedtime / wake
    let typicalBedtime: Date
    let typicalWakeTime: Date
    // Screen 5 — pre-bed: 0=phone, 1=TV, 2=book, 3=talk, 4=dim lights, 5=shower, 6=exercise, 7=eat, 8=nothing
    let preBedActivities: Set<Int>
    // Screen 6 — tried before: 0=melatonin, 1=meditation, 2=light dinner, 3=journaling, 4=therapy, 5=CBT-I, 6=warm bath
    let triedBefore: Set<Int>
    // Screen 7 — environment
    let bedroomTempF: Double
    let lightsLevel: Int  // 0=Bright 1=Half-dim 2=Warm dim 3=Mostly dark

    init(from state: AppState) {
        sleepProblems     = state.selectedSleepProblems
        wakingFactors     = state.selectedWakes
        mainWindowMinutes = state.sleepWindowMinutes
        typicalBedtime    = state.typicalBedtime
        typicalWakeTime   = state.typicalWakeTime
        preBedActivities  = state.selectedPreBedActivities
        triedBefore       = state.selectedTriedThings
        bedroomTempF      = state.bedroomTempF
        lightsLevel       = state.lightsLevel
    }

    // Minutes until the user's typical bedtime (from right now).
    // Returns 0 if bedtime passed within the last 30 min — treat that as "start now".
    var timeToTargetBedtimeMinutes: Int {
        let now = Date()
        let cal = Calendar.current
        let bedComponents = cal.dateComponents([.hour, .minute], from: typicalBedtime)
        guard let upcoming = cal.nextDate(
            after: now.addingTimeInterval(-30 * 60),
            matching: bedComponents,
            matchingPolicy: .nextTime
        ) else { return 999 }
        let diff = upcoming.timeIntervalSince(now)
        return diff < 0 ? 0 : Int(diff / 60)
    }

    // Convenience flags used by the generator
    var brainRaces: Bool        { sleepProblems.contains(1) }
    var wakesAtNight: Bool      { sleepProblems.contains(2) }
    var hasADHD: Bool           { wakingFactors.contains(3) }
    var hasAnxiety: Bool        { wakingFactors.contains(4) }
    var isNewParent: Bool       { wakingFactors.contains(0) }
    var isFounder: Bool         { wakingFactors.contains(2) }
    var roomIsTooWarm: Bool     { bedroomTempF >= 71 }
    var lightsAreTooHard: Bool  { lightsLevel <= 1 }
}

// MARK: - Nightly Step (generator-level type)

enum NightlyStepKind: Equatable {
    case brightnessCheck
    case temperatureLog
    case brainDump
    case boringStory
    case fourSevenEightBreathing
    case existingHabit(label: String)
    // An evening reminder to stop a habit X minutes before bed.
    // minutesBefore is evidence-based (screens=60, exercise=180, eating=120).
    case avoidReminder(label: String, minutesBefore: Int)

    var displayLabel: String {
        switch self {
        case .brightnessCheck:                  return "Dim the lights"
        case .temperatureLog:                   return "Temperature check"
        case .brainDump:                        return "Brain dump"
        case .boringStory:                      return "Boring story"
        case .fourSevenEightBreathing:          return "4-7-8 breathing"
        case .existingHabit(let label):         return label
        case .avoidReminder(let label, _):      return label
        }
    }

    // avoidReminders are not timed steps in the bedtime sequence
    var estimatedMinutes: Int {
        switch self {
        case .brightnessCheck:          return 1
        case .temperatureLog:           return 1
        case .brainDump:                return 2
        case .boringStory:              return 20
        case .fourSevenEightBreathing:  return 5
        case .existingHabit(let label):
            switch label {
            case "Warm shower or bath": return 10
            case "Reading (physical book)": return 20
            case "Dimming the lights": return 5
            default: return 5
            }
        case .avoidReminder:            return 0
        }
    }

    static func forLabel(_ label: String) -> NightlyStepKind? {
        switch label {
        case "Dim the lights":      return .brightnessCheck
        case "Temperature check":   return .temperatureLog
        case "Brain dump":          return .brainDump
        case "Boring story":        return .boringStory
        case "4-7-8 breathing":     return .fourSevenEightBreathing
        default:                    return nil
        }
    }

    var routineMode: RoutineMode {
        switch self {
        case .brightnessCheck, .temperatureLog, .avoidReminder:  return .reminderOnly
        case .existingHabit:                                      return .experiment
        default:                                                  return .inSequence
        }
    }

    func toRoutineStep(order: Int) -> RoutineStep {
        RoutineStep(order: order, label: displayLabel, mode: routineMode)
    }

    // Scheduled time relative to bedtime. avoidReminders use their own offset;
    // all others are computed by the caller from the sequential flow.
    func scheduledDate(bedtime: Date, sequenceOffset: Int) -> Date {
        let cal = Calendar.current
        if case .avoidReminder(_, let minutesBefore) = self {
            return cal.date(byAdding: .minute, value: -minutesBefore, to: bedtime) ?? bedtime
        }
        return cal.date(byAdding: .minute, value: -sequenceOffset, to: bedtime) ?? bedtime
    }
}

// MARK: - Generated Routine

struct GeneratedRoutine {
    // The bedtime sequence — steps the user actively does at night
    var steps: [NightlyStepKind]
    // Evening reminders to stop harmful habits before the routine even starts
    var avoidReminders: [NightlyStepKind]
    var explanation: String
    var keptHabitLabels: [String]
    var shouldStartImmediately: Bool

    var totalMinutes: Int { steps.reduce(0) { $0 + $1.estimatedMinutes } }

    // Converts to RoutineStep structs for AppState.coreRoutine.
    // avoidReminders come first (Pre-Wind Down), then the bedtime sequence.
    func toCoreRoutineSteps() -> [RoutineStep] {
        (avoidReminders + steps).enumerated().map { i, kind in kind.toRoutineStep(order: i + 1) }
    }
}

// MARK: - Main Entry Point

func generateStartingRoutine(from answers: OnboardingAnswers) -> GeneratedRoutine {
    let isCloseToBedtime = answers.timeToTargetBedtimeMinutes <= 60
    var steps: [NightlyStepKind] = []

    // 1. Environmental checks only when bedtime is imminent
    if isCloseToBedtime {
        if answers.lightsAreTooHard { steps.append(.brightnessCheck) }
        if answers.roomIsTooWarm   { steps.append(.temperatureLog) }
    }

    // 2. Keep up to 2 high-value existing habits (the "Gentle Reset" anchor)
    let keptHabits = selectTopExistingHabits(from: answers, max: 2)
    steps += keptHabits.map { NightlyStepKind.existingHabit(label: $0) }

    // 3. Primary wind-down — the single highest-impact addition
    let primary = determinePrimaryWindDown(from: answers)
    steps.append(primary)

    // 4. Secondary wind-down if the window allows it
    if answers.mainWindowMinutes >= 10,
       let secondary = determineSecondaryWindDown(from: answers, excluding: primary) {
        steps.append(secondary)
    }

    // 5. Trim to fit the time window the user said they have
    let maxSteps: Int
    switch answers.mainWindowMinutes {
    case ..<10:    maxSteps = 3
    case 10..<20:  maxSteps = 4
    default:       maxSteps = steps.count
    }
    if steps.count > maxSteps { steps = Array(steps.prefix(maxSteps)) }

    // 6. Build avoid reminders (separate from bedtime steps — these fire earlier in the evening)
    let avoidReminders = buildAvoidReminders(from: answers)

    // 7. Build the Gentle Reset explanation
    let explanation = buildExplanation(answers: answers, steps: steps, keptHabits: keptHabits, avoidReminders: avoidReminders)

    return GeneratedRoutine(
        steps: steps,
        avoidReminders: avoidReminders,
        explanation: explanation,
        keptHabitLabels: keptHabits,
        shouldStartImmediately: isCloseToBedtime
    )
}

// MARK: - Habit Ranking

// Index → human label (matches OnboardingView Screen 5 order)
private let habitLabels: [Int: String] = [
    0: "Phone / scrolling",
    1: "TV / screens",
    2: "Reading (physical book)",
    3: "Socialising",
    4: "Dimming the lights",
    5: "Warm shower or bath",
    6: "Evening exercise",
    7: "Light snack",
    8: "Gentle wind-down",
]

// Positive score = sleep-friendly anchor worth keeping.
// Negative = harmful, gets an avoidReminder instead.
private let habitScore: [Int: Int] = [
    0: -2,  // phone — blue light + mental stimulation
    1: -2,  // TV — same
    2:  3,  // physical book — excellent cognitive off-ramp
    3:  1,  // socialising — ok if calm
    4:  3,  // dim lights — proven melatonin anchor
    5:  3,  // shower — triggers core-temp drop
    6: -1,  // exercise — fine in general, but timing within 3h disrupts sleep
    7: -1,  // snack — digestion disrupts sleep onset within 2h
    8:  0,  // "nothing specific" — no concrete anchor to keep
]

private func selectTopExistingHabits(from answers: OnboardingAnswers, max: Int) -> [String] {
    answers.preBedActivities
        .filter { (habitScore[$0] ?? 0) > 0 }
        .sorted { (habitScore[$0] ?? 0) > (habitScore[$1] ?? 0) }
        .prefix(max)
        .compactMap { habitLabels[$0] }
}

// MARK: - Avoid Reminders

// Evidence-based cutoffs for habits that interfere with sleep onset
private struct AvoidConfig {
    let label: String
    let minutesBefore: Int
    let reason: String
}

private let avoidConfigs: [Int: AvoidConfig] = [
    // Screens: blue light suppresses melatonin for ~60 min; mental stimulation adds more
    0: AvoidConfig(label: "No screens",         minutesBefore: 60,  reason: "screens delay melatonin by about 30–60 minutes"),
    1: AvoidConfig(label: "No screens",         minutesBefore: 60,  reason: "screens delay melatonin by about 30–60 minutes"),
    // Exercise: cortisol and adrenaline take ~2–3h to clear
    6: AvoidConfig(label: "Finish workouts",    minutesBefore: 180, reason: "intense exercise raises cortisol, which takes 2–3 hours to drop"),
    // Eating: digestion raises core temp and disrupts sleep onset within 2h
    7: AvoidConfig(label: "No heavy snacks",    minutesBefore: 120, reason: "digestion raises body temperature, which works against sleep onset"),
]

private func buildAvoidReminders(from answers: OnboardingAnswers) -> [NightlyStepKind] {
    var seen = Set<String>()  // deduplicate by label (phone + TV both → one "No screens")
    var reminders: [NightlyStepKind] = []

    // Sort by minutesBefore descending so the earliest reminder appears first
    let indices = answers.preBedActivities
        .compactMap { i -> (Int, AvoidConfig)? in
            guard let config = avoidConfigs[i] else { return nil }
            return (i, config)
        }
        .sorted { $0.1.minutesBefore > $1.1.minutesBefore }

    for (_, config) in indices {
        guard !seen.contains(config.label) else { continue }
        seen.insert(config.label)
        reminders.append(.avoidReminder(label: config.label, minutesBefore: config.minutesBefore))
    }

    return reminders
}

// MARK: - Wind-Down Selection

private func determinePrimaryWindDown(from answers: OnboardingAnswers) -> NightlyStepKind {
    // Racing brain / ADHD / founder → Brain Dump clears the queue before sleep
    if answers.brainRaces || answers.hasADHD || answers.isFounder { return .brainDump }
    // Anxiety → 4-7-8 is a direct nervous-system downshift
    if answers.hasAnxiety { return .fourSevenEightBreathing }
    // Default: boring story occupies the narrative brain without stimulating it
    return .boringStory
}

private func determineSecondaryWindDown(
    from answers: OnboardingAnswers,
    excluding primary: NightlyStepKind
) -> NightlyStepKind? {
    switch primary {
    case .brainDump:
        return .boringStory
    case .fourSevenEightBreathing:
        return .boringStory
    case .boringStory where answers.brainRaces || answers.hasADHD:
        return .brainDump
    default:
        return nil
    }
}

// MARK: - Explanation Builder

private func buildExplanation(
    answers: OnboardingAnswers,
    steps: [NightlyStepKind],
    keptHabits: [String],
    avoidReminders: [NightlyStepKind]
) -> String {
    var parts: [String] = []

    if !keptHabits.isEmpty {
        let list = keptHabits.joined(separator: " and ")
        parts.append("We kept your \(list) — you already do this well.")
    }

    for step in steps {
        switch step {
        case .brainDump:
            let reason: String
            if answers.hasADHD         { reason = "your mind tends to stay busy" }
            else if answers.isFounder  { reason = "you're carrying a lot at end of day" }
            else                       { reason = "your brain races when you lie down" }
            parts.append("Added Brain Dump because \(reason) — two minutes to empty the queue.")
        case .boringStory:
            parts.append("Added Boring Story to replace the mental chatter with something calm and forgettable.")
        case .fourSevenEightBreathing:
            parts.append("Added 4-7-8 Breathing — a direct signal to your nervous system to downshift.")
        case .brightnessCheck:
            parts.append("Starting with a light check — bright light at this hour delays melatonin by up to 30 minutes.")
        case .temperatureLog:
            parts.append("Your room is on the warm side. Cooling it down helps trigger the core-temperature drop that starts sleep.")
        default:
            break
        }
    }

    // Reference avoid reminders by name so the explanation connects to the Pre-Wind Down badges
    for reminder in avoidReminders {
        guard case .avoidReminder(let label, let minutesBefore) = reminder else { continue }
        let hours = minutesBefore >= 60 ? "\(minutesBefore / 60)h" : "\(minutesBefore) min"
        switch label {
        case "No screens":
            parts.append("We set a \(hours) screen cutoff — blue light and scrolling keep the brain alert long after you put the phone down.")
        case "Finish workouts":
            parts.append("Added a \(hours) workout cutoff — cortisol from exercise takes a few hours to clear before your body can settle.")
        case "No heavy snacks":
            parts.append("Added a \(hours) snack cutoff — digestion raises your core temperature, which works against sleep onset.")
        default:
            break
        }
    }

    return parts.joined(separator: " ")
}
