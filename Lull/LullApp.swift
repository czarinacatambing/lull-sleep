import SwiftUI
import UserNotifications

@main
struct LullApp: App {
    @StateObject private var state = AppState()
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate

    init() {
        let doneAction = UNNotificationAction(identifier: "MARK_DONE", title: "Mark done", options: [])
        let bedtimeCategory = UNNotificationCategory(
            identifier: "BEDTIME_REMINDER", actions: [doneAction], intentIdentifiers: [], options: [])

        let logAction = UNNotificationAction(identifier: "LOG_SLEEP", title: "Log it", options: [.foreground])
        let morningCategory = UNNotificationCategory(
            identifier: "MORNING_CHECKIN", actions: [logAction], intentIdentifiers: [], options: [])

        UNUserNotificationCenter.current().setNotificationCategories([bedtimeCategory, morningCategory])
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
                .onAppear { appDelegate.state = state }
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

    // Called when user taps a notification (or its action) while app is backgrounded or closed.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let category = response.notification.request.content.categoryIdentifier
        if category == "MORNING_CHECKIN" {
            DispatchQueue.main.async {
                // Find today's log entry and open it
                if let index = self.state?.sleepLogs.firstIndex(where: { $0.isToday }) {
                    self.state?.selectedDotIndex = index
                }
            }
        }
        completionHandler()
    }
}
