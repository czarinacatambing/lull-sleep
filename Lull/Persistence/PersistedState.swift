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
}
