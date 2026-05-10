import Foundation

struct ExperimentEngine {

    enum Decision: Equatable {
        case keepTesting  // fewer than 5 scored nights
        case promote      // meaningful positive impact → add to core routine
        case drop         // neutral or negative → discard and try something new
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

    // MARK: - Promote / Drop evaluation (runs every morning after logging a score)

    static func evaluate(
        logs: [SleepLogEntry],
        coreRoutine: [RoutineStep],
        remedyScores: [String: Int]
    ) -> Status? {
        guard let experimentStep = coreRoutine.first(where: { $0.mode == .experiment }) else { return nil }
        let variable = experimentStep.label
        let remedyId = experimentStep.remedyId

        // Prefer stable RemedyID comparison; fall back to display string for old records.
        let experimentLogs = logs.filter { entry in
            guard entry.score > 0 else { return false }
            if let eid = entry.variableRemedyId, let rid = remedyId { return eid == rid }
            return entry.variable == variable
        }
        let baselineLogs = logs.filter { entry in
            guard entry.score > 0 else { return false }
            if let eid = entry.variableRemedyId, let rid = remedyId { return eid != rid }
            return entry.variable != variable
        }

        let night = min(experimentLogs.count, 5)

        let baseline: Double = baselineLogs.isEmpty
            ? 0
            : Double(baselineLogs.map(\.score).reduce(0, +)) / Double(baselineLogs.count)

        let recentExp = experimentLogs.suffix(5)
        let expAvg: Double = recentExp.isEmpty
            ? baseline
            : Double(recentExp.map(\.score).reduce(0, +)) / Double(recentExp.count)

        let delta = baseline == 0 ? 0 : expAvg - baseline

        let decision: Decision = experimentLogs.count < 5
            ? .keepTesting
            : (delta > 0.3 ? .promote : .drop)

        let next = suggestNextVariable(
            logs: logs,
            coreRoutine: coreRoutine,
            remedyScores: remedyScores
        )

        return Status(variable: variable, night: night, scoreDelta: delta,
                      decision: decision, nextCandidate: next)
    }

    // MARK: - Weighted next-variable suggestion

    /// Scores every possible remedy candidate and returns the label of the best one.
    ///
    /// Formula: totalScore = (historicalScore × 0.7) + (onboardingScore × 0.2) + smartAdjustments
    ///
    /// - historicalScore (0–10): normalised average improvement on nights where this variable was tested.
    ///   If no history exists, score is 0 (first suggestion falls back to onboarding match).
    /// - onboardingScore (0–10): raw remedy score from scoreRemedies(), capped at 10.
    /// - smartAdjustments: flat additive bonuses/penalties.
    static func suggestNextVariable(
        logs: [SleepLogEntry],
        coreRoutine: [RoutineStep],
        remedyScores: [String: Int]
    ) -> String? {
        let inRoutine = Set(coreRoutine.map(\.label))
        // Candidates: Bedtime Prep remedies + passive Bedtime Ritual items (e.g. weighted blanket).
        // Weighted blanket has no lead time and is displayed in the Bedtime Ritual section when selected.
        let allCandidates = allBedroomPrepRemedies + [R.weightedBlanket]

        let scored: [(label: String, total: Double)] = allCandidates.map { candidate in
            // Historical score — prefer RemedyID match for newer records
            let candidateId = RemedyID.fromLabel(candidate)
            let experimentLogs = logs.filter { entry in
                guard entry.score > 0 else { return false }
                if let eid = entry.variableRemedyId, let cid = candidateId { return eid == cid }
                return entry.variable == candidate
            }
            let baselineLogs = logs.filter { entry in
                guard entry.score > 0 else { return false }
                if let eid = entry.variableRemedyId, let cid = candidateId { return eid != cid }
                return entry.variable != candidate
            }
            let historicalScore: Double
            if experimentLogs.isEmpty {
                historicalScore = 0
            } else {
                let baseline: Double = baselineLogs.isEmpty
                    ? 0
                    : Double(baselineLogs.map(\.score).reduce(0, +)) / Double(baselineLogs.count)
                let expAvg = Double(experimentLogs.suffix(5).map(\.score).reduce(0, +))
                           / Double(min(experimentLogs.count, 5))
                let delta = baseline == 0 ? 0 : expAvg - baseline
                // Normalise: delta 0 → 5, delta +2.5 → 10, delta −2.5 → 0
                historicalScore = min(10, max(0, delta * 2 + 5))
            }

            // Onboarding match score (0–10)
            let onboardingScore = min(10.0, Double(remedyScores[candidate] ?? 0))

            // Smart adjustments
            var adjustments: Double = 0
            if candidate == R.dimTheLights || candidate == R.coldRoomPrep { adjustments += 3 }
            if inRoutine.contains(candidate) { adjustments -= 10 }
            let isBedtimePrep = remedyLeadTimes[candidate] != nil
            if isBedtimePrep && logs.count < 15 { adjustments += 2 }

            let total = historicalScore * 0.7 + onboardingScore * 0.2 + adjustments
            return (candidate, total)
        }

        return scored
            .filter { !inRoutine.contains($0.label) }
            .max(by: { $0.total < $1.total })?
            .label
    }
}
