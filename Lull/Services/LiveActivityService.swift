import ActivityKit
import Foundation

// Manages the bedtime prep checklist Live Activity lifecycle.
// Start:  called from DashboardView when evening state appears + prep items exist
// Update: called from AppState.togglePrepDone
// End:    called when all items are done or the nightly ritual starts
class LiveActivityService {
    static let shared = LiveActivityService()

    private let appGroupSuite      = "group.com.trylull.app"
    private let pendingTogglesKey  = "lull_pendingPrepToggles"
    private let pendingRatingKey   = "lull_pendingMorningRating"
    private let pendingRatingAtKey = "lull_pendingMorningRatingAt"
    private let pendingMidSleepKey = "lull_pendingOpenMidSleep"

    // MARK: - Lifecycle

    func startIfNeeded(prepSteps: [RoutineStep], doneIds: Set<UUID>,
                       bedtime: Date, leadTimes: [String: Int]) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let items = prepSteps.map { step -> PrepChecklistAttributes.Item in
            let leadMins = leadTimes[step.label] ?? 90
            let cal = Calendar.current
            let scheduledTime = cal.date(byAdding: .minute, value: -leadMins, to: bedtime) ?? bedtime
            return PrepChecklistAttributes.Item(
                id: step.id.uuidString,
                label: step.label,
                scheduledTime: scheduledTime
            )
        }

        guard !items.isEmpty else { return }

        // If already running just update it.
        if let existing = Activity<PrepChecklistAttributes>.activities.first {
            let state = PrepChecklistAttributes.ContentState(
                doneIds: doneIds.map { $0.uuidString },
                updatedAt: Date()
            )
            Task { await existing.update(ActivityContent(state: state, staleDate: nil)) }
            return
        }

        let attrs = PrepChecklistAttributes(items: items, bedtime: bedtime)
        let state = PrepChecklistAttributes.ContentState(
            doneIds: doneIds.map { $0.uuidString },
            updatedAt: Date()
        )

        do {
            _ = try Activity.request(
                attributes: attrs,
                content: ActivityContent(state: state, staleDate: bedtime),
                pushType: nil
            )
        } catch {
            print("[LiveActivity] Failed to start: \(error)")
        }
    }

    func update(doneIds: Set<UUID>) {
        let doneIdStrings = doneIds.map { $0.uuidString }
        let state = PrepChecklistAttributes.ContentState(
            doneIds: doneIdStrings,
            updatedAt: Date()
        )
        Task {
            for activity in Activity<PrepChecklistAttributes>.activities {
                await activity.update(ActivityContent(state: state, staleDate: nil))
            }
        }
    }

    func end(dismissalPolicy: ActivityUIDismissalPolicy = .default) {
        Task {
            for activity in Activity<PrepChecklistAttributes>.activities {
                await activity.end(nil, dismissalPolicy: dismissalPolicy)
            }
        }
    }

    // MARK: - App Group sync

    // Called on app foreground — reads toggles made from the lock screen and
    // returns the IDs that need to be applied via AppState.togglePrepDone.
    func consumePendingToggles() -> [UUID] {
        let defaults = UserDefaults(suiteName: appGroupSuite)
        let pending = defaults?.stringArray(forKey: pendingTogglesKey) ?? []
        guard !pending.isEmpty else { return [] }
        defaults?.removeObject(forKey: pendingTogglesKey)
        return pending.compactMap { UUID(uuidString: $0) }
    }

    // MARK: - Sleep Companion lifecycle

    var isSleepActivityRunning: Bool {
        !Activity<LullSleepAttributes>.activities.isEmpty
    }

    func startSleepActivity(bedtime: Date, wakeTime: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard wakeTime > bedtime else { return }

        // If one is already running, just refresh its content.
        if let existing = Activity<LullSleepAttributes>.activities.first {
            let state = LullSleepAttributes.ContentState(
                phase: existing.content.state.phase,
                bedtime: bedtime,
                wakeTime: wakeTime,
                rating: existing.content.state.rating,
                score: existing.content.state.score,
                deltaVsBaseline: existing.content.state.deltaVsBaseline,
                baselineLabel: existing.content.state.baselineLabel,
                experimentLabel: existing.content.state.experimentLabel
            )
            Task { await existing.update(ActivityContent(state: state, staleDate: wakeTime)) }
            return
        }

        let attrs = LullSleepAttributes(startedAt: bedtime)
        let state = LullSleepAttributes.ContentState(
            phase: .sleeping,
            bedtime: bedtime,
            wakeTime: wakeTime
        )

        do {
            _ = try Activity.request(
                attributes: attrs,
                content: ActivityContent(state: state, staleDate: wakeTime),
                pushType: nil
            )
        } catch {
            print("[LiveActivity] Failed to start sleep activity: \(error)")
        }
    }

    // Promote the underlying state from .sleeping to .awaitingRating. The view
    // already renders the wake UI based on the clock; this just brings the
    // data state in sync so subsequent updates make sense.
    func updateToAwaitingRating() {
        Task {
            for activity in Activity<LullSleepAttributes>.activities {
                var state = activity.content.state
                guard state.phase == .sleeping else { continue }
                state.phase = .awaitingRating
                await activity.update(ActivityContent(state: state, staleDate: nil))
            }
        }
    }

    // Called on app foreground. Returns the pending rating (if any) so AppState
    // can persist it and compute the score. The intent has already stored the
    // rating in App Group UserDefaults from a Lock Screen tap.
    func consumePendingRating() -> (rating: Int, at: Date)? {
        let defaults = UserDefaults(suiteName: appGroupSuite)
        guard let rating = defaults?.object(forKey: pendingRatingKey) as? Int else { return nil }
        let at = (defaults?.object(forKey: pendingRatingAtKey) as? Date) ?? Date()
        defaults?.removeObject(forKey: pendingRatingKey)
        defaults?.removeObject(forKey: pendingRatingAtKey)
        return (rating, at)
    }

    // Final phase: push score + delta, then end the activity after ~4s so the
    // confirmation lingers.
    func publishRatedAndEnd(rating: Int, score: Double, deltaVsBaseline: Double?, baselineLabel: String?) {
        Task {
            for activity in Activity<LullSleepAttributes>.activities {
                var state = activity.content.state
                state.phase = .rated
                state.rating = rating
                state.score = score
                state.deltaVsBaseline = deltaVsBaseline
                state.baselineLabel = baselineLabel
                await activity.update(ActivityContent(state: state, staleDate: nil))
            }
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            for activity in Activity<LullSleepAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    func consumePendingMidSleepRequest() -> Bool {
        let defaults = UserDefaults(suiteName: appGroupSuite)
        guard defaults?.bool(forKey: pendingMidSleepKey) == true else { return false }
        defaults?.removeObject(forKey: pendingMidSleepKey)
        return true
    }

    func endCurrentSleepActivity(dismissalPolicy: ActivityUIDismissalPolicy = .immediate) {
        Task {
            for activity in Activity<LullSleepAttributes>.activities {
                await activity.end(nil, dismissalPolicy: dismissalPolicy)
            }
        }
    }
}
