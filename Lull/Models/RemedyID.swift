import Foundation

// Stable enum identity for every remedy — survives display-string renames.
// The raw String value is the JSON key; never change a case's raw value.
enum RemedyID: String, Codable, CaseIterable {
    // Bedtime Prep
    case dimTheLights
    case noScreens
    case appBlocking
    case finishWorkouts
    case noHeavySnacks
    case noAlcohol
    case noCaffeine
    case coldRoomPrep
    case warmShower
    case magnesium
    case herbalTea
    case weightedBlanket

    // Wind Down interactive
    case brainDump
    case boringStory
    case breathing478
    case gratitudeJournal
    case gentleStretching
    case progressiveMuscleRelaxation
    case readingBook

    // Maps an R-constant display label to a stable RemedyID.
    // Returns nil for labels with no canonical ID (e.g. "Brightness check").
    static func fromLabel(_ label: String) -> RemedyID? {
        switch label {
        case R.dimTheLights:     return .dimTheLights
        case R.noScreens:        return .noScreens
        case R.appBlocking:      return .appBlocking
        case R.finishWorkouts:   return .finishWorkouts
        case R.noHeavySnacks:    return .noHeavySnacks
        case R.noAlcohol:        return .noAlcohol
        case R.noCaffeine:       return .noCaffeine
        case R.coldRoomPrep:     return .coldRoomPrep
        case R.warmShower:       return .warmShower
        case R.magnesium:        return .magnesium
        case R.herbalTea:        return .herbalTea
        case R.weightedBlanket:  return .weightedBlanket
        case R.brainDump:        return .brainDump
        case R.boringStory:      return .boringStory
        case R.breathing478:     return .breathing478
        case R.gratitudeJournal: return .gratitudeJournal
        case R.gentleStretching: return .gentleStretching
        case R.pmr:              return .progressiveMuscleRelaxation
        case R.readingBook:      return .readingBook
        default:                 return nil
        }
    }
}

// MARK: - Supporting types for per-night data

enum LightsLevelSource: String, Codable {
    case sensor       // camera EV reading
    case selfReported // user selected a swatch
}

enum StepStatus: String, Codable {
    case completed
    case skipped
}

struct StepAttempt: Codable {
    var remedyId: RemedyID?
    var labelSnapshot: String
    var status: StepStatus
    var durationSeconds: Int?
}
