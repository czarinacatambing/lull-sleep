import AppIntents
import ActivityKit

private let appGroupSuite = "group.com.trylull.app"
private let pendingTogglesKey = "lull_pendingPrepToggles"

struct TogglePrepItemIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Mark prep item done"
    static var description = IntentDescription("Toggles a bedtime prep item from the lock screen.")
    static var isDiscoverable: Bool = false
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Item ID")
    var itemId: String

    init() {}
    init(itemId: String) { self.itemId = itemId }

    func perform() async throws -> some IntentResult {
        // Update the Live Activity state directly so the lock screen refreshes instantly.
        for activity in Activity<PrepChecklistAttributes>.activities {
            var doneIds = activity.content.state.doneIds
            if let idx = doneIds.firstIndex(of: itemId) {
                doneIds.remove(at: idx)
            } else {
                doneIds.append(itemId)
            }
            let newState = PrepChecklistAttributes.ContentState(
                doneIds: doneIds,
                updatedAt: Date()
            )
            await activity.update(ActivityContent(state: newState, staleDate: nil))
        }

        // Write to App Group so the main app stays in sync when it opens.
        let defaults = UserDefaults(suiteName: appGroupSuite)
        var pending = defaults?.stringArray(forKey: pendingTogglesKey) ?? []
        if let idx = pending.firstIndex(of: itemId) {
            pending.remove(at: idx)
        } else {
            pending.append(itemId)
        }
        defaults?.set(pending, forKey: pendingTogglesKey)
        defaults?.synchronize()

        return .result()
    }
}
