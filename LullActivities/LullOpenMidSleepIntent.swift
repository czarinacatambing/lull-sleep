import AppIntents
import Foundation

private let appGroupSuite = "group.com.trylull.app"
private let pendingMidSleepKey = "lull_pendingOpenMidSleep"

// Foregrounds the app and asks it to switch to Mid-Sleep mode.
// We can't use OpenURLIntent here because that's iOS 18+ and Lull targets iOS 17,
// so we set a flag in the App Group and let LullApp pick it up on scenePhase.active.
struct LullOpenMidSleepIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Open Mid-Sleep mode"
    static var description = IntentDescription("Opens Lull to Mid-Sleep mode from the Lock Screen.")
    static var isDiscoverable: Bool = false
    static var openAppWhenRun: Bool = true

    init() {}

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: appGroupSuite)
        defaults?.set(true, forKey: pendingMidSleepKey)
        return .result()
    }
}
