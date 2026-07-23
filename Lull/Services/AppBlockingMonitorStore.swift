import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

struct AppBlockingMonitorWindow: Codable, Equatable, Identifiable {
    enum Reason: String, Codable {
        case rule
        case sleepWindow
    }

    let id: String
    let start: Date
    let end: Date
    let reason: Reason
    let ruleTitle: String?
    let wakeTimeText: String?
}

enum AppBlockingMonitorStore {
    static let suiteName = "group.com.trylull.app"

    private static let selectionDataKey = "tenthirty_monitorSelectionData"
    private static let windowsDataKey = "tenthirty_monitorWindowsData"
    private static let activityNamesKey = "tenthirty_monitorActivityNames"
    private static let shieldWakeTimeTextKey = "tenthirty_shieldWakeTimeText"
    private static let shieldLockReasonKey = "tenthirty_shieldLockReason"
    private static let shieldRuleTitleKey = "tenthirty_shieldRuleTitle"
    private static let emergencyAppAccessUntilKey = "tenthirty_emergencyAppAccessUntil"

    static func save(selection: FamilyActivitySelection, windows: [AppBlockingMonitorWindow]) {
        let defaults = UserDefaults(suiteName: suiteName)
        defaults?.set(try? JSONEncoder().encode(selection), forKey: selectionDataKey)
        defaults?.set(try? JSONEncoder().encode(windows), forKey: windowsDataKey)
    }

    static func clearSchedule() {
        let defaults = UserDefaults(suiteName: suiteName)
        defaults?.removeObject(forKey: selectionDataKey)
        defaults?.removeObject(forKey: windowsDataKey)
        defaults?.removeObject(forKey: activityNamesKey)
    }

    static func activityNames() -> [DeviceActivityName] {
        let rawNames = UserDefaults(suiteName: suiteName)?.stringArray(forKey: activityNamesKey) ?? []
        return rawNames.map { DeviceActivityName($0) }
    }

    static func saveActivityNames(_ names: [DeviceActivityName]) {
        UserDefaults(suiteName: suiteName)?.set(names.map(\.rawValue), forKey: activityNamesKey)
    }

    static func activeWindows(now: Date = Date()) -> [AppBlockingMonitorWindow] {
        windows().filter { $0.start <= now && now < $0.end }
    }

    static func window(for activityName: DeviceActivityName) -> AppBlockingMonitorWindow? {
        let prefix = "tenthirty.lock."
        guard activityName.rawValue.hasPrefix(prefix) else { return nil }
        let id = String(activityName.rawValue.dropFirst(prefix.count))
        return windows().first { $0.id == id }
    }

    static func windows() -> [AppBlockingMonitorWindow] {
        guard let data = UserDefaults(suiteName: suiteName)?.data(forKey: windowsDataKey),
              let decoded = try? JSONDecoder().decode([AppBlockingMonitorWindow].self, from: data) else {
            return []
        }
        return decoded
    }

    static func applyCurrentShield(now: Date = Date()) {
        let store = ManagedSettingsStore()
        guard !isEmergencyAccessActive(now: now) else {
            store.clearAllSettings()
            return
        }
        let active = activeWindows(now: now)
        guard let window = active.sorted(by: windowSort).first,
              let selection = savedSelection(),
              (!selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty) else {
            store.clearAllSettings()
            return
        }

        syncShieldContext(for: window)
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
    }

    static func applyShield(for activityName: DeviceActivityName) {
        guard let window = window(for: activityName) else {
            applyCurrentShield()
            return
        }
        applyShield(for: window)
    }

    private static func applyShield(for window: AppBlockingMonitorWindow) {
        let store = ManagedSettingsStore()
        guard !isEmergencyAccessActive() else {
            store.clearAllSettings()
            return
        }
        guard let selection = savedSelection(),
              (!selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty) else {
            store.clearAllSettings()
            return
        }

        syncShieldContext(for: window)
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
    }

    private static func isEmergencyAccessActive(now: Date = Date()) -> Bool {
        guard let until = UserDefaults(suiteName: suiteName)?.object(forKey: emergencyAppAccessUntilKey) as? Date else {
            return false
        }
        return now < until
    }

    private static func savedSelection() -> FamilyActivitySelection? {
        guard let data = UserDefaults(suiteName: suiteName)?.data(forKey: selectionDataKey) else {
            return nil
        }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }

    private static func syncShieldContext(for window: AppBlockingMonitorWindow) {
        let defaults = UserDefaults(suiteName: suiteName)
        defaults?.set(window.wakeTimeText, forKey: shieldWakeTimeTextKey)
        defaults?.set(window.ruleTitle, forKey: shieldRuleTitleKey)
        switch window.reason {
        case .rule:
            defaults?.set("rule", forKey: shieldLockReasonKey)
        case .sleepWindow:
            defaults?.set("sleep_window", forKey: shieldLockReasonKey)
        }
        defaults?.synchronize()
    }

    private static func windowSort(_ lhs: AppBlockingMonitorWindow, _ rhs: AppBlockingMonitorWindow) -> Bool {
        if lhs.reason != rhs.reason {
            return lhs.reason == .sleepWindow
        }
        return lhs.start < rhs.start
    }
}
