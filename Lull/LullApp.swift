import SwiftUI
import UserNotifications

@main
struct LullApp: App {
    @StateObject private var state = AppState()
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let doneAction = UNNotificationAction(identifier: "MARK_DONE", title: "Mark done", options: [])
        let bedtimeCategory = UNNotificationCategory(
            identifier: "BEDTIME_REMINDER", actions: [doneAction], intentIdentifiers: [], options: [])

        let logAction = UNNotificationAction(identifier: "LOG_SLEEP", title: "Log it", options: [.foreground])
        let morningCategory = UNNotificationCategory(
            identifier: "MORNING_CHECKIN", actions: [logAction], intentIdentifiers: [], options: [])

        let midSleepAction = UNNotificationAction(identifier: "OPEN_MID_SLEEP", title: "Open Lull", options: [.foreground])
        let midSleepCategory = UNNotificationCategory(
            identifier: "MID_SLEEP_CHECK", actions: [midSleepAction], intentIdentifiers: [], options: [])

        UNUserNotificationCenter.current().setNotificationCategories([bedtimeCategory, morningCategory, midSleepCategory])
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
                .onAppear { appDelegate.state = state }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { state.persist() }
        }
    }
}

// Handles notification taps and routes them into AppState.
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var state: AppState?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let category = response.notification.request.content.categoryIdentifier
        DispatchQueue.main.async {
            if category == "MORNING_CHECKIN" {
                if let index = self.state?.sleepLogs.firstIndex(where: { $0.isToday }) {
                    self.state?.selectedDotIndex = index
                }
            } else if category == "MID_SLEEP_CHECK" {
                self.state?.showMidSleepMode = true
            }
        }
        completionHandler()
    }
}
