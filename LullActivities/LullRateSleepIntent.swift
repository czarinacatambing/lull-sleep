import ActivityKit
import AppIntents
import Foundation

private let appGroupSuite = "group.com.trylull.app"
private let pendingRatingKey = "lull_pendingMorningRating"
private let pendingRatingAtKey = "lull_pendingMorningRatingAt"

// Records a morning sleep rating from the Live Activity wake-state dots
// without foregrounding the app. The dots fill immediately via a local
// activity.update; the final score + delta is computed when the app next
// foregrounds (see LiveActivityService.applyPendingRating).
struct LullRateSleepIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Rate last night"
    static var description = IntentDescription("Records last night's sleep rating from the Lock Screen.")
    static var isDiscoverable: Bool = false
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Rating")
    var rating: Int

    init() {}
    init(rating: Int) { self.rating = rating }

    func perform() async throws -> some IntentResult {
        // 1. Stash the rating in the App Group so the main app picks it up
        //    on next foreground and writes it into AppState.morningScore.
        let defaults = UserDefaults(suiteName: appGroupSuite)
        defaults?.set(rating, forKey: pendingRatingKey)
        defaults?.set(Date(), forKey: pendingRatingAtKey)

        // 2. Push an interim update to the current Sleep Activity so the
        //    dots fill within ~100ms. We set phase = .awaitingRating
        //    (the data state catches up to what the view has already been
        //    rendering since wakeTime) and the rating value.
        for activity in Activity<LullSleepAttributes>.activities {
            var state = activity.content.state
            state.phase = .awaitingRating
            state.rating = rating
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }

        return .result()
    }
}
