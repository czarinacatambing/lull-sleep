import Foundation

struct PersistedState: Codable {
    // Schema versions:
    //   1 — original
    //   2 — added migration: consolidate orphaned morning-rating entries
    //       created by the pre-1.0(4) logMorningScore bug
    var schemaVersion: Int = 2

    // Onboarding preferences
    var selectedSleepProblems: Set<Int>
    var selectedWakes: Set<Int>
    var sleepWindowMinutes: Int
    var typicalBedtime: Date
    var typicalWakeTime: Date
    var selectedPreBedActivities: Set<Int>
    var selectedTriedThings: Set<Int>

    // Routine — mutated by experiment engine
    var coreRoutine: [RoutineStep]
    var routineExplanation: String

    // Per-night history
    var sleepLogs: [SleepLogEntry]

    // Tester identity
    var testerName: String = ""

    // Onboarding baseline
    var baselineScore: Int = 0

    // Prep checklist completion (resets at wake time each day)
    var prepDoneIds: [UUID] = []
    var prepDoneDate: Date? = nil

    // Promotion celebration — pending modal + recently-promoted pill tracking.
    var pendingPromotion: PendingPromotion? = nil
    var recentlyPromotedRemedyId: RemedyID? = nil
    var recentlyPromotedAt: Date? = nil

    init(schemaVersion: Int = 2,
         testerName: String = "",
         selectedSleepProblems: Set<Int>,
         selectedWakes: Set<Int>,
         sleepWindowMinutes: Int,
         typicalBedtime: Date,
         typicalWakeTime: Date,
         selectedPreBedActivities: Set<Int>,
         selectedTriedThings: Set<Int>,
         coreRoutine: [RoutineStep],
         routineExplanation: String,
         sleepLogs: [SleepLogEntry],
         baselineScore: Int = 0,
         prepDoneIds: [UUID] = [],
         prepDoneDate: Date? = nil,
         pendingPromotion: PendingPromotion? = nil,
         recentlyPromotedRemedyId: RemedyID? = nil,
         recentlyPromotedAt: Date? = nil) {
        self.schemaVersion            = schemaVersion
        self.testerName               = testerName
        self.selectedSleepProblems    = selectedSleepProblems
        self.selectedWakes            = selectedWakes
        self.sleepWindowMinutes       = sleepWindowMinutes
        self.typicalBedtime           = typicalBedtime
        self.typicalWakeTime          = typicalWakeTime
        self.selectedPreBedActivities = selectedPreBedActivities
        self.selectedTriedThings      = selectedTriedThings
        self.coreRoutine              = coreRoutine
        self.routineExplanation       = routineExplanation
        self.sleepLogs                = sleepLogs
        self.baselineScore            = baselineScore
        self.prepDoneIds              = prepDoneIds
        self.prepDoneDate             = prepDoneDate
        self.pendingPromotion         = pendingPromotion
        self.recentlyPromotedRemedyId = recentlyPromotedRemedyId
        self.recentlyPromotedAt       = recentlyPromotedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion            = (try? c.decodeIfPresent(Int.self,          forKey: .schemaVersion))   ?? 1
        selectedSleepProblems    = try c.decode(Set<Int>.self,                forKey: .selectedSleepProblems)
        selectedWakes            = try c.decode(Set<Int>.self,                forKey: .selectedWakes)
        sleepWindowMinutes       = try c.decode(Int.self,                     forKey: .sleepWindowMinutes)
        typicalBedtime           = try c.decode(Date.self,                    forKey: .typicalBedtime)
        typicalWakeTime          = try c.decode(Date.self,                    forKey: .typicalWakeTime)
        selectedPreBedActivities = try c.decode(Set<Int>.self,                forKey: .selectedPreBedActivities)
        selectedTriedThings      = try c.decode(Set<Int>.self,                forKey: .selectedTriedThings)
        coreRoutine              = try c.decode([RoutineStep].self,           forKey: .coreRoutine)
        routineExplanation       = try c.decode(String.self,                  forKey: .routineExplanation)
        sleepLogs                = try c.decode([SleepLogEntry].self,         forKey: .sleepLogs)
        testerName               = (try? c.decodeIfPresent(String.self,             forKey: .testerName))   ?? ""
        baselineScore            = (try? c.decodeIfPresent(Int.self,                forKey: .baselineScore))   ?? 0
        prepDoneIds              = (try? c.decodeIfPresent([UUID].self,             forKey: .prepDoneIds))  ?? []
        prepDoneDate             = try? c.decodeIfPresent(Date.self,                forKey: .prepDoneDate)
        pendingPromotion         = try? c.decodeIfPresent(PendingPromotion.self,    forKey: .pendingPromotion)
        recentlyPromotedRemedyId = try? c.decodeIfPresent(RemedyID.self,            forKey: .recentlyPromotedRemedyId)
        recentlyPromotedAt       = try? c.decodeIfPresent(Date.self,                forKey: .recentlyPromotedAt)
    }
}
