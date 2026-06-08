import Foundation

struct PersistedState: Codable {
    // Schema versions:
    //   1 — original
    //   2 — added migration: consolidate orphaned morning-rating entries
    //       created by the pre-1.0(4) logMorningScore bug
    //   3 — normalize sleep scores to the 1-5 rating scale
    //   4 — app blocking configuration
    //   5 — onboarding activation fields: current/target sleep windows,
    //       chronotype, bottleneck, and commitment time
    //   6 — night-5 paywall state
    //   7 — timezone identifier for re-anchoring wall-clock sleep times
    //   8 — app-managed trial and premium/free routine snapshots
    //   9 — streak milestone queue and acknowledgement state
    var schemaVersion: Int = 9

    // Onboarding preferences
    var selectedSleepProblems: Set<Int>
    var selectedWakes: Set<Int>
    var sleepWindowMinutes: Int
    var currentBedtime: Date
    var currentWakeTime: Date
    var targetBedtime: Date
    var targetWakeTime: Date
    var typicalBedtime: Date
    var typicalWakeTime: Date
    var selectedPreBedActivities: Set<Int>
    var selectedTriedThings: Set<Int>
    var chronotype: Chronotype
    var bottleneck: SleepBottleneck
    var committedRoutineTime: Date?
    var timeZoneIdentifier: String
    var paywallState: PaywallState = PaywallState()
    var originalGeneratedRoutine: [RoutineStep]? = nil
    var trialCustomizedRoutine: [RoutineStep]? = nil

    // Routine — mutated by experiment engine
    var coreRoutine: [RoutineStep]
    var routineExplanation: String

    // Per-night history
    var sleepLogs: [SleepLogEntry]

    // Tester identity
    var testerName: String = ""

    // Onboarding baseline
    var baselineScore: Int = 0

    // Checklist completion (resets at wake time each day)
    var prepDoneIds: [UUID] = []
    var prepDoneDate: Date? = nil
    var ritualDoneIds: [UUID] = []
    var ritualDoneDate: Date? = nil

    // Promotion celebration — pending modal + recently-promoted pill tracking.
    var pendingPromotion: PendingPromotion? = nil
    var recentlyPromotedRemedyId: RemedyID? = nil
    var recentlyPromotedAt: Date? = nil

    // Streak milestone presentation state
    var pendingStreakMilestoneDay: Int? = nil
    var acknowledgedStreakMilestoneDays: [Int] = []
    var streakMilestonePaywallPromptedDays: [Int] = []

    // App blocking setup
    var appBlockingSelectionData: Data? = nil
    var appBlockingEnabled: Bool = false
    var appBlockingStartTime: Date? = nil
    var appBlockingEndTime: Date? = nil
    var appBlockingGraceMinutes: Int = 5
    var gentleBlockingBypassedUntil: Date? = nil

    init(schemaVersion: Int = 9,
         testerName: String = "",
         selectedSleepProblems: Set<Int>,
         selectedWakes: Set<Int>,
         sleepWindowMinutes: Int,
         currentBedtime: Date? = nil,
         currentWakeTime: Date? = nil,
         targetBedtime: Date? = nil,
         targetWakeTime: Date? = nil,
         typicalBedtime: Date,
         typicalWakeTime: Date,
         selectedPreBedActivities: Set<Int>,
         selectedTriedThings: Set<Int>,
         coreRoutine: [RoutineStep],
         routineExplanation: String,
         sleepLogs: [SleepLogEntry],
         chronotype: Chronotype = .steadySleeper,
         bottleneck: SleepBottleneck = .inconsistentRhythm,
         committedRoutineTime: Date? = nil,
         timeZoneIdentifier: String = TimeZone.autoupdatingCurrent.identifier,
         paywallState: PaywallState = PaywallState(),
         originalGeneratedRoutine: [RoutineStep]? = nil,
         trialCustomizedRoutine: [RoutineStep]? = nil,
         baselineScore: Int = 0,
         prepDoneIds: [UUID] = [],
         prepDoneDate: Date? = nil,
         ritualDoneIds: [UUID] = [],
         ritualDoneDate: Date? = nil,
         pendingPromotion: PendingPromotion? = nil,
         recentlyPromotedRemedyId: RemedyID? = nil,
         recentlyPromotedAt: Date? = nil,
         pendingStreakMilestoneDay: Int? = nil,
         acknowledgedStreakMilestoneDays: [Int] = [],
         streakMilestonePaywallPromptedDays: [Int] = [],
         appBlockingSelectionData: Data? = nil,
         appBlockingEnabled: Bool = false,
         appBlockingStartTime: Date? = nil,
         appBlockingEndTime: Date? = nil,
         appBlockingGraceMinutes: Int = 5,
         gentleBlockingBypassedUntil: Date? = nil) {
        self.schemaVersion            = schemaVersion
        self.testerName               = testerName
        self.selectedSleepProblems    = selectedSleepProblems
        self.selectedWakes            = selectedWakes
        self.sleepWindowMinutes       = sleepWindowMinutes
        self.currentBedtime           = currentBedtime ?? typicalBedtime
        self.currentWakeTime          = currentWakeTime ?? typicalWakeTime
        self.targetBedtime            = targetBedtime ?? typicalBedtime
        self.targetWakeTime           = targetWakeTime ?? typicalWakeTime
        self.typicalBedtime           = typicalBedtime
        self.typicalWakeTime          = typicalWakeTime
        self.selectedPreBedActivities = selectedPreBedActivities
        self.selectedTriedThings      = selectedTriedThings
        self.chronotype               = chronotype
        self.bottleneck               = bottleneck
        self.committedRoutineTime     = committedRoutineTime
        self.timeZoneIdentifier       = timeZoneIdentifier
        self.paywallState             = paywallState
        self.originalGeneratedRoutine = originalGeneratedRoutine
        self.trialCustomizedRoutine   = trialCustomizedRoutine
        self.coreRoutine              = coreRoutine
        self.routineExplanation       = routineExplanation
        self.sleepLogs                = sleepLogs
        self.baselineScore            = baselineScore
        self.prepDoneIds              = prepDoneIds
        self.prepDoneDate             = prepDoneDate
        self.ritualDoneIds            = ritualDoneIds
        self.ritualDoneDate           = ritualDoneDate
        self.pendingPromotion         = pendingPromotion
        self.recentlyPromotedRemedyId = recentlyPromotedRemedyId
        self.recentlyPromotedAt       = recentlyPromotedAt
        self.pendingStreakMilestoneDay = pendingStreakMilestoneDay
        self.acknowledgedStreakMilestoneDays = acknowledgedStreakMilestoneDays
        self.streakMilestonePaywallPromptedDays = streakMilestonePaywallPromptedDays
        self.appBlockingSelectionData = appBlockingSelectionData
        self.appBlockingEnabled       = appBlockingEnabled
        self.appBlockingStartTime     = appBlockingStartTime
        self.appBlockingEndTime       = appBlockingEndTime
        self.appBlockingGraceMinutes  = appBlockingGraceMinutes
        self.gentleBlockingBypassedUntil = gentleBlockingBypassedUntil
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion            = (try? c.decodeIfPresent(Int.self,          forKey: .schemaVersion))   ?? 1
        selectedSleepProblems    = try c.decode(Set<Int>.self,                forKey: .selectedSleepProblems)
        selectedWakes            = try c.decode(Set<Int>.self,                forKey: .selectedWakes)
        sleepWindowMinutes       = try c.decode(Int.self,                     forKey: .sleepWindowMinutes)
        typicalBedtime           = try c.decode(Date.self,                    forKey: .typicalBedtime)
        typicalWakeTime          = try c.decode(Date.self,                    forKey: .typicalWakeTime)
        currentBedtime           = (try? c.decodeIfPresent(Date.self,         forKey: .currentBedtime)) ?? typicalBedtime
        currentWakeTime          = (try? c.decodeIfPresent(Date.self,         forKey: .currentWakeTime)) ?? typicalWakeTime
        targetBedtime            = (try? c.decodeIfPresent(Date.self,         forKey: .targetBedtime)) ?? typicalBedtime
        targetWakeTime           = (try? c.decodeIfPresent(Date.self,         forKey: .targetWakeTime)) ?? typicalWakeTime
        selectedPreBedActivities = try c.decode(Set<Int>.self,                forKey: .selectedPreBedActivities)
        selectedTriedThings      = try c.decode(Set<Int>.self,                forKey: .selectedTriedThings)
        chronotype               = (try? c.decodeIfPresent(Chronotype.self,   forKey: .chronotype)) ?? .steadySleeper
        bottleneck               = (try? c.decodeIfPresent(SleepBottleneck.self, forKey: .bottleneck)) ?? .inconsistentRhythm
        committedRoutineTime     = try? c.decodeIfPresent(Date.self,          forKey: .committedRoutineTime)
        timeZoneIdentifier       = (try? c.decodeIfPresent(String.self,        forKey: .timeZoneIdentifier)) ?? TimeZone.autoupdatingCurrent.identifier
        paywallState             = (try? c.decodeIfPresent(PaywallState.self, forKey: .paywallState)) ?? PaywallState()
        originalGeneratedRoutine = try? c.decodeIfPresent([RoutineStep].self,  forKey: .originalGeneratedRoutine)
        trialCustomizedRoutine   = try? c.decodeIfPresent([RoutineStep].self,  forKey: .trialCustomizedRoutine)
        coreRoutine              = try c.decode([RoutineStep].self,           forKey: .coreRoutine)
        routineExplanation       = try c.decode(String.self,                  forKey: .routineExplanation)
        sleepLogs                = try c.decode([SleepLogEntry].self,         forKey: .sleepLogs)
        testerName               = (try? c.decodeIfPresent(String.self,             forKey: .testerName))   ?? ""
        baselineScore            = (try? c.decodeIfPresent(Int.self,                forKey: .baselineScore))   ?? 0
        prepDoneIds              = (try? c.decodeIfPresent([UUID].self,             forKey: .prepDoneIds))  ?? []
        prepDoneDate             = try? c.decodeIfPresent(Date.self,                forKey: .prepDoneDate)
        ritualDoneIds            = (try? c.decodeIfPresent([UUID].self,             forKey: .ritualDoneIds))  ?? []
        ritualDoneDate           = try? c.decodeIfPresent(Date.self,                forKey: .ritualDoneDate)
        pendingPromotion         = try? c.decodeIfPresent(PendingPromotion.self,    forKey: .pendingPromotion)
        recentlyPromotedRemedyId = try? c.decodeIfPresent(RemedyID.self,            forKey: .recentlyPromotedRemedyId)
        recentlyPromotedAt       = try? c.decodeIfPresent(Date.self,                forKey: .recentlyPromotedAt)
        pendingStreakMilestoneDay = try? c.decodeIfPresent(Int.self,                forKey: .pendingStreakMilestoneDay)
        acknowledgedStreakMilestoneDays = (try? c.decodeIfPresent([Int].self,       forKey: .acknowledgedStreakMilestoneDays)) ?? []
        streakMilestonePaywallPromptedDays = (try? c.decodeIfPresent([Int].self,    forKey: .streakMilestonePaywallPromptedDays)) ?? []
        appBlockingSelectionData = try? c.decodeIfPresent(Data.self,                forKey: .appBlockingSelectionData)
        appBlockingEnabled       = (try? c.decodeIfPresent(Bool.self,               forKey: .appBlockingEnabled)) ?? false
        appBlockingStartTime     = try? c.decodeIfPresent(Date.self,                forKey: .appBlockingStartTime)
        appBlockingEndTime       = try? c.decodeIfPresent(Date.self,                forKey: .appBlockingEndTime)
        appBlockingGraceMinutes  = (try? c.decodeIfPresent(Int.self,                forKey: .appBlockingGraceMinutes)) ?? 5
        gentleBlockingBypassedUntil = try? c.decodeIfPresent(Date.self,             forKey: .gentleBlockingBypassedUntil)

        if paywallState.originalGeneratedRoutine == nil {
            paywallState.originalGeneratedRoutine = originalGeneratedRoutine
        }
        if paywallState.trialCustomizedRoutine == nil {
            paywallState.trialCustomizedRoutine = trialCustomizedRoutine
        }
        if paywallState.gentleBlockingBypassedUntil == nil {
            paywallState.gentleBlockingBypassedUntil = gentleBlockingBypassedUntil
        }
    }
}
