import Foundation

// MARK: - Canonical remedy name constants
// These string values are used as keys throughout the scoring system,
// as RoutineStep labels, and as SleepLogEntry.variable values.
// They must match NightlyStepKind.displayLabel exactly for Wind Down steps.

enum R {
    // Wind Down interactive steps
    static let brainDump        = "Brain dump"
    static let boringStory      = "Boring story"
    static let breathing478     = "4-7-8 breathing"
    static let gratitudeJournal = "Gratitude journal"
    static let gentleStretching = "Gentle stretching"
    static let pmr              = "Progressive muscle relaxation"
    static let readingBook      = "Reading (physical book)"

    // Bedtime Prep reminder steps
    static let dimTheLights    = "Dim the lights"
    static let noScreens       = "No screens"
    static let appBlocking     = "App blocking"
    static let finishWorkouts  = "Finish workouts"
    static let noHeavySnacks   = "No heavy snacks"
    static let noAlcohol       = "No alcohol"
    static let noCaffeine      = "No caffeine"
    static let coldRoomPrep    = "Cold room prep"
    static let warmShower      = "Warm shower or bath"
    static let magnesium       = "Magnesium glycinate"
    static let herbalTea       = "Herbal tea"
    static let weightedBlanket = "Weighted blanket"
}

// MARK: - Remedy lead times (minutes before bed)
// Used by both the generator and AppState.scheduledRoutine.
let remedyLeadTimes: [String: Int] = [
    R.noAlcohol:       180,
    R.noCaffeine:      360,
    R.noScreens:        75,
    R.appBlocking:      75,
    R.finishWorkouts:  180,
    R.noHeavySnacks:   120,
    R.dimTheLights:     75,
    R.coldRoomPrep:     90,
    R.warmShower:       90,
    R.magnesium:        45,
    R.herbalTea:        45,
    R.weightedBlanket:  30,
]

// All wind down candidate labels (compete for the 2 variable Wind Down slots)
let allWindDownRemedies: [String] = [
    R.brainDump, R.boringStory, R.breathing478,
    R.gratitudeJournal, R.gentleStretching, R.pmr, R.readingBook,
]

// All bedtime prep remedy labels
let allBedroomPrepRemedies: [String] = Array(remedyLeadTimes.keys)

// MARK: - Nightly Step Kind

enum NightlyStepKind: Equatable {
    case brightnessCheck
    case temperatureLog
    case brainDump
    case boringStory
    case fourSevenEightBreathing
    case gratitudeJournal
    case gentleStretching
    case progressiveMuscleRelaxation
    case existingHabit(label: String)
    // Evening reminder to stop a habit X minutes before bed.
    case avoidReminder(label: String, minutesBefore: Int)

    var displayLabel: String {
        switch self {
        case .brightnessCheck:            return "Brightness check"
        case .temperatureLog:             return "Temperature check"
        case .brainDump:                  return R.brainDump
        case .boringStory:                return R.boringStory
        case .fourSevenEightBreathing:    return R.breathing478
        case .gratitudeJournal:           return R.gratitudeJournal
        case .gentleStretching:           return R.gentleStretching
        case .progressiveMuscleRelaxation: return R.pmr
        case .existingHabit(let label):   return label
        case .avoidReminder(let label, _): return label
        }
    }

    var estimatedMinutes: Int {
        switch self {
        case .brightnessCheck:            return 1
        case .temperatureLog:             return 1
        case .brainDump:                  return 2
        case .gratitudeJournal:           return 3
        case .gentleStretching:           return 5
        case .fourSevenEightBreathing:    return 5
        case .progressiveMuscleRelaxation: return 5
        case .boringStory:                return 20
        case .existingHabit(let label):
            switch label {
            case R.readingBook:           return 20
            case R.warmShower:            return 10
            default:                      return 5
            }
        case .avoidReminder:              return 0
        }
    }

    // Converts a stored RoutineStep label back to a NightlyStepKind.
    static func forLabel(_ label: String) -> NightlyStepKind? {
        switch label {
        case "Brightness check":          return .brightnessCheck
        case "Temperature check":         return .temperatureLog
        case R.brainDump:                 return .brainDump
        case R.boringStory:               return .boringStory
        case R.breathing478:              return .fourSevenEightBreathing
        case R.gratitudeJournal:          return .gratitudeJournal
        case R.gentleStretching:          return .gentleStretching
        case R.pmr:                       return .progressiveMuscleRelaxation
        default:                          return nil
        }
    }

    var routineMode: RoutineMode {
        switch self {
        case .avoidReminder: return .reminderOnly
        default:             return .inSequence
        }
    }

    func toRoutineStep(order: Int) -> RoutineStep {
        RoutineStep(order: order, label: displayLabel, mode: routineMode)
    }

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
    var steps: [NightlyStepKind]          // Wind Down sequence (inSequence)
    var avoidReminders: [NightlyStepKind] // Bedtime Prep reminders (reminderOnly)
    var explanation: String
    var keptHabitLabels: [String]
    var shouldStartImmediately: Bool

    var totalMinutes: Int { steps.reduce(0) { $0 + $1.estimatedMinutes } }

    func toCoreRoutineSteps() -> [RoutineStep] {
        (avoidReminders + steps).enumerated().map { i, kind in kind.toRoutineStep(order: i + 1) }
    }
}

// MARK: - Onboarding Answer Mapping

struct OnboardingAnswers {
    let sleepProblems: Set<Int>
    let wakingFactors: Set<Int>
    let mainWindowMinutes: Int
    let typicalBedtime: Date
    let typicalWakeTime: Date
    let preBedActivities: Set<Int>
    let triedBefore: Set<Int>
    let bedroomTempF: Double
    let lightsLevel: Int

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
}

// MARK: - Remedy ↔ Onboarding Mapping

// (screen, answerIndex) → remedy labels that score points for this answer.
// Screen 5 (pre-bed activities) carries 2x weight in scoreRemedies().
private struct AnswerKey: Hashable {
    let screen: Int
    let index: Int
}

private let remedyMapping: [AnswerKey: [String]] = [
    // Screen 1 — Sleep Problems (+1 per selection)
    AnswerKey(screen: 1, index: 0): [R.dimTheLights, R.noScreens, R.warmShower,
                                      R.breathing478, R.brainDump, R.boringStory],
    AnswerKey(screen: 1, index: 1): [R.dimTheLights, R.noScreens, R.gratitudeJournal,
                                      R.brainDump, R.breathing478, R.pmr, R.boringStory],
    AnswerKey(screen: 1, index: 2): [R.coldRoomPrep, R.herbalTea, R.weightedBlanket,
                                      R.breathing478, R.brainDump],
    AnswerKey(screen: 1, index: 3): [R.coldRoomPrep, R.warmShower, R.magnesium, R.weightedBlanket],

    // Screen 2 — Waking Factors / Situation (+1 per selection)
    AnswerKey(screen: 2, index: 0): [R.dimTheLights, R.herbalTea, R.gentleStretching,
                                      R.warmShower, R.brainDump, R.breathing478],
    AnswerKey(screen: 2, index: 1): [R.coldRoomPrep, R.dimTheLights, R.noCaffeine,
                                      R.magnesium, R.boringStory],
    AnswerKey(screen: 2, index: 2): [R.dimTheLights, R.noScreens, R.brainDump,
                                      R.breathing478, R.pmr],
    AnswerKey(screen: 2, index: 3): [R.dimTheLights, R.noScreens, R.brainDump,
                                      R.breathing478, R.pmr, R.boringStory],
    AnswerKey(screen: 2, index: 4): [R.dimTheLights, R.herbalTea, R.breathing478,
                                      R.brainDump, R.pmr],
    AnswerKey(screen: 2, index: 5): [R.coldRoomPrep, R.warmShower, R.gentleStretching,
                                      R.pmr, R.weightedBlanket],

    // Screen 5 — Pre-Bed Activities (+2 per selection, "Screen 4" 2x weight in spec)
    AnswerKey(screen: 5, index: 0): [R.dimTheLights, R.noScreens, R.brainDump, R.appBlocking],
    AnswerKey(screen: 5, index: 1): [R.dimTheLights, R.noScreens, R.readingBook,
                                      R.boringStory, R.appBlocking],
    AnswerKey(screen: 5, index: 2): [R.readingBook],
    // index 3 ("Talk or socialize") — no CSV mapping
    AnswerKey(screen: 5, index: 4): [R.dimTheLights],
    AnswerKey(screen: 5, index: 5): [R.warmShower],
    AnswerKey(screen: 5, index: 6): [R.finishWorkouts],
    AnswerKey(screen: 5, index: 7): [R.noHeavySnacks, R.herbalTea],
    AnswerKey(screen: 5, index: 8): [R.dimTheLights, R.brainDump, R.breathing478, R.boringStory],
]

// Pre-bed activities that are positive sleep habits worth keeping in Wind Down.
// index → remedy label
private let keptHabitMap: [Int: String] = [
    2: R.readingBook,  // "Read a physical book"
    4: R.dimTheLights, // "Dim the lights or use warm lighting"
    5: R.warmShower,   // "Have a shower or bath"
]

// Wind Down difficulty (lower = easier = shown first in routine)
private let windDownDifficulty: [String: Int] = [
    R.boringStory:      1,
    R.readingBook:      2,
    R.gratitudeJournal: 3,
    R.brainDump:        4,
    R.gentleStretching: 5,
    R.breathing478:     6,
    R.pmr:              7,
]

// MARK: - Scoring

/// Scores every remedy against the user's onboarding answers.
/// - Screen 1 & 2 selections → +1 per mapped remedy
/// - Screen 5 selections (pre-bed activities) → +2 per mapped remedy
/// - "Dim the lights" always gets +3 extra
/// - Up to 2 kept positive habits each get +2
func scoreRemedies(from answers: OnboardingAnswers) -> [String: Int] {
    var scores: [String: Int] = [:]

    for idx in answers.sleepProblems {
        for remedy in remedyMapping[AnswerKey(screen: 1, index: idx)] ?? [] {
            scores[remedy, default: 0] += 1
        }
    }

    for idx in answers.wakingFactors {
        for remedy in remedyMapping[AnswerKey(screen: 2, index: idx)] ?? [] {
            scores[remedy, default: 0] += 1
        }
    }

    for idx in answers.preBedActivities {
        for remedy in remedyMapping[AnswerKey(screen: 5, index: idx)] ?? [] {
            scores[remedy, default: 0] += 2
        }
    }

    scores[R.dimTheLights, default: 0] += 3

    let keptHabits = answers.preBedActivities
        .compactMap { keptHabitMap[$0] }
        .prefix(2)
    for habit in keptHabits {
        scores[habit, default: 0] += 2
    }

    return scores
}

// MARK: - Routine Generator
//
// Gentle Reset philosophy for the first routine:
// • Bedtime Prep: Dim the lights always + max 1 additional. App Blocking never shown.
// • Wind Down: 2 fixed checks + existing positive habits (up to 2) + at most 1 new method.
//   A new method is only added when the user has no Wind Down habits already AND the
//   scoring produced at least one Wind Down candidate (i.e. a real sleep-onset signal).

func generateStartingRoutine(from answers: OnboardingAnswers) -> GeneratedRoutine {
    let isCloseToBedtime = answers.timeToTargetBedtimeMinutes <= 60
    let scores = scoreRemedies(from: answers)

    // Stable iteration order for kept habits (Set order is non-deterministic)
    let keptHabitLabels = answers.preBedActivities
        .sorted()
        .compactMap { keptHabitMap[$0] }
        .prefix(2)
        .map { $0 }

    let prepSteps    = buildInitialPrepSteps(scores: scores)
    let windDownSteps = buildInitialWindDownSteps(scores: scores, keptHabitLabels: Array(keptHabitLabels))

    let explanation = buildGentleExplanation(
        windDown: windDownSteps,
        prep: prepSteps,
        keptHabits: Array(keptHabitLabels)
    )

    return GeneratedRoutine(
        steps: windDownSteps,
        avoidReminders: prepSteps,
        explanation: explanation,
        keptHabitLabels: Array(keptHabitLabels),
        shouldStartImmediately: isCloseToBedtime
    )
}

// Bedtime Prep cap: Dim the lights (always) + at most 1 more. App Blocking excluded.
private func buildInitialPrepSteps(scores: [String: Int]) -> [NightlyStepKind] {
    var steps: [NightlyStepKind] = [
        .avoidReminder(label: R.dimTheLights, minutesBefore: remedyLeadTimes[R.dimTheLights]!)
    ]

    let extra = allBedroomPrepRemedies
        .filter { $0 != R.dimTheLights && $0 != R.appBlocking }
        .compactMap { remedy -> (label: String, score: Int, leadTime: Int)? in
            guard let score = scores[remedy], score > 0,
                  let leadTime = remedyLeadTimes[remedy] else { return nil }
            return (remedy, score, leadTime)
        }
        .max { $0.score < $1.score }

    if let extra {
        steps.append(.avoidReminder(label: extra.label, minutesBefore: extra.leadTime))
    }

    return steps.sorted { lhs, rhs in
        guard case .avoidReminder(_, let a) = lhs,
              case .avoidReminder(_, let b) = rhs else { return false }
        return a > b  // largest lead time first = earliest reminder in the evening
    }
}

// Wind Down cap: 2 fixed checks + existing Wind Down habits (up to 2) OR 1 new method.
// A new method is added only when the user has no Wind Down habits and scoring signals
// a sleep-onset issue (at least one Wind Down remedy scored > 0).
private func buildInitialWindDownSteps(
    scores: [String: Int],
    keptHabitLabels: [String]
) -> [NightlyStepKind] {
    var steps: [NightlyStepKind] = [.brightnessCheck, .temperatureLog]

    // Only readingBook lives in allWindDownRemedies; warmShower and dimTheLights are Bedtime Prep.
    let windDownKeptHabits = keptHabitLabels.filter { allWindDownRemedies.contains($0) }
    for label in windDownKeptHabits {
        steps.append(.existingHabit(label: label))
    }

    // If the user already has Wind Down habits, don't pile on anything new.
    guard windDownKeptHabits.isEmpty else { return steps }

    // Use the scoring pool as the signal check: if nothing mapped to a Wind Down remedy,
    // there's nothing meaningful to add for this user right now.
    let hasSignal = allWindDownRemedies.contains { (scores[$0] ?? 0) > 0 }
    guard hasSignal else { return steps }

    // Add exactly one new method — top scorer, easiest on a tie-break.
    let topCandidate = allWindDownRemedies
        .compactMap { remedy -> (label: String, score: Int)? in
            guard let score = scores[remedy], score > 0 else { return nil }
            return (remedy, score)
        }
        .sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return (windDownDifficulty[lhs.label] ?? 99) < (windDownDifficulty[rhs.label] ?? 99)
        }
        .first

    if let candidate = topCandidate, let kind = nightlyStepKind(for: candidate.label) {
        steps.append(kind)
    }

    return steps
}

// Converts a scored remedy name to its NightlyStepKind.
private func nightlyStepKind(for remedy: String) -> NightlyStepKind? {
    switch remedy {
    case R.brainDump:        return .brainDump
    case R.boringStory:      return .boringStory
    case R.breathing478:     return .fourSevenEightBreathing
    case R.gratitudeJournal: return .gratitudeJournal
    case R.gentleStretching: return .gentleStretching
    case R.pmr:              return .progressiveMuscleRelaxation
    case R.readingBook:      return .existingHabit(label: R.readingBook)
    default:                 return nil
    }
}

// MARK: - Explanation Builder

private func buildGentleExplanation(
    windDown: [NightlyStepKind],
    prep: [NightlyStepKind],
    keptHabits: [String]
) -> String {
    var parts: [String] = ["We kept things super simple for your first few nights."]

    for habit in keptHabits {
        switch habit {
        case R.readingBook:
            parts.append("You already read before bed — that's one of the best things you can do, so we kept it in.")
        case R.dimTheLights:
            parts.append("You already dim the lights before bed. That's already working for you.")
        case R.warmShower:
            parts.append("You already shower before bed — the temperature drop afterward is a genuine sleep trigger.")
        default:
            parts.append("We kept your \(habit) habit — you already do this well.")
        }
    }

    // New Wind Down method (anything beyond the two fixed checks and existing habits)
    let newSteps = windDown.dropFirst(2).filter {
        if case .existingHabit = $0 { return false }
        return true
    }
    for step in newSteps {
        switch step {
        case .brainDump:
            parts.append("We added one thing: a quick Brain Dump. Two minutes to empty your head before you close your eyes.")
        case .boringStory:
            parts.append("We added one thing: a Boring Story. It gives your mind something mild to follow instead of looping on the day.")
        case .fourSevenEightBreathing:
            parts.append("We added one thing: 4-7-8 Breathing. Five minutes to signal your nervous system that it's safe to rest.")
        case .gratitudeJournal:
            parts.append("We added one thing: a quick Gratitude note. It shifts focus off the day's noise before you sleep.")
        case .gentleStretching:
            parts.append("We added one thing: a short stretch. A few minutes to release physical tension before you lie down.")
        case .progressiveMuscleRelaxation:
            parts.append("We added one thing: a short body relaxation. Tense and release — it quiets the body surprisingly fast.")
        default:
            break
        }
    }

    for step in prep {
        guard case .avoidReminder(let label, let minutesBefore) = step else { continue }
        let timeLabel = minutesBefore >= 60 ? "\(minutesBefore / 60)h" : "\(minutesBefore) min"
        switch label {
        case R.dimTheLights:
            parts.append("Dim the lights \(timeLabel) before bed — it tells your brain the day is ending.")
        case R.noScreens:
            parts.append("Put screens away \(timeLabel) before bed. Blue light delays melatonin by up to 30 minutes.")
        case R.finishWorkouts:
            parts.append("Finish workouts \(timeLabel) before bed — cortisol from exercise takes a few hours to clear.")
        case R.noHeavySnacks:
            parts.append("No heavy snacks \(timeLabel) before bed — digestion raises core temperature and works against sleep onset.")
        case R.noAlcohol:
            parts.append("Skip alcohol \(timeLabel) before bed — even one drink fragments sleep in the second half of the night.")
        case R.noCaffeine:
            parts.append("Cut off caffeine \(timeLabel) before bed — it has a long half-life and stays active longer than most people expect.")
        case R.coldRoomPrep:
            parts.append("Cool your room \(timeLabel) before bed — a drop in core temperature is a key trigger for sleep onset.")
        case R.warmShower:
            parts.append("Time your shower \(timeLabel) before bed — the post-shower temperature drop helps trigger sleep.")
        case R.magnesium:
            parts.append("Take Magnesium glycinate \(timeLabel) before bed — it's one of the better-evidenced supplements for sleep quality.")
        case R.herbalTea:
            parts.append("Herbal tea \(timeLabel) before bed — the ritual and mild calming effects both help signal wind-down.")
        case R.weightedBlanket:
            parts.append("Use your weighted blanket — the gentle pressure activates the parasympathetic nervous system.")
        default:
            break
        }
    }

    parts.append("Once this feels easy, we'll layer in more.")
    return parts.joined(separator: " ")
}
