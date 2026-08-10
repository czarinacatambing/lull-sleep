import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

struct AppBlockingMonitorWindow: Codable, Equatable, Identifiable {
    enum Reason: String, Codable {
        case rule
        case sleepWindow
        case reconcile
    }

    enum Recurrence: String, Codable {
        case oneTime
        case daily
    }

    let id: String
    let start: Date
    let end: Date
    let reason: Reason
    let ruleTitle: String?
    let wakeTimeText: String?
    let recurrence: Recurrence
    let startMinuteOfDay: Int
    let endMinuteOfDay: Int

    init(id: String,
         start: Date,
         end: Date,
         reason: Reason,
         ruleTitle: String?,
         wakeTimeText: String?,
         recurrence: Recurrence = .oneTime) {
        self.id = id
        self.start = start
        self.end = end
        self.reason = reason
        self.ruleTitle = ruleTitle
        self.wakeTimeText = wakeTimeText
        self.recurrence = recurrence
        let calendar = Calendar.current
        self.startMinuteOfDay = calendar.component(.hour, from: start) * 60
            + calendar.component(.minute, from: start)
        self.endMinuteOfDay = calendar.component(.hour, from: end) * 60
            + calendar.component(.minute, from: end)
    }

    private enum CodingKeys: String, CodingKey {
        case id, start, end, reason, ruleTitle, wakeTimeText, recurrence, startMinuteOfDay, endMinuteOfDay
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        start = try container.decode(Date.self, forKey: .start)
        end = try container.decode(Date.self, forKey: .end)
        reason = try container.decode(Reason.self, forKey: .reason)
        ruleTitle = try container.decodeIfPresent(String.self, forKey: .ruleTitle)
        wakeTimeText = try container.decodeIfPresent(String.self, forKey: .wakeTimeText)
        recurrence = try container.decodeIfPresent(Recurrence.self, forKey: .recurrence) ?? .oneTime
        let calendar = Calendar.current
        startMinuteOfDay = try container.decodeIfPresent(Int.self, forKey: .startMinuteOfDay)
            ?? calendar.component(.hour, from: start) * 60 + calendar.component(.minute, from: start)
        endMinuteOfDay = try container.decodeIfPresent(Int.self, forKey: .endMinuteOfDay)
            ?? calendar.component(.hour, from: end) * 60 + calendar.component(.minute, from: end)
    }
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
    private static let gentleBypassUntilKey = "tenthirty_gentleBypassUntil"

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
        windows().filter { isActive($0, now: now) }
    }

    static func isActive(_ window: AppBlockingMonitorWindow, now: Date) -> Bool {
        guard window.reason != .reconcile else { return false }
        switch window.recurrence {
        case .oneTime:
            return window.start <= now && now < window.end
        case .daily:
            guard now >= window.start else { return false }
            let calendar = Calendar.current
            let nowMinutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
            let startMinutes = window.startMinuteOfDay
            let endMinutes = window.endMinuteOfDay
            if startMinutes == endMinutes { return true }
            if startMinutes < endMinutes {
                return nowMinutes >= startMinutes && nowMinutes < endMinutes
            }
            return nowMinutes >= startMinutes || nowMinutes < endMinutes
        }
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
        guard !isTemporaryUnlockActive(now: now) else {
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
        if window.reason == .reconcile {
            applyCurrentShield()
            return
        }
        applyShield(for: window)
    }

    private static func applyShield(for window: AppBlockingMonitorWindow) {
        let store = ManagedSettingsStore()
        guard isActive(window, now: Date()) else {
            applyCurrentShield()
            return
        }
        guard !isTemporaryUnlockActive() else {
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

    private static func isTemporaryUnlockActive(now: Date = Date()) -> Bool {
        let defaults = UserDefaults(suiteName: suiteName)
        let emergencyUntil = defaults?.object(forKey: emergencyAppAccessUntilKey) as? Date
        let gentleBypassUntil = defaults?.object(forKey: gentleBypassUntilKey) as? Date
        return [emergencyUntil, gentleBypassUntil]
            .compactMap { $0 }
            .contains { now < $0 }
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
        case .reconcile:
            break
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
