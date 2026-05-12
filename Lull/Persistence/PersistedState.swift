import Foundation

struct PersistedState: Codable {
    var schemaVersion: Int = 1

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

    // Onboarding baseline
    var baselineScore: Int = 0

    // Prep checklist completion (resets at wake time each day)
    var prepDoneIds: [UUID] = []
    var prepDoneDate: Date? = nil

    init(schemaVersion: Int = 1,
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
         prepDoneDate: Date? = nil) {
        self.schemaVersion            = schemaVersion
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
        baselineScore            = (try? c.decodeIfPresent(Int.self,          forKey: .baselineScore))   ?? 0
        prepDoneIds              = (try? c.decodeIfPresent([UUID].self,       forKey: .prepDoneIds))  ?? []
        prepDoneDate             = try? c.decodeIfPresent(Date.self,          forKey: .prepDoneDate)
    }
}
