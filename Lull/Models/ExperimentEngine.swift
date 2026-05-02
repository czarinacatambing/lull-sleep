import Foundation

// Pure logic — no SwiftUI. Reads sleep logs + coreRoutine, returns what to do next.
struct ExperimentEngine {

    // Variables queued for testing, in priority order.
    // Anything already in coreRoutine is skipped when picking the next candidate.
    static let candidatePool: [String] = [
        "Magnesium glycinate · 30 min before bed",
        "No caffeine after 2 pm",
        "Cold room · target 65°F",
        "Consistent wake time",
        "White noise",
        "Journaling · 10 min",
        "No alcohol",
        "Morning sunlight · 10 min",
    ]

    enum Decision: Equatable {
        case keepTesting   // fewer than 5 scored nights
        case promote       // meaningful positive impact → add to core routine
        case drop          // neutral or negative → discard
    }

    struct Status {
        var variable: String
        var night: Int           // scored nights so far (1–5)
        var scoreDelta: Double   // experiment avg − baseline avg
        var decision: Decision
        var nextCandidate: String?

        var scoreDeltaString: String {
            guard night > 0 else { return "—" }
            let s = String(format: "%.1f", abs(scoreDelta))
            return scoreDelta >= 0 ? "+\(s)" : "-\(s)"
        }

        var insightLine: String {
            switch decision {
            case .keepTesting:
                let remaining = 5 - night
                let nightWord = remaining == 1 ? "night" : "nights"
                return "\(remaining) more \(nightWord) of data before we decide."
            case .promote:
                return "Scores up \(scoreDeltaString) with this variable. Adding to your core routine."
            case .drop:
                return scoreDelta > 0
                    ? "Marginal improvement (\(scoreDeltaString)). Moving on to the next variable."
                    : "No benefit detected. Dropping and trying something new."
            }
        }
    }

    // Main evaluation entry point.
    static func evaluate(logs: [SleepLogEntry], coreRoutine: [RoutineStep]) -> Status? {
        guard let experimentStep = coreRoutine.first(where: { $0.mode == .experiment }) else { return nil }
        let variable = experimentStep.label

        let experimentLogs = logs.filter { $0.variable == variable && $0.score > 0 }
        let baselineLogs   = logs.filter { $0.variable != variable && $0.score > 0 }

        let night = min(experimentLogs.count, 5)

        // Baseline: average score on non-experiment nights
        let baseline: Double = baselineLogs.isEmpty
            ? 0
            : Double(baselineLogs.map(\.score).reduce(0, +)) / Double(baselineLogs.count)

        // Experiment average (last 5 scored nights)
        let recentExp = experimentLogs.suffix(5)
        let expAvg: Double = recentExp.isEmpty
            ? baseline
            : Double(recentExp.map(\.score).reduce(0, +)) / Double(recentExp.count)

        let delta = baseline == 0 ? 0 : expAvg - baseline

        let decision: Decision
        if experimentLogs.count < 5 {
            decision = .keepTesting
        } else {
            decision = delta > 0.3 ? .promote : .drop
        }

        let inRoutine = Set(coreRoutine.map(\.label))
        let next = candidatePool.first { !inRoutine.contains($0) && $0 != variable }

        return Status(variable: variable, night: night, scoreDelta: delta,
                      decision: decision, nextCandidate: next)
    }
}
