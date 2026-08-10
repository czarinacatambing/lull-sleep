import SwiftUI
import Combine
import UserNotifications
import ActivityKit
import DeviceActivity
import FamilyControls
import ManagedSettings
import PostHog

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

struct StreakSummary {
    var completedNights: Int
    var expectedNights: Int
    var completionRate: Int
    var last13: [StreakNight]
    var nextCount: Int { completedNights + 1 }
}

struct StreakNight: Identifiable, Equatable {
    enum State: Equatable { case completed, missed, tonight, future }

    var id: Date { date }
    let date: Date
    let state: State
}

struct StreakMilestonePresentation: Identifiable, Equatable {
    var id: Int { day }

    let day: Int
    let headlineRate: Int
    let headlineLabel: String
    let secondaryRate: Int?
    let secondaryLabel: String?
    let averageSleepScore: Double?
    let showsConfetti: Bool
}

enum SleepThief: String, Codable, CaseIterable, Identifiable {
    case scrolling
    case racingMind
    case bedtimeDelay
    case nightPhone
    case inconsistentNights

    var id: String { rawValue }

    var title: String {
        switch self {
        case .scrolling: return "I get stuck scrolling"
        case .racingMind: return "My brain won't shut off"
        case .bedtimeDelay: return "I keep delaying bedtime"
        case .nightPhone: return "I wake up and grab my phone"
        case .inconsistentNights: return "My nights are inconsistent"
        }
    }

    var analyticsValue: String { rawValue }
}

enum SleepRuleKind: String, Codable, CaseIterable, Identifiable {
    case morningSun
    case caffeineCutoff
    case workoutCutoff
    case warmShower
    case dimLights
    case tomorrowsPlan
    case gratitudeJournal
    case inBed

    var id: String { rawValue }

    static var editableCases: [SleepRuleKind] {
        allCases.filter { $0 != .inBed }
    }

    var title: String {
        switch self {
        case .morningSun: return "Morning sun"
        case .caffeineCutoff: return "Caffeine cutoff"
        case .workoutCutoff: return "Workout cutoff"
        case .warmShower: return "Warm shower or bath"
        case .dimLights: return "Dim lights"
        case .tomorrowsPlan: return "Tomorrow's plan"
        case .gratitudeJournal: return "Gratitude journal"
        case .inBed: return "Ready for sleep"
        }
    }

    var detail: String {
        switch self {
        case .morningSun: return "Get outdoor light anytime this morning."
        case .caffeineCutoff: return "Confirm you're done with caffeine for today."
        case .workoutCutoff: return "Confirm you're done with workouts for today."
        case .warmShower: return "Take a warm shower or bath before bed."
        case .dimLights: return "Lower lights before your sleepy signal gets crowded out."
        case .tomorrowsPlan: return "Write tomorrow's plan so your brain can stop rehearsing."
        case .gratitudeJournal: return "Write one thing that made the day feel safe or worthwhile."
        case .inBed: return "Confirm you're ready for sleep to earn tonight's firefly."
        }
    }

    var graceMinutes: Int {
        switch self {
        case .morningSun: return 30
        case .caffeineCutoff, .workoutCutoff: return 15
        case .warmShower, .dimLights: return 10
        case .tomorrowsPlan, .gratitudeJournal: return 5
        case .inBed: return 0
        }
    }

    var leadMinutesBeforeBed: Int? {
        switch self {
        case .morningSun: return nil
        case .caffeineCutoff: return 360
        case .workoutCutoff: return 180
        case .warmShower: return 90
        case .dimLights: return 75
        case .tomorrowsPlan: return 30
        case .gratitudeJournal: return 15
        case .inBed: return 0
        }
    }

    var isPreBedRule: Bool {
        self != .inBed && leadMinutesBeforeBed != nil
    }

    var isWakeSideRule: Bool {
        self != .inBed && !isPreBedRule
    }

    var completionPrompt: String {
        switch self {
        case .caffeineCutoff: return "Done with caffeine for today?"
        case .workoutCutoff: return "Done with workouts for today?"
        case .morningSun: return "Mark morning sun done"
        case .warmShower: return "Mark shower done"
        case .dimLights: return "Mark lights dimmed"
        case .tomorrowsPlan: return "Mark tomorrow's plan done"
        case .gratitudeJournal: return "Mark gratitude journal done"
        case .inBed: return "Confirm ready for sleep"
        }
    }
}

/// Default morning-sun window when the user has not customized it yet.
enum MorningSunWindowDefaults {
    static let startHour = 6
    static let startMinute = 0
    static let endHour = 12
    static let endMinute = 0

    static func start(on date: Date, calendar: Calendar = .autoupdatingCurrent) -> Date {
        calendar.date(
            bySettingHour: startHour,
            minute: startMinute,
            second: 0,
            of: date
        ) ?? date
    }

    static func end(on date: Date, calendar: Calendar = .autoupdatingCurrent) -> Date {
        calendar.date(
            bySettingHour: endHour,
            minute: endMinute,
            second: 0,
            of: date
        ) ?? date
    }
}

struct SleepRuleCompletion: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    let rule: SleepRuleKind
    let dueAt: Date
    var completedAt: Date
    var completedWithinGrace: Bool
}

struct SleepRuleSlip: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    let rule: SleepRuleKind
    let dueAt: Date
    var slippedAt: Date
}

struct SleepRuleConfiguration: Codable, Equatable {
    var availableTime: Date?
    var dueTime: Date?
    var graceMinutes: Int?
}

struct SleepContractItem: Identifiable, Equatable {
    var id: String { "\(rule.rawValue)-\(Int(dueAt.timeIntervalSince1970))" }
    let rule: SleepRuleKind
    let availableAt: Date
    let dueAt: Date
    let graceEndsAt: Date
    let startsTomorrow: Bool
    let completion: SleepRuleCompletion?
    let slip: SleepRuleSlip?

    var isCompleted: Bool { completion != nil }
    var isSlipped: Bool { slip != nil }
    var isResolved: Bool { isCompleted || isSlipped }
    var isRange: Bool {
        !Calendar.current.isDate(availableAt, equalTo: dueAt, toGranularity: .minute)
    }
    var isLateCompletion: Bool {
        guard let completion else { return false }
        return completion.completedAt > graceEndsAt
    }
}

struct ContractLockEvent: Codable, Identifiable, Equatable {
    enum Kind: String, Codable {
        case rule
        case sleepWindow
    }

    var id: UUID = UUID()
    let kind: Kind
    let rule: SleepRuleKind?
    let occurredAt: Date
}

struct ContractAllClearEvent: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    let contractDay: Date
    let occurredAt: Date
}

enum EmergencyAppAccessReason: String, CaseIterable, Codable, Identifiable {
    case work
    case family
    case health
    case travel
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .work: return "Work"
        case .family: return "Family"
        case .health: return "Health"
        case .travel: return "Travel"
        case .other: return "Other"
        }
    }
}

enum EmergencyAppAccessDuration: Int, CaseIterable, Codable, Identifiable {
    case five = 5
    case fifteen = 15
    case thirty = 30

    var id: Int { rawValue }
    var title: String { "\(rawValue) min" }
    var timeInterval: TimeInterval { TimeInterval(rawValue * 60) }
}

struct EmergencyAppAccessSession: Codable, Equatable {
    let reason: EmergencyAppAccessReason
    let duration: EmergencyAppAccessDuration
    let startedAt: Date
    let endsAt: Date
}

struct SleepContractEnforcementSnapshot: Equatable {
    enum LockState: Equatable {
        case unlocked
        case lockedByRule(SleepContractItem)
        case coolingDown(SleepContractItem, until: Date)
        case sleepWindow(until: Date)
    }

    let now: Date
    let lockState: LockState
    let actionableItems: [SleepContractItem]
    let allItems: [SleepContractItem]

    var isLocked: Bool {
        switch lockState {
        case .lockedByRule, .coolingDown, .sleepWindow:
            return true
        case .unlocked:
            return false
        }
    }

    var isSleepWindow: Bool {
        if case .sleepWindow = lockState { return true }
        return false
    }
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
    private static let firstNightReviewRequestKey = "tenthirtyFirstNightReviewRequestQueued"
    private static let firstNightReviewRequestAttemptedKey = "tenthirtyFirstNightReviewRequestAttempted"

    static let maxSleepScore = 5
    private static let obsoleteNotificationIdentifiers =
        ["morning_rating_primary", "morning_rating_noon"] +
        (0..<14).flatMap { ["morning_rating_primary_\($0)", "morning_rating_noon_\($0)"] } +
        ["mid_sleep_check", "get_up_return"]
    private static let appGroupSuite = "group.com.trylull.app"
    private static let shieldWakeTimeTextKey = "tenthirty_shieldWakeTimeText"
    private static let shieldLockReasonKey = "tenthirty_shieldLockReason"
    private static let shieldRuleTitleKey = "tenthirty_shieldRuleTitle"
    private static let emergencyAppAccessUntilKey = "tenthirty_emergencyAppAccessUntil"
    private static let gentleBypassUntilKey = "tenthirty_gentleBypassUntil"
    private static let missedHabitCooldownMinutes = 10
    private let appBlockingStore = ManagedSettingsStore()
    private let deviceActivityCenter = DeviceActivityCenter()
    private var appBlockingRefreshWorkItem: DispatchWorkItem?
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
    @AppStorage("hasSeenFirstFireflyPrompt") var hasSeenFirstFireflyPrompt = false
    @Published var pendingOnboardingFireflyHandoff = false

    var isOnboardingFireflyCompanionActive: Bool {
        true
    }

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
    @Published var sleepThief: SleepThief? = nil
    @Published var sleepContractActivatedAt: Date? = nil
    @Published var selectedSleepRules: Set<SleepRuleKind> = []
    @Published var sleepRuleConfigurations: [SleepRuleKind: SleepRuleConfiguration] = [:]
    @Published var sleepRuleCompletions: [SleepRuleCompletion] = []
    @Published var sleepRuleSlips: [SleepRuleSlip] = []
    @Published var contractLockEvents: [ContractLockEvent] = []
    @Published var contractAllClearEvents: [ContractAllClearEvent] = []
    #if DEBUG
    @Published var uiTestHoldConfirmFixtureActive = false
    #endif
    @Published var paywallState = PaywallState()
    @Published var activePaywallRoute: PaywallRoute? = nil
    @Published var activePaywallVerdict: PaywallVerdict? = nil
    @Published var activeRevenueCatPaywall: RevenueCatPaywallContext? = nil
    @Published var activeStreakMilestone: StreakMilestonePresentation? = nil

    var hasActiveSleepContract: Bool {
        sleepContractActivatedAt != nil && !selectedSleepRules.subtracting([.inBed]).isEmpty
    }

    // MARK: - Home / Dashboard
    @Published var showNightlyFlow = false
    @Published var showSleepSounds = false
    @Published var showMorningCheckIn = false
    @Published var appBlockingSelection = FamilyActivitySelection()
    @Published var appBlockingEnabled = false
    @Published var appBlockingStartTime: Date = Date()
    @Published var appBlockingEndTime: Date = Date()
    @Published var appBlockingGraceMinutes = 5
    @Published var emergencyAppAccessSession: EmergencyAppAccessSession? = nil

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

    var isTrialActive: Bool {
        paywallState.isTrialActive()
    }

    var isPaidPremium: Bool {
        paywallState.tier == .subscribed
    }

    var hasPremiumAccess: Bool {
        isPaidPremium || isTrialActive
    }

    var isFreeAccess: Bool {
        !hasPremiumAccess
    }

    var canCustomizeRoutine: Bool {
        hasPremiumAccess
    }

    var canUseSleepSounds: Bool {
        hasPremiumAccess
    }

    var canUseContentLibrary: Bool {
        hasPremiumAccess
    }

    var canUseHardAppBlocking: Bool {
        hasPremiumAccess
    }

    var canUseReassessment: Bool {
        hasPremiumAccess
    }

    var trialDaysRemainingText: String? {
        guard isTrialActive, let end = paywallState.trialEndsAt else { return nil }
        let seconds = max(0, end.timeIntervalSince(Date()))
        let days = max(1, Int(ceil(seconds / (24 * 60 * 60))))
        return "\(days)d trial left"
    }

    @Published var coreRoutine: [RoutineStep] = [
        RoutineStep(order: 1, label: R.dimTheLights,       mode: .reminderOnly, leadTimeMins: 75, remedyId: .dimTheLights),
        RoutineStep(order: 2, label: R.noScreens,          mode: .reminderOnly, leadTimeMins: 75, remedyId: .noScreens),
        RoutineStep(order: 3, label: R.weightedBlanket,    mode: .reminderOnly, leadTimeMins: 90, remedyId: .weightedBlanket),
        RoutineStep(order: 4, label: "Brightness check",   mode: .inSequence, durationLabel: "10s"),
        RoutineStep(order: 5, label: "Temperature check",  mode: .inSequence, durationLabel: "10s"),
        RoutineStep(order: 6, label: R.brainDump,          mode: .inSequence, durationLabel: "2m · voice", remedyId: .brainDump),
        RoutineStep(order: 7, label: R.boringStory,        mode: .inSequence, durationLabel: BoringStoryStepConfig.fresh.durationSummary, remedyId: .boringStory),
    ]

    // MARK: - Generated routine (set during onboarding)
    @Published var generatedRoutine: GeneratedRoutine? = nil
    @Published var routineExplanation: String = ""
    @Published var routineShouldStartNow: Bool = false
    @Published var generatedRoutineRemedyIds: [RemedyID] = []
    @Published var routineIntroOrder: [RemedyID] = []
    @Published var routineBacklog: [RemedyID] = []
    @Published var routineReinforcedRemedyIds: [RemedyID] = []
    @Published var showHealthScreening: Bool = false

    func applyGeneratedRoutine(_ routine: GeneratedRoutine, scheduleNotifications: Bool = true) {
        generatedRoutine      = routine
        coreRoutine           = routine.toCoreRoutineSteps()
        convertExperimentStepsToHabits()
        routineExplanation    = routine.explanation
        routineShouldStartNow = shouldOfferImmediateOnboardingRitual
        generatedRoutineRemedyIds = routine.remedyIds
        routineIntroOrder = routine.introOrder
        routineBacklog = routine.backlog
        routineReinforcedRemedyIds = routine.reinforcedRemedyIds
        showHealthScreening = routine.showHealthScreening
        if paywallState.originalGeneratedRoutine == nil {
            paywallState.originalGeneratedRoutine = coreRoutine
        }
        paywallState.lastReassessmentAt = Date()
        persist()
        if scheduleNotifications {
            scheduleAllNotifications()
        }
    }

    private func startTrialIfNeeded() {
        guard !paywallState.trialHasStarted else { return }
        let now = Date()
        paywallState.tier = .trial
        paywallState.trialStartedAt = now
        paywallState.trialEndsAt = Calendar.current.date(byAdding: .day, value: 7, to: now)
        paywallState.trialExpiredAt = nil
        paywallState.verdictRevealed = true
        paywallState.originalGeneratedRoutine = paywallState.originalGeneratedRoutine ?? coreRoutine
        paywallState.lastReassessmentAt = paywallState.lastReassessmentAt ?? now
        trackAnalytics("local_trial_started", [
            "trial_days": "7",
            "routine_step_count": "\(coreRoutine.count)"
        ])
    }

    func evaluateTrialStatus() {
        if isTrialActive {
            if paywallState.tier != .trial && paywallState.tier != .subscribed {
                paywallState.tier = .trial
                paywallState.trialExpiredAt = nil
                paywallState.verdictRevealed = true
                restorePremiumRoutineIfAvailable()
                persist()
                scheduleAllNotifications()
                refreshAppBlockingShield()
            }
            return
        }
        guard paywallState.tier == .trial else { return }
        expireTrialAndPresentPaywall()
    }

    func presentUpgradePaywall() {
        trackAnalytics("upgrade_paywall_requested", [
            "logged_night_count": "\(loggedNightCount)"
        ])
        activeRevenueCatPaywall = .upgrade
    }

    func handleRevenueCatPaywallDismissed(isSubscribed: Bool) {
        let context = activeRevenueCatPaywall
        trackAnalytics("revenuecat_paywall_dismissed", [
            "context": context?.rawValue ?? "",
            "is_subscribed": isSubscribed ? "true" : "false",
            "logged_night_count": "\(loggedNightCount)"
        ])
        activeRevenueCatPaywall = nil
        if isSubscribed {
            presentPendingStreakMilestoneIfEligible()
            return
        }
        if isTrialActive {
            if paywallState.tier != .trial {
                paywallState.tier = .trial
                paywallState.trialExpiredAt = nil
                paywallState.verdictRevealed = true
                persist()
            }
            presentPendingStreakMilestoneIfEligible()
            return
        }
        guard context == .trialExpired else { return }
        completeTrialDowngrade()
    }

    func expireTrialAndPresentPaywall() {
        guard paywallState.tier == .trial else { return }
        guard !isTrialActive else {
            paywallState.trialExpiredAt = nil
            persist()
            return
        }
        paywallState.trialExpiredAt = paywallState.trialExpiredAt ?? Date()
        markSubscriptionRequired(reason: "local_trial_expired")
    }

    func handleSubscriptionLapsed() {
        guard hasCompletedOnboarding else { return }
        guard !hasPremiumAccess else { return }
        refreshAppBlockingShield()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        clearObsoleteNotifications()
        LiveActivityService.shared.end(dismissalPolicy: .immediate)
    }

    private func markSubscriptionRequired(reason: String) {
        paywallState.trialExpiredAt = paywallState.trialExpiredAt ?? Date()
        activeRevenueCatPaywall = .trialExpired
        handleSubscriptionLapsed()
        trackAnalytics("trial_expired_paywall_presented", [
            "reason": reason,
            "logged_night_count": "\(loggedNightCount)",
            "routine_step_count": "\(coreRoutine.count)"
        ])
        persist()
    }

    private func completeTrialDowngrade() {
        guard paywallState.tier != .subscribed else { return }
        guard !isTrialActive else {
            paywallState.tier = .trial
            paywallState.trialExpiredAt = nil
            paywallState.verdictRevealed = true
            persist()
            return
        }
        if paywallState.trialCustomizedRoutine == nil {
            paywallState.trialCustomizedRoutine = coreRoutine
        }
        paywallState.tier = .free
        paywallState.verdictRevealed = false
        restoreFreeRoutine()
        persist()
        handleSubscriptionLapsed()
    }

    private func restoreFreeRoutine() {
        let source = paywallState.originalGeneratedRoutine ?? coreRoutine
        coreRoutine = source.filter { !Self.isPremiumOnlyRoutineStep($0) }
        convertExperimentStepsToHabits()
        normalizeRoutineOrder()
    }

    private static func isPremiumOnlyRoutineStep(_ step: RoutineStep) -> Bool {
        step.label == R.sleepSounds
            || step.remedyId == .sleepSounds
            || step.label == R.boringStory
            || step.remedyId == .boringStory
            || step.label == R.bodyScan
            || step.remedyId == .bodyScan
    }

    private func captureTrialRoutineEdit() {
        guard isTrialActive else { return }
        paywallState.trialCustomizedRoutine = coreRoutine
    }

    private func restorePremiumRoutineIfAvailable() {
        guard let saved = paywallState.trialCustomizedRoutine else { return }
        coreRoutine = saved
        convertExperimentStepsToHabits()
        normalizeRoutineOrder()
    }

    func convertExperimentStepsToHabits() {
        var changed = false
        for idx in coreRoutine.indices where coreRoutine[idx].mode == .experiment {
            coreRoutine[idx].mode = isPrepRoutineStep(coreRoutine[idx]) ? .reminderOnly : .inSequence
            changed = true
        }
        if changed {
            normalizeRoutineOrder()
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

    var firstBedtimePrepDueTime: Date {
        let cal = Calendar.current
        let prepDueTimes = routinePrepSteps.map { step in
            cal.date(byAdding: .minute, value: -step.resolvedLeadTimeMins, to: typicalBedtime) ?? typicalBedtime
        }
        return prepDueTimes.min() ?? defaultRoutineStartTime
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
    @Published var prepCompletionAnimationRequest: UUID? = nil
    var suppressPrepLiveActivityForSession = false

    func refreshPrepLiveActivityIfEligible() {
        LiveActivityService.shared.end(dismissalPolicy: .immediate)
    }

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
        prepCompletionAnimationRequest = id
        LiveActivityService.shared.update(doneIds: prepDoneIds)
        if prepDoneIds.count == preWindDownSteps.count {
            LiveActivityService.shared.end(dismissalPolicy: .after(.now + 30))
        }
    }

    func togglePrepFromLiveActivity(_ id: UUID) {
        let wasDone = prepDoneIds.contains(id)
        togglePrepDone(id)
        requestedTab = 0
        if !wasDone, prepDoneIds.contains(id) {
            prepCompletionAnimationRequest = id
        }
    }

    func clearPrepCompletionAnimationRequest(_ id: UUID) {
        if prepCompletionAnimationRequest == id {
            prepCompletionAnimationRequest = nil
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
        let baselineCaptured   = baselineScore

        morningScore = rating
        logMorningScore()

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

    func shouldRouteLiveActivityTapToMorning(now: Date = Date()) -> Bool {
        now >= nextWakeTimeOrTodayWake()
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
    @Published var shouldRequestReviewAfterFirstNight = UserDefaults.standard.bool(forKey: AppState.firstNightReviewRequestKey)

    // MARK: - Promotion celebration
    // Set when an experimental variable graduates into the core routine; cleared
    // when the user dismisses the big celebration screen. Persisted so it survives
    // a relaunch if the user logs the rating and quits before seeing the modal.
    @Published var pendingPromotion: PendingPromotion? = nil

    // Set after acknowledging a promotion — drives the "Recently promoted" pill
    // on the routine list for 7 days. Persisted.
    @Published var recentlyPromotedRemedyId: RemedyID? = nil
    @Published var recentlyPromotedAt: Date? = nil

    // Streak milestones are earned at night, then presented the next morning
    // after rating or once the morning check-in window has passed.
    @Published var pendingStreakMilestoneDay: Int? = nil
    @Published var acknowledgedStreakMilestoneDays: Set<Int> = []
    @Published var streakMilestonePaywallPromptedDays: Set<Int> = []

    // Transient (not persisted) — triggers a brief amber pulse on the routine
    // list item right after the big celebration dismisses.
    @Published var routinePulseRemedyId: RemedyID? = nil

    // Transient — when set, HomeTabView snaps to this tab index, then clears.
    // Used by acknowledgePromotion() to route the user to the Routine tab.
    @Published var requestedTab: Int? = nil
    @Published var requestedRoutineStepIDToEdit: UUID? = nil

    @Published var justTriggeredNightFivePaywall: Bool = false

    #if DEBUG
    // Debug-only time-of-day override for testing the Today tab without changing
    // the simulator clock or sleep window. Mutually exclusive.
    @Published var debugForceMorningState: Bool = false
    @Published var debugForceEveningState: Bool = false

    func debugClearTodaysRating() {
        let cal = Calendar.current
        let bedtimeDay = bedtimeDate(for: Date(), calendar: cal)
        var changed = false

        for idx in sleepLogs.indices where (
            cal.isDateInYesterday(sleepLogs[idx].date)
            || cal.isDateInToday(sleepLogs[idx].date)
            || cal.isDate(sleepLogs[idx].date, inSameDayAs: bedtimeDay)
        ) {
            sleepLogs[idx].score = 0
            sleepLogs[idx].actualWakeTime = nil
            sleepLogs[idx].hoursSlept = nil
            changed = true
        }

        morningScore = 0
        if changed {
            persist()
        }
    }

    func debugResetTodayDeckProgress(now: Date = Date()) {
        let cal = Calendar.current
        let bedtimeDay = bedtimeDate(for: now, calendar: cal)

        prepDoneIds.removeAll()
        ritualDoneIds.removeAll()
        nightlyStep = 0
        showNightlyFlow = false

        for idx in sleepLogs.indices where cal.isDate(sleepLogs[idx].date, inSameDayAs: bedtimeDay) {
            sleepLogs[idx].completedNightlyFlow = false
            sleepLogs[idx].actualRitualStart = nil
            sleepLogs[idx].actualBedtime = nil
            sleepLogs[idx].stepAttempts.removeAll()
        }
        sleepRuleSlips.removeAll {
            cal.isDate(contractAnchorDate(for: $0.dueAt), inSameDayAs: bedtimeDay)
        }

        persist()
    }

    func debugSeedCompletedNightsAndExpireTrial(
        count requestedCount: Int,
        presentMilestone: Bool = false,
        expireTrial: Bool = true
    ) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let seedScores = [3, 4, 3, 4, 4, 5, 4]
        let seedVariables = [
            R.brainDump,
            R.brainDump,
            R.brainDump,
            R.boringStory,
            R.boringStory,
            R.sleepSounds,
            R.sleepSounds
        ]
        let seedHoursSlept = [6.5, 7.0, 7.0, 7.5, 7.5, 8.0, 7.5]
        let count = min(max(requestedCount, 0), seedScores.count)
        let scores = Array(seedScores.prefix(count))
        let variables = Array(seedVariables.prefix(count))
        let hoursSlept = Array(seedHoursSlept.prefix(count))
        let routineSteps = coreRoutine.filter { $0.mode != .reminderOnly }

        sleepLogs = scores.enumerated().map { index, score in
            let daysAgo = scores.count - index
            let day = cal.date(byAdding: .day, value: -daysAgo, to: today) ?? today
            var bedtimeComponents = cal.dateComponents([.hour, .minute], from: typicalBedtime)
            bedtimeComponents.year = cal.component(.year, from: day)
            bedtimeComponents.month = cal.component(.month, from: day)
            bedtimeComponents.day = cal.component(.day, from: day)
            let seededBedtime = cal.date(from: bedtimeComponents) ?? day
            let bedtime = cal.date(byAdding: .minute, value: index * 3, to: seededBedtime) ?? seededBedtime
            let wakeTime = cal.date(byAdding: .hour, value: 8, to: bedtime) ?? typicalWakeTime
            let variable = variables[index]
            var entry = SleepLogEntry(
                date: day,
                variable: variable,
                variableRemedyId: RemedyID.fromLabel(variable),
                score: score
            )
            entry.actualRitualStart = cal.date(byAdding: .minute, value: -45, to: bedtime)
            entry.actualBedtime = bedtime
            entry.actualWakeTime = wakeTime
            entry.hoursSlept = hoursSlept[index]
            entry.lightsLevel = min(3, 1 + (index % 3))
            entry.lightsLevelSource = .selfReported
            entry.perceivedTemp = index % 4
            entry.brainDumpDurationSec = variable == R.brainDump ? 120 + index * 12 : nil
            entry.completedNightlyFlow = true
            entry.stepAttempts = routineSteps.map { step in
                StepAttempt(
                    remedyId: step.remedyId ?? RemedyID.fromLabel(step.label),
                    labelSnapshot: step.label,
                    status: .completed,
                    durationSeconds: NightlyStepKind.forLabel(step.label).map { $0.estimatedMinutes * 60 }
                )
            }
            return entry
        }

        baselineScore = 3
        morningScore = 0
        morningHoursSlept = 7.5
        pendingPromotion = nil
        justTriggeredNightFivePaywall = false
        prepDoneIds = []
        ritualDoneIds = []
        selectedDotIndex = nil

        if paywallState.originalGeneratedRoutine == nil {
            paywallState.originalGeneratedRoutine = coreRoutine
        }
        paywallState.trialCustomizedRoutine = coreRoutine
        paywallState.tier = .trial
        if expireTrial {
            paywallState.trialStartedAt = Calendar.current.date(byAdding: .day, value: -8, to: Date())
            paywallState.trialEndsAt = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        } else if !paywallState.isTrialActive() {
            let now = Date()
            paywallState.trialStartedAt = paywallState.trialStartedAt ?? now
            paywallState.trialEndsAt = Calendar.current.date(byAdding: .day, value: 7, to: now)
        }
        paywallState.trialExpiredAt = nil
        paywallState.verdictRevealed = true
        hasCompletedOnboarding = true
        initialTab = 0
        requestedTab = 0
        debugForceMorningState = false
        debugForceEveningState = false

        let shouldPresentMilestone = presentMilestone && isMilestoneDay(count)
        if shouldPresentMilestone {
            pendingStreakMilestoneDay = count
            acknowledgedStreakMilestoneDays.remove(count)
            streakMilestonePaywallPromptedDays.remove(count)
            activeRevenueCatPaywall = nil
            activeStreakMilestone = buildStreakMilestonePresentation(day: count)
        }

        persist()
        if !shouldPresentMilestone {
            evaluateTrialStatus()
        }
    }

    func debugSeedSevenNightsAndExpireTrial() {
        debugSeedCompletedNightsAndExpireTrial(count: 7)
    }

    func debugSimulateCancelledTrialExpired(now: Date = Date()) {
        hasCompletedOnboarding = true
        sleepContractActivatedAt = sleepContractActivatedAt ?? now
        if selectedSleepRules.isEmpty {
            selectedSleepRules = [.caffeineCutoff, .dimLights, .tomorrowsPlan]
        }

        paywallState.tier = .subscribed
        paywallState.trialStartedAt = nil
        paywallState.trialEndsAt = nil
        paywallState.trialExpiredAt = now
        paywallState.verdictRevealed = false
        applyRevenueCatEntitlement(isActive: false)
        handleSubscriptionLapsed()
        persist()
    }

    func debugClearCancelledTrialSimulation() {
        paywallState.trialExpiredAt = nil
        activeRevenueCatPaywall = nil
        persist()
    }
    #endif

    var lastNightEntry: SleepLogEntry? {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return sleepLogs.last { Calendar.current.isDate($0.date, inSameDayAs: yesterday) }
    }

    func bedtimeDate(for date: Date,
                     calendar: Calendar = .autoupdatingCurrent) -> Date {
        let bedtimeComponents = calendar.dateComponents([.hour, .minute], from: typicalBedtime)
        let bedMinute = (bedtimeComponents.hour ?? 22) * 60 + (bedtimeComponents.minute ?? 30)
        let wakeComponents = calendar.dateComponents([.hour, .minute], from: typicalWakeTime)
        let wakeMinute = (wakeComponents.hour ?? 7) * 60 + (wakeComponents.minute ?? 0)
        let dateMinute = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)

        if bedMinute <= wakeMinute {
            // Same-day sleep window: after wake, roll to the next sleep cycle.
            if dateMinute >= wakeMinute {
                let nextCycleDay = calendar.date(byAdding: .day, value: 1, to: date) ?? date
                return calendar.startOfDay(for: nextCycleDay)
            }
            return calendar.startOfDay(for: date)
        }

        let adjusted = dateMinute < wakeMinute
            ? (calendar.date(byAdding: .day, value: -1, to: date) ?? date)
            : date
        return calendar.startOfDay(for: adjusted)
    }

    func bedtimeDate(forWakeTime wake: Date,
                     calendar: Calendar = .autoupdatingCurrent) -> Date {
        let bedtimeComponents = calendar.dateComponents([.hour, .minute], from: typicalBedtime)
        var bedtime = calendar.date(
            bySettingHour: bedtimeComponents.hour ?? 22,
            minute: bedtimeComponents.minute ?? 30,
            second: 0,
            of: wake
        ) ?? wake
        if bedtime > wake {
            bedtime = calendar.date(byAdding: .day, value: -1, to: bedtime) ?? bedtime
        }
        return calendar.startOfDay(for: bedtime)
    }

    private func completedWindDownDates(calendar: Calendar = .autoupdatingCurrent) -> [Date] {
        let dates = sleepLogs
            .filter(\.completedNightlyFlow)
            .map { calendar.startOfDay(for: $0.date) }
        return Array(Set(dates)).sorted()
    }

    var streakSummary: StreakSummary {
        let cal = Calendar.current
        let completed = completedWindDownDates(calendar: cal)
        guard let first = completed.first else {
            let today = bedtimeDate(for: Date(), calendar: cal)
            return StreakSummary(
                completedNights: 0,
                expectedNights: 0,
                completionRate: 0,
                last13: [StreakNight(date: today, state: .tonight)]
            )
        }

        let today = bedtimeDate(for: Date(), calendar: cal)
        let completedSet = Set(completed)
        let expected = max(1, (cal.dateComponents([.day], from: first, to: today).day ?? 0) + 1)
        let rate = Int((Double(completed.count) / Double(expected) * 100).rounded())
        let start = cal.date(byAdding: .day, value: -12, to: today) ?? today
        let last13 = (0..<13).compactMap { offset -> StreakNight? in
            guard let date = cal.date(byAdding: .day, value: offset, to: start) else { return nil }
            let day = cal.startOfDay(for: date)
            if day > today { return StreakNight(date: day, state: .future) }
            if completedSet.contains(day) { return StreakNight(date: day, state: .completed) }
            if day == today { return StreakNight(date: day, state: .tonight) }
            if day < first { return StreakNight(date: day, state: .future) }
            return StreakNight(date: day, state: .missed)
        }

        return StreakSummary(
            completedNights: completed.count,
            expectedNights: expected,
            completionRate: rate,
            last13: last13
        )
    }

    private func isMilestoneDay(_ day: Int) -> Bool {
        day == 3 || day == 7 || day == 30 || day == 60 || day == 90 || (day > 90 && day % 30 == 0)
    }

    private func queueStreakMilestoneIfNeeded() {
        let day = completedWindDownDates().count
        guard isMilestoneDay(day),
              !acknowledgedStreakMilestoneDays.contains(day)
        else { return }
        pendingStreakMilestoneDay = day
    }

    func morningWindowEnd(for date: Date = Date(),
                          calendar: Calendar = .autoupdatingCurrent) -> Date? {
        let wakeComponents = calendar.dateComponents([.hour, .minute], from: typicalWakeTime)
        var combined = calendar.dateComponents([.year, .month, .day], from: date)
        combined.hour = wakeComponents.hour ?? 7
        combined.minute = wakeComponents.minute ?? 0
        guard let wake = calendar.date(from: combined) else { return nil }

        let plusFour = calendar.date(byAdding: .hour, value: 4, to: wake) ?? wake
        var elevenComponents = calendar.dateComponents([.year, .month, .day], from: date)
        elevenComponents.hour = 11
        elevenComponents.minute = 0
        let elevenAm = calendar.date(from: elevenComponents) ?? plusFour
        return max(plusFour, elevenAm)
    }

    private func isMorningWindowActive(now: Date = Date()) -> Bool {
        let cal = Calendar.current
        let wakeComponents = cal.dateComponents([.hour, .minute], from: typicalWakeTime)
        var combined = cal.dateComponents([.year, .month, .day], from: now)
        combined.hour = wakeComponents.hour ?? 7
        combined.minute = wakeComponents.minute ?? 0
        guard let wake = cal.date(from: combined),
              let windowEnd = morningWindowEnd(for: now, calendar: cal)
        else { return false }
        return now >= wake && now < windowEnd
    }

    private func hasRatedCurrentMorning(now: Date = Date()) -> Bool {
        let cal = Calendar.current
        return sleepLogs.contains {
            $0.score > 0 && (cal.isDateInToday($0.date) || cal.isDateInYesterday($0.date))
        }
    }

    func presentPendingStreakMilestoneIfEligible(now: Date = Date()) {
        guard activeStreakMilestone == nil,
              activeRevenueCatPaywall == nil,
              let day = pendingStreakMilestoneDay
        else { return }

        let canPresentNow = hasRatedCurrentMorning(now: now) || !isMorningWindowActive(now: now)
        guard canPresentNow else { return }

        if !hasPremiumAccess {
            guard !streakMilestonePaywallPromptedDays.contains(day) else { return }
            streakMilestonePaywallPromptedDays.insert(day)
            activeRevenueCatPaywall = .upgrade
            trackAnalytics("habit_milestone_paywall_presented", [
                "milestone_day": "\(day)",
                "logged_night_count": "\(loggedNightCount)"
            ])
            persist()
            return
        }

        activeStreakMilestone = buildStreakMilestonePresentation(day: day)
        trackAnalytics("habit_milestone_presented", [
            "milestone_day": "\(day)",
            "logged_night_count": "\(loggedNightCount)"
        ])
    }

    func acknowledgeStreakMilestone() {
        guard let milestone = activeStreakMilestone else { return }
        acknowledgedStreakMilestoneDays.insert(milestone.day)
        if pendingStreakMilestoneDay == milestone.day {
            pendingStreakMilestoneDay = nil
        }
        activeStreakMilestone = nil
        trackAnalytics("habit_milestone_acknowledged", [
            "milestone_day": "\(milestone.day)",
            "logged_night_count": "\(loggedNightCount)"
        ])
        persist()
    }

    private func buildStreakMilestonePresentation(day: Int) -> StreakMilestonePresentation {
        let cal = Calendar.current
        let completed = completedWindDownDates(calendar: cal)
        guard let first = completed.first else {
            return StreakMilestonePresentation(
                day: day,
                headlineRate: 0,
                headlineLabel: "THIS YEAR",
                secondaryRate: nil,
                secondaryLabel: nil,
                averageSleepScore: nil,
                showsConfetti: true
            )
        }

        let milestoneDate = completed.indices.contains(day - 1) ? completed[day - 1] : (completed.last ?? first)
        let last30Start = cal.date(byAdding: .day, value: -29, to: milestoneDate) ?? milestoneDate
        let ytdStart = cal.date(from: cal.dateComponents([.year], from: milestoneDate)) ?? first

        let headlineStart = day >= 60 ? last30Start : max(first, ytdStart)
        let headlineRate = completionRate(from: headlineStart, to: milestoneDate, completedDates: completed, calendar: cal)
        let secondaryRate = day >= 60
            ? completionRate(from: max(first, ytdStart), to: milestoneDate, completedDates: completed, calendar: cal)
            : nil

        let averageScopeStart = day >= 60 ? last30Start : headlineStart
        let average = averageSleepScore(from: averageScopeStart, to: milestoneDate, calendar: cal)
        let confetti = average.map { $0 > Double(baselineScore) } ?? true

        return StreakMilestonePresentation(
            day: day,
            headlineRate: headlineRate,
            headlineLabel: day >= 60 ? "LAST 30 DAYS" : "THIS YEAR",
            secondaryRate: secondaryRate,
            secondaryLabel: day >= 60 ? "THIS YEAR" : nil,
            averageSleepScore: average,
            showsConfetti: confetti
        )
    }

    private func completionRate(from start: Date,
                                to end: Date,
                                completedDates: [Date],
                                calendar: Calendar) -> Int {
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        let expected = max(1, (calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0) + 1)
        let completedSet = Set(completedDates)
        var count = 0
        for offset in 0..<expected {
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDay) else { continue }
            if completedSet.contains(calendar.startOfDay(for: date)) {
                count += 1
            }
        }
        return Int((Double(count) / Double(expected) * 100).rounded())
    }

    private func averageSleepScore(from start: Date,
                                   to end: Date,
                                   calendar: Calendar) -> Double? {
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        let scored = sleepLogs.filter {
            let day = calendar.startOfDay(for: $0.date)
            return $0.score > 0 && day >= startDay && day <= endDay
        }
        guard !scored.isEmpty else { return nil }
        return Double(scored.map(\.score).reduce(0, +)) / Double(scored.count)
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
            #if DEBUG
            print("[Migration] Consolidated \(removed.count) orphaned rating entr\(removed.count == 1 ? "y" : "ies").")
            #endif
        }
    }

    // One-time data migration: enforces TenThirty's 1-5 sleep-score scale for any
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
            #if DEBUG
            print("[Migration] Normalized sleep scores to the 1-\(Self.maxSleepScore) scale.")
            #endif
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
            .max { lhs, rhs in
                let lhsHasNightlyData = sleepLogs[lhs].completedNightlyFlow
                    || sleepLogs[lhs].actualBedtime != nil
                    || !sleepLogs[lhs].stepAttempts.isEmpty
                let rhsHasNightlyData = sleepLogs[rhs].completedNightlyFlow
                    || sleepLogs[rhs].actualBedtime != nil
                    || !sleepLogs[rhs].stepAttempts.isEmpty
                if lhsHasNightlyData != rhsHasNightlyData {
                    return !lhsHasNightlyData && rhsHasNightlyData
                }
                return sleepLogs[lhs].date < sleepLogs[rhs].date
            }
    }

    // MARK: - Telemetry

    func trackAppOpened() {
        trackAnalytics("app_opened")
    }

    func trackFirstOpenIfNeeded() {
        let key = "tenthirty.analytics.first_open.v1"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        let queued = AnalyticsService.track(
            "first_open",
            installId: installId,
            properties: baseAnalyticsProperties().merging([
                "is_onboarding_complete": hasCompletedOnboarding ? "true" : "false"
            ]) { _, new in new }
        )
        if queued {
            UserDefaults.standard.set(true, forKey: key)
        }
    }

    func trackOnboardingStarted() {
        trackAnalytics("onboarding_started")
    }

    func trackOnboardingScreen(_ screenName: String) {
        trackAnalytics("onboarding_screen_\(screenName)")
    }

    func trackOnboardingFireflyCompanionShown() {
        guard isOnboardingFireflyCompanionActive else { return }
        trackAnalytics("onboarding_firefly_companion_shown")
    }

    func trackPaywallPrimaryTapped(product: LullStoreProduct) {
        trackAnalytics("paywall_primary_tapped", [
            "product_id": product.productID,
            "product": product.rawValue
        ])
    }

    func trackPaywallViewed(context: String) {
        var properties: AnalyticsService.Properties = [
            "context": context,
            "default_product_id": LullStoreProduct.yearly.productID
        ]
        if context == "trial_expired" {
            properties["offer_type"] = "paid_resubscribe"
        } else {
            properties["offer_type"] = "seven_night_trial"
            properties["trial_days"] = "7"
        }
        trackAnalytics("paywall_viewed", properties)
    }

    func trackPurchaseStarted(product: LullStoreProduct) {
        trackAnalytics("purchase_started", [
            "product_id": product.productID,
            "product": product.rawValue
        ])
    }

    func trackPurchaseSucceeded(product: LullStoreProduct,
                              isTrial: Bool,
                              conversionSource: String = "onboarding_paywall") {
        trackAnalytics("purchase_succeeded", [
            "product_id": product.productID,
            "product": product.rawValue,
            "is_trial": isTrial ? "true" : "false",
            "conversion_source": conversionSource
        ])
        trackAnalytics(isTrial ? "trial_started" : "subscription_started", [
            "product_id": product.productID,
            "product": product.rawValue,
            "conversion_source": conversionSource
        ])
    }

    func trackRestoreStarted(context: String) {
        trackAnalytics("restore_started", ["context": context])
    }

    func trackRestoreSucceeded(context: String,
                               isTrial: Bool,
                               productIdentifier: String?) {
        trackAnalytics("restore_succeeded", [
            "context": context,
            "is_trial": isTrial ? "true" : "false",
            "product_id": productIdentifier ?? ""
        ])
    }

    func trackRestoreFailed(context: String, errorMessage: String?) {
        trackAnalytics("restore_failed", [
            "context": context,
            "has_error": errorMessage?.isEmpty == false ? "true" : "false"
        ])
    }

    func trackPurchaseCancelled(product: LullStoreProduct) {
        trackAnalytics("purchase_cancelled", [
            "product_id": product.productID,
            "product": product.rawValue
        ])
    }

    func trackPurchaseFailed(product: LullStoreProduct, error: Error) {
        let nsError = error as NSError
        trackAnalytics("purchase_failed", [
            "product_id": product.productID,
            "product": product.rawValue,
            "error_domain": nsError.domain,
            "error_code": "\(nsError.code)"
        ])
    }

    func trackHardAppBlockingPermissionRequested() {
        trackAnalytics("hard_app_blocking_permission_requested")
    }

    func trackHardAppBlockingPermissionResult(granted: Bool,
                                               source: String,
                                               hasError: Bool = false) {
        trackAnalytics("hard_app_blocking_permission_result", [
            "granted": granted ? "true" : "false",
            "source": source,
            "has_error": hasError ? "true" : "false"
        ])
    }

    func trackAppBlockingSkipped(context: String) {
        trackAnalytics("app_blocking_skipped", ["context": context])
    }

    func trackTodayFirstFireflyPromptShown() {
        guard isOnboardingFireflyCompanionActive else { return }
        trackAnalytics("today_first_firefly_prompt_shown")
    }

    func trackTodayFirstFireflyPromptDismissed(method: String) {
        guard isOnboardingFireflyCompanionActive else { return }
        trackAnalytics("today_first_firefly_prompt_dismissed", [
            "method": method
        ])
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
        let entry = sleepLogs
            .filter { $0.completedNightlyFlow }
            .sorted { ($0.actualBedtime ?? $0.date) > ($1.actualBedtime ?? $1.date) }
            .first ?? sleepLogs.first(where: { $0.isToday })
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

    func recordBoringStoryMediaSession(contentId: String?,
                                       listenedSeconds: Int,
                                       totalDurationSeconds: Int,
                                       completed: Bool) {
        recordMediaSession(
            mediaType: "boring_story",
            contentId: contentId,
            configuredDurationSeconds: totalDurationSeconds,
            listenedDurationSeconds: listenedSeconds,
            completed: completed
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

    func trackTodayDeckStarted(stepCount: Int) {
        trackAnalytics("ritual_started", [
            "step_count": "\(stepCount)"
        ])
    }

    func trackTodayDeckStep(step: RoutineStep,
                            status: StepStatus,
                            stepType: String,
                            index: Int) {
        updateTodayLog {
            $0.stepAttempts.append(
                StepAttempt(
                    remedyId: step.remedyId ?? RemedyID.fromLabel(step.label),
                    labelSnapshot: step.label,
                    status: status,
                    durationSeconds: nil
                )
            )
        }

        trackAnalytics(status == .completed ? "step_completed" : "step_skipped", [
            "step_type": stepType,
            "step_title": step.label,
            "index": "\(index)"
        ])

        if step.remedyId == .noScreens || step.remedyId == .appBlocking || step.label == R.noScreens || step.label == R.appBlocking {
            trackAnalytics("phone_step_completed", [
                "completed": status == .completed ? "true" : "false",
                "step_title": step.label
            ])
        }
    }

    func trackTodayDeckCompleted(completedCount: Int, skippedCount: Int) {
        trackAnalytics("ritual_completed", [
            "completed_count": "\(completedCount)",
            "skipped_count": "\(skippedCount)",
            "reached_end": "true"
        ])
        recordGuidedWindDownCompleted()
        trackAnalytics("firefly_earned", [
            "night_number": "\(completedWindDownNightCount)"
        ])
    }

    func trackTodayDeckInsightsOpened() {
        trackAnalytics("insights_opened")
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

        trackAnalytics("onboarding_completed")
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
        trackAnalytics("morning_checkin", [
            "value": subjectiveMorningValue(for: entry.score)
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

    private func subjectiveMorningValue(for score: Int) -> String {
        switch score {
        case 1...2: return "rough"
        case 3: return "okay"
        default: return "rested"
        }
    }

    private func baseAnalyticsProperties() -> AnalyticsService.Properties {
        [
            "chronotype": chronotype.rawValue,
            "bottleneck": bottleneck.rawValue,
            "has_completed_onboarding": hasCompletedOnboarding ? "true" : "false",
            "user_tier": paywallState.tier.rawValue,
            "has_premium_access": hasPremiumAccess ? "true" : "false",
            "logged_night_count": "\(loggedNightCount)",
            "habit_completed_nights": "\(streakSummary.completedNights)",
            "trial_day": "\(trialDayNumber)",
            "routine_step_count": "\(coreRoutine.count)",
            "test_cohort": analyticsCohort,
            "onboarding_firefly_companion": onboardingFireflyCompanionBucket
        ]
    }

    private func baseResearchPayload() -> [String: ResearchValue] {
        [
            "chronotype": .string(chronotype.rawValue),
            "bottleneck": .string(bottleneck.rawValue),
            "has_completed_onboarding": .bool(hasCompletedOnboarding),
            "user_tier": .string(paywallState.tier.rawValue),
            "has_premium_access": .bool(hasPremiumAccess),
            "logged_night_count": .int(loggedNightCount),
            "habit_completed_nights": .int(streakSummary.completedNights),
            "trial_day": .int(trialDayNumber),
            "routine_step_count": .int(coreRoutine.count),
            "test_cohort": .string(analyticsCohort)
        ]
    }

    private var analyticsCohort: String {
        let value = (Bundle.main.infoDictionary?["LullAnalyticsCohort"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if value.contains("$(") { return "" }
        return value
    }

    var onboardingFireflyCompanionBucket: String {
        isOnboardingFireflyCompanionActive ? "on" : "off"
    }

    private var trialDayNumber: Int {
        guard let started = paywallState.trialStartedAt else { return 0 }
        let start = Calendar.current.startOfDay(for: started)
        let today = Calendar.current.startOfDay(for: Date())
        let days = Calendar.current.dateComponents([.day], from: start, to: today).day ?? 0
        return max(1, days + 1)
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
    // on app foreground and after morning score logging — TenThirty is a daily-use
    // app so one of those triggers will fire reliably without needing BGTaskScheduler.
    func autoExportIfDue() {
        if let last = lastExportDate, Calendar.current.isDateInToday(last) { return }
        exportData()
    }

    func exportData() {
        guard !isExporting else { return }
        isExporting = true
        lastExportError = nil
        trackAnalytics("feedback_export_started", [
            "logged_night_count": "\(loggedNightCount)"
        ])

        let snapshot = PersistedState(
            schemaVersion: 14,
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
            generatedRoutineRemedyIds: generatedRoutineRemedyIds,
            routineIntroOrder: routineIntroOrder,
            routineBacklog: routineBacklog,
            routineReinforcedRemedyIds: routineReinforcedRemedyIds,
            showHealthScreening: showHealthScreening,
            sleepLogs: sleepLogs,
            chronotype: chronotype,
            bottleneck: bottleneck,
            committedRoutineTime: committedRoutineTime,
            sleepThief: sleepThief,
            sleepContractActivatedAt: sleepContractActivatedAt,
            selectedSleepRules: Array(selectedSleepRules),
            sleepRuleConfigurations: sleepRuleConfigurations,
            sleepRuleCompletions: sleepRuleCompletions,
            sleepRuleSlips: sleepRuleSlips,
            contractLockEvents: contractLockEvents,
            contractAllClearEvents: contractAllClearEvents,
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
                self.trackAnalytics("feedback_export_completed", [
                    "logged_night_count": "\(self.loggedNightCount)"
                ])
            } catch {
                lastExportError = error.localizedDescription
                self.trackAnalytics("feedback_export_failed", [
                    "error": error.localizedDescription,
                    "logged_night_count": "\(self.loggedNightCount)"
                ])
            }
            isExporting = false
        }
    }

    // MARK: - Init / Persistence

    #if DEBUG
    private static func shouldSkipPersistedStateForUITest() -> Bool {
        let arguments = ProcessInfo.processInfo.arguments
        let environment = ProcessInfo.processInfo.environment
        let holdFixture = arguments.contains("--uitest-hold-confirm-fixture")
            || environment["UITEST_HOLD_CONFIRM_FIXTURE"] == "1"
        let onboardingComplete = arguments.contains("--uitest-completed-onboarding")
            || environment["UITEST_COMPLETED_ONBOARDING"] == "1"
        let freshInstall = arguments.contains("--uitest-fresh-install")
            || environment["UITEST_FRESH_INSTALL"] == "1"
        return freshInstall || (holdFixture && onboardingComplete)
    }
    #endif

    init() {
        #if DEBUG
        let skipPersistedState = Self.shouldSkipPersistedStateForUITest()
        #else
        let skipPersistedState = false
        #endif

        if !skipPersistedState, let saved = PersistenceStore.shared.load() {
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
            _sleepThief               = Published(initialValue: saved.sleepThief)
            _sleepContractActivatedAt = Published(initialValue: saved.sleepContractActivatedAt)
            _selectedSleepRules       = Published(initialValue: Set(saved.selectedSleepRules))
            _sleepRuleConfigurations  = Published(initialValue: saved.sleepRuleConfigurations)
            _sleepRuleCompletions     = Published(initialValue: saved.sleepRuleCompletions)
            _sleepRuleSlips           = Published(initialValue: saved.sleepRuleSlips)
            _contractLockEvents       = Published(initialValue: saved.contractLockEvents)
            _contractAllClearEvents   = Published(initialValue: saved.contractAllClearEvents)
            _paywallState             = Published(initialValue: saved.paywallState)
            _coreRoutine              = Published(initialValue: saved.coreRoutine)
            _routineExplanation       = Published(initialValue: saved.routineExplanation)
            _generatedRoutineRemedyIds = Published(initialValue: saved.generatedRoutineRemedyIds)
            _routineIntroOrder        = Published(initialValue: saved.routineIntroOrder)
            _routineBacklog           = Published(initialValue: saved.routineBacklog)
            _routineReinforcedRemedyIds = Published(initialValue: saved.routineReinforcedRemedyIds)
            _showHealthScreening      = Published(initialValue: saved.showHealthScreening)
            _sleepLogs                = Published(initialValue: saved.sleepLogs)
            _baselineScore            = Published(initialValue: saved.baselineScore)
            _prepDoneIds              = Published(initialValue: Set(saved.prepDoneIds))
            _prepDoneDate             = Published(initialValue: saved.prepDoneDate)
            _ritualDoneIds            = Published(initialValue: Set(saved.ritualDoneIds))
            _ritualDoneDate           = Published(initialValue: saved.ritualDoneDate)
            _pendingPromotion         = Published(initialValue: saved.pendingPromotion)
            _recentlyPromotedRemedyId = Published(initialValue: saved.recentlyPromotedRemedyId)
            _recentlyPromotedAt       = Published(initialValue: saved.recentlyPromotedAt)
            _pendingStreakMilestoneDay = Published(initialValue: saved.pendingStreakMilestoneDay)
            _acknowledgedStreakMilestoneDays = Published(initialValue: Set(saved.acknowledgedStreakMilestoneDays))
            _streakMilestonePaywallPromptedDays = Published(initialValue: Set(saved.streakMilestonePaywallPromptedDays))
            if let data = saved.appBlockingSelectionData,
               let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
                _appBlockingSelection = Published(initialValue: decoded)
            }
            _appBlockingEnabled = Published(initialValue: saved.appBlockingEnabled)
            _appBlockingStartTime = Published(initialValue: saved.appBlockingStartTime ?? Self.defaultAppBlockingStart(from: saved.typicalBedtime))
            _appBlockingEndTime = Published(initialValue: saved.appBlockingEndTime ?? Self.defaultAppBlockingEnd(from: saved.typicalWakeTime))
            _appBlockingGraceMinutes = Published(initialValue: saved.appBlockingGraceMinutes)
            _emergencyAppAccessSession = Published(initialValue: saved.emergencyAppAccessSession)
            if paywallState.originalGeneratedRoutine == nil {
                paywallState.originalGeneratedRoutine = saved.originalGeneratedRoutine ?? saved.coreRoutine
            }
            if paywallState.trialCustomizedRoutine == nil {
                paywallState.trialCustomizedRoutine = saved.trialCustomizedRoutine
            }
            if paywallState.gentleBlockingBypassedUntil == nil {
                paywallState.gentleBlockingBypassedUntil = saved.gentleBlockingBypassedUntil
            }
            if hasCompletedOnboarding && paywallState.tier == .onboarding {
                paywallState.tier = .free
                paywallState.verdictRevealed = false
            } else if paywallState.isTrialActive() && paywallState.tier != .subscribed {
                paywallState.tier = .trial
                paywallState.trialExpiredAt = nil
                paywallState.verdictRevealed = true
            } else if paywallState.tier == .awaitingVerdict ||
                        paywallState.tier == .paywallPending ||
                        paywallState.tier == .shareUnlocked ||
                        paywallState.tier == .freeForever {
                paywallState.tier = .free
                paywallState.verdictRevealed = false
            }
            if hasCompletedOnboarding && sleepContractActivatedAt == nil {
                sleepContractActivatedAt = saved.committedRoutineTime ?? Date()
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
            } else if saved.schemaVersion < 8 {
                DispatchQueue.main.async {
                    self.persist()
                }
            } else if saved.schemaVersion < 9 {
                DispatchQueue.main.async {
                    self.convertExperimentStepsToHabits()
                    self.persist()
                }
            } else if saved.schemaVersion < 11 {
                DispatchQueue.main.async {
                    self.persist()
                }
            } else if saved.schemaVersion < 12 {
                DispatchQueue.main.async {
                    self.persist()
                }
            } else if saved.schemaVersion < 13 {
                DispatchQueue.main.async {
                    self.persist()
                }
            } else if saved.schemaVersion < 15 {
                DispatchQueue.main.async {
                    self.persist()
                }
            }

            // Reschedule on every launch so notifications stay current (e.g. after OS clears them)
            DispatchQueue.main.async {
                _ = self.handleTimeZoneChangeIfNeeded()
                self.scheduleAllNotifications()
                self.evaluateTrialStatus()
                self.refreshAppBlockingShield()
            }
        } else {
            _appBlockingStartTime = Published(initialValue: Self.defaultAppBlockingStart(from: typicalBedtime))
            _appBlockingEndTime = Published(initialValue: Self.defaultAppBlockingEnd(from: typicalWakeTime))
        }

        #if DEBUG
        applyUITestLaunchArgumentsIfNeeded()
        #endif
    }

    #if DEBUG
    func applyUITestLaunchArgumentsIfNeeded(_ arguments: [String] = ProcessInfo.processInfo.arguments) {
        let environment = ProcessInfo.processInfo.environment
        let freshInstall = arguments.contains("--uitest-fresh-install")
            || environment["UITEST_FRESH_INSTALL"] == "1"
        if freshInstall {
            hasCompletedOnboarding = false
            requestedTab = nil
            showNightlyFlow = false
            paywallState = PaywallState()
            return
        }
        let onboardingComplete = arguments.contains("--uitest-completed-onboarding")
            || environment["UITEST_COMPLETED_ONBOARDING"] == "1"
        guard onboardingComplete else { return }

        hasCompletedOnboarding = true
        pendingOnboardingFireflyHandoff = false
        hasSeenFirstFireflyPrompt = true
        requestedTab = 0

        let cal = Calendar.current
        typicalBedtime = cal.date(bySettingHour: 22, minute: 30, second: 0, of: Date()) ?? typicalBedtime
        typicalWakeTime = cal.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? typicalWakeTime
        sleepWindowMinutes = 30

        coreRoutine = [
            RoutineStep(
                order: 1,
                label: R.noScreens,
                mode: .reminderOnly,
                leadTimeMins: 75,
                durationLabel: nil,
                notes: "No screens before bed.",
                repeatCadence: "every",
                notifyEnabled: true,
                remedyId: .noScreens,
                category: .bedtimePrep,
                enforcementMode: .nudge
            ),
            RoutineStep(
                order: 2,
                label: R.brainDump,
                mode: .inSequence,
                leadTimeMins: nil,
                durationLabel: "2m",
                notes: "Clear the loop before sleep.",
                repeatCadence: "every",
                notifyEnabled: false,
                remedyId: .brainDump,
                category: .windDown,
                enforcementMode: nil
            )
        ]
        sleepLogs = []
        prepDoneIds = []
        ritualDoneIds = []
        prepDoneDate = nil
        ritualDoneDate = nil
        appBlockingSelection = FamilyActivitySelection()
        appBlockingEnabled = false
        sleepThief = .scrolling
        sleepContractActivatedAt = Date()
        selectedSleepRules = [.caffeineCutoff, .dimLights, .tomorrowsPlan]
        sleepRuleConfigurations = [:]
        sleepRuleCompletions = []
        sleepRuleSlips = []
        contractLockEvents = []
        contractAllClearEvents = []
        paywallState.tier = .subscribed
        paywallState.trialExpiredAt = nil

        if arguments.contains("--uitest-hold-confirm-fixture")
            || environment["UITEST_HOLD_CONFIRM_FIXTURE"] == "1" {
            configureUITestHoldConfirmFixture(calendar: cal)
        }
        if arguments.contains("--uitest-start-trends")
            || environment["UITEST_START_TRENDS"] == "1" {
            requestedTab = 2
        }
    }

    private func configureUITestHoldConfirmFixture(calendar: Calendar) {
        uiTestHoldConfirmFixtureActive = true
        selectedSleepRules = [.dimLights]
        sleepContractActivatedAt = calendar.date(byAdding: .day, value: -2, to: Date())
        let now = Date()
        sleepRuleConfigurations[.dimLights] = SleepRuleConfiguration(
            availableTime: calendar.date(byAdding: .hour, value: -2, to: now),
            dueTime: calendar.date(byAdding: .minute, value: -1, to: now),
            graceMinutes: 30
        )
        sleepRuleCompletions = []
        sleepRuleSlips = []
        appBlockingEnabled = false
        appBlockingSelection = FamilyActivitySelection()
        paywallState.tier = .subscribed
        paywallState.trialExpiredAt = nil
        paywallState.verdictRevealed = false
        requestedTab = 0
    }
    #endif

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
            generatedRoutineRemedyIds: generatedRoutineRemedyIds,
            routineIntroOrder:        routineIntroOrder,
            routineBacklog:           routineBacklog,
            routineReinforcedRemedyIds: routineReinforcedRemedyIds,
            showHealthScreening:      showHealthScreening,
            sleepLogs:                sleepLogs,
            chronotype:               chronotype,
            bottleneck:               bottleneck,
            committedRoutineTime:     committedRoutineTime,
            sleepThief:               sleepThief,
            sleepContractActivatedAt: sleepContractActivatedAt,
            selectedSleepRules:       Array(selectedSleepRules),
            sleepRuleConfigurations:  sleepRuleConfigurations,
            sleepRuleCompletions:     sleepRuleCompletions,
            sleepRuleSlips:           sleepRuleSlips,
            contractLockEvents:       contractLockEvents,
            contractAllClearEvents:   contractAllClearEvents,
            timeZoneIdentifier:       persistedTimeZoneIdentifier,
            paywallState:             paywallState,
            originalGeneratedRoutine: paywallState.originalGeneratedRoutine,
            trialCustomizedRoutine:   paywallState.trialCustomizedRoutine,
            baselineScore:            baselineScore,
            prepDoneIds:              Array(prepDoneIds),
            prepDoneDate:             prepDoneDate,
            ritualDoneIds:            Array(ritualDoneIds),
            ritualDoneDate:           ritualDoneDate,
            pendingPromotion:         pendingPromotion,
            recentlyPromotedRemedyId: recentlyPromotedRemedyId,
            recentlyPromotedAt:       recentlyPromotedAt,
            pendingStreakMilestoneDay: pendingStreakMilestoneDay,
            acknowledgedStreakMilestoneDays: Array(acknowledgedStreakMilestoneDays),
            streakMilestonePaywallPromptedDays: Array(streakMilestonePaywallPromptedDays),
            appBlockingSelectionData: try? JSONEncoder().encode(appBlockingSelection),
            appBlockingEnabled:       appBlockingEnabled,
            appBlockingStartTime:     appBlockingStartTime,
            appBlockingEndTime:       appBlockingEndTime,
            appBlockingGraceMinutes:  appBlockingGraceMinutes,
            gentleBlockingBypassedUntil: paywallState.gentleBlockingBypassedUntil,
            emergencyAppAccessSession: emergencyAppAccessSession
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
        guard !isContractEditingLocked() else {
            trackContractEditBlockedDuringLock("sleep_window")
            return
        }
        committedRoutineTime = nil
        appBlockingStartTime = typicalBedtime
        appBlockingEndTime = typicalWakeTime
        persist()
        scheduleAllNotifications()
        refreshAppBlockingShield()
    }

    func configureAppBlocking(selection: FamilyActivitySelection,
                              enabled: Bool,
                              startTime: Date,
                              endTime: Date,
                              graceMinutes: Int) {
        guard !isContractEditingLocked() else {
            trackContractEditBlockedDuringLock("blocked_apps")
            refreshAppBlockingShield()
            return
        }
        appBlockingSelection = selection
        appBlockingEnabled = enabled
        appBlockingStartTime = canUseHardAppBlocking ? startTime : typicalBedtime
        appBlockingEndTime = endTime
        appBlockingGraceMinutes = graceMinutes
        trackAnalytics("app_blocking_configured", [
            "enabled": enabled ? "true" : "false",
            "has_application_targets": selection.applicationTokens.isEmpty ? "false" : "true",
            "has_category_targets": selection.categoryTokens.isEmpty ? "false" : "true",
            "grace_minutes": "\(graceMinutes)",
            "blocking_mode": canUseHardAppBlocking ? "hard" : "gentle"
        ])
        if canUseHardAppBlocking {
            trackAnalytics("hard_app_blocking_configured", [
                "enabled": enabled ? "true" : "false",
                "has_application_targets": selection.applicationTokens.isEmpty ? "false" : "true",
                "has_category_targets": selection.categoryTokens.isEmpty ? "false" : "true"
            ])
        }
        persist()
        refreshAppBlockingShield()
    }

    var orderedSelectedSleepRules: [SleepRuleKind] {
        selectedSleepRules
            .filter { $0 != .inBed }
            .sorted { lhs, rhs in
            sleepContractItem(for: lhs, on: Date()).dueAt < sleepContractItem(for: rhs, on: Date()).dueAt
        }
    }

    var sleepContractPreviewItems: [SleepContractItem] {
        orderedSelectedSleepRules.map { sleepContractItem(for: $0, on: Date()) }
    }

    func sleepContractPreviewItem(for rule: SleepRuleKind) -> SleepContractItem {
        sleepContractItem(for: rule, on: Date())
    }

    var nextSleepContractItem: SleepContractItem? {
        let now = Date()
        return todaysContractItems(now: now)
            .filter { !$0.isCompleted && !$0.startsTomorrow && $0.graceEndsAt >= now }
            .sorted { $0.availableAt < $1.availableAt }
            .first
    }

    var currentSleepRulePromptItem: SleepContractItem? {
        sleepContractSnapshot().actionableItems.first ?? nextSleepContractItem
    }

    func canCompleteSleepRule(_ item: SleepContractItem, now: Date = Date()) -> Bool {
        guard !item.startsTomorrow else { return false }
        if item.rule == .inBed {
            return isInBedCheckpointUnlocked(item) && isInBedCheckpointAvailable(item, now: now)
        }
        guard item.availableAt <= now else { return false }
        return true
    }

    func setSleepThief(_ thief: SleepThief) {
        sleepThief = thief
        trackAnalytics("sleep_thief_selected", [
            "sleep_thief": thief.analyticsValue
        ])
        persist()
    }

    func toggleSleepRule(_ rule: SleepRuleKind) {
        guard rule != .inBed else { return }
        guard !isContractEditingLocked() else {
            trackContractEditBlockedDuringLock("rule_toggle")
            return
        }
        if selectedSleepRules.contains(rule) {
            selectedSleepRules.remove(rule)
        } else {
            selectedSleepRules.insert(rule)
        }

        trackAnalytics("sleep_rules_selected", [
            "selected_rule_count": "\(selectedSleepRules.count)",
            "selected_rules": orderedSelectedSleepRules.map(\.rawValue).joined(separator: ",")
        ])
        persist()
        refreshAppBlockingShield()
    }

    func completeSleepRule(_ rule: SleepRuleKind, at completedAt: Date = Date()) {
        let item = contractItemToComplete(for: rule, now: completedAt)
        completeSleepRule(item, at: completedAt)
    }

    func completeSleepRule(_ item: SleepContractItem, at completedAt: Date = Date()) {
        guard canCompleteSleepRule(item, now: completedAt) else { return }
        let completedWithinGrace = item.rule == .inBed || completedAt <= item.graceEndsAt
        let completion = SleepRuleCompletion(
            rule: item.rule,
            dueAt: item.dueAt,
            completedAt: completedAt,
            completedWithinGrace: completedWithinGrace
        )

        if let index = sleepRuleCompletions.firstIndex(where: {
            $0.rule == item.rule && Calendar.current.isDate($0.dueAt, equalTo: item.dueAt, toGranularity: .minute)
        }) {
            sleepRuleCompletions[index] = completion
        } else {
            sleepRuleCompletions.append(completion)
        }
        sleepRuleSlips.removeAll {
            $0.rule == item.rule && Calendar.current.isDate($0.dueAt, equalTo: item.dueAt, toGranularity: .minute)
        }

        trackAnalytics(completedWithinGrace ? "sleep_rule_completed_on_time" : "sleep_rule_completed_late", [
            "sleep_rule": item.rule.rawValue,
            "due_at": Self.researchDateString(item.dueAt),
            "completed_at": Self.researchDateString(completedAt),
            "cooldown_minutes": "0"
        ])
        persist()
        scheduleAllNotifications()
        refreshAppBlockingShield(now: completedAt)
    }

    func recordSleepRuleSlip(_ item: SleepContractItem, at slippedAt: Date = Date()) {
        let slip = SleepRuleSlip(
            rule: item.rule,
            dueAt: item.dueAt,
            slippedAt: slippedAt
        )

        if let index = sleepRuleSlips.firstIndex(where: {
            $0.rule == item.rule && Calendar.current.isDate($0.dueAt, equalTo: item.dueAt, toGranularity: .minute)
        }) {
            sleepRuleSlips[index] = slip
        } else {
            sleepRuleSlips.append(slip)
        }

        sleepRuleCompletions.removeAll {
            $0.rule == item.rule && Calendar.current.isDate($0.dueAt, equalTo: item.dueAt, toGranularity: .minute)
        }

        trackAnalytics("sleep_rule_slipped", [
            "sleep_rule": item.rule.rawValue,
            "due_at": Self.researchDateString(item.dueAt),
            "slipped_at": Self.researchDateString(slippedAt),
            "cooldown_minutes": "\(Self.missedHabitCooldownMinutes)"
        ])
        trackAnalytics("sleep_rule_cooldown_started", [
            "sleep_rule": item.rule.rawValue,
            "cooldown_minutes": "\(Self.missedHabitCooldownMinutes)"
        ])
        persist()
        scheduleAllNotifications()
        refreshAppBlockingShield(now: slippedAt)
    }

    func isSleepRuleCompleted(_ rule: SleepRuleKind, now: Date = Date()) -> Bool {
        let item = sleepContractItem(for: rule, on: now)
        return item.completion != nil
    }

    func hasClearedContractDay(now: Date = Date()) -> Bool {
        let items = sleepWindowEntryItems(now: now)
        guard !items.isEmpty else { return false }
        return items.allSatisfy(\.isCompleted)
    }

    @discardableResult
    func recordContractAllClearIfNeeded(now: Date = Date()) -> ContractAllClearEvent? {
        guard hasClearedContractDay(now: now) else { return nil }
        let contractDay = contractAnchorDate(for: now)
        let calendar = Calendar.current
        let alreadyRecorded = contractAllClearEvents.contains {
            calendar.isDate($0.contractDay, inSameDayAs: contractDay)
        }
        guard !alreadyRecorded else { return nil }
        let event = ContractAllClearEvent(contractDay: contractDay, occurredAt: now)
        contractAllClearEvents.append(event)
        persist()
        trackAnalytics("contract_all_clear", [
            "rule_count": "\(sleepWindowEntryItems(now: now).count)"
        ])
        return event
    }

    func setSleepRuleTime(_ rule: SleepRuleKind, to time: Date) {
        guard !isContractEditingLocked() else {
            trackContractEditBlockedDuringLock("rule_time")
            return
        }
        var config = sleepRuleConfigurations[rule] ?? SleepRuleConfiguration()
        config.dueTime = time
        if rule == .morningSun {
            config = normalizedMorningSunConfiguration(config)
        }
        sleepRuleConfigurations[rule] = config
        persist()
        scheduleAllNotifications()
        refreshAppBlockingShield()
    }

    func setSleepRuleAvailableTime(_ rule: SleepRuleKind, to time: Date) {
        guard !isContractEditingLocked() else {
            trackContractEditBlockedDuringLock("rule_time")
            return
        }
        var config = sleepRuleConfigurations[rule] ?? SleepRuleConfiguration()
        config.availableTime = time
        if rule == .morningSun {
            config = normalizedMorningSunConfiguration(config)
        }
        sleepRuleConfigurations[rule] = config
        persist()
        scheduleAllNotifications()
        refreshAppBlockingShield()
    }

    func morningSunWindowLabel(on date: Date = Date()) -> String {
        let window = morningSunWindow(on: date)
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "Active from \(formatter.string(from: window.start)) to \(formatter.string(from: window.end))"
    }

    func setSleepRuleGraceMinutes(_ rule: SleepRuleKind, to minutes: Int) {
        guard !isContractEditingLocked() else {
            trackContractEditBlockedDuringLock("rule_grace")
            return
        }
        var config = sleepRuleConfigurations[rule] ?? SleepRuleConfiguration()
        config.graceMinutes = max(0, minutes)
        sleepRuleConfigurations[rule] = config
        persist()
        refreshAppBlockingShield()
    }

    func sleepRuleGraceMinutes(_ rule: SleepRuleKind) -> Int {
        sleepRuleConfigurations[rule]?.graceMinutes ?? rule.graceMinutes
    }

    func isContractEditingLocked(now: Date = Date()) -> Bool {
        appBlockingEnabled && hasConfiguredAppBlockingTargets && sleepContractSnapshot(now: now).isLocked
    }

    private func trackContractEditBlockedDuringLock(_ editType: String) {
        trackAnalytics("contract_edit_blocked_during_lock", [
            "edit_type": editType
        ])
    }

    func sleepContractSnapshot(now: Date = Date()) -> SleepContractEnforcementSnapshot {
        let items = todaysContractItems(now: now)
        let isSleepWindow = isWithinSleepWindow(now: now)
        let actionableSource = isSleepWindow ? contractItemsAround(now: now) : items
        let actionableCandidates = actionableSource
            .filter { !$0.isResolved && canCompleteSleepRule($0, now: now) }
            .filter { now.timeIntervalSince($0.dueAt) <= 18 * 60 * 60 }
            .sorted { lhs, rhs in
                if lhs.graceEndsAt != rhs.graceEndsAt { return lhs.graceEndsAt < rhs.graceEndsAt }
                return lhs.availableAt < rhs.availableAt
            }
        let actionable = Self.deduplicatedActionableItems(actionableCandidates)

        let lockState: SleepContractEnforcementSnapshot.LockState
        if isSleepWindow {
            lockState = .sleepWindow(until: nextOccurrence(of: appBlockingEndTime, after: now) ?? appBlockingEndTime)
        } else if let overdue = actionable.first(where: { $0.rule != .inBed && !$0.isResolved && now >= $0.graceEndsAt }) {
            lockState = .lockedByRule(overdue)
        } else if let cooldown = activeSleepContractCooldown(now: now) {
            lockState = .coolingDown(cooldown.item, until: cooldown.until)
        } else {
            lockState = .unlocked
        }

        return SleepContractEnforcementSnapshot(
            now: now,
            lockState: lockState,
            actionableItems: actionable,
            allItems: items
        )
    }

    private static func deduplicatedActionableItems(_ items: [SleepContractItem]) -> [SleepContractItem] {
        var keptRules = Set<SleepRuleKind>()
        return items.filter { item in
            if item.rule == .inBed {
                return keptRules.insert(item.rule).inserted
            }
            return true
        }
    }

    private func morningSunWindow(on date: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        let config = sleepRuleConfigurations[.morningSun]
        let start = Self.timeOnDay(
            config?.availableTime ?? MorningSunWindowDefaults.start(on: day, calendar: calendar),
            on: day,
            calendar: calendar
        )
        var end = Self.timeOnDay(
            config?.dueTime ?? MorningSunWindowDefaults.end(on: day, calendar: calendar),
            on: day,
            calendar: calendar
        )
        if end <= start {
            end = calendar.date(byAdding: .hour, value: 6, to: start) ?? end
        }
        return (start, end)
    }

    private func normalizedMorningSunConfiguration(_ config: SleepRuleConfiguration) -> SleepRuleConfiguration {
        var normalized = config
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: Date())
        let start = Self.timeOnDay(
            normalized.availableTime ?? MorningSunWindowDefaults.start(on: day, calendar: calendar),
            on: day,
            calendar: calendar
        )
        var end = Self.timeOnDay(
            normalized.dueTime ?? MorningSunWindowDefaults.end(on: day, calendar: calendar),
            on: day,
            calendar: calendar
        )
        if end <= start {
            end = calendar.date(byAdding: .minute, value: 30, to: start) ?? end
        }
        normalized.availableTime = start
        normalized.dueTime = end
        return normalized
    }

    private static func timeOnDay(_ time: Date, on day: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.date(
            bySettingHour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: 0,
            of: day
        ) ?? day
    }

    private func sleepRuleWindow(for rule: SleepRuleKind, on date: Date = Date()) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        if rule == .inBed {
            return inBedCheckpointWindow(on: date)
        }

        if rule == .morningSun {
            return morningSunWindow(on: date)
        }

        if let configured = sleepRuleConfigurations[rule]?.dueTime {
            let components = calendar.dateComponents([.hour, .minute], from: configured)
            let due = calendar.date(
                bySettingHour: components.hour ?? 0,
                minute: components.minute ?? 0,
                second: 0,
                of: date
            ) ?? date
            return (due, due)
        }

        let bedtimeComponents = calendar.dateComponents([.hour, .minute], from: typicalBedtime)
        let bedtime = calendar.date(
            bySettingHour: bedtimeComponents.hour ?? 22,
            minute: bedtimeComponents.minute ?? 30,
            second: 0,
            of: date
        ) ?? typicalBedtime
        let due = calendar.date(byAdding: .minute, value: -(rule.leadMinutesBeforeBed ?? 0), to: bedtime) ?? bedtime
        return (due, due)
    }

    private func inBedCheckpointWindow(on date: Date) -> (start: Date, end: Date) {
        let ruleItems = orderedSelectedSleepRules
            .filter { $0.isPreBedRule }
            .map { sleepContractItem(for: $0, on: date) }
        if !ruleItems.isEmpty, ruleItems.allSatisfy(\.isCompleted),
           let lastCompletion = ruleItems.compactMap(\.completion?.completedAt).max() {
            return (lastCompletion, lastCompletion)
        }

        let bedtimeComponents = Calendar.current.dateComponents([.hour, .minute], from: typicalBedtime)
        let bedtime = Calendar.current.date(
            bySettingHour: bedtimeComponents.hour ?? 22,
            minute: bedtimeComponents.minute ?? 30,
            second: 0,
            of: date
        ) ?? typicalBedtime
        if ruleItems.isEmpty {
            return (bedtime, bedtime)
        }
        if !ruleItems.isEmpty, ruleItems.allSatisfy(\.startsTomorrow) {
            return (bedtime, bedtime)
        }
        let lastRuleDue = ruleItems.map(\.dueAt).max() ?? bedtime
        return (lastRuleDue, lastRuleDue)
    }

    private func sleepContractItem(for rule: SleepRuleKind, on date: Date) -> SleepContractItem {
        let window = sleepRuleWindow(for: rule, on: date)
        let dueAt = window.end
        let graceEndsAt = Calendar.current.date(byAdding: .minute, value: sleepRuleGraceMinutes(rule), to: dueAt) ?? dueAt
        let activatedAt = sleepContractActivatedAt
        let startsTomorrow = activatedAt.map { activatedAt in
            if rule == .inBed && isWithinWindow(now: activatedAt, start: typicalBedtime, end: appBlockingEndTime) {
                return false
            }
            return Calendar.current.isDate(contractAnchorDate(for: activatedAt), inSameDayAs: contractAnchorDate(for: dueAt)) &&
            activatedAt > graceEndsAt
        } ?? false
        return SleepContractItem(
            rule: rule,
            availableAt: window.start,
            dueAt: dueAt,
            graceEndsAt: graceEndsAt,
            startsTomorrow: startsTomorrow,
            completion: completion(for: rule, dueAt: dueAt),
            slip: slip(for: rule, dueAt: dueAt)
        )
    }

    private func completion(for rule: SleepRuleKind, dueAt: Date) -> SleepRuleCompletion? {
        sleepRuleCompletions.first {
            $0.rule == rule && Calendar.current.isDate($0.dueAt, equalTo: dueAt, toGranularity: .minute)
        }
    }

    private func slip(for rule: SleepRuleKind, dueAt: Date) -> SleepRuleSlip? {
        sleepRuleSlips.first {
            $0.rule == rule && Calendar.current.isDate($0.dueAt, equalTo: dueAt, toGranularity: .minute)
        }
    }

    private func isInBedCheckpointUnlocked(_ item: SleepContractItem) -> Bool {
        guard item.rule == .inBed else { return true }
        let ruleItems = orderedSelectedSleepRules
            .filter { $0.isPreBedRule }
            .map { sleepContractItem(for: $0, on: item.dueAt) }
        let requiredTodayItems = ruleItems.filter { !$0.startsTomorrow }
        return requiredTodayItems.allSatisfy(\.isCompleted)
    }

    private func isInBedCheckpointAvailable(_ item: SleepContractItem, now: Date) -> Bool {
        guard item.rule == .inBed else { return true }
        let earlyAccessStart = Calendar.current.date(byAdding: .minute, value: -10, to: item.availableAt) ?? item.availableAt
        return now >= earlyAccessStart
    }

    private func sleepWindowEntryItems(now: Date = Date()) -> [SleepContractItem] {
        todaysContractItems(now: now).filter {
            !$0.startsTomorrow && ($0.rule == .inBed || $0.rule.isPreBedRule)
        }
    }

    private func contractItemsAround(now: Date) -> [SleepContractItem] {
        let calendar = Calendar.current
        let anchor = contractAnchorDate(for: now)
        return selectedSleepRules.flatMap { rule in
            [-1, 0, 1].compactMap { offset -> SleepContractItem? in
                guard let date = calendar.date(byAdding: .day, value: offset, to: anchor) else { return nil }
                return sleepContractItem(for: rule, on: date)
            }
        } + [-1, 0, 1].compactMap { offset -> SleepContractItem? in
            guard hasActiveSleepContract,
                  let date = calendar.date(byAdding: .day, value: offset, to: anchor) else { return nil }
            return sleepContractItem(for: .inBed, on: date)
        }
    }

    func todaysContractItems(now: Date = Date()) -> [SleepContractItem] {
        let anchor = contractAnchorDate(for: now)
        let rules = orderedSelectedSleepRules + (hasActiveSleepContract ? [.inBed] : [])
        return rules
            .map { rule in
                let date = rule.isWakeSideRule ? wakeSideRuleAnchorDate(for: now) : anchor
                return sleepContractItem(for: rule, on: date)
            }
            .sorted { lhs, rhs in
                if lhs.availableAt != rhs.availableAt { return lhs.availableAt < rhs.availableAt }
                return lhs.dueAt < rhs.dueAt
            }
    }

    private func contractAnchorDate(for now: Date) -> Date {
        bedtimeDate(for: now)
    }

    private func wakeSideRuleAnchorDate(for now: Date) -> Date {
        let calendar = Calendar.current
        let contractAnchor = contractAnchorDate(for: now)
        let bedtimeComponents = calendar.dateComponents([.hour, .minute], from: typicalBedtime)
        let bedMinute = (bedtimeComponents.hour ?? 22) * 60 + (bedtimeComponents.minute ?? 30)
        let wakeComponents = calendar.dateComponents([.hour, .minute], from: typicalWakeTime)
        let wakeMinute = (wakeComponents.hour ?? 7) * 60 + (wakeComponents.minute ?? 0)
        let nowMinute = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)

        // Before wake during an overnight sleep window, morning habits belong to calendar today.
        if bedMinute > wakeMinute, nowMinute < wakeMinute {
            return calendar.startOfDay(for: now)
        }
        return contractAnchor
    }

    private func contractItemToComplete(for rule: SleepRuleKind, now: Date) -> SleepContractItem {
        let candidates = contractItemsAround(now: now)
            .filter { $0.rule == rule }
            .sorted { abs($0.availableAt.timeIntervalSince(now)) < abs($1.availableAt.timeIntervalSince(now)) }

        if let available = candidates
            .filter({ $0.availableAt <= now && !$0.startsTomorrow })
            .sorted(by: { $0.availableAt > $1.availableAt })
            .first {
            return available
        }

        return candidates.first ?? sleepContractItem(for: rule, on: now)
    }

    private func activeSleepContractRuleLock(now: Date) -> SleepContractItem? {
        return contractItemsAround(now: now)
            .filter { $0.rule != .inBed }
            .filter { now.timeIntervalSince($0.dueAt) <= 18 * 60 * 60 }
            .sorted { $0.dueAt < $1.dueAt }
            .first { item in
                !item.isResolved && !item.startsTomorrow && now >= item.graceEndsAt
            }
    }

    private func activeSleepContractCooldown(now: Date) -> (item: SleepContractItem, until: Date)? {
        let cooldown = TimeInterval(Self.missedHabitCooldownMinutes * 60)
        return contractItemsAround(now: now)
            .filter { $0.rule != .inBed }
            .compactMap { item -> (SleepContractItem, Date)? in
                guard let slip = item.slip else { return nil }
                let until = slip.slippedAt.addingTimeInterval(cooldown)
                guard now < until else { return nil }
                return (item, until)
            }
            .sorted { $0.1 < $1.1 }
            .first
    }

    private func isWithinSleepWindow(now: Date = Date()) -> Bool {
        isWithinWindow(now: now, start: effectiveSleepWindowStart(now: now), end: appBlockingEndTime)
    }

    func effectiveSleepWindowStart(now: Date = Date()) -> Date {
        scheduledSleepWindowStart(now: now)
    }

    private func scheduledSleepWindowStart(now: Date) -> Date {
        let calendar = Calendar.current
        let anchor = contractAnchorDate(for: now)
        let bedtimeComponents = calendar.dateComponents([.hour, .minute], from: typicalBedtime)
        return calendar.date(
            bySettingHour: bedtimeComponents.hour ?? 22,
            minute: bedtimeComponents.minute ?? 30,
            second: 0,
            of: anchor
        ) ?? typicalBedtime
    }

    private func isWithinWindow(now: Date, start: Date, end: Date) -> Bool {
        let cal = Calendar.current
        let nowMins = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        let startMins = cal.component(.hour, from: start) * 60 + cal.component(.minute, from: start)
        let endMins = cal.component(.hour, from: end) * 60 + cal.component(.minute, from: end)

        if startMins == endMins { return true }
        if startMins < endMins {
            return nowMins >= startMins && nowMins < endMins
        }
        return nowMins >= startMins || nowMins < endMins
    }

    func refreshAppBlockingShield(now: Date = Date()) {
        expireEmergencyAppAccessIfNeeded(now: now)
        guard hasPremiumAccess else {
            appBlockingStore.clearAllSettings()
            rescheduleDeviceActivityMonitors(now: now, hasConfiguration: false)
            scheduleNextAppBlockingShieldRefresh(now: now, hasConfiguration: false)
            return
        }
        let hasTargets = !appBlockingSelection.applicationTokens.isEmpty || !appBlockingSelection.categoryTokens.isEmpty
        let bypassed = paywallState.gentleBlockingBypassedUntil.map { now < $0 } ?? false
        let emergencyAccessActive = activeEmergencyAppAccessEnd(now: now) != nil
        syncEmergencyAppAccessContext()
        let snapshot = sleepContractSnapshot(now: now)
        let contractRuleLock: SleepContractItem?
        let shieldReason: String
        switch snapshot.lockState {
        case .lockedByRule(let item), .coolingDown(let item, _):
            contractRuleLock = item
            shieldReason = "rule"
        case .sleepWindow:
            contractRuleLock = nil
            shieldReason = "sleep_window"
        case .unlocked:
            contractRuleLock = nil
            shieldReason = "time_window"
        }
        syncShieldContext(
            reason: shieldReason,
            ruleTitle: contractRuleLock?.rule.title
        )
        let contractLockActive = appBlockingEnabled &&
            hasTargets &&
            snapshot.isLocked
        let shouldApply = contractLockActive &&
            (canUseHardAppBlocking || !bypassed) &&
            !emergencyAccessActive

        if shouldApply {
            appBlockingStore.shield.applications = appBlockingSelection.applicationTokens.isEmpty ? nil : appBlockingSelection.applicationTokens
            appBlockingStore.shield.applicationCategories = appBlockingSelection.categoryTokens.isEmpty ? nil : .specific(appBlockingSelection.categoryTokens)
            recordContractLockActivationIfNeeded(snapshot: snapshot, now: now)
        } else {
            appBlockingStore.clearAllSettings()
        }

        let hasMonitorConfiguration = appBlockingEnabled &&
            hasTargets
        rescheduleDeviceActivityMonitors(now: now, hasConfiguration: hasMonitorConfiguration)
        scheduleNextAppBlockingShieldRefresh(now: now, hasConfiguration: appBlockingEnabled && hasTargets)
    }

    private func recordContractLockActivationIfNeeded(snapshot: SleepContractEnforcementSnapshot, now: Date) {
        guard shouldRecordContractLockActivation(snapshot: snapshot, now: now) else { return }

        let eventKind: ContractLockEvent.Kind
        let eventRule: SleepRuleKind?
        switch snapshot.lockState {
        case .lockedByRule(let item), .coolingDown(let item, _):
            eventKind = .rule
            eventRule = item.rule
        case .sleepWindow:
            eventKind = .sleepWindow
            eventRule = nil
        case .unlocked:
            return
        }

        let alreadyRecorded = contractLockEvents.contains { event in
            event.kind == eventKind &&
            event.rule == eventRule &&
            lockEvent(event, matchesContractDayOf: now)
        }
        guard !alreadyRecorded else { return }
        contractLockEvents.append(ContractLockEvent(kind: eventKind, rule: eventRule, occurredAt: now))
        persist()
        sendAppLockNotification(kind: eventKind, rule: eventRule, occurredAt: now)
    }

    func shouldRecordContractLockActivation(snapshot: SleepContractEnforcementSnapshot, now: Date) -> Bool {
        guard hasCompletedOnboarding, sleepContractActivatedAt != nil else { return false }
        switch snapshot.lockState {
        case .lockedByRule, .coolingDown, .sleepWindow:
            return true
        case .unlocked:
            return false
        }
    }

    private func sendAppLockNotification(kind: ContractLockEvent.Kind, rule: SleepRuleKind?, occurredAt: Date) {
        let content = UNMutableNotificationContent()
        content.sound = .default
        content.categoryIdentifier = "APP_LOCKED"
        content.interruptionLevel = .timeSensitive
        content.relevanceScore = 1.0

        switch kind {
        case .rule:
            content.title = "Apps locked"
            if let rule {
                content.body = "\(rule.title) was missed. Open TenThirty and hold to confirm it late."
            } else {
                content.body = "A sleep rule was missed. Open TenThirty and hold to confirm it late."
            }
        case .sleepWindow:
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            content.title = "Sleep window started"
            content.body = "Your selected apps are locked until \(formatter.string(from: typicalWakeTime))."
        }

        let dayKey = Self.researchDateString(occurredAt).replacingOccurrences(of: ":", with: "-")
        let ruleKey = rule?.rawValue ?? "sleep-window"
        let request = UNNotificationRequest(
            identifier: "app_lock_\(kind.rawValue)_\(ruleKey)_\(dayKey)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    func lockEvent(_ event: ContractLockEvent, matchesContractDayOf date: Date) -> Bool {
        let calendar = Calendar.current
        switch event.kind {
        case .sleepWindow:
            return calendar.isDate(contractDay(forLockEvent: event), inSameDayAs: contractAnchorDate(for: date))
        case .rule:
            return calendar.isDate(event.occurredAt, inSameDayAs: date)
        }
    }

    func contractDay(forLockEvent event: ContractLockEvent) -> Date {
        switch event.kind {
        case .sleepWindow:
            return contractAnchorDate(for: event.occurredAt)
        case .rule:
            return Calendar.current.startOfDay(for: event.occurredAt)
        }
    }

    private func syncShieldContext(reason: String, ruleTitle: String?) {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let wakeText = formatter.string(from: typicalWakeTime)
        let defaults = UserDefaults(suiteName: Self.appGroupSuite)
        defaults?.set(wakeText, forKey: Self.shieldWakeTimeTextKey)
        defaults?.set(reason, forKey: Self.shieldLockReasonKey)
        defaults?.set(ruleTitle, forKey: Self.shieldRuleTitleKey)
        defaults?.synchronize()
    }

    private func syncEmergencyAppAccessContext() {
        let defaults = UserDefaults(suiteName: Self.appGroupSuite)
        if let endsAt = emergencyAppAccessSession?.endsAt, Date() < endsAt {
            defaults?.set(endsAt, forKey: Self.emergencyAppAccessUntilKey)
        } else {
            defaults?.removeObject(forKey: Self.emergencyAppAccessUntilKey)
        }
        if !canUseHardAppBlocking,
           let bypassUntil = paywallState.gentleBlockingBypassedUntil,
           Date() < bypassUntil {
            defaults?.set(bypassUntil, forKey: Self.gentleBypassUntilKey)
        } else {
            defaults?.removeObject(forKey: Self.gentleBypassUntilKey)
        }
        defaults?.synchronize()
    }

    private func scheduleNextAppBlockingShieldRefresh(now: Date, hasConfiguration: Bool) {
        appBlockingRefreshWorkItem?.cancel()
        appBlockingRefreshWorkItem = nil

        guard hasConfiguration else { return }

        let candidates = [
            nextAppBlockingBoundary(after: now),
            nextSleepContractBoundary(after: now),
            activeEmergencyAppAccessEnd(now: now)
        ].compactMap { $0 }
        guard let nextBoundary = candidates.min() else { return }

        let delay = max(1, nextBoundary.timeIntervalSince(now) + 1)
        let workItem = DispatchWorkItem { [weak self] in
            self?.refreshAppBlockingShield()
        }
        appBlockingRefreshWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func rescheduleDeviceActivityMonitors(now: Date, hasConfiguration: Bool) {
        let priorNames = AppBlockingMonitorStore.activityNames()

        guard hasConfiguration else {
            if !priorNames.isEmpty {
                deviceActivityCenter.stopMonitoring(priorNames)
            }
            AppBlockingMonitorStore.clearSchedule()
            return
        }

        let windows = appBlockingMonitorWindows(now: now)
        guard !windows.isEmpty else {
            if !priorNames.isEmpty {
                deviceActivityCenter.stopMonitoring(priorNames)
            }
            AppBlockingMonitorStore.save(selection: appBlockingSelection, windows: [])
            AppBlockingMonitorStore.saveActivityNames([])
            return
        }

        AppBlockingMonitorStore.save(selection: appBlockingSelection, windows: windows)
        if !priorNames.isEmpty {
            deviceActivityCenter.stopMonitoring(priorNames)
        }

        var schedulingFailures: [String] = []
        let scheduledNames = windows.compactMap { window -> DeviceActivityName? in
            let activityName = DeviceActivityName("tenthirty.lock.\(window.id)")
            guard let schedule = deviceActivitySchedule(for: window, now: now) else { return nil }
            do {
                try deviceActivityCenter.startMonitoring(activityName, during: schedule)
                return activityName
            } catch {
                schedulingFailures.append(activityName.rawValue)
                #if DEBUG
                print("[DeviceActivity] Failed to schedule \(activityName.rawValue): \(error.localizedDescription)")
                #endif
                return nil
            }
        }
        AppBlockingMonitorStore.saveActivityNames(scheduledNames)
        if !schedulingFailures.isEmpty {
            trackAnalytics("app_blocking_monitor_schedule_failed", [
                "expected_count": "\(windows.count)",
                "scheduled_count": "\(scheduledNames.count)",
                "failed_activities": schedulingFailures.joined(separator: ",")
            ])
        }
    }

    func appBlockingMonitorWindows(now: Date) -> [AppBlockingMonitorWindow] {
        let calendar = Calendar.current
        let wakeText = formattedAppBlockingWakeTime()
        var windows: [AppBlockingMonitorWindow] = []

        let anchor = contractAnchorDate(for: now)
        let ruleAnchors = [0, 1, 2].compactMap { calendar.date(byAdding: .day, value: $0, to: anchor) }
        for rule in orderedSelectedSleepRules {
            let nextUnresolvedItem = ruleAnchors
                .map { sleepContractItem(for: rule, on: $0) }
                .filter { !$0.isResolved && !$0.startsTomorrow }
                .sorted { $0.graceEndsAt < $1.graceEndsAt }
                .first { ruleLockMonitorEnd(start: $0.graceEndsAt) > now }
            guard let item = nextUnresolvedItem else { continue }
            let start = item.graceEndsAt
            windows.append(AppBlockingMonitorWindow(
                id: "rule.\(item.rule.rawValue)",
                start: start,
                end: ruleLockMonitorEnd(start: start),
                reason: .rule,
                ruleTitle: item.rule.title,
                wakeTimeText: wakeText,
                recurrence: .daily
            ))
        }

        let nextSleepWindow = [-1, 0, 1]
            .compactMap { calendar.date(byAdding: .day, value: $0, to: anchor) }
            .map { sleepWindowStart(onContractDay: $0) }
            .map { ($0, sleepWindowMonitorEnd(start: $0)) }
            .sorted { $0.0 < $1.0 }
            .first { $0.1 > now }
        if let (start, end) = nextSleepWindow {
            windows.append(AppBlockingMonitorWindow(
                id: "sleep",
                start: start,
                end: end,
                reason: .sleepWindow,
                ruleTitle: nil,
                wakeTimeText: wakeText,
                recurrence: .daily
            ))
        }

        let cooldown = activeSleepContractCooldown(now: now)
        if let cooldown {
            windows.append(AppBlockingMonitorWindow(
                id: monitorWindowID(prefix: "cooldown", rule: cooldown.item.rule, start: now),
                start: now,
                end: cooldown.until,
                reason: .rule,
                ruleTitle: cooldown.item.rule.title,
                wakeTimeText: wakeText
            ))
        }

        let resumeBoundaries = [
            activeEmergencyAppAccessEnd(now: now).map { ("emergency", $0) },
            paywallState.gentleBlockingBypassedUntil.flatMap {
                !canUseHardAppBlocking && now < $0 ? ("bypass", $0) : nil
            },
            cooldown.map { ("cooldown", $0.until) }
        ].compactMap { $0 }
        for (kind, start) in resumeBoundaries {
            windows.append(AppBlockingMonitorWindow(
                id: "reconcile.\(kind).\(Int(start.timeIntervalSince1970))",
                start: start,
                // DeviceActivity rejects intervals shorter than 15 minutes.
                // This window never shields; its start callback only reconciles
                // the recurring base windows after temporary access expires.
                end: start.addingTimeInterval(15 * 60),
                reason: .reconcile,
                ruleTitle: nil,
                wakeTimeText: wakeText
            ))
        }

        return Array(Dictionary(grouping: windows, by: \.id).compactMap { $0.value.first })
            .sorted { lhs, rhs in
                if lhs.start != rhs.start { return lhs.start < rhs.start }
                return lhs.id < rhs.id
            }
    }

    func deviceActivitySchedule(for window: AppBlockingMonitorWindow, now: Date) -> DeviceActivitySchedule? {
        let calendar = Calendar.current
        if window.recurrence == .daily {
            let startComponents = DateComponents(
                hour: window.startMinuteOfDay / 60,
                minute: window.startMinuteOfDay % 60
            )
            let endComponents = DateComponents(
                hour: window.endMinuteOfDay / 60,
                minute: window.endMinuteOfDay % 60
            )
            return DeviceActivitySchedule(intervalStart: startComponents, intervalEnd: endComponents, repeats: true)
        }
        let start = max(window.start, now.addingTimeInterval(2))
        guard window.end > start else { return nil }
        // DeviceActivity requires at least a 15-minute interval. A separate
        // reconciliation window at the semantic boundary prevents padding a
        // shorter cooldown from extending the actual lock.
        let end = max(window.end, start.addingTimeInterval(15 * 60))
        var startComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: start)
        startComponents.calendar = calendar
        startComponents.timeZone = calendar.timeZone
        var endComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: end)
        endComponents.calendar = calendar
        endComponents.timeZone = calendar.timeZone
        return DeviceActivitySchedule(intervalStart: startComponents, intervalEnd: endComponents, repeats: false)
    }

    private func monitorWindowID(prefix: String, rule: SleepRuleKind?, start: Date) -> String {
        let timestamp = Int(start.timeIntervalSince1970)
        if let rule {
            return "\(prefix).\(rule.rawValue).\(timestamp)"
        }
        return "\(prefix).\(timestamp)"
    }

    private func ruleLockMonitorEnd(start: Date) -> Date {
        sleepWindowMonitorEnd(start: start)
    }

    private func sleepWindowStart(onContractDay contractDay: Date) -> Date {
        let calendar = Calendar.current
        let bedtimeComponents = calendar.dateComponents([.hour, .minute], from: typicalBedtime)
        return calendar.date(
            bySettingHour: bedtimeComponents.hour ?? 22,
            minute: bedtimeComponents.minute ?? 30,
            second: 0,
            of: contractDay
        ) ?? contractDay
    }

    private func sleepWindowMonitorEnd(start: Date) -> Date {
        nextOccurrence(of: appBlockingEndTime, after: start) ?? start.addingTimeInterval(18 * 60 * 60)
    }

    private func formattedAppBlockingWakeTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: typicalWakeTime)
    }

    private func nextAppBlockingBoundary(after now: Date) -> Date? {
        let cal = Calendar.current
        let activeStart = canUseHardAppBlocking ? appBlockingStartTime : typicalBedtime
        let startMins = cal.component(.hour, from: activeStart) * 60 + cal.component(.minute, from: activeStart)
        let endMins = cal.component(.hour, from: appBlockingEndTime) * 60 + cal.component(.minute, from: appBlockingEndTime)
        guard startMins != endMins else { return nil }

        let boundary = isWithinAppBlockingWindow(now: now) ? appBlockingEndTime : activeStart
        return nextOccurrence(of: boundary, after: now)
    }

    private func nextSleepContractBoundary(after now: Date) -> Date? {
        let cooldown = TimeInterval(Self.missedHabitCooldownMinutes * 60)
        let ruleBoundaries = contractItemsAround(now: now).flatMap { item -> [Date] in
            var dates = [item.dueAt, item.graceEndsAt]
            if let slip = item.slip {
                dates.append(slip.slippedAt.addingTimeInterval(cooldown))
            }
            return dates
        }
        let sleepBoundaries = [
            nextOccurrence(of: effectiveSleepWindowStart(now: now), after: now),
            nextOccurrence(of: appBlockingEndTime, after: now)
        ].compactMap { $0 }
        return (ruleBoundaries + sleepBoundaries)
            .filter { $0 > now }
            .min()
    }

    private func nextOccurrence(of wallClockDate: Date, after now: Date) -> Date? {
        let cal = Calendar.current
        let components = cal.dateComponents([.hour, .minute], from: wallClockDate)
        guard let hour = components.hour,
              let minute = components.minute,
              let today = cal.date(bySettingHour: hour, minute: minute, second: 0, of: now) else {
            return nil
        }
        if today > now { return today }
        return cal.date(byAdding: .day, value: 1, to: today)
    }

    func bypassGentleAppBlockingUntilTomorrow(now: Date = Date()) {
        guard !canUseHardAppBlocking else { return }
        let cal = Calendar.current
        let wakeComponents = cal.dateComponents([.hour, .minute], from: typicalWakeTime)
        let todayWake = cal.date(
            bySettingHour: wakeComponents.hour ?? 7,
            minute: wakeComponents.minute ?? 0,
            second: 0,
            of: now
        ) ?? now
        let bypassEnd = now < todayWake
            ? todayWake
            : (cal.date(byAdding: .day, value: 1, to: todayWake) ?? now.addingTimeInterval(24 * 60 * 60))
        paywallState.gentleBlockingBypassedUntil = bypassEnd
        trackAnalytics("app_blocking_bypassed", [
            "blocking_mode": "gentle"
        ])
        persist()
        refreshAppBlockingShield(now: now)
    }

    var hasActiveEmergencyAppAccess: Bool {
        activeEmergencyAppAccessEnd() != nil
    }

    func activeEmergencyAppAccessEnd(now: Date = Date()) -> Date? {
        guard let session = emergencyAppAccessSession, now < session.endsAt else { return nil }
        return session.endsAt
    }

    func startEmergencyAppAccess(reason: EmergencyAppAccessReason,
                                 duration: EmergencyAppAccessDuration,
                                 now: Date = Date()) {
        let endsAt = now.addingTimeInterval(duration.timeInterval)
        emergencyAppAccessSession = EmergencyAppAccessSession(
            reason: reason,
            duration: duration,
            startedAt: now,
            endsAt: endsAt
        )
        syncEmergencyAppAccessContext()
        trackAnalytics("emergency_app_access_started", [
            "reason": reason.rawValue,
            "duration_minutes": "\(duration.rawValue)"
        ])
        persist()
        refreshAppBlockingShield(now: now)
    }

    private func expireEmergencyAppAccessIfNeeded(now: Date = Date()) {
        if let session = emergencyAppAccessSession, now >= session.endsAt {
            emergencyAppAccessSession = nil
            syncEmergencyAppAccessContext()
            persist()
        }
    }

    func isWithinAppBlockingWindow(now: Date = Date()) -> Bool {
        let cal = Calendar.current
        let nowMins = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        let activeStart = canUseHardAppBlocking ? appBlockingStartTime : typicalBedtime
        let startMins = cal.component(.hour, from: activeStart) * 60 + cal.component(.minute, from: activeStart)
        let endMins = cal.component(.hour, from: appBlockingEndTime) * 60 + cal.component(.minute, from: appBlockingEndTime)

        if startMins == endMins { return true }
        if startMins < endMins {
            return nowMins >= startMins && nowMins < endMins
        }
        return nowMins >= startMins || nowMins < endMins
    }

    // Upserts the current sleep-window log and persists.
    func updateTodayLog(at date: Date = Date(), _ mutation: (inout SleepLogEntry) -> Void) {
        let bedtimeDay = bedtimeDate(for: date)
        let calendar = Calendar.current

        if let idx = sleepLogs.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: bedtimeDay) }) {
            mutation(&sleepLogs[idx])
        } else {
            var entry = SleepLogEntry(date: bedtimeDay, variable: tonightVariable, score: 0)
            entry.variableRemedyId = tonightRemedyId
            mutation(&entry)
            sleepLogs.append(entry)
        }
        persist()
    }

    func recordGuidedWindDownCompleted(at completedAt: Date = Date()) {
        let bedtimeDay = bedtimeDate(for: completedAt)
        updateTodayLog(at: completedAt) {
            $0.date = bedtimeDay
            $0.completedNightlyFlow = true
            $0.actualBedtime = completedAt
        }
        markAllRitualDone()
        queueStreakMilestoneIfNeeded()
        persist()
        recordNightlySessionCompleted()
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
        guard canCompleteOnboardingAfterPurchase() else { return }
        initialTab = 0
        pendingOnboardingFireflyHandoff = isOnboardingFireflyCompanionActive && !hasSeenFirstFireflyPrompt
        sleepContractActivatedAt = sleepContractActivatedAt ?? Date()
        hasCompletedOnboarding = true
        persist()
        scheduleNotificationsAfterCommitmentIfNeeded()
        recordOnboardingTelemetry(route: "home")
    }

    func completeOnboardingToRoutine() {
        guard canCompleteOnboardingAfterPurchase() else { return }
        initialTab = 1
        pendingOnboardingFireflyHandoff = isOnboardingFireflyCompanionActive && !hasSeenFirstFireflyPrompt
        sleepContractActivatedAt = sleepContractActivatedAt ?? Date()
        hasCompletedOnboarding = true
        persist()
        scheduleNotificationsAfterCommitmentIfNeeded()
        recordOnboardingTelemetry(route: "rules")
    }

    func completeOnboardingAndStartRitual() {
        guard canCompleteOnboardingAfterPurchase() else { return }
        initialTab = 0
        requestedTab = 0
        pendingOnboardingFireflyHandoff = isOnboardingFireflyCompanionActive && !hasSeenFirstFireflyPrompt
        sleepContractActivatedAt = sleepContractActivatedAt ?? Date()
        hasCompletedOnboarding = true
        showNightlyFlow = false
        persist()
        scheduleNotificationsAfterCommitmentIfNeeded()
        recordOnboardingTelemetry(route: "start_ritual")
    }

    private func canCompleteOnboardingAfterPurchase() -> Bool {
        true
    }

    func commitRoutineReminder(at time: Date) {
        committedRoutineTime = time
        persist()
        scheduleAllNotifications()
    }

    private func scheduleNotificationsAfterCommitmentIfNeeded() {
        scheduleAllNotifications()
    }

    func logMorningScore() {
        let score = Self.clampedSleepScore(morningScore)
        morningScore = score
        let shouldQueueFirstNightReview = shouldQueueFirstNightReviewRequest()
        var loggedEntry: SleepLogEntry?

        if let idx = ratableEntryIndex {
            sleepLogs[idx].score            = score
            sleepLogs[idx].variable         = tonightVariable
            sleepLogs[idx].variableRemedyId = tonightRemedyId
            sleepLogs[idx].actualWakeTime   = Date()
            sleepLogs[idx].hoursSlept       = morningHoursSlept
            loggedEntry = sleepLogs[idx]
        } else {
            // No recent unrated entry — create one for the sleep window that
            // just ended. This handles both overnight and same-day sleep windows.
            let cal = Calendar.current
            let now = Date()
            let wakeComponents = cal.dateComponents([.hour, .minute], from: typicalWakeTime)
            let wake = cal.date(
                bySettingHour: wakeComponents.hour ?? 7,
                minute: wakeComponents.minute ?? 0,
                second: 0,
                of: now
            ) ?? now
            let bedtimeDay = bedtimeDate(forWakeTime: wake, calendar: cal)
            var entry = SleepLogEntry(date: bedtimeDay, variable: tonightVariable, score: score)
            entry.variableRemedyId = tonightRemedyId
            entry.actualWakeTime   = Date()
            entry.hoursSlept       = morningHoursSlept
            sleepLogs.append(entry)
            loggedEntry = entry
        }
        clearObsoleteNotifications()
        justTriggeredNightFivePaywall = false
        persist()
        if let loggedEntry {
            recordMorningTelemetry(entry: loggedEntry)
        }
        if shouldQueueFirstNightReview {
            UserDefaults.standard.set(true, forKey: Self.firstNightReviewRequestKey)
            shouldRequestReviewAfterFirstNight = true
            trackAnalytics("app_review_request_queued", [
                "trigger": "first_night"
            ])
        }
        presentPendingStreakMilestoneIfEligible()
    }

    private func shouldQueueFirstNightReviewRequest() -> Bool {
        guard !UserDefaults.standard.bool(forKey: Self.firstNightReviewRequestKey) else { return false }
        guard !UserDefaults.standard.bool(forKey: Self.firstNightReviewRequestAttemptedKey) else { return false }
        return !sleepLogs.contains { $0.score > 0 }
    }

    func consumeFirstNightReviewRequest() {
        UserDefaults.standard.removeObject(forKey: Self.firstNightReviewRequestKey)
        UserDefaults.standard.set(true, forKey: Self.firstNightReviewRequestAttemptedKey)
        shouldRequestReviewAfterFirstNight = false
    }

    private func shouldTriggerNightFivePaywall(statusBefore: ExperimentEngine.Status?,
                                               statusAfter: ExperimentEngine.Status?) -> Bool {
        false
    }

    func recordVerdictShareAttempt(source: ShareUnlockSource) {
        trackAnalytics("verdict_share_attempted", [
            "share_source": source.rawValue,
            "logged_night_count": "\(loggedNightCount)"
        ])
    }

    func unlockVerdict(method: UnlockMethod) {
        paywallState.unlockMethod = method
        paywallState.verdictRevealed = true
        switch method {
        case .subscribe(let plan):
            paywallState.tier = .subscribed
            trackAnalytics("verdict_unlocked", [
                "unlock_method": "subscribe",
                "plan": plan.rawValue,
                "logged_night_count": "\(loggedNightCount)"
            ])
        case .share(let source):
            paywallState.tier = .shareUnlocked
            trackAnalytics("verdict_unlocked", [
                "unlock_method": "share",
                "share_source": source.rawValue,
                "logged_night_count": "\(loggedNightCount)"
            ])
        }
        persist()
    }

    func applyRevenueCatEntitlement(isActive: Bool) {
        if isActive {
            activeRevenueCatPaywall = nil
            let wasFree = paywallState.tier == .free
            let previousTier = paywallState.tier
            paywallState.tier = .subscribed
            paywallState.verdictRevealed = true
            if previousTier != .subscribed {
                trackAnalytics("premium_entitlement_active", [
                    "previous_tier": previousTier.rawValue,
                    "logged_night_count": "\(loggedNightCount)"
                ])
            }
            if wasFree {
                restorePremiumRoutineIfAvailable()
                scheduleAllNotifications()
            }
        } else if paywallState.tier == .subscribed {
            let fallbackTier = paywallState.isTrialActive() ? UserTier.trial : UserTier.free
            paywallState.tier = paywallState.isTrialActive() ? .trial : .free
            paywallState.unlockMethod = nil
            paywallState.verdictRevealed = false
            trackAnalytics("premium_entitlement_inactive", [
                "fallback_tier": fallbackTier.rawValue,
                "logged_night_count": "\(loggedNightCount)"
            ])
            if paywallState.tier == .free {
                restoreFreeRoutine()
                markSubscriptionRequired(reason: "revenuecat_entitlement_inactive")
            }
        }
        persist()
    }

    func markFreeForever() {
        paywallState.tier = .freeForever
        paywallState.verdictRevealed = false
        paywallState.unlockMethod = nil
        trackAnalytics("free_forever_selected", [
            "logged_night_count": "\(loggedNightCount)"
        ])
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
        trackAnalytics("day14_prompt_dismissed", [
            "dismissal_count": "\(paywallState.dismissalCount)",
            "logged_night_count": "\(loggedNightCount)"
        ])
        persist()
    }

    func seedDay14Verdict() {
        activePaywallVerdict = buildVerdictSnapshotFromRecentLogs()
        paywallState.tier = .paywallPending
        paywallState.verdictRevealed = false
        trackAnalytics("day14_verdict_requested", [
            "logged_night_count": "\(loggedNightCount)"
        ])
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
        captureTrialRoutineEdit()
        logRoutineUpdated(kind: "reorder", stepID: section.first?.id)
        persist()
        rescheduleRoutineSurfaces()
    }

    func moveWindDown(from source: IndexSet, to destination: Int) {
        var section = windDownSteps
        section.move(fromOffsets: source, toOffset: destination)
        coreRoutine = preWindDownSteps + section
        normalizeRoutineOrder()
        captureTrialRoutineEdit()
        logRoutineUpdated(kind: "reorder", stepID: section.first?.id)
        persist()
        rescheduleRoutineSurfaces()
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
        captureTrialRoutineEdit()
        logRoutineUpdated(kind: "reorder", stepID: moving.id)
        persist()
        rescheduleRoutineSurfaces()
    }

    func moveRoutineStep(_ moving: RoutineStep, toIndex targetIndex: Int, in sectionKind: RoutineSectionKind) {
        var section = sectionKind == .prep ? routinePrepSteps : routineRitualSteps
        guard let from = section.firstIndex(where: { $0.id == moving.id }) else { return }

        let clampedTarget = min(max(targetIndex, 0), section.count - 1)
        guard from != clampedTarget else { return }

        section.move(fromOffsets: IndexSet(integer: from), toOffset: clampedTarget > from ? clampedTarget + 1 : clampedTarget)

        switch sectionKind {
        case .prep:
            coreRoutine = section + routineRitualSteps
        case .ritual:
            coreRoutine = routinePrepSteps + section
        case .morning:
            return
        }

        normalizeRoutineOrder()
        captureTrialRoutineEdit()
        logRoutineUpdated(kind: "reorder", stepID: moving.id)
        persist()
        rescheduleRoutineSurfaces()
    }

    @discardableResult
    func addRoutineStep(from item: RoutineLibraryStep) -> RoutineStep {
        guard canCustomizeRoutine else {
            presentUpgradePaywall()
            return RoutineStep(order: coreRoutine.count + 1, label: item.label, mode: .reminderOnly)
        }
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
        if item.id == "story" {
            step.boringStoryConfig = .fresh
            step.durationLabel = BoringStoryStepConfig.fresh.durationSummary
            step.remedyId = .boringStory
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
        captureTrialRoutineEdit()
        logRoutineUpdated(kind: "add", stepID: step.id)
        persist()
        rescheduleRoutineSurfaces()
        return step
    }

    func updateRoutineStep(_ updated: RoutineStep) {
        guard canCustomizeRoutine else {
            presentUpgradePaywall()
            return
        }
        guard let idx = coreRoutine.firstIndex(where: { $0.id == updated.id }) else { return }
        let previous = coreRoutine[idx]
        if previous.label != updated.label {
            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: ["bedtime_prep_\(previous.label)"]
            )
            trackAnalytics("routine_step_swapped", [
                "from_remedy_id": previous.remedyId?.rawValue ?? "",
                "to_remedy_id": updated.remedyId?.rawValue ?? "",
                "from_step_mode": previous.mode.rawValue,
                "to_step_mode": updated.mode.rawValue,
                "routine_step_count": "\(coreRoutine.count)"
            ])
        }
        coreRoutine[idx] = updated
        normalizeRoutineOrder()
        captureTrialRoutineEdit()
        logRoutineUpdated(kind: "edit", stepID: updated.id)
        persist()
        rescheduleRoutineSurfaces()
    }

    func removeRoutineStep(_ step: RoutineStep) {
        guard canCustomizeRoutine else {
            presentUpgradePaywall()
            return
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["bedtime_prep_\(step.label)"]
        )
        coreRoutine.removeAll { $0.id == step.id }
        normalizeRoutineOrder()
        if step.mode == .experiment {
            #if DEBUG
            print("[Analytics] experiment_aborted step_id=\(step.id.uuidString) label=\"\(step.label)\"")
            #endif
        }
        captureTrialRoutineEdit()
        logRoutineUpdated(kind: "remove", stepID: step.id)
        persist()
        rescheduleRoutineSurfaces()
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
        let step = stepID.flatMap { id in coreRoutine.first(where: { $0.id == id }) }
        trackAnalytics("routine_updated", [
            "update_kind": kind,
            "remedy_id": step?.remedyId?.rawValue ?? "",
            "step_mode": step?.mode.rawValue ?? "",
            "routine_step_count": "\(coreRoutine.count)",
            "prep_step_count": "\(preWindDownSteps.count)",
            "ritual_step_count": "\(windDownSteps.count)"
        ])
        #if DEBUG
        print("[Analytics] routine_updated kind=\(kind) step_id=\(stepID?.uuidString ?? "unknown")")
        #endif
    }

    private func rescheduleRoutineSurfaces() {
        scheduleBedtimePrepNotifications()
        refreshPrepLiveActivityIfEligible()
    }

    @AppStorage("variableIsOverridden") var variableIsOverridden: Bool = false

    func changeExperimentVariable(to label: String) {
        guard canCustomizeRoutine else {
            presentUpgradePaywall()
            return
        }
        let previous = coreRoutine.first { $0.mode == .experiment }
        let nextRemedyId = RemedyID.fromLabel(label)
        coreRoutine.removeAll { $0.mode == .experiment }
        coreRoutine.append(RoutineStep(
            order: coreRoutine.count + 1,
            label: label,
            mode: .experiment,
            remedyId: nextRemedyId
        ))
        variableIsOverridden = true
        captureTrialRoutineEdit()
        trackAnalytics("routine_variable_swapped", [
            "from_remedy_id": previous?.remedyId?.rawValue ?? "",
            "to_remedy_id": nextRemedyId?.rawValue ?? "",
            "routine_step_count": "\(coreRoutine.count)"
        ])
        persist()
        rescheduleRoutineSurfaces()
    }

    func resetToSuggestedVariable() {
        guard canCustomizeRoutine else {
            presentUpgradePaywall()
            return
        }
        let routineWithoutExperiment = coreRoutine.filter { $0.mode != .experiment }
        guard let suggested = ExperimentEngine.suggestNextVariable(
            logs: sleepLogs,
            coreRoutine: routineWithoutExperiment,
            remedyScores: remedyScores
        ) else { return }
        let previous = coreRoutine.first { $0.mode == .experiment }
        let nextRemedyId = RemedyID.fromLabel(suggested)
        coreRoutine.removeAll { $0.mode == .experiment }
        coreRoutine.append(RoutineStep(
            order: coreRoutine.count + 1,
            label: suggested,
            mode: .experiment,
            remedyId: nextRemedyId
        ))
        variableIsOverridden = false
        captureTrialRoutineEdit()
        trackAnalytics("routine_variable_reset", [
            "from_remedy_id": previous?.remedyId?.rawValue ?? "",
            "to_remedy_id": nextRemedyId?.rawValue ?? "",
            "routine_step_count": "\(coreRoutine.count)"
        ])
        persist()
        rescheduleRoutineSurfaces()
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
        rescheduleRoutineSurfaces()
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

    var completedWindDownNightCount: Int {
        completedWindDownDates().count
    }

    var hasNoScreensRoutineStep: Bool {
        coreRoutine.contains { $0.remedyId == .noScreens || $0.label == R.noScreens }
    }

    var hasAppBlockingRoutineStep: Bool {
        coreRoutine.contains { $0.remedyId == .appBlocking || $0.label == R.appBlocking }
    }

    var hasConfiguredAppBlockingTargets: Bool {
        !appBlockingSelection.applicationTokens.isEmpty || !appBlockingSelection.categoryTokens.isEmpty
    }

    var hasBlockedAppTargets: Bool {
        hasConfiguredAppBlockingTargets
    }

    var requiresBlockedAppsBeforeRuleActions: Bool {
        appBlockingEnabled && canUseHardAppBlocking && !hasConfiguredAppBlockingTargets
    }

    var shouldOfferAppBlockingSetup: Bool {
        hasNoScreensRoutineStep &&
        !hasConfiguredAppBlockingTargets
    }

    var shouldOfferAppBlockingAfterFirstNight: Bool {
        shouldOfferAppBlockingSetup
    }

    func startAppBlockingOfferSetup() {
        requestedRoutineStepIDToEdit = nil
        requestedTab = 1
    }

    // Per-item primary notification copy — see Docs/notification-copy.md
    private static let prepNotificationCopy: [String: (title: String, body: String)] = [
        R.dimTheLights: (
            "Dim the lights",
            "Lamps only from here. Bright light tells your brain it's still daytime."
        ),
        R.noScreens: (
            "Wind down screen time",
            "Blue light suppresses melatonin and tells your brain it's still daytime. TenThirty is fine — TikTok, email, and news aren't. Taper from here."
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

    func sleepContractNotificationItems(now: Date = Date()) -> [(item: SleepContractItem, dayOffset: Int)] {
        let calendar = Calendar.current
        let anchor = contractAnchorDate(for: now)
        var notificationItems: [(item: SleepContractItem, dayOffset: Int)] = []

        for dayOffset in 0..<2 {
            guard let contractDay = calendar.date(byAdding: .day, value: dayOffset, to: anchor) else { continue }
            for rule in orderedSelectedSleepRules {
                let item = sleepContractItem(for: rule, on: contractDay)
                guard !item.startsTomorrow else { continue }
                guard !item.isResolved else { continue }
                notificationItems.append((item, dayOffset))
            }
        }

        return notificationItems
    }

    func scheduleSleepContractRuleNotifications() {
        let now = Date()

        for (item, dayOffset) in sleepContractNotificationItems(now: now) {
                let dueFireDate = item.rule == .morningSun ? item.availableAt : item.dueAt
                if dueFireDate > now {
                    scheduleSleepContractNotification(
                        identifier: "sleep_contract_due_\(item.rule.rawValue)_\(dayOffset)",
                        title: item.rule.title,
                        body: sleepContractNotificationBody(for: item),
                        fireDate: dueFireDate
                    )
                }

                if item.graceEndsAt > now {
                    scheduleSleepContractNotification(
                        identifier: "sleep_contract_grace_\(item.rule.rawValue)_\(dayOffset)",
                        title: "Selected apps lock now",
                        body: "\(item.rule.title) was not confirmed before grace ended. Open TenThirty to complete it late.",
                        fireDate: item.graceEndsAt
                    )
                }
        }
    }

    private func scheduleSleepContractNotification(identifier: String,
                                                   title: String,
                                                   body: String,
                                                   fireDate: Date) {
        let calendar = Calendar.current
        var comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        comps.second = 0

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "SLEEP_CONTRACT_RULE"
        content.interruptionLevel = .timeSensitive
        content.relevanceScore = 1.0

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func sleepContractNotificationBody(for item: SleepContractItem) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        if item.isRange {
            return "Confirm by \(formatter.string(from: item.dueAt)) before your selected apps get locked."
        }
        return "Confirm before grace ends at \(formatter.string(from: item.graceEndsAt)) before your selected apps get locked."
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
            content.body = "Close to bedtime now. Tap to start tonight's ritual — TenThirty will guide you through to lights-out."
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

    func clearObsoleteNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: Self.obsoleteNotificationIdentifiers)
        center.removeDeliveredNotifications(withIdentifiers: Self.obsoleteNotificationIdentifiers)
    }

    func scheduleAllNotifications() {
        guard hasPremiumAccess else {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            clearObsoleteNotifications()
            return
        }

        #if DEBUG
        print("[NotifDebug] scheduleAllNotifications() called. bedtime=\(typicalBedtime), windDownDuration=\(windDownDurationMinutes)min, prepSteps=\(preWindDownSteps.count), windDownSteps=\(windDownSteps.count)")
        #endif

        // UNUserNotificationCenter.add silently drops requests until permission
        // is granted. If status is .notDetermined we have to request first,
        // then do the actual scheduling on the main queue after the prompt
        // resolves.
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { [weak self] settings in
            guard let self = self else { return }
            #if DEBUG
            print("[NotifDebug] auth status: \(settings.authorizationStatus.rawValue) (0=notDetermined, 1=denied, 2=authorized, 3=provisional)")
            #endif

            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    #if DEBUG
                    print("[NotifDebug] permission prompt resolved: granted=\(granted), error=\(error?.localizedDescription ?? "nil")")
                    #endif
                    guard granted else { return }
                    DispatchQueue.main.async { self.performScheduling() }
                }
            case .denied:
                #if DEBUG
                print("[NotifDebug] permission denied — user must re-enable in Settings → TenThirty → Notifications")
                #endif
            default:
                DispatchQueue.main.async { self.performScheduling() }
            }
        }
    }

    private func performScheduling() {
        // A full schedule rebuild should not leave any prior sleep-window
        // requests behind, especially dynamic "bedtime_prep_<label>" IDs.
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        clearObsoleteNotifications()
        if hasCompletedOnboarding {
            scheduleSleepContractRuleNotifications()
        } else {
            scheduleBedtimePrepNotifications()
        }
        #if DEBUG
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.dumpPendingNotifications()
        }
        #endif
    }

    #if DEBUG
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
    #endif

    // MARK: - Canonical schedule

    static var prepLeadTimes: [String: Int] { remedyLeadTimes }

    var scheduledRoutine: [ScheduledStep] {
        let cal = Calendar.current
        let bed = typicalBedtime

        let inSeq = coreRoutine.filter {
            !isPrepRoutineStep($0) && (
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

    var windDownSteps: [RoutineStep] {
        coreRoutine.filter {
            $0.mode == .inSequence ||
            ($0.mode == .experiment && allWindDownRemedies.contains($0.label))
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
    var category: RoutineCategory? = nil
    var enforcementMode: RemedyEnforcementMode? = nil
    var sleepSoundConfig: SleepSoundStepConfig? = nil
    var boringStoryConfig: BoringStoryStepConfig? = nil
}

extension RoutineStep {
    var resolvedLeadTimeMins: Int {
        leadTimeMins ?? AppState.prepLeadTimes[label] ?? 90
    }

    var isScreenBlockingConfigurationStep: Bool {
        remedyId == .appBlocking ||
        label == R.appBlocking
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
