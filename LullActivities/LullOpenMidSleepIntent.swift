import AppIntents
import Foundation

struct LullOpenMidSleepIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Open Mid-Sleep mode"
    static var description = IntentDescription("Mid-Sleep mode opens from the Today screen after Ready for sleep.")
    static var isDiscoverable: Bool = false
    static var openAppWhenRun: Bool = false

    init() {}

    func perform() async throws -> some IntentResult {
        return .result()
    }
}
