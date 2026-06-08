import SwiftUI
import Combine
import UserNotifications
import ActivityKit
import FamilyControls
import ManagedSettings

enum Chronotype: String, Codable {
    case earlySleeper
    case steadySleeper
    case lateSleeper
    case drifter

    var displayName: String {
        switch self {
        case .earlySleeper: return "Early Sleeper"
        case .steadySleeper: return "Steady Sleeper"
        case .lateSleeper: return "Late Sleeper"
        case .drifter: return "Drifter"
        }
    }

    var pluralDisplayName: String {
        switch self {
        case .earlySleeper: return "Early Sleepers"
        case .steadySleeper: return "Steady Sleepers"
        case .lateSleeper: return "Late Sleepers"
        case .drifter: return "Drifters"
        }
    }
}

enum SleepBottleneck: String, Codable {
    case preSleepRumination
    case fragmentedSleep
    case insufficientDeepSleep
    case shortSleepWindow
    case inconsistentRhythm

    var displayName: String {
        switch self {
        case .preSleepRumination: return "Pre-sleep rumination"
        case .fragmentedSleep: return "Fragmented sleep"
        case .insufficientDeepSleep: return "Insufficient deep sleep"
        case .shortSleepWindow: return "Short sleep window"
        case .inconsistentRhythm: return "Inconsistent rhythm"
        }
    }

    var suggestedExperiment: String {
        switch self {
        case .preSleepRumination: return "Brain Dump"
        case .fragmentedSleep: return "Dim the lights"
        case .insufficientDeepSleep: return "Temperature check"
        case .shortSleepWindow: return "Earlier wind-down"
        case .inconsistentRhythm: return "Fixed bedtime anchor"
        }
    }
}

struct SleepPatternClassification {
    var chronotype: Chronotype
    var bottleneck: SleepBottleneck
    var isProvisional: Bool
}

func classifySleepPattern(
    sleepProblems: Set<Int>,
    wakingFactors: Set<Int>,
    currentBedtime: Date,
    currentWakeTime: Date
) -> SleepPatternClassification {
    let racingMind = sleepProblems.contains(0) || sleepProblems.contains(1)
    let fragmented = sleepProblems.contains(2) || sleepProblems.contains(3)
    let neuroLean = wakingFactors.contains(2) || wakingFactors.contains(3) || wakingFactors.contains(4)
    let situational = wakingFactors.contains(0) || wakingFactors.contains(1)

    let duration = sleepDurationMinutes(bedtime: currentBedtime, wakeTime: currentWakeTime)
    let midpoint = sleepMidpointMinute(bedtime: currentBedtime, wakeTime: currentWakeTime)

    let chronotype: Chronotype
    if fragmented && (duration < 7 * 60 || wakingFactors.contains(4)) {
        chronotype = .drifter
    } else if midpoint <= 2 * 60 + 30 {
        chronotype = .earlySleeper
    } else if midpoint >= 4 * 60 || (racingMind && neuroLean) {
        chronotype = .lateSleeper
    } else {
        chronotype = .steadySleeper
    }

    let bottleneck: SleepBottleneck
    if racingMind {
        bottleneck = .preSleepRumination
    } else if sleepProblems.contains(2) {
        bottleneck = .fragmentedSleep
    } else if sleepProblems.contains(3) {
        bottleneck = .insufficientDeepSleep
    } else if duration < 7 * 60 {
        bottleneck = .shortSleepWindow
    } else {
        bottleneck = .inconsistentRhythm
    }

    return SleepPatternClassification(
        chronotype: chronotype,
        bottleneck: bottleneck,
        isProvisional: situational
    )
}

private func minuteOfDay(_ date: Date) -> Int {
    let cal = Calendar.current
    return cal.component(.hour, from: date) * 60 + cal.component(.minute, from: date)
}

private func sleepDurationMinutes(bedtime: Date, wakeTime: Date) -> Int {
    let bed = minuteOfDay(bedtime)
    let wake = minuteOfDay(wakeTime)
    let raw = wake - bed
    return raw > 0 ? raw : raw + 24 * 60
}

private func sleepMidpointMinute(bedtime: Date, wakeTime: Date) -> Int {
    let bed = minuteOfDay(bedtime)
    let duration = sleepDurationMinutes(bedtime: bedtime, wakeTime: wakeTime)
    return (bed + duration / 2) % (24 * 60)
}

class AppState: ObservableObject {
    static let maxSleepScore = 5
    private static let morningRatingNotificationIdentifiers =
        ["morning_rating_primary", "morning_rating_noon"] +
        (0..<14).flatMap { ["morning_rating_primary_\($0)", "morning_rating_noon_\($0)"] }
    private let appBlockingStore = ManagedSettingsStore()
    private var persistedTimeZoneIdentifier = TimeZone.autoupdatingCurrent.identifier

    static func clampedSleepScore(_ score: Int) -> Int {
        guard score > 0 else { return 0 }
        return min(max(score, 1), maxSleepScore)
    }

    static func clockDurationMinutes(from start: Date,
                                     to end: Date,
                                     calendar: Calendar = .autoupdatingCurrent) -> Int {
        let startComponents = calendar.dateComponents([.hour, .minute], from: start)
        let endComponents = calendar.dateComponents([.hour, .minute], from: end)
        let startMinutes = (startComponents.hour ?? 0) * 60 + (startComponents.minute ?? 0)
        let endMinutes = (endComponents.hour ?? 0) * 60 + (endComponents.minute ?? 0)
        let raw = endMinutes - startMinutes
        return raw > 0 ? raw : raw + 24 * 60
    }

    private static let researchDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static func researchDateString(_ date: Date) -> String {
        researchDateFormatter.string(from: date)
    }

    private func researchDateValue(_ date: Date?) -> ResearchValue {
        guard let date else { return .null }
        return .string(Self.researchDateString(date))
    }

    private static func reanchoredWallClockDate(_ date: Date,
                                                from oldTimeZone: TimeZone,
                                                to newTimeZone: TimeZone) -> Date {
        var oldCalendar = Calendar(identifier: .gregorian)
        oldCalendar.timeZone = oldTimeZone

        var newCalendar = Calendar(identifier: .gregorian)
        newCalendar.timeZone = newTimeZone

        let components = oldCalendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return newCalendar.date(from: components) ?? date
    }

    // MARK: - Launch routing
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false

    // MARK: - Onboarding answers
    @Published var testerName: String = ""
    @Published var selectedSleepProblems: Set<Int> = []
    @Published var selectedWakes: Set<Int> = []
    @Published var sleepWindowMinutes: Int = 20
    @Published var currentBedtime: Date = {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return Calendar.current.date(bySettingHour: 23, minute: 30, second: 0, of: yesterday) ?? Date()
    }()
    @Published var currentWakeTime: Date = {
        return Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    }()
    @Published var targetBedtime: Date = {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return Calendar.current.date(bySettingHour: 23, minute: 30, second: 0, of: yesterday) ?? Date()
    }()
    @Published var targetWakeTime: Date = {
        return Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    }()
    @Published var typicalBedtime: Date = {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return Calendar.current.date(bySettingHour: 22, minute: 30, second: 0, of: yesterday) ?? Date()
    }()
    @Published var typicalWakeTime: Date = {
        return Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    }()
    @Published var selectedPreBedActivities: Set<Int> = []
    @Published var selectedTriedThings: Set<Int> = []
    @Published var chronotype: Chronotype = .steadySleeper
    @Published var bottleneck: SleepBottleneck = .inconsistentRhythm
    @Published var committedRoutineTime: Date? = nil
    @Published var paywallState = PaywallState()
    @Published var activePaywallRoute: PaywallRoute? = nil
    @Published var activePaywallVerdict: PaywallVerdict? = nil

    // MARK: - Home / Dashboard
    @Published var showNightlyFlow = false
    @Published var showMidSleepMode = false
    @Published var showSleepSounds = false
    @Published var showMorningCheckIn = false
    @Published var appBlockingSelection = FamilyActivitySelection()
    @Published var appBlockingEnabled = false
    @Published var appBlockingStartTime: Date = Date()
    @Published var appBlockingEndTime: Date = Date()
    @Published var appBlockingGraceMinutes = 5

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
        RoutineStep(order: 1, label: R.dimTheLights,       mode: .reminderOnly, leadTimeMins: 75, remedyId: .dimTheLights),
        RoutineStep(order: 2, label: R.noScreens,          mode: .reminderOnly, leadTimeMins: 75, remedyId: .noScreens),
        RoutineStep(order: 3, label: R.weightedBlanket,    mode: .experiment,   leadTimeMins: 90, remedyId: .weightedBlanket),
        RoutineStep(order: 4, label: "Brightness check",   mode: .inSequence, durationLabel: "10s"),
        RoutineStep(order: 5, label: "Temperature check",  mode: .inSequence, durationLabel: "10s"),
        RoutineStep(order: 6, label: R.brainDump,          mode: .inSequence, durationLabel: "2m · voice", remedyId: .brainDump),
        RoutineStep(order: 7, label: R.boringStory,        mode: .inSequence, durationLabel: "AI · 8m", remedyId: .boringStory),
    ]

    // MARK: - Generated routine (set during onboarding)
    @Published var generatedRoutine: GeneratedRoutine? = nil
    @Published var routineExplanation: String = ""
    @Published var routineShouldStartNow: Bool = false

    func applyGeneratedRoutine(_ routine: GeneratedRoutine, scheduleNotifications: Bool = true) {
        generatedRoutine      = routine
        coreRoutine           = routine.toCoreRoutineSteps()
        routineExplanation    = routine.explanation
        routineShouldStartNow = shouldOfferImmediateOnboardingRitual
        persist()
        if scheduleNotifications {
            scheduleAllNotifications()
        }
    }

    func refreshOnboardingClassifications() {
        let result = classifySleepPattern(
            sleepProblems: selectedSleepProblems,
            wakingFactors: selectedWakes,
            currentBedtime: currentBedtime,
            currentWakeTime: currentWakeTime
        )
        chronotype = result.chronotype
        bottleneck = result.bottleneck
        persist()
    }

    var defaultRoutineStartTime: Date {
        scheduledRoutine.first?.time
            ?? Calendar.current.date(byAdding: .minute, value: -30, to: targetBedtime)
            ?? targetBedtime
    }

    var preferredSleepWindowIsActive: Bool {
        isCurrentTimeInWindow(
            from: typicalBedtime,
            to: Calendar.current.date(byAdding: .minute, value: sleepWindowMinutes, to: typicalBedtime) ?? typicalBedtime
        )
    }

    var routineStartWindowIsActive: Bool {
        isCurrentTimeInWindow(
            from: defaultRoutineStartTime,
            to: Calendar.current.date(byAdding: .minute, value: sleepWindowMinutes, to: typicalBedtime) ?? typicalBedtime
        )
    }

    var shouldOfferImmediateOnboardingRitual: Bool {
        routineStartWindowIsActive
    }

    private func isCurrentTimeInWindow(from start: Date, to end: Date, now: Date = Date()) -> Bool {
        let cal = Calendar.current
        let nowMinute = minuteOfDay(now, calendar: cal)
        let startMinute = minuteOfDay(start, calendar: cal)
        let endMinute = minuteOfDay(end, calendar: cal)

        if startMinute <= endMinute {
            return nowMinute >= startMinute && nowMinute <= endMinute
        }
        return nowMinute >= startMinute || nowMinute <= endMinute
    }

    private func minuteOfDay(_ date: Date, calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
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
    @Published var ritualDoneIds: Set<UUID> = []
    @Published var ritualDoneDate: Date? = nil
    var suppressPrepLiveActivityForSession = false

    static func defaultAppBlockingStart(from bedtime: Date) -> Date {
        Calendar.current.date(byAdding: .minute, value: -75, to: bedtime) ?? bedtime
    }

    static func defaultAppBlockingEnd(from wakeTime: Date) -> Date {
        wakeTime
    }

    func togglePrepDone(_ id: UUID) {
        if prepDoneIds.contains(id) { prepDoneIds.remove(id) }
        else { prepDoneIds.insert(id) }
        prepDoneDate = Date()
        persist()
        scheduleBedtimePrepSummary()
        LiveActivityService.shared.update(doneIds: prepDoneIds)
        if prepDoneIds.count == preWindDownSteps.count {
            LiveActivityService.shared.end(dismissalPolicy: .after(.now + 30))
        }
    }

    func completePrepFromLiveActivity(_ id: UUID) {
        if !prepDoneIds.contains(id) {
            prepDoneIds.insert(id)
            prepDoneDate = Date()
            persist()
            scheduleBedtimePrepSummary()
        }
        requestedTab = 0
        LiveActivityService.shared.update(doneIds: prepDoneIds)
        if prepDoneIds.count == preWindDownSteps.count {
            LiveActivityService.shared.end(dismissalPolicy: .after(.now + 30))
        }
    }

    func toggleRitualDone(_ id: UUID) {
        if ritualDoneIds.contains(id) { unmarkRitualDone(id) }
    }

    func unmarkRitualDone(_ id: UUID) {
        guard ritualDoneIds.contains(id) else { return }
        ritualDoneIds.remove(id)
        ritualDoneDate = Date()
        persist()
    }

    func markRitualDone(_ id: UUID) {
        guard !ritualDoneIds.contains(id) else { return }
        ritualDoneIds.insert(id)
        ritualDoneDate = Date()
        persist()
    }

    func markRitualDone(label: String) {
        guard let step = windDownSteps.first(where: { $0.label == label }) else { return }
        markRitualDone(step.id)
    }

    func markAllRitualDone() {
        let ids = Set(windDownSteps.map(\.id))
        if ritualDoneIds != ids {
            ritualDoneIds = ids
            ritualDoneDate = Date()
            persist()
        }
    }

    func resetPrepIfNeeded() {
        let lastDate = [prepDoneDate, ritualDoneDate].compactMap { $0 }.max()
        guard let lastDate else { return }
        let cal = Calendar.current
        let wc = cal.dateComponents([.hour, .minute], from: typicalWakeTime)
        guard let todayWake = cal.date(bySettingHour: wc.hour ?? 7,
                                       minute: wc.minute ?? 0,
                                       second: 0, of: Date()) else { return }
        if Date() >= todayWake && lastDate < todayWake {
            prepDoneIds = []
            prepDoneDate = nil
            ritualDoneIds = []
            ritualDoneDate = nil
            suppressPrepLiveActivityForSession = false
            persist()
            scheduleBedtimePrepSummary()
        }
    }

    // MARK: - Brain dump helpers

    // When the user deletes a recording from the Brain Dumps browser, clear
    // any matching SleepLogEntry's reference so MorningCheckInView doesn't
    // try to render a player for a file that no longer exists.
    func clearBrainDumpReference(forFileAt url: URL) {
        let relative = "brain_dumps/" + url.lastPathComponent
        var changed = false
        for i in sleepLogs.indices where sleepLogs[i].brainDumpFilePath == relative {
            sleepLogs[i].brainDumpFilePath = nil
            sleepLogs[i].brainDumpDurationSec = nil
            changed = true
        }
        if changed { persist() }
    }

    // MARK: - Sleep Companion Live Activity helpers

    // The next wake time anchored to today/tomorrow based on the user's
    // typicalWakeTime hour/minute. Used to seed the Live Activity countdown.
    func nextWakeTime() -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: typicalWakeTime)
        let now = Date()
        var candidate = cal.date(bySettingHour: comps.hour ?? 7,
                                 minute: comps.minute ?? 0,
                                 second: 0,
                                 of: now) ?? now
        if candidate <= now {
            candidate = cal.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        }
        return candidate
    }

    // Called on app foreground. If a Lock Screen rating tap stashed a value
    // in the App Group, persist it as morningScore and push the .rated state
    // (with score + delta) to the Live Activity so the confirmation lingers.
    func ingestPendingLiveActivityRating() {
        guard let pending = LiveActivityService.shared.consumePendingRating() else { return }
        ingestLiveActivityRating(rating: pending.rating, at: pending.at)
    }

    // URL-driven Live Activity rating path. This mirrors the App Group ingest
    // path but avoids relying on Button(intent:) firing from the Lock Screen.
    func ingestLiveActivityRating(rating rawRating: Int, at: Date = Date()) {
        let rating = Self.clampedSleepScore(rawRating)
        guard rating > 0 else { return }
        // Capture before logMorningScore/advanceExperiment mutate state.
        let mostRecentRated    = sleepLogs.filter { $0.score > 0 }.sorted { $0.date > $1.date }.first
        let yesterdayCaptured  = mostRecentRated?.score
        let baselineCaptured   = baselineScore
        let variableCaptured   = experimentStatus?.variable
        let preLogNight        = experimentStatus?.night ?? 0

        morningScore = rating
        logMorningScore()

        // Show the reward sheet when the app opens.
        pendingMorningReward = PendingMorningReward(
            score: rating,
            yesterday: yesterdayCaptured,
            baseline: baselineCaptured,
            variable: variableCaptured,
            night: preLogNight + 1
        )

        let delta = Double(rating - baselineCaptured)
        let baseLabel = sameWeekdayBaselineLabel(for: at)

        LiveActivityService.shared.publishRatedAndEnd(
            rating: rating,
            score: Double(rating),
            deltaVsBaseline: delta,
            baselineLabel: baseLabel
        )
    }

    // Promote the Live Activity from .sleeping → .awaitingRating once the
    // app foregrounds past the user's wake time. The view already renders
    // the wake UI based on the clock; this just syncs the data state.
    func syncSleepActivityWakeStateIfNeeded() {
        if Date() >= nextWakeTimeOrTodayWake() {
            LiveActivityService.shared.updateToAwaitingRating()
        }
    }

    private func nextWakeTimeOrTodayWake() -> Date {
        // Return *today's* wake time anchor — for detecting whether we've
        // crossed it since bedtime. If today's wake hasn't happened yet,
        // we use it directly; nextWakeTime() would already roll to tomorrow.
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: typicalWakeTime)
        return cal.date(bySettingHour: comps.hour ?? 7,
                        minute: comps.minute ?? 0,
                        second: 0,
                        of: Date()) ?? Date()
    }

    private func sameWeekdayBaselineLabel(for ratedAt: Date) -> String {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: ratedAt)
        let priorMatching = sleepLogs
            .filter {
                $0.score > 0 &&
                cal.component(.weekday, from: $0.date) == weekday &&
                $0.date < cal.startOfDay(for: ratedAt)
            }
            .max(by: { $0.date < $1.date })
        if priorMatching != nil {
            let f = DateFormatter()
            f.dateFormat = "EEE"
            return f.string(from: priorMatching!.date).uppercased()
        }
        return "BASELINE"
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

    // Transient — queued by both the dashboard MorningRateHero and the
    // SleepLogDetailView "Log this morning" CTA. ContentView observes this
    // and presents MorningRewardView as a sheet (with mini confetti when
    // the just-logged score is greater than yesterday's).
    @Published var pendingMorningReward: PendingMorningReward? = nil
    @Published var justTriggeredNightFivePaywall: Bool = false

    // Debug-only time-of-day override for testing the morning/evening branches
    // on the Today tab without changing the simulator clock or wake time.
    // Mutually exclusive (set one → other clears). Wrapped in #if DEBUG at the
    // UI layer so they're never reachable on TestFlight or App Store builds.
    @Published var debugForceMorningState: Bool = false
    @Published var debugForceEveningState: Bool = false

    // Debug: zeros the score on last night's entry (or today's, if last night
    // has nothing) so the user can re-test the unrated morning hero.
    func debugClearTodaysRating() {
        let cal = Calendar.current
        if let idx = sleepLogs.firstIndex(where: {
            cal.isDateInYesterday($0.date) || cal.isDateInToday($0.date)
        }) {
            sleepLogs[idx].score = 0
            sleepLogs[idx].actualWakeTime = nil
            sleepLogs[idx].hoursSlept = nil
            persist()
        }
    }

    #if DEBUG
    func debugSeedNightFivePaywallReadiness() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        coreRoutine.removeAll { $0.mode == .experiment }
        coreRoutine.append(RoutineStep(
            order: coreRoutine.count + 1,
            label: R.brainDump,
            mode: .experiment,
            durationLabel: "12m",
            remedyId: .brainDump
        ))
        normalizeRoutineOrder()

        func day(_ offset: Int) -> Date {
            cal.date(byAdding: .day, value: offset, to: today) ?? today
        }

        var seeded: [SleepLogEntry] = []
        seeded.append(SleepLogEntry(date: day(-7), variable: R.dimTheLights, variableRemedyId: .dimTheLights, score: 3))
        seeded.append(SleepLogEntry(date: day(-6), variable: R.noScreens, variableRemedyId: .noScreens, score: 3))
        seeded.append(SleepLogEntry(date: day(-5), variable: R.brainDump, variableRemedyId: .brainDump, score: 4))
        seeded.append(SleepLogEntry(date: day(-4), variable: R.brainDump, variableRemedyId: .brainDump, score: 4))
        seeded.append(SleepLogEntry(date: day(-3), variable: R.brainDump, variableRemedyId: .brainDump, score: 4))
        seeded.append(SleepLogEntry(date: day(-2), variable: R.brainDump, variableRemedyId: .brainDump, score: 5))

        var lastNight = SleepLogEntry(date: day(-1), variable: R.brainDump, variableRemedyId: .brainDump, score: 0)
        lastNight.completedNightlyFlow = true
        lastNight.actualBedtime = typicalBedtime
        seeded.append(lastNight)

        sleepLogs = seeded
        baselineScore = 3
        morningScore = 0
        morningHoursSlept = 7.5
        pendingMorningReward = nil
        pendingPromotion = nil
        activePaywallRoute = nil
        activePaywallVerdict = nil
        justTriggeredNightFivePaywall = false
        paywallState = PaywallState(tier: .awaitingVerdict, verdictRevealed: false)
        hasCompletedOnboarding = true
        initialTab = 0
        requestedTab = 0
        debugForceMorningState = true
        debugForceEveningState = false
        persist()
    }
    #endif

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

    // One-time data migration: enforces Lull's 1-5 sleep-score scale for any
    // values saved while the Live Activity path briefly doubled ratings.
    func normalizeSleepScoreScale() {
        var changed = false

        let clampedBaseline = Self.clampedSleepScore(baselineScore)
        if clampedBaseline != baselineScore {
            baselineScore = clampedBaseline
            changed = true
        }

        for i in sleepLogs.indices {
            let clampedScore = Self.clampedSleepScore(sleepLogs[i].score)
            if clampedScore != sleepLogs[i].score {
                sleepLogs[i].score = clampedScore
                changed = true
            }
        }

        if changed {
            print("[Migration] Normalized sleep scores to the 1-\(Self.maxSleepScore) scale.")
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

    // MARK: - Telemetry

    func trackAppOpened() {
        trackAnalytics("app_opened")
    }

    func flushResearchData() {
        Task {
            await ResearchDataService.shared.flushQueued()
        }
    }

    func recordNightlySessionStarted() {
        let ritualStartedAt = Date()
        updateTodayLog {
            $0.variable = tonightVariable
            $0.variableRemedyId = tonightRemedyId
            $0.actualRitualStart = ritualStartedAt
        }

        let payload = baseResearchPayload().merging([
            "night_id": .string(currentNightId ?? ""),
            "routine_id": .string(routineFingerprint),
            "tested_remedy_id": .string(tonightRemedyId?.rawValue ?? ""),
            "tested_remedy_label": .string(tonightVariable),
            "routine_step_count": .int(nightlyStepTotal),
            "routine_day_number": .int(experimentStatus?.night ?? 0),
            "current_bedtime": .string(Self.researchDateString(currentBedtime)),
            "target_bedtime": .string(Self.researchDateString(targetBedtime)),
            "expected_ritual_start_at": .string(Self.researchDateString(expectedRitualStartAt)),
            "actual_ritual_start_at": .string(Self.researchDateString(ritualStartedAt))
        ]) { _, new in new }

        trackAnalytics("nightly_session_started", [
            "tested_remedy_id": tonightRemedyId?.rawValue ?? "",
            "routine_day_number": "\(experimentStatus?.night ?? 0)",
            "routine_step_count": "\(nightlyStepTotal)",
            "current_bedtime": Self.researchDateString(currentBedtime),
            "target_bedtime": Self.researchDateString(targetBedtime),
            "expected_ritual_start_at": Self.researchDateString(expectedRitualStartAt),
            "actual_ritual_start_at": Self.researchDateString(ritualStartedAt)
        ])
        submitResearch("nightly_session_started", payload: payload)
    }

    func recordNightlySessionCompleted() {
        let entry = sleepLogs.first(where: { $0.isToday })
        trackAnalytics("nightly_session_completed", [
            "tested_remedy_id": entry?.variableRemedyId?.rawValue ?? tonightRemedyId?.rawValue ?? "",
            "routine_step_attempt_count": "\(entry?.stepAttempts.count ?? 0)"
        ])

        let payload = baseResearchPayload().merging([
            "night_id": .string(entry?.id.uuidString ?? ""),
            "tested_remedy_id": .string(entry?.variableRemedyId?.rawValue ?? tonightRemedyId?.rawValue ?? ""),
            "completed_nightly_flow": .bool(entry?.completedNightlyFlow ?? true),
            "routine_step_attempt_count": .int(entry?.stepAttempts.count ?? 0),
            "current_bedtime": .string(Self.researchDateString(currentBedtime)),
            "target_bedtime": .string(Self.researchDateString(targetBedtime)),
            "expected_ritual_start_at": .string(Self.researchDateString(expectedRitualStartAt)),
            "actual_ritual_start_at": researchDateValue(entry?.actualRitualStart)
        ]) { _, new in new }
        submitResearch("nightly_session_completed", payload: payload)
    }

    func recordCurrentStepStarted() {
        guard nightlyStep < nightlyFlowSteps.count else { return }
        let kind = nightlyFlowSteps[nightlyStep]
        let label = kind.displayLabel
        let routineStep = coreRoutine.first { $0.label == label }
        let remedyId = routineStep?.remedyId ?? RemedyID.fromLabel(label)

        trackAnalytics("routine_step_started", [
            "remedy_id": remedyId?.rawValue ?? "",
            "step_label": label,
            "step_mode": routineStep?.mode.rawValue ?? "",
            "step_index": "\(nightlyStep + 1)",
            "tested_remedy_id": tonightRemedyId?.rawValue ?? ""
        ])

        let payload = baseResearchPayload().merging([
            "night_id": .string(currentNightId ?? ""),
            "step_index": .int(nightlyStep + 1),
            "step_label": .string(label),
            "remedy_id": .string(remedyId?.rawValue ?? ""),
            "step_mode": .string(routineStep?.mode.rawValue ?? ""),
            "tested_remedy_id": .string(tonightRemedyId?.rawValue ?? "")
        ]) { _, new in new }
        submitResearch("routine_step_started", payload: payload)
    }

    func recordSleepSoundAttempt(status: StepStatus,
                                 config: SleepSoundStepConfig,
                                 listenedSeconds: Int?) {
        let configuredSeconds = config.infinite ? nil : (config.durationMinutes ?? 60) * 60
        recordCurrentStepAttempt(status: status, durationSeconds: listenedSeconds)
        recordMediaSession(
            mediaType: "sleep_sound",
            contentId: config.soundId?.rawValue,
            configuredDurationSeconds: configuredSeconds,
            listenedDurationSeconds: listenedSeconds,
            completed: status == .completed,
            extra: [
                "infinite": .bool(config.infinite),
                "fade_out": .bool(config.fadeOut)
            ]
        )
    }

    func recordBoringStorySession(contentId: String?,
                                  listenedSeconds: Int,
                                  totalDurationSeconds: Int,
                                  status: StepStatus) {
        recordCurrentStepAttempt(status: status, durationSeconds: listenedSeconds)
        recordMediaSession(
            mediaType: "boring_story",
            contentId: contentId,
            configuredDurationSeconds: totalDurationSeconds,
            listenedDurationSeconds: listenedSeconds,
            completed: status == .completed
        )
    }

    func recordBrainDumpSession(durationSeconds: Int,
                                hasRecording: Bool) {
        recordMediaSession(
            mediaType: "brain_dump",
            contentId: nil,
            configuredDurationSeconds: 120,
            listenedDurationSeconds: durationSeconds,
            completed: durationSeconds > 0,
            extra: [
                "has_recording": .bool(hasRecording)
            ]
        )
    }

    private func trackAnalytics(_ event: String,
                                _ properties: AnalyticsService.Properties = [:]) {
        var merged = baseAnalyticsProperties()
        properties.forEach { merged[$0.key] = $0.value }
        AnalyticsService.track(event, installId: installId, properties: merged)
    }

    private func submitResearch(_ eventName: String,
                                payload: [String: ResearchValue]) {
        let id = installId
        Task {
            await ResearchDataService.shared.submit(
                eventName: eventName,
                installId: id,
                payload: payload
            )
        }
    }

    private func recordOnboardingTelemetry(route: String) {
        let payload = baseResearchPayload().merging([
            "completion_route": .string(route),
            "selected_sleep_problem_ids": .intArray(selectedSleepProblems.sorted()),
            "selected_wake_factor_ids": .intArray(selectedWakes.sorted()),
            "selected_pre_bed_activity_ids": .intArray(selectedPreBedActivities.sorted()),
            "selected_tried_thing_ids": .intArray(selectedTriedThings.sorted()),
            "sleep_window_minutes": .int(sleepWindowMinutes),
            "chronotype": .string(chronotype.rawValue),
            "bottleneck": .string(bottleneck.rawValue),
            "baseline_score": .int(baselineScore),
            "generated_routine_step_count": .int(coreRoutine.count),
            "tested_remedy_id": .string(tonightRemedyId?.rawValue ?? "")
        ]) { _, new in new }

        trackAnalytics("onboarding_completed", [
            "completion_route": route,
            "chronotype": chronotype.rawValue,
            "bottleneck": bottleneck.rawValue,
            "tested_remedy_id": tonightRemedyId?.rawValue ?? ""
        ])
        submitResearch("onboarding_profile_recorded", payload: payload)
    }

    private func recordMediaSession(mediaType: String,
                                    contentId: String?,
                                    configuredDurationSeconds: Int?,
                                    listenedDurationSeconds: Int?,
                                    completed: Bool,
                                    extra: [String: ResearchValue] = [:]) {
        let analyticsEvent = "\(mediaType)_recorded"
        trackAnalytics(analyticsEvent, [
            "media_type": mediaType,
            "content_id": contentId ?? "",
            "duration_bucket": durationBucket(listenedDurationSeconds),
            "completed": completed ? "true" : "false"
        ])

        var payload = baseResearchPayload().merging([
            "night_id": .string(currentNightId ?? ""),
            "media_type": .string(mediaType),
            "content_id": .string(contentId ?? ""),
            "configured_duration_seconds": researchInt(configuredDurationSeconds),
            "listened_duration_seconds": researchInt(listenedDurationSeconds),
            "completed": .bool(completed),
            "tested_remedy_id": .string(tonightRemedyId?.rawValue ?? "")
        ]) { _, new in new }
        extra.forEach { payload[$0.key] = $0.value }
        submitResearch("media_session_recorded", payload: payload)
    }

    private func recordMorningTelemetry(entry: SleepLogEntry) {
        let scoreBucket = entry.score >= 4 ? "4-5" : "\(entry.score)"
        trackAnalytics("morning_checkin_completed", [
            "sleep_score_bucket": scoreBucket,
            "tested_remedy_id": entry.variableRemedyId?.rawValue ?? "",
            "has_note": entry.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "false" : "true",
            "has_voice_note": entry.brainDumpFilePath == nil ? "false" : "true"
        ])

        let payload = baseResearchPayload().merging([
            "night_id": .string(entry.id.uuidString),
            "sleep_score": .int(entry.score),
            "hours_slept": researchDouble(entry.hoursSlept),
            "tested_remedy_id": .string(entry.variableRemedyId?.rawValue ?? ""),
            "tested_remedy_label": .string(entry.variable),
            "has_note": .bool(!entry.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty),
            "has_voice_note": .bool(entry.brainDumpFilePath != nil),
            "completed_nightly_flow": .bool(entry.completedNightlyFlow),
            "routine_step_attempt_count": .int(entry.stepAttempts.count),
            "lights_level": researchInt(entry.lightsLevel),
            "lights_level_source": .string(entry.lightsLevelSource?.rawValue ?? ""),
            "perceived_temp": researchInt(entry.perceivedTemp)
        ]) { _, new in new }
        submitResearch("morning_checkin_recorded", payload: payload)
    }

    private func baseAnalyticsProperties() -> AnalyticsService.Properties {
        [
            "chronotype": chronotype.rawValue,
            "bottleneck": bottleneck.rawValue,
            "has_completed_onboarding": hasCompletedOnboarding ? "true" : "false",
            "user_tier": paywallState.tier.rawValue
        ]
    }

    private func baseResearchPayload() -> [String: ResearchValue] {
        [
            "chronotype": .string(chronotype.rawValue),
            "bottleneck": .string(bottleneck.rawValue),
            "has_completed_onboarding": .bool(hasCompletedOnboarding),
            "user_tier": .string(paywallState.tier.rawValue)
        ]
    }

    private var currentNightId: String? {
        sleepLogs.first(where: { $0.isToday })?.id.uuidString
    }

    private var routineFingerprint: String {
        coreRoutine
            .map { "\($0.order):\($0.remedyId?.rawValue ?? $0.label):\($0.mode.rawValue)" }
            .joined(separator: "|")
    }

    private func researchInt(_ value: Int?) -> ResearchValue {
        guard let value else { return .null }
        return .int(value)
    }

    private func researchDouble(_ value: Double?) -> ResearchValue {
        guard let value else { return .null }
        return .double(value)
    }

    private func durationBucket(_ seconds: Int?) -> String {
        guard let seconds else { return "unknown" }
        switch seconds {
        case 0: return "0"
        case 1..<60: return "<1m"
        case 60..<300: return "1-5m"
        case 300..<900: return "5-15m"
        case 900..<1800: return "15-30m"
        default: return "30m+"
        }
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
            schemaVersion: 7,
            testerName: testerName,
            selectedSleepProblems: selectedSleepProblems,
            selectedWakes: selectedWakes,
            sleepWindowMinutes: sleepWindowMinutes,
            currentBedtime: currentBedtime,
            currentWakeTime: currentWakeTime,
            targetBedtime: targetBedtime,
            targetWakeTime: targetWakeTime,
            typicalBedtime: typicalBedtime,
            typicalWakeTime: typicalWakeTime,
            selectedPreBedActivities: selectedPreBedActivities,
            selectedTriedThings: selectedTriedThings,
            coreRoutine: coreRoutine,
            routineExplanation: routineExplanation,
            sleepLogs: sleepLogs,
            chronotype: chronotype,
            bottleneck: bottleneck,
            committedRoutineTime: committedRoutineTime,
            timeZoneIdentifier: persistedTimeZoneIdentifier,
            paywallState: paywallState
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
            persistedTimeZoneIdentifier = saved.timeZoneIdentifier
            _testerName               = Published(initialValue: saved.testerName)
            _selectedSleepProblems    = Published(initialValue: saved.selectedSleepProblems)
            _selectedWakes            = Published(initialValue: saved.selectedWakes)
            _sleepWindowMinutes       = Published(initialValue: saved.sleepWindowMinutes)
            _currentBedtime           = Published(initialValue: saved.currentBedtime)
            _currentWakeTime          = Published(initialValue: saved.currentWakeTime)
            _targetBedtime            = Published(initialValue: saved.targetBedtime)
            _targetWakeTime           = Published(initialValue: saved.targetWakeTime)
            _typicalBedtime           = Published(initialValue: saved.typicalBedtime)
            _typicalWakeTime          = Published(initialValue: saved.typicalWakeTime)
            _selectedPreBedActivities = Published(initialValue: saved.selectedPreBedActivities)
            _selectedTriedThings      = Published(initialValue: saved.selectedTriedThings)
            _chronotype               = Published(initialValue: saved.chronotype)
            _bottleneck               = Published(initialValue: saved.bottleneck)
            _committedRoutineTime     = Published(initialValue: saved.committedRoutineTime)
            _paywallState             = Published(initialValue: saved.paywallState)
            _coreRoutine              = Published(initialValue: saved.coreRoutine)
            _routineExplanation       = Published(initialValue: saved.routineExplanation)
            _sleepLogs                = Published(initialValue: saved.sleepLogs)
            _baselineScore            = Published(initialValue: saved.baselineScore)
            _prepDoneIds              = Published(initialValue: Set(saved.prepDoneIds))
            _prepDoneDate             = Published(initialValue: saved.prepDoneDate)
            _ritualDoneIds            = Published(initialValue: Set(saved.ritualDoneIds))
            _ritualDoneDate           = Published(initialValue: saved.ritualDoneDate)
            _pendingPromotion         = Published(initialValue: saved.pendingPromotion)
            _recentlyPromotedRemedyId = Published(initialValue: saved.recentlyPromotedRemedyId)
            _recentlyPromotedAt       = Published(initialValue: saved.recentlyPromotedAt)
            if let data = saved.appBlockingSelectionData,
               let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
                _appBlockingSelection = Published(initialValue: decoded)
            }
            _appBlockingEnabled = Published(initialValue: saved.appBlockingEnabled)
            _appBlockingStartTime = Published(initialValue: saved.appBlockingStartTime ?? Self.defaultAppBlockingStart(from: saved.typicalBedtime))
            _appBlockingEndTime = Published(initialValue: saved.appBlockingEndTime ?? Self.defaultAppBlockingEnd(from: saved.typicalWakeTime))
            _appBlockingGraceMinutes = Published(initialValue: saved.appBlockingGraceMinutes)
            if hasCompletedOnboarding && paywallState.tier == .onboarding {
                paywallState.tier = .awaitingVerdict
                paywallState.verdictRevealed = false
            }

            // Run any pending data migrations once.
            if saved.schemaVersion < 2 {
                DispatchQueue.main.async {
                    self.migrateOrphanedRatings()
                    self.normalizeSleepScoreScale()
                    self.persist()  // saves with new schemaVersion (default = 3)
                }
            } else if saved.schemaVersion < 3 {
                DispatchQueue.main.async {
                    self.normalizeSleepScoreScale()
                    self.persist()  // saves with new schemaVersion (default = 4)
                }
            } else if saved.schemaVersion < 4 {
                DispatchQueue.main.async {
                    self.persist()  // saves with new schemaVersion (default = 4)
                }
            } else if saved.schemaVersion < 5 {
                DispatchQueue.main.async {
                    self.persist()
                }
            } else if saved.schemaVersion < 7 {
                DispatchQueue.main.async {
                    self.persist()
                }
            }

            // Reschedule on every launch so notifications stay current (e.g. after OS clears them)
            DispatchQueue.main.async {
                _ = self.handleTimeZoneChangeIfNeeded()
                self.scheduleAllNotifications()
                self.refreshAppBlockingShield()
            }
        } else {
            _appBlockingStartTime = Published(initialValue: Self.defaultAppBlockingStart(from: typicalBedtime))
            _appBlockingEndTime = Published(initialValue: Self.defaultAppBlockingEnd(from: typicalWakeTime))
        }
    }

    func persist() {
        let snapshot = PersistedState(
            testerName:               testerName,
            selectedSleepProblems:    selectedSleepProblems,
            selectedWakes:            selectedWakes,
            sleepWindowMinutes:       sleepWindowMinutes,
            currentBedtime:           currentBedtime,
            currentWakeTime:          currentWakeTime,
            targetBedtime:            targetBedtime,
            targetWakeTime:           targetWakeTime,
            typicalBedtime:           typicalBedtime,
            typicalWakeTime:          typicalWakeTime,
            selectedPreBedActivities: selectedPreBedActivities,
            selectedTriedThings:      selectedTriedThings,
            coreRoutine:              coreRoutine,
            routineExplanation:       routineExplanation,
            sleepLogs:                sleepLogs,
            chronotype:               chronotype,
            bottleneck:               bottleneck,
            committedRoutineTime:     committedRoutineTime,
            timeZoneIdentifier:       persistedTimeZoneIdentifier,
            paywallState:             paywallState,
            baselineScore:            baselineScore,
            prepDoneIds:              Array(prepDoneIds),
            prepDoneDate:             prepDoneDate,
            ritualDoneIds:            Array(ritualDoneIds),
            ritualDoneDate:           ritualDoneDate,
            pendingPromotion:         pendingPromotion,
            recentlyPromotedRemedyId: recentlyPromotedRemedyId,
            recentlyPromotedAt:       recentlyPromotedAt,
            appBlockingSelectionData: try? JSONEncoder().encode(appBlockingSelection),
            appBlockingEnabled:       appBlockingEnabled,
            appBlockingStartTime:     appBlockingStartTime,
            appBlockingEndTime:       appBlockingEndTime,
            appBlockingGraceMinutes:  appBlockingGraceMinutes
        )
        PersistenceStore.shared.save(snapshot)
    }

    @discardableResult
    func handleTimeZoneChangeIfNeeded() -> Bool {
        let currentTimeZone = TimeZone.autoupdatingCurrent
        guard persistedTimeZoneIdentifier != currentTimeZone.identifier else { return false }

        let previousTimeZone = TimeZone(identifier: persistedTimeZoneIdentifier) ?? currentTimeZone
        currentBedtime = Self.reanchoredWallClockDate(currentBedtime, from: previousTimeZone, to: currentTimeZone)
        currentWakeTime = Self.reanchoredWallClockDate(currentWakeTime, from: previousTimeZone, to: currentTimeZone)
        targetBedtime = Self.reanchoredWallClockDate(targetBedtime, from: previousTimeZone, to: currentTimeZone)
        targetWakeTime = Self.reanchoredWallClockDate(targetWakeTime, from: previousTimeZone, to: currentTimeZone)
        typicalBedtime = Self.reanchoredWallClockDate(typicalBedtime, from: previousTimeZone, to: currentTimeZone)
        typicalWakeTime = Self.reanchoredWallClockDate(typicalWakeTime, from: previousTimeZone, to: currentTimeZone)
        appBlockingStartTime = Self.reanchoredWallClockDate(appBlockingStartTime, from: previousTimeZone, to: currentTimeZone)
        appBlockingEndTime = Self.reanchoredWallClockDate(appBlockingEndTime, from: previousTimeZone, to: currentTimeZone)
        if let routineTime = committedRoutineTime {
            committedRoutineTime = Self.reanchoredWallClockDate(routineTime, from: previousTimeZone, to: currentTimeZone)
        }
        persistedTimeZoneIdentifier = currentTimeZone.identifier
        persist()
        return true
    }

    func sleepWindowWasEdited() {
        committedRoutineTime = nil
        persist()
        scheduleAllNotifications()
        refreshAppBlockingShield()
    }

    func configureAppBlocking(selection: FamilyActivitySelection,
                              enabled: Bool,
                              startTime: Date,
                              endTime: Date,
                              graceMinutes: Int) {
        appBlockingSelection = selection
        appBlockingEnabled = enabled
        appBlockingStartTime = startTime
        appBlockingEndTime = endTime
        appBlockingGraceMinutes = graceMinutes
        persist()
        refreshAppBlockingShield()
    }

    func refreshAppBlockingShield(now: Date = Date()) {
        let hasStep = hasRoutineStep(label: R.appBlocking)
        let hasTargets = !appBlockingSelection.applicationTokens.isEmpty || !appBlockingSelection.categoryTokens.isEmpty
        let shouldApply = hasStep && appBlockingEnabled && hasTargets && isWithinAppBlockingWindow(now: now)

        if shouldApply {
            appBlockingStore.shield.applications = appBlockingSelection.applicationTokens.isEmpty ? nil : appBlockingSelection.applicationTokens
            appBlockingStore.shield.applicationCategories = appBlockingSelection.categoryTokens.isEmpty ? nil : .specific(appBlockingSelection.categoryTokens)
        } else {
            appBlockingStore.clearAllSettings()
        }
    }

    func isWithinAppBlockingWindow(now: Date = Date()) -> Bool {
        let cal = Calendar.current
        let nowMins = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        let startMins = cal.component(.hour, from: appBlockingStartTime) * 60 + cal.component(.minute, from: appBlockingStartTime)
        let endMins = cal.component(.hour, from: appBlockingEndTime) * 60 + cal.component(.minute, from: appBlockingEndTime)

        if startMins == endMins { return true }
        if startMins < endMins {
            return nowMins >= startMins && nowMins < endMins
        }
        return nowMins >= startMins || nowMins < endMins
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
        let routineStep = coreRoutine.first { $0.label == label }
        let attempt = StepAttempt(
            remedyId: routineStep?.remedyId ?? RemedyID.fromLabel(label),
            labelSnapshot: label,
            status: status,
            durationSeconds: durationSeconds
        )
        updateTodayLog { $0.stepAttempts.append(attempt) }
        if status == .completed {
            markRitualDone(label: label)
        }

        let remedyId = attempt.remedyId?.rawValue ?? ""
        let statusEvent = status == .completed ? "routine_step_completed" : "routine_step_skipped"
        trackAnalytics(statusEvent, [
            "remedy_id": remedyId,
            "step_label": label,
            "step_mode": routineStep?.mode.rawValue ?? "",
            "step_index": "\(nightlyStep + 1)",
            "duration_bucket": durationBucket(durationSeconds),
            "tested_remedy_id": tonightRemedyId?.rawValue ?? ""
        ])

        let payload = baseResearchPayload().merging([
            "night_id": .string(currentNightId ?? ""),
            "step_attempt_id": .string(UUID().uuidString),
            "step_index": .int(nightlyStep + 1),
            "step_label": .string(label),
            "remedy_id": .string(remedyId),
            "step_mode": .string(routineStep?.mode.rawValue ?? ""),
            "status": .string(status.rawValue),
            "duration_seconds": researchInt(durationSeconds),
            "tested_remedy_id": .string(tonightRemedyId?.rawValue ?? "")
        ]) { _, new in new }
        submitResearch("routine_step_attempt_recorded", payload: payload)
    }

    @Published var initialTab: Int = 0

    func completeOnboarding() {
        initialTab = 0
        if paywallState.tier == .onboarding {
            paywallState.tier = .awaitingVerdict
            paywallState.verdictRevealed = false
        }
        hasCompletedOnboarding = true
        persist()
        recordOnboardingTelemetry(route: "home")
    }

    func completeOnboardingToRoutine() {
        initialTab = 1
        if paywallState.tier == .onboarding {
            paywallState.tier = .awaitingVerdict
            paywallState.verdictRevealed = false
        }
        hasCompletedOnboarding = true
        persist()
        recordOnboardingTelemetry(route: "routine")
    }

    func completeOnboardingAndStartRitual() {
        initialTab = 0
        requestedTab = 0
        if paywallState.tier == .onboarding {
            paywallState.tier = .awaitingVerdict
            paywallState.verdictRevealed = false
        }
        hasCompletedOnboarding = true
        showNightlyFlow = true
        persist()
        recordOnboardingTelemetry(route: "start_ritual")
    }

    func logMorningScore() {
        let score = Self.clampedSleepScore(morningScore)
        morningScore = score
        let statusBeforeMutation = experimentStatus
        var loggedEntry: SleepLogEntry?

        if let idx = ratableEntryIndex {
            sleepLogs[idx].score            = score
            sleepLogs[idx].variable         = tonightVariable
            sleepLogs[idx].variableRemedyId = tonightRemedyId
            sleepLogs[idx].actualWakeTime   = Date()
            sleepLogs[idx].hoursSlept       = morningHoursSlept
            loggedEntry = sleepLogs[idx]
        } else {
            // No recent unrated entry — create one dated yesterday so the dot
            // lands on "last night," not today.
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            var entry = SleepLogEntry(date: yesterday, variable: tonightVariable, score: score)
            entry.variableRemedyId = tonightRemedyId
            entry.actualWakeTime   = Date()
            entry.hoursSlept       = morningHoursSlept
            sleepLogs.append(entry)
            loggedEntry = entry
        }
        let completedVerdictStatus = experimentStatus
        clearMorningRatingNotifications()
        scheduleMorningRatingNotifications(skipToday: true)
        if shouldTriggerNightFivePaywall(statusBefore: statusBeforeMutation, statusAfter: completedVerdictStatus) {
            activePaywallVerdict = buildVerdictSnapshot(status: completedVerdictStatus)
            paywallState.tier = .paywallPending
            paywallState.verdictRevealed = false
            justTriggeredNightFivePaywall = true
            activePaywallRoute = .nightFive
        } else {
            justTriggeredNightFivePaywall = false
        }
        advanceExperiment()
        persist()
        if let loggedEntry {
            recordMorningTelemetry(entry: loggedEntry)
        }
    }

    private func shouldTriggerNightFivePaywall(statusBefore: ExperimentEngine.Status?,
                                               statusAfter: ExperimentEngine.Status?) -> Bool {
        guard paywallState.tier == .awaitingVerdict || paywallState.tier == .paywallPending else { return false }
        guard paywallState.verdictRevealed == false else { return false }
        guard let statusAfter, statusAfter.night >= 5 else { return false }
        return (statusBefore?.night ?? 0) < 5
    }

    func unlockVerdict(method: UnlockMethod) {
        paywallState.unlockMethod = method
        paywallState.verdictRevealed = true
        switch method {
        case .subscribe:
            paywallState.tier = .subscribed
        case .share:
            paywallState.tier = .shareUnlocked
        }
        persist()
    }

    func applyRevenueCatEntitlement(isActive: Bool) {
        if isActive {
            paywallState.tier = .subscribed
            paywallState.verdictRevealed = true
        } else if paywallState.tier == .subscribed {
            paywallState.tier = .paywallPending
            paywallState.unlockMethod = nil
            paywallState.verdictRevealed = false
        }
        persist()
    }

    func markFreeForever() {
        paywallState.tier = .freeForever
        paywallState.verdictRevealed = false
        paywallState.unlockMethod = nil
        persist()
    }

    var loggedNightCount: Int {
        sleepLogs.filter { $0.score > 0 }.count
    }

    var shouldPresentDay14Prompt: Bool {
        guard paywallState.tier == .freeForever else { return false }
        guard paywallState.dismissalCount < 3 else { return false }
        guard loggedNightCount >= 14 else { return false }
        if let last = paywallState.lastDismissalAt,
           let cooldownEnd = Calendar.current.date(byAdding: .day, value: 30, to: last),
           Date() < cooldownEnd {
            return false
        }
        return true
    }

    func dismissDay14Prompt() {
        paywallState.dismissalCount += 1
        paywallState.lastDismissalAt = Date()
        persist()
    }

    func seedDay14Verdict() {
        activePaywallVerdict = buildVerdictSnapshotFromRecentLogs()
        paywallState.tier = .paywallPending
        paywallState.verdictRevealed = false
        persist()
    }

    func buildVerdictSnapshotFromRecentLogs() -> PaywallVerdict {
        buildVerdictSnapshot(status: experimentStatus)
    }

    private func buildVerdictSnapshot(status: ExperimentEngine.Status?) -> PaywallVerdict {
        let variable = status?.variable ?? tonightVariable
        let delta = status?.scoreDelta ?? recentFiveDelta()
        let outcome: PaywallOutcome = {
            if delta > 0.3 { return .positive }
            if delta < -0.15 { return .negative }
            return .neutral
        }()
        let deltaText = status?.scoreDeltaString ?? String(format: "%@%.1f", delta >= 0 ? "+" : "-", abs(delta))
        let sentence: String = {
            switch outcome {
            case .positive:
                return "\(variable) improved your sleep score across the test window."
            case .neutral:
                return "\(variable) landed close to your baseline across the test window."
            case .negative:
                return "\(variable) did not improve your sleep score across the test window."
            }
        }()
        return PaywallVerdict(
            diagnosis: bottleneck.displayName,
            confirmation: "Confirmed across 5 nights",
            experiment: "\(variable) · \(experimentDurationLabel(for: variable)) before bed",
            chronotype: chronotype,
            scoreDelta: deltaText,
            outcome: outcome,
            verdictSentence: sentence,
            research: researchLine(for: variable),
            recommendation: nextRecommendation(after: status, outcome: outcome),
            nightsLogged: loggedNightCount,
            sparklineScores: sleepLogs.filter { $0.score > 0 }.sorted { $0.date < $1.date }.suffix(14).map(\.score)
        )
    }

    private func recentFiveDelta() -> Double {
        let rated = sleepLogs.filter { $0.score > 0 }.sorted { $0.date < $1.date }
        let recent = rated.suffix(5)
        let earlier = rated.dropLast(min(5, rated.count))
        guard !recent.isEmpty, !earlier.isEmpty else { return 0 }
        let recentAvg = Double(recent.map(\.score).reduce(0, +)) / Double(recent.count)
        let earlierAvg = Double(earlier.map(\.score).reduce(0, +)) / Double(earlier.count)
        return recentAvg - earlierAvg
    }

    private func experimentDurationLabel(for variable: String) -> String {
        switch variable {
        case R.brainDump: return "12 min"
        case R.breathing478: return "5 min"
        case R.boringStory: return "20 min"
        default: return "10 min"
        }
    }

    private func researchLine(for variable: String) -> String {
        switch variable {
        case R.brainDump:
            return "Writing down unfinished thoughts before bed can reduce cognitive arousal and make the next step easier to choose."
        case R.breathing478:
            return "Extended exhalation patterns are used to shift the nervous system toward a calmer pre-sleep state."
        case R.dimTheLights:
            return "Lower evening light exposure helps protect the body's melatonin signal and supports a steadier bedtime rhythm."
        default:
            return "The useful signal is not whether a technique sounds right. It is whether your own five-night data moved."
        }
    }

    private func nextRecommendation(after status: ExperimentEngine.Status?, outcome: PaywallOutcome) -> String {
        if outcome == .positive {
            return "Keep \(status?.variable ?? tonightVariable) in tonight's wind-down and start the next experiment after one steady night."
        }
        if let next = status?.nextCandidate {
            return "Move on to \(next) tonight. Your last five nights are enough to stop guessing."
        }
        return "Keep the routine steady tonight and collect one more clean morning rating before changing the variable."
    }

    func movePreWindDown(from source: IndexSet, to destination: Int) {
        var section = preWindDownSteps
        section.move(fromOffsets: source, toOffset: destination)
        coreRoutine = section + windDownSteps
        normalizeRoutineOrder()
        logRoutineUpdated(kind: "reorder", stepID: section.first?.id)
        persist()
    }

    func moveWindDown(from source: IndexSet, to destination: Int) {
        var section = windDownSteps
        section.move(fromOffsets: source, toOffset: destination)
        coreRoutine = preWindDownSteps + section
        normalizeRoutineOrder()
        logRoutineUpdated(kind: "reorder", stepID: section.first?.id)
        persist()
    }

    func moveRoutineStep(_ moving: RoutineStep, before target: RoutineStep, in sectionKind: RoutineSectionKind) {
        var section = sectionKind == .prep ? routinePrepSteps : routineRitualSteps
        guard let from = section.firstIndex(where: { $0.id == moving.id }),
              let to = section.firstIndex(where: { $0.id == target.id }),
              from != to else { return }

        section.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)

        switch sectionKind {
        case .prep:
            coreRoutine = section + routineRitualSteps
        case .ritual:
            coreRoutine = routinePrepSteps + section
        case .morning:
            return
        }

        normalizeRoutineOrder()
        logRoutineUpdated(kind: "reorder", stepID: moving.id)
        persist()
    }

    @discardableResult
    func addRoutineStep(from item: RoutineLibraryStep) -> RoutineStep {
        let mode: RoutineMode = item.defaultSection == .ritual ? .inSequence : .reminderOnly
        var step = RoutineStep(
            order: coreRoutine.count + 1,
            label: item.label,
            mode: mode,
            leadTimeMins: item.defaultWhen,
            durationLabel: item.defaultDur,
            notes: nil,
            repeatCadence: "every",
            notifyEnabled: true,
            remedyId: RemedyID.fromLabel(item.label)
        )
        if item.id == "blanket" {
            step.remedyId = .weightedBlanket
        }
        if item.id == "sleep-sounds" {
            step.sleepSoundConfig = .fresh
            step.durationLabel = SleepSoundStepConfig.fresh.durationSummary
            step.remedyId = .sleepSounds
        }

        switch item.defaultSection {
        case .prep:
            coreRoutine = routinePrepSteps + [step] + routineRitualSteps
        case .ritual:
            coreRoutine = routinePrepSteps + routineRitualSteps + [step]
        case .morning:
            return step
        }
        normalizeRoutineOrder()
        logRoutineUpdated(kind: "add", stepID: step.id)
        persist()
        scheduleBedtimePrepNotifications()
        return step
    }

    func updateRoutineStep(_ updated: RoutineStep) {
        guard let idx = coreRoutine.firstIndex(where: { $0.id == updated.id }) else { return }
        let previous = coreRoutine[idx]
        if previous.label != updated.label {
            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: ["bedtime_prep_\(previous.label)"]
            )
        }
        coreRoutine[idx] = updated
        normalizeRoutineOrder()
        logRoutineUpdated(kind: "edit", stepID: updated.id)
        persist()
        scheduleBedtimePrepNotifications()
    }

    func removeRoutineStep(_ step: RoutineStep) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["bedtime_prep_\(step.label)"]
        )
        coreRoutine.removeAll { $0.id == step.id }
        normalizeRoutineOrder()
        if step.mode == .experiment {
            print("[Analytics] experiment_aborted step_id=\(step.id.uuidString) label=\"\(step.label)\"")
        }
        logRoutineUpdated(kind: "remove", stepID: step.id)
        persist()
        scheduleBedtimePrepNotifications()
    }

    func hasRoutineStep(label: String) -> Bool {
        coreRoutine.contains { $0.label.caseInsensitiveCompare(label) == .orderedSame }
    }

    func sectionKind(for step: RoutineStep) -> RoutineSectionKind {
        isPrepRoutineStep(step) ? .prep : .ritual
    }

    private func normalizeRoutineOrder() {
        for idx in coreRoutine.indices {
            coreRoutine[idx].order = idx + 1
        }
    }

    private func logRoutineUpdated(kind: String, stepID: UUID?) {
        print("[Analytics] routine_updated kind=\(kind) step_id=\(stepID?.uuidString ?? "unknown")")
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
        content.interruptionLevel = .timeSensitive
        content.relevanceScore = 1.0

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
            let leadMins = step.resolvedLeadTimeMins
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

    var expectedRitualStartAt: Date {
        let cal = Calendar.current
        return committedRoutineTime
            ?? cal.date(byAdding: .minute, value: -windDownDurationMinutes, to: typicalBedtime)
            ?? typicalBedtime
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

        if let primaryFire = committedRoutineTime ?? cal.date(byAdding: .minute, value: -duration, to: typicalBedtime) {
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
           let followupFire = cal.date(byAdding: .minute, value: followupGap, to: committedRoutineTime ?? (cal.date(byAdding: .minute, value: -duration, to: typicalBedtime) ?? typicalBedtime)) {
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

    func clearMorningRatingNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: Self.morningRatingNotificationIdentifiers)
        center.removeDeliveredNotifications(withIdentifiers: Self.morningRatingNotificationIdentifiers)
    }

    func scheduleMorningRatingNotifications(skipToday: Bool = false) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: Self.morningRatingNotificationIdentifiers)

        // Keep this scheduled even when Live Activities are enabled. A sleep
        // Live Activity can be removed by iOS before morning on longer sleep
        // windows, so the notification is the reliability fallback.

        let cal = Calendar.current
        let now = Date()
        let wakeComps = cal.dateComponents([.hour, .minute], from: typicalWakeTime)
        let startOffset = skipToday ? 1 : 0
        let dayOffsets = Array(startOffset..<(startOffset + 14))

        for (slot, dayOffset) in dayOffsets.enumerated() {
            guard let targetDay = cal.date(byAdding: .day, value: dayOffset, to: cal.startOfDay(for: now)),
                  let wakeAnchor = cal.date(bySettingHour: wakeComps.hour ?? 7,
                                            minute: wakeComps.minute ?? 0,
                                            second: 0,
                                            of: targetDay),
                  let primaryFire = cal.date(byAdding: .minute, value: 30, to: wakeAnchor)
            else { continue }

            if primaryFire > now {
                let content = UNMutableNotificationContent()
                content.title = "How did you sleep?"
                content.body = "Take 5 seconds to rate last night. It helps Lull improve your routine."
                content.sound = .default
                content.categoryIdentifier = "MORNING_CHECKIN"
                content.interruptionLevel = .timeSensitive
                content.relevanceScore = 1.0

                var comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: primaryFire)
                comps.second = 0

                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let request = UNNotificationRequest(identifier: "morning_rating_primary_\(slot)", content: content, trigger: trigger)
                center.add(request)
            }

            if let noonFire = cal.date(bySettingHour: 12, minute: 0, second: 0, of: targetDay),
               noonFire > now {
                let noonContent = UNMutableNotificationContent()
                noonContent.title = "Still time to log your sleep"
                noonContent.body = "A quick rating helps track what's working for you."
                noonContent.sound = .default
                noonContent.categoryIdentifier = "MORNING_CHECKIN"
                noonContent.interruptionLevel = .timeSensitive
                noonContent.relevanceScore = 1.0

                var noonComps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: noonFire)
                noonComps.second = 0

                let noonTrigger = UNCalendarNotificationTrigger(dateMatching: noonComps, repeats: false)
                let noonRequest = UNNotificationRequest(identifier: "morning_rating_noon_\(slot)", content: noonContent, trigger: noonTrigger)
                center.add(noonRequest)
            }
        }
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
        // A full schedule rebuild should not leave any prior sleep-window
        // requests behind, especially dynamic "bedtime_prep_<label>" IDs.
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
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
            !isPrepRoutineStep($0) &&
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
            .filter { isPrepRoutineStep($0) }
            .map { step in
                let mins = step.resolvedLeadTimeMins
                let time = cal.date(byAdding: .minute, value: -mins, to: bed) ?? bed
                let badge = step.mode == .experiment ? "\(mins) min before bed" : "Reminder · \(mins) min before bed"
                return ScheduledStep(step: step, time: time, badge: badge)
            }

        return (prepSteps + seqSteps).sorted { $0.time < $1.time }
    }

    var preWindDownSteps: [RoutineStep] {
        routinePrepSteps
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

    var routinePrepSteps: [RoutineStep] {
        coreRoutine.filter { isPrepRoutineStep($0) }
    }

    var routineRitualSteps: [RoutineStep] {
        coreRoutine.filter { !isPrepRoutineStep($0) }
    }

    private func isPrepRoutineStep(_ step: RoutineStep) -> Bool {
        step.mode == .reminderOnly ||
        step.leadTimeMins != nil ||
        (step.mode == .experiment && step.label == R.weightedBlanket) ||
        (step.mode == .experiment && !allWindDownRemedies.contains(step.label))
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
        let mins = Self.clockDurationMinutes(from: typicalBedtime, to: typicalWakeTime)
        let h = mins / 60
        let m = mins % 60
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
    var leadTimeMins: Int? = nil
    var durationLabel: String? = nil
    var notes: String? = nil
    var repeatCadence: String? = nil
    var notifyEnabled: Bool? = nil
    var remedyId: RemedyID? = nil
    var sleepSoundConfig: SleepSoundStepConfig? = nil
}

extension RoutineStep {
    var resolvedLeadTimeMins: Int {
        leadTimeMins ?? AppState.prepLeadTimes[label] ?? 90
    }
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
    var actualRitualStart: Date? = nil     // when nightly flow opened
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
