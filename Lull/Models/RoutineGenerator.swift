import Foundation

// MARK: - Canonical remedy name constants
// These string values are used as keys throughout the scoring system,
// as RoutineStep labels, and as SleepLogEntry.variable values.
// They must match NightlyStepKind.displayLabel exactly for Wind Down steps.

enum R {
    // Wind Down interactive steps
    static let brainDump        = "Brain dump"
    static let boringStory      = "Boring story"
    static let sleepSounds      = "Sleep sounds"
    static let breathing478     = "4-7-8 breathing"
    static let gratitudeJournal = "Gratitude journal"
    static let gentleStretching = "Gentle stretching"
    static let pmr              = "Progressive muscle relaxation"
    static let bodyScan         = "Body scan"
    static let readingBook      = "Reading (physical book)"

    // Bedtime Prep reminder steps (scheduled before bed with a lead time)
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
    static let blackoutCurtains = "Blackout curtains"

    // Bedtime Ritual steps (passive/physical, done in bed — no lead time)
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
    R.blackoutCurtains: 90,
]

// All wind down candidate labels (compete for the 2 variable Wind Down slots)
let allWindDownRemedies: [String] = [
    R.brainDump, R.boringStory, R.sleepSounds, R.breathing478,
    R.gratitudeJournal, R.gentleStretching, R.pmr, R.bodyScan, R.readingBook, R.weightedBlanket,
]

// All bedtime prep remedy labels
let allBedroomPrepRemedies: [String] = [
    R.noAlcohol, R.noCaffeine, R.noScreens, R.appBlocking,
    R.finishWorkouts, R.noHeavySnacks, R.dimTheLights,
    R.coldRoomPrep, R.warmShower, R.magnesium, R.herbalTea,
    R.blackoutCurtains,
]

// MARK: - Nightly Step Kind

enum NightlyStepKind: Equatable {
    case brightnessCheck
    case temperatureLog
    case brainDump
    case boringStory
    case sleepSounds
    case fourSevenEightBreathing
    case gratitudeJournal
    case gentleStretching
    case progressiveMuscleRelaxation
    case bodyScan
    case existingHabit(label: String)
    // Evening reminder to stop a habit X minutes before bed.
    case avoidReminder(label: String, minutesBefore: Int)

    var displayLabel: String {
        switch self {
        case .brightnessCheck:            return "Brightness check"
        case .temperatureLog:             return "Temperature check"
        case .brainDump:                  return R.brainDump
        case .boringStory:                return R.boringStory
        case .sleepSounds:                return R.sleepSounds
        case .fourSevenEightBreathing:    return R.breathing478
        case .gratitudeJournal:           return R.gratitudeJournal
        case .gentleStretching:           return R.gentleStretching
        case .progressiveMuscleRelaxation: return R.pmr
        case .bodyScan:                   return R.bodyScan
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
        case .bodyScan:                   return 5
        case .boringStory:                return 20
        case .sleepSounds:                return 60
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
        case R.sleepSounds:               return .sleepSounds
        case R.breathing478:              return .fourSevenEightBreathing
        case R.gratitudeJournal:          return .gratitudeJournal
        case R.gentleStretching:          return .gentleStretching
        case R.pmr:                       return .progressiveMuscleRelaxation
        case R.bodyScan:                  return .bodyScan
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
        RoutineStep(order: order, label: displayLabel, mode: routineMode, remedyId: RemedyID.fromLabel(displayLabel))
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
    var remedyIds: [RemedyID] = []
    var introOrder: [RemedyID] = []
    var backlog: [RemedyID] = []
    var reinforcedRemedyIds: [RemedyID] = []
    var showHealthScreening: Bool = false

    var totalMinutes: Int { steps.reduce(0) { $0 + $1.estimatedMinutes } }

    func toCoreRoutineSteps() -> [RoutineStep] {
        let hasNewWindDownMethod = steps.contains {
            switch $0 {
            case .existingHabit, .brightnessCheck, .temperatureLog: return false
            default: return true
            }
        }
        let dimLightsIsExistingHabit = keptHabitLabels.contains(R.dimTheLights)

        return (avoidReminders + steps).enumerated().map { i, kind in
            var step = kind.toRoutineStep(order: i + 1)
            switch kind {
            case .brightnessCheck, .temperatureLog:
                break
            case .existingHabit:
                break
            case .avoidReminder(let label, _):
                if !hasNewWindDownMethod && !dimLightsIsExistingHabit && label == R.dimTheLights {
                    step.mode = .experiment
                }
            default:
                step.mode = .experiment
            }
            return step
        }
    }
}

// MARK: - Onboarding Answer Mapping

struct OnboardingAnswers {
    let sleepProblems: Set<Int>
    let wakingFactors: Set<Int>
    let satisfaction: Int
    let mainWindowMinutes: Int
    let typicalBedtime: Date
    let typicalWakeTime: Date
    let preBedActivities: Set<Int>
    let triedBefore: Set<Int>

    init(from state: AppState) {
        sleepProblems     = state.selectedSleepProblems
        wakingFactors     = state.selectedWakes
        satisfaction       = state.baselineScore
        mainWindowMinutes = state.sleepWindowMinutes
        typicalBedtime    = state.typicalBedtime
        typicalWakeTime   = state.typicalWakeTime
        preBedActivities  = state.selectedPreBedActivities
        triedBefore       = state.selectedTriedThings
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

// MARK: - Routine Engine Config

private enum Phenotype: Hashable {
    case a, b, c, d, other, all
}

private enum Habit: Hashable {
    case scroll, tv, readBook, talk, showerBath, exercise
    case eatSnack, podcast, chores, coffee, alcohol, work, none
}

private struct RoutineEngineConfig {
    static let q1Weight = 3
    static let q4Weight = 1
    static let popularityWeight = 3
}

private struct RemedyConfig {
    let id: RemedyID
    let label: String
    let strength: (Set<Phenotype>) -> Int
    let popularity: Int
    let difficulty: Int
    let phenotypes: Set<Phenotype>
    let habitTriggers: Set<Habit>
    let gate: Habit?
    let requiresPhenotype: Set<Phenotype>
    let leadTimeMinutes: Int?
    let isWindDown: Bool
    let order: Int

    func strengthValue(for phenotypes: Set<Phenotype>) -> Int {
        strength(phenotypes)
    }
}

private struct ScoredRemedy {
    let config: RemedyConfig
    let matchPoints: Int
    let clinicalScore: Int
    let rank: Int
}

private let remedyConfigs: [RemedyConfig] = [
    .init(id: .noCaffeine, label: R.noCaffeine, strength: { _ in 3 }, popularity: 0, difficulty: 3,
          phenotypes: [.a, .b, .c], habitTriggers: [.coffee], gate: .coffee, requiresPhenotype: [],
          leadTimeMinutes: 360, isWindDown: false, order: 0),
    .init(id: .noAlcohol, label: R.noAlcohol, strength: { _ in 3 }, popularity: 0, difficulty: 3,
          phenotypes: [.c, .d], habitTriggers: [.alcohol], gate: .alcohol, requiresPhenotype: [.c, .d],
          leadTimeMinutes: 180, isWindDown: false, order: 1),
    .init(id: .noScreens, label: R.noScreens, strength: { _ in 3 }, popularity: 0, difficulty: 3,
          phenotypes: [.a, .b], habitTriggers: [.scroll, .tv, .work], gate: nil, requiresPhenotype: [],
          leadTimeMinutes: 75, isWindDown: false, order: 2),
    .init(id: .appBlocking, label: R.appBlocking, strength: { _ in 3 }, popularity: 0, difficulty: 3,
          phenotypes: [.a, .b], habitTriggers: [.scroll], gate: .scroll, requiresPhenotype: [],
          leadTimeMinutes: 75, isWindDown: false, order: 3),
    .init(id: .dimTheLights, label: R.dimTheLights, strength: { _ in 2 }, popularity: 2, difficulty: 2,
          phenotypes: [.a], habitTriggers: [.scroll, .tv], gate: nil, requiresPhenotype: [],
          leadTimeMinutes: 75, isWindDown: false, order: 4),
    .init(id: .coldRoomPrep, label: R.coldRoomPrep, strength: { _ in 2 }, popularity: 1, difficulty: 1,
          phenotypes: [.a, .c], habitTriggers: [], gate: nil, requiresPhenotype: [],
          leadTimeMinutes: 90, isWindDown: false, order: 5),
    .init(id: .noHeavySnacks, label: R.noHeavySnacks, strength: { _ in 2 }, popularity: 0, difficulty: 2,
          phenotypes: [.a, .d], habitTriggers: [.eatSnack], gate: .eatSnack, requiresPhenotype: [],
          leadTimeMinutes: 120, isWindDown: false, order: 6),
    .init(id: .finishWorkouts, label: R.finishWorkouts, strength: { _ in 2 }, popularity: 0, difficulty: 2,
          phenotypes: [.a], habitTriggers: [.exercise], gate: .exercise, requiresPhenotype: [],
          leadTimeMinutes: 180, isWindDown: false, order: 7),
    .init(id: .weightedBlanket, label: R.weightedBlanket, strength: { $0.contains(.b) ? 2 : 1 }, popularity: 2, difficulty: 1,
          phenotypes: [.a, .b, .c], habitTriggers: [], gate: nil, requiresPhenotype: [],
          leadTimeMinutes: nil, isWindDown: true, order: 8),
    .init(id: .magnesium, label: R.magnesium, strength: { _ in 1 }, popularity: 1, difficulty: 1,
          phenotypes: [.a, .c], habitTriggers: [], gate: nil, requiresPhenotype: [],
          leadTimeMinutes: 45, isWindDown: false, order: 9),
    .init(id: .herbalTea, label: R.herbalTea, strength: { _ in 1 }, popularity: 2, difficulty: 1,
          phenotypes: [.a], habitTriggers: [], gate: nil, requiresPhenotype: [],
          leadTimeMinutes: 45, isWindDown: false, order: 10),
    .init(id: .brainDump, label: R.brainDump, strength: { _ in 3 }, popularity: 1, difficulty: 1,
          phenotypes: [.b], habitTriggers: [.work, .talk], gate: nil, requiresPhenotype: [],
          leadTimeMinutes: nil, isWindDown: true, order: 11),
    .init(id: .progressiveMuscleRelaxation, label: R.pmr, strength: { _ in 2 }, popularity: 1, difficulty: 2,
          phenotypes: [.a, .b], habitTriggers: [], gate: nil, requiresPhenotype: [],
          leadTimeMinutes: nil, isWindDown: true, order: 12),
    .init(id: .bodyScan, label: R.bodyScan, strength: { _ in 2 }, popularity: 1, difficulty: 1,
          phenotypes: [.a, .b], habitTriggers: [], gate: nil, requiresPhenotype: [],
          leadTimeMinutes: nil, isWindDown: true, order: 13),
    .init(id: .boringStory, label: R.boringStory, strength: { _ in 2 }, popularity: 2, difficulty: 1,
          phenotypes: [.a, .b], habitTriggers: [], gate: nil, requiresPhenotype: [],
          leadTimeMinutes: nil, isWindDown: true, order: 14),
    .init(id: .gratitudeJournal, label: R.gratitudeJournal, strength: { _ in 1 }, popularity: 1, difficulty: 1,
          phenotypes: [.b], habitTriggers: [], gate: nil, requiresPhenotype: [],
          leadTimeMinutes: nil, isWindDown: true, order: 15),
    .init(id: .gentleStretching, label: R.gentleStretching, strength: { _ in 1 }, popularity: 1, difficulty: 2,
          phenotypes: [.a], habitTriggers: [], gate: nil, requiresPhenotype: [],
          leadTimeMinutes: nil, isWindDown: true, order: 16),
    .init(id: .readingBook, label: R.readingBook, strength: { _ in 1 }, popularity: 1, difficulty: 2,
          phenotypes: [.a, .b], habitTriggers: [.readBook], gate: nil, requiresPhenotype: [],
          leadTimeMinutes: nil, isWindDown: true, order: 17),
    .init(id: .sleepSounds, label: R.sleepSounds, strength: { _ in 1 }, popularity: 2, difficulty: 1,
          phenotypes: [.a, .b, .c, .d], habitTriggers: [], gate: nil, requiresPhenotype: [],
          leadTimeMinutes: nil, isWindDown: true, order: 18),
    .init(id: .breathing478, label: R.breathing478, strength: { _ in 1 }, popularity: 2, difficulty: 1,
          phenotypes: [.a, .b], habitTriggers: [], gate: nil, requiresPhenotype: [],
          leadTimeMinutes: nil, isWindDown: true, order: 19),
    .init(id: .blackoutCurtains, label: R.blackoutCurtains, strength: { _ in 1 }, popularity: 1, difficulty: 1,
          phenotypes: [.a, .c], habitTriggers: [], gate: nil, requiresPhenotype: [],
          leadTimeMinutes: 90, isWindDown: false, order: 20),
]

private var remedyConfigById: [RemedyID: RemedyConfig] {
    Dictionary(uniqueKeysWithValues: remedyConfigs.map { ($0.id, $0) })
}

private let warmBathConfig = RemedyConfig(
    id: .warmShower,
    label: R.warmShower,
    strength: { _ in 1 },
    popularity: 2,
    difficulty: 1,
    phenotypes: [],
    habitTriggers: [],
    gate: nil,
    requiresPhenotype: [],
    leadTimeMinutes: 90,
    isWindDown: false,
    order: -1
)

private func config(for id: RemedyID) -> RemedyConfig? {
    id == .warmShower ? warmBathConfig : remedyConfigById[id]
}

private let baselineRemedyIds: [RemedyID] = [.noScreens, .dimTheLights, .sleepSounds]

private let habitDerivedBaselineIds: [Habit: [RemedyID]] = [
    .coffee: [.noCaffeine],
    .eatSnack: [.noHeavySnacks],
    .scroll: [.appBlocking],
    .exercise: [.finishWorkouts],
]

// MARK: - Answer Mapping

private func selectedPhenotypes(from answers: OnboardingAnswers) -> Set<Phenotype> {
    let allProblemOptionCount = 5
    if answers.sleepProblems == Set(0..<allProblemOptionCount) {
        return [.all]
    }

    var result: Set<Phenotype> = []
    if answers.sleepProblems.contains(0) { result.insert(.a) }
    if answers.sleepProblems.contains(1) { result.insert(.b) }
    if answers.sleepProblems.contains(2) { result.insert(.c) }
    if answers.sleepProblems.contains(3) { result.insert(.d) }
    if answers.sleepProblems.contains(4) { result.insert(.other) }
    return result
}

private func selectedHabits(from answers: OnboardingAnswers) -> Set<Habit> {
    var result: Set<Habit> = []
    if answers.preBedActivities.contains(0) { result.insert(.scroll) }
    if answers.preBedActivities.contains(1) { result.insert(.tv) }
    if answers.preBedActivities.contains(2) { result.insert(.readBook) }
    if answers.preBedActivities.contains(3) { result.insert(.talk) }
    if answers.preBedActivities.contains(4) { result.insert(.showerBath) }
    if answers.preBedActivities.contains(5) { result.insert(.exercise) }
    if answers.preBedActivities.contains(6) { result.insert(.eatSnack) }
    if answers.preBedActivities.contains(7) { result.insert(.podcast) }
    if answers.preBedActivities.contains(8) { result.insert(.chores) }
    if answers.preBedActivities.contains(9) { result.insert(.coffee) }
    if answers.preBedActivities.contains(10) { result.insert(.work) }
    if answers.preBedActivities.contains(11) { result.insert(.alcohol) }
    if answers.preBedActivities.contains(12) { result.insert(.none) }
    return result
}

private func starterSetSize(for satisfaction: Int) -> Int {
    switch satisfaction {
    case 1, 2: return 5
    case 3:    return 4
    default:   return 3
    }
}

private func usesBaselinePath(_ phenotypes: Set<Phenotype>) -> Bool {
    phenotypes == [.other] || phenotypes == [.all] || phenotypes.isEmpty
}

// MARK: - Scoring

func scoreRemedies(from answers: OnboardingAnswers) -> [String: Int] {
    let phenotypes = selectedPhenotypes(from: answers)
    let habits = selectedHabits(from: answers)
    return scoredRemedies(phenotypes: phenotypes, habits: habits)
        .reduce(into: [:]) { $0[$1.config.label] = $1.clinicalScore }
}

private func scoredRemedies(phenotypes: Set<Phenotype>, habits: Set<Habit>) -> [ScoredRemedy] {
    remedyConfigs.compactMap { config in
        guard config.id != .warmShower else { return nil }
        if let gate = config.gate, !habits.contains(gate) { return nil }
        if !config.requiresPhenotype.isEmpty && config.requiresPhenotype.isDisjoint(with: phenotypes) {
            return nil
        }

        let phenotypeMatches = config.phenotypes.intersection(phenotypes).count
        let habitMatches = config.habitTriggers.intersection(habits).count
        let matchPoints = RoutineEngineConfig.q1Weight * phenotypeMatches
            + RoutineEngineConfig.q4Weight * habitMatches
        let strength = config.strengthValue(for: phenotypes)
        let clinicalScore = strength * matchPoints
        guard clinicalScore > 0 else { return nil }

        let rank = clinicalScore + RoutineEngineConfig.popularityWeight * config.popularity
        return ScoredRemedy(config: config, matchPoints: matchPoints, clinicalScore: clinicalScore, rank: rank)
    }
    .sorted(by: scoredSort(phenotypes: phenotypes))
}

private func scoredSort(phenotypes: Set<Phenotype>) -> (ScoredRemedy, ScoredRemedy) -> Bool {
    { lhs, rhs in
        if lhs.rank != rhs.rank { return lhs.rank > rhs.rank }
        let lhsStrength = lhs.config.strengthValue(for: phenotypes)
        let rhsStrength = rhs.config.strengthValue(for: phenotypes)
        if lhsStrength != rhsStrength { return lhsStrength > rhsStrength }
        if lhs.config.difficulty != rhs.config.difficulty {
            return lhs.config.difficulty < rhs.config.difficulty
        }
        return lhs.config.order < rhs.config.order
    }
}

// MARK: - Routine Generator

func generateStartingRoutine(from answers: OnboardingAnswers) -> GeneratedRoutine {
    let phenotypes = selectedPhenotypes(from: answers)
    let habits = selectedHabits(from: answers)
    let isCloseToBedtime = answers.timeToTargetBedtimeMinutes <= 60
    let totalSlots = starterSetSize(for: answers.satisfaction)
    let scoredSlotCount = max(0, totalSlots - 1)

    let selectedScored: [RemedyID]
    let backlogIds: [RemedyID]
    if usesBaselinePath(phenotypes) {
        let baseline = baselineSelection(habits: habits, limit: scoredSlotCount)
        selectedScored = baseline.selected
        backlogIds = baseline.backlog
    } else {
        let scored = scoredRemedies(phenotypes: phenotypes, habits: habits)
        selectedScored = scored.prefix(scoredSlotCount).map(\.config.id)
        backlogIds = scored.dropFirst(scoredSlotCount).map(\.config.id)
    }

    let remedyIds = [.warmShower] + selectedScored.filter { $0 != .warmShower }
    let reinforcedIds = reinforcedRemedyIds(habits: habits)
    let introOrder = buildIntroOrder(remedyIds: remedyIds, phenotypes: phenotypes)
    let avoidReminders = buildPrepSteps(remedyIds: remedyIds)
    let windDownSteps = buildWindDownSteps(remedyIds: remedyIds)
    let showHealth = phenotypes.contains(.d) || phenotypes.contains(.all)
    let explanation = buildRoutineExplanation(
        remedyIds: remedyIds,
        reinforcedRemedyIds: reinforcedIds,
        showHealthScreening: showHealth
    )

    return GeneratedRoutine(
        steps: windDownSteps,
        avoidReminders: avoidReminders,
        explanation: explanation,
        keptHabitLabels: reinforcedIds.compactMap { config(for: $0)?.label },
        shouldStartImmediately: isCloseToBedtime,
        remedyIds: remedyIds,
        introOrder: introOrder,
        backlog: backlogIds,
        reinforcedRemedyIds: reinforcedIds,
        showHealthScreening: showHealth
    )
}

private func baselineSelection(habits: Set<Habit>, limit: Int) -> (selected: [RemedyID], backlog: [RemedyID]) {
    var orderedIds = baselineRemedyIds
    for habit in HabitOrder.baselineDerived where habits.contains(habit) {
        orderedIds.append(contentsOf: habitDerivedBaselineIds[habit] ?? [])
    }

    let deduped = orderedIds.reduce(into: [RemedyID]()) { result, id in
        if id != .warmShower && !result.contains(id) {
            result.append(id)
        }
    }

    return (Array(deduped.prefix(limit)), Array(deduped.dropFirst(limit)))
}

private enum HabitOrder {
    static let baselineDerived: [Habit] = [.coffee, .scroll, .eatSnack, .exercise]
}

private func reinforcedRemedyIds(habits: Set<Habit>) -> [RemedyID] {
    var ids: [RemedyID] = []
    if habits.contains(.readBook) { ids.append(.readingBook) }
    if habits.contains(.showerBath) { ids.append(.warmShower) }
    return ids
}

private func buildPrepSteps(remedyIds: [RemedyID]) -> [NightlyStepKind] {
    remedyIds.compactMap { id in
        guard let config = config(for: id), !config.isWindDown else { return nil }
        return .avoidReminder(label: config.label, minutesBefore: config.leadTimeMinutes ?? 90)
    }
}

private func buildWindDownSteps(remedyIds: [RemedyID]) -> [NightlyStepKind] {
    var steps: [NightlyStepKind] = [.brightnessCheck, .temperatureLog]
    for id in remedyIds {
        guard let config = config(for: id), config.isWindDown else { continue }
        if let kind = nightlyStepKind(for: config.label) {
            steps.append(kind)
        }
    }
    return steps
}

private func buildIntroOrder(remedyIds: [RemedyID], phenotypes: Set<Phenotype>) -> [RemedyID] {
    let configs = remedyIds.compactMap { config(for: $0) }
    guard let opener = configs.sorted(by: introOpenerSort(phenotypes: phenotypes)).first else {
        return remedyIds
    }

    var ordered: [RemedyID] = [opener.id]
    if let strongest = configs
        .filter({ $0.id != opener.id })
        .sorted(by: introStrengthSort(phenotypes: phenotypes))
        .first {
        ordered.append(strongest.id)
    }

    let rest = configs
        .filter { !ordered.contains($0.id) }
        .sorted {
            if $0.difficulty != $1.difficulty { return $0.difficulty < $1.difficulty }
            return $0.order < $1.order
        }
        .map(\.id)

    return ordered + rest
}

private func introOpenerSort(phenotypes: Set<Phenotype>) -> (RemedyConfig, RemedyConfig) -> Bool {
    { lhs, rhs in
        if lhs.difficulty != rhs.difficulty { return lhs.difficulty < rhs.difficulty }
        if lhs.popularity != rhs.popularity { return lhs.popularity > rhs.popularity }
        return lhs.order < rhs.order
    }
}

private func introStrengthSort(phenotypes: Set<Phenotype>) -> (RemedyConfig, RemedyConfig) -> Bool {
    { lhs, rhs in
        let lhsStrength = lhs.strengthValue(for: phenotypes)
        let rhsStrength = rhs.strengthValue(for: phenotypes)
        if lhsStrength != rhsStrength { return lhsStrength > rhsStrength }
        if lhs.difficulty != rhs.difficulty { return lhs.difficulty < rhs.difficulty }
        return lhs.order < rhs.order
    }
}

// Converts a scored remedy name to its NightlyStepKind.
private func nightlyStepKind(for remedy: String) -> NightlyStepKind? {
    switch remedy {
    case R.brainDump:        return .brainDump
    case R.boringStory:      return .boringStory
    case R.sleepSounds:      return .sleepSounds
    case R.breathing478:     return .fourSevenEightBreathing
    case R.gratitudeJournal: return .gratitudeJournal
    case R.gentleStretching: return .gentleStretching
    case R.pmr:              return .progressiveMuscleRelaxation
    case R.bodyScan:         return .bodyScan
    case R.readingBook:      return .existingHabit(label: R.readingBook)
    case R.weightedBlanket:  return .existingHabit(label: R.weightedBlanket)
    default:                 return nil
    }
}

// MARK: - Explanation Builder

private func buildRoutineExplanation(
    remedyIds: [RemedyID],
    reinforcedRemedyIds: [RemedyID],
    showHealthScreening: Bool
) -> String {
    var parts: [String] = ["We built a starter routine from your sleep pattern and bedtime habits."]

    if remedyIds.contains(.warmShower) {
        if reinforcedRemedyIds.contains(.warmShower) {
            parts.append("You already shower or bathe at night, so we’ll focus on timing it about 90 minutes before sleep.")
        } else {
            parts.append("A warm shower or bath is included by default because the post-shower temperature drop helps cue sleep.")
        }
    }

    if reinforcedRemedyIds.contains(.readingBook) {
        parts.append("You already read a physical book, so we’ll reinforce that instead of treating it like a new prescription.")
    }

    let selectedLabels = remedyIds
        .filter { $0 != .warmShower }
        .compactMap { config(for: $0)?.label }
    if !selectedLabels.isEmpty {
        parts.append("Your first scored remedies are \(selectedLabels.joined(separator: ", ")).")
    }

    if showHealthScreening {
        parts.append("Because unrefreshed sleep can have physical causes, we’ll also show a gentle health screening prompt.")
    }

    return parts.joined(separator: " ")
}
