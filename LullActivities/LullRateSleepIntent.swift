import ActivityKit
import AppIntents
import Foundation
import UserNotifications

private let appGroupSuite = "group.com.trylull.app"
private let pendingRatingKey = "lull_pendingMorningRating"
private let pendingRatingAtKey = "lull_pendingMorningRatingAt"
private let morningRatingNotificationIdentifiers =
    ["morning_rating_primary", "morning_rating_noon"] +
    (0..<14).flatMap { ["morning_rating_primary_\($0)", "morning_rating_noon_\($0)"] }

// Records a morning sleep rating from the Live Activity wake-state dots
// without foregrounding the app. The dots fill immediately via a local
// activity.update; the final score + delta is computed when the app next
// foregrounds (see LiveActivityService.applyPendingRating).
struct LullRateSleepIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Rate last night"
    static var description = IntentDescription("Records last night's sleep rating from the Lock Screen.")
    static var isDiscoverable: Bool = false
    // Must be false: if true, iOS launches the host app the moment perform()
    // returns and suspends the extension before the awaited activity.update /
    // activity.end calls actually flush, leaving the confirm card un-rendered.
    // The user can tap the confirm card (.widgetURL("tenthirty://reward")) to open
    // the app when they're ready.
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Rating")
    var rating: Int

    init() {}
    init(rating: Int) { self.rating = rating }

    func perform() async throws -> some IntentResult {
        let savedRating = min(max(rating, 1), 5)

        // 1. Stash the rating in the App Group so the main app picks it up
        //    on next foreground and writes it into AppState.morningScore.
        let defaults = UserDefaults(suiteName: appGroupSuite)
        defaults?.set(savedRating, forKey: pendingRatingKey)
        defaults?.set(Date(), forKey: pendingRatingAtKey)

        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.removePendingNotificationRequests(withIdentifiers: morningRatingNotificationIdentifiers)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: morningRatingNotificationIdentifiers)

        // 2. Push the confirmation card immediately so the user sees
        //    "Your score is saved" within ~100ms — no app launch required.
        //    score/delta stay nil; the in-app reward sheet shows the real
        //    numbers when the user next opens the app.
        //    Then schedule the activity to auto-dismiss ~60s later. We do
        //    update + end (not end alone) because ending with content from
        //    the widget extension process is flaky about rendering the new
        //    state — update reliably swaps the card to .rated, end seals it.
        let dismissAt = Date().addingTimeInterval(60)
        for activity in Activity<LullSleepAttributes>.activities {
            var state = activity.content.state
            state.phase = .rated
            state.rating = savedRating
            state.score = Double(savedRating)
            state.deltaVsBaseline = nil
            state.baselineLabel = nil
            let content = ActivityContent(state: state, staleDate: nil, relevanceScore: 1.0)
            await activity.update(content)
        }

        // Give the Live Activity renderer a beat to paint the confirmation
        // before asking iOS to schedule dismissal. Ending in the same turn can
        // collapse the visible state change on-device.
        try? await Task.sleep(nanoseconds: 750_000_000)

        for activity in Activity<LullSleepAttributes>.activities {
            var state = activity.content.state
            state.phase = .rated
            state.rating = savedRating
            state.score = Double(savedRating)
            state.deltaVsBaseline = nil
            state.baselineLabel = nil
            let content = ActivityContent(state: state, staleDate: nil, relevanceScore: 1.0)
            await activity.end(content, dismissalPolicy: .after(dismissAt))
        }

        return .result()
    }
}
