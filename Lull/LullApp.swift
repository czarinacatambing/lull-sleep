import SwiftUI
import UserNotifications

@main
struct LullApp: App {
    @StateObject private var state = AppState()
    @StateObject private var subscriptions = LullSubscriptionManager()
    @StateObject private var sleepSoundsAudio = SleepSoundsAudioStore()
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @Environment(\.scenePhase) private var scenePhase

    init() {
        LullRevenueCatConfig.configure()

        let doneAction = UNNotificationAction(identifier: "MARK_DONE", title: "Mark done", options: [])
        let bedtimeCategory = UNNotificationCategory(
            identifier: "BEDTIME_REMINDER", actions: [doneAction], intentIdentifiers: [], options: [])

        let logAction = UNNotificationAction(identifier: "LOG_SLEEP", title: "Log it", options: [.foreground])
        let morningCategory = UNNotificationCategory(
            identifier: "MORNING_CHECKIN", actions: [logAction], intentIdentifiers: [], options: [])

        let midSleepAction = UNNotificationAction(identifier: "OPEN_MID_SLEEP", title: "Open Lull", options: [.foreground])
        let midSleepCategory = UNNotificationCategory(
            identifier: "MID_SLEEP_CHECK", actions: [midSleepAction], intentIdentifiers: [], options: [])

        let startRitualAction = UNNotificationAction(identifier: "OPEN_RITUAL", title: "Start ritual", options: [.foreground])
        let windDownStartCategory = UNNotificationCategory(
            identifier: "WIND_DOWN_START", actions: [startRitualAction], intentIdentifiers: [], options: [])

        UNUserNotificationCenter.current().setNotificationCategories([bedtimeCategory, morningCategory, midSleepCategory, windDownStartCategory])
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
                .environmentObject(subscriptions)
                .environmentObject(sleepSoundsAudio)
                .onAppear {
                    appDelegate.state = state
                    subscriptions.start()
                    state.applyRevenueCatEntitlement(isActive: subscriptions.isLullProActive)
                    state.evaluateTrialStatus()
                }
                .onChange(of: subscriptions.isLullProActive) { _, isActive in
                    state.applyRevenueCatEntitlement(isActive: isActive)
                    state.evaluateTrialStatus()
                }
                .onOpenURL { url in
                    guard url.scheme == "lull" else { return }
                    if url.host == "midsleep" {
                        state.showMidSleepMode = true
                    } else if url.host == "reward" {
                        state.ingestPendingLiveActivityRating()
                    } else if url.host == "rate" {
                        let ratingValue = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                            .queryItems?
                            .first(where: { $0.name == "score" || $0.name == "rating" })?
                            .value
                        if let ratingValue, let rating = Int(ratingValue), (1...5).contains(rating) {
                            state.ingestLiveActivityRating(rating: rating)
                        }
                    } else if url.host == "prep-done" {
                        let itemId = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                            .queryItems?
                            .first(where: { $0.name == "id" })?
                            .value
                        if let itemId, let id = UUID(uuidString: itemId) {
                            state.completePrepFromLiveActivity(id)
                        }
                    }
                }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                state.persist()
            case .active:
                Task { await subscriptions.refreshCustomerInfo() }
                state.evaluateTrialStatus()
                state.trackAppOpened()
                state.flushResearchData()
                if state.handleTimeZoneChangeIfNeeded() {
                    state.scheduleAllNotifications()
                }
                state.refreshAppBlockingShield()
                // Apply any prep-item toggles made from the Lock Screen while the app was closed.
                let pendingIds = LiveActivityService.shared.consumePendingToggles()
                for id in pendingIds { state.togglePrepDone(id) }
                // The Sleep Companion "Mid-Sleep mode" button writes a flag
                // to the App Group before openAppWhenRun foregrounds us.
                // Delay slightly so the extension process has time to flush.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if LiveActivityService.shared.consumePendingMidSleepRequest() {
                        state.showMidSleepMode = true
                    }
                }
                // Sync the Sleep Companion data state to the wake phase if we
                // crossed wake time, then pull in any rating tapped from the
                // Lock Screen and publish the .rated confirmation.
                state.syncSleepActivityWakeStateIfNeeded()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    state.ingestPendingLiveActivityRating()
                }
            default:
                break
            }
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
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let category = response.notification.request.content.categoryIdentifier
        DispatchQueue.main.async {
            switch category {
            case "MORNING_CHECKIN", "BEDTIME_REMINDER":
                // Both surfaces live on the Today tab now — the morning hero
                // handles rating, and the prep checklist sits below it for
                // bedtime prep items.
                self.state?.requestedTab = 0
            case "WIND_DOWN_START":
                self.state?.cancelWindDownStartNotifications()
                self.state?.showNightlyFlow = true
            case "MID_SLEEP_CHECK":
                self.state?.showMidSleepMode = true
            default:
                break
            }
        }
        completionHandler()
    }
}
