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
    private let morningRatingWindow: TimeInterval = 4 * 60 * 60

    // MARK: - Lifecycle

    func startIfNeeded(prepSteps: [RoutineStep], doneIds: Set<UUID>,
                       bedtime: Date, leadTimes: [String: Int]) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let now = Date()
        let anchoredBedtime = nextBedtimeAnchor(from: bedtime, now: now)
        let items = prepSteps.map { step -> PrepChecklistAttributes.Item in
            let leadMins = leadTimes[step.label] ?? step.resolvedLeadTimeMins
            let scheduledTime = Calendar.autoupdatingCurrent.date(
                byAdding: .minute,
                value: -leadMins,
                to: anchoredBedtime
            ) ?? anchoredBedtime
            return PrepChecklistAttributes.Item(
                id: step.id.uuidString,
                label: step.label,
                scheduledTime: scheduledTime
            )
        }

        guard !items.isEmpty else { return }
        if let firstPrepTime = items.map(\.scheduledTime).min(), now < firstPrepTime {
            end(dismissalPolicy: .immediate)
            return
        }
        guard doneIds.count < items.count else {
            end(dismissalPolicy: .immediate)
            return
        }

        // If already running just update it.
        if let existing = Activity<PrepChecklistAttributes>.activities.first {
            let state = PrepChecklistAttributes.ContentState(
                doneIds: doneIds.map { $0.uuidString },
                updatedAt: Date()
            )
            Task { await existing.update(ActivityContent(state: state, staleDate: nil)) }
            return
        }

        let attrs = PrepChecklistAttributes(items: items, bedtime: anchoredBedtime)
        let state = PrepChecklistAttributes.ContentState(
            doneIds: doneIds.map { $0.uuidString },
            updatedAt: Date()
        )

        do {
            _ = try Activity.request(
                attributes: attrs,
                content: ActivityContent(state: state, staleDate: anchoredBedtime),
                pushType: nil
            )
        } catch {
            #if DEBUG
            print("[LiveActivity] Failed to start: \(error)")
            #endif
        }
    }

    private func nextBedtimeAnchor(from bedtime: Date, now: Date) -> Date {
        let cal = Calendar.autoupdatingCurrent
        let comps = cal.dateComponents([.hour, .minute], from: bedtime)
        var candidate = cal.date(bySettingHour: comps.hour ?? 23,
                                 minute: comps.minute ?? 0,
                                 second: 0,
                                 of: now) ?? bedtime
        if candidate <= now {
            candidate = cal.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        }
        return candidate
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
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            #if DEBUG
            print("[LiveActivity] Sleep activity not started: Live Activities are disabled for TenThirty.")
            #endif
            return
        }
        let effectiveWakeTime = wakeTimeAnchoredAfter(bedtime: bedtime, wakeTime: wakeTime)
        guard effectiveWakeTime > bedtime else {
            #if DEBUG
            print("[LiveActivity] Sleep activity not started: wakeTime (\(effectiveWakeTime)) is not after bedtime (\(bedtime)).")
            #endif
            return
        }

        let sleepActivities = Activity<LullSleepAttributes>.activities

        // If one is already running, reuse it as a fresh sleep session. Do
        // not preserve the old phase: a prior wake/rated activity would hide
        // the sleeping-state Mid-Sleep affordance on the next night.
        if let existing = sleepActivities.first {
            #if DEBUG
            print("[LiveActivity] Refreshing existing sleep activity as sleeping until \(effectiveWakeTime).")
            #endif
            let state = LullSleepAttributes.ContentState(
                phase: .sleeping,
                bedtime: bedtime,
                wakeTime: effectiveWakeTime
            )
            Task {
                await existing.update(ActivityContent(
                    state: state,
                    staleDate: effectiveWakeTime,
                    relevanceScore: 0.8
                ))
                for extra in sleepActivities.dropFirst() {
                    await extra.end(nil, dismissalPolicy: .immediate)
                }
            }
            return
        }

        let attrs = LullSleepAttributes(startedAt: bedtime)
        let state = LullSleepAttributes.ContentState(
            phase: .sleeping,
            bedtime: bedtime,
            wakeTime: effectiveWakeTime
        )

        do {
            let activity = try Activity.request(
                attributes: attrs,
                content: ActivityContent(
                    state: state,
                    staleDate: effectiveWakeTime,
                    relevanceScore: 0.8
                ),
                pushType: nil
            )
            #if DEBUG
            print("[LiveActivity] Started sleep activity \(activity.id) from \(bedtime) to \(effectiveWakeTime).")
            #endif
        } catch {
            #if DEBUG
            print("[LiveActivity] Failed to start sleep activity: \(error)")
            #endif
        }
    }

    private func wakeTimeAnchoredAfter(bedtime: Date, wakeTime: Date) -> Date {
        let cal = Calendar.autoupdatingCurrent
        let comps = cal.dateComponents([.hour, .minute], from: wakeTime)
        var candidate = cal.date(bySettingHour: comps.hour ?? 7,
                                 minute: comps.minute ?? 0,
                                 second: 0,
                                 of: bedtime) ?? wakeTime
        if candidate <= bedtime {
            candidate = cal.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        }
        return candidate
    }

    // Promote the underlying state from .sleeping to .awaitingRating. The view
    // already renders the wake UI based on the clock; this just brings the
    // data state in sync so subsequent updates make sense.
    // Guards on the activity's OWN wakeTime, not the caller's, so we don't
    // flip a still-sleeping activity just because we're past today's typical
    // wake hour (e.g. ritual started in the evening, wakeTime is tomorrow).
    func updateToAwaitingRating() {
        Task {
            for activity in Activity<LullSleepAttributes>.activities {
                var state = activity.content.state
                guard state.phase == .sleeping else { continue }
                guard Date() >= state.wakeTime else { continue }
                state.phase = .awaitingRating
                await activity.update(ActivityContent(
                    state: state,
                    staleDate: self.ratingWindowEnd(for: state.wakeTime),
                    relevanceScore: 1.0
                ))
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
                await activity.update(ActivityContent(state: state, staleDate: nil, relevanceScore: 1.0))
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

    private func ratingWindowEnd(for wakeTime: Date) -> Date {
        wakeTime.addingTimeInterval(morningRatingWindow)
    }
}
