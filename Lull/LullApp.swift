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

        let startRitualAction = UNNotificationAction(identifier: "OPEN_RITUAL", title: "Start ritual", options: [.foreground])
        let windDownStartCategory = UNNotificationCategory(
            identifier: "WIND_DOWN_START", actions: [startRitualAction], intentIdentifiers: [], options: [])

        let appLockedAction = UNNotificationAction(identifier: "OPEN_TODAY", title: "Open TenThirty", options: [.foreground])
        let appLockedCategory = UNNotificationCategory(
            identifier: "APP_LOCKED", actions: [appLockedAction], intentIdentifiers: [], options: [])

        let contractRuleAction = UNNotificationAction(identifier: "OPEN_TODAY", title: "Open TenThirty", options: [.foreground])
        let contractRuleCategory = UNNotificationCategory(
            identifier: "SLEEP_CONTRACT_RULE", actions: [contractRuleAction], intentIdentifiers: [], options: [])

        UNUserNotificationCenter.current().setNotificationCategories([
            bedtimeCategory,
            windDownStartCategory,
            appLockedCategory,
            contractRuleCategory
        ])
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
                .environmentObject(subscriptions)
                .environmentObject(sleepSoundsAudio)
                .onAppear {
                    #if DEBUG
                    state.applyUITestLaunchArgumentsIfNeeded()
                    #endif
                    appDelegate.state = state
                    PostHogReplayService.configureIfNeeded(installId: state.installId)
                    state.trackFirstOpenIfNeeded()
                    subscriptions.start(postHogUserID: state.installId)
                    state.clearObsoleteNotifications()
                }
                .onChange(of: subscriptions.hasResolvedInitialCustomerInfo) { _, resolved in
                    guard resolved else { return }
                    state.applyRevenueCatEntitlement(isActive: subscriptions.isLullProActive)
                    state.evaluateTrialStatus()
                }
                .onChange(of: subscriptions.isLullProActive) { _, isActive in
                    state.applyRevenueCatEntitlement(isActive: isActive)
                    state.evaluateTrialStatus()
                }
                .onOpenURL { url in
                    guard url.scheme == "tenthirty" else { return }
                    if url.host == "awake" {
                        state.requestedTab = 0
                        LiveActivityService.shared.endCurrentSleepActivity(dismissalPolicy: .immediate)
                    } else if url.host == "reward" {
                        state.ingestPendingLiveActivityRating()
                    } else if url.host == "liveactivity" {
                        if state.shouldRouteLiveActivityTapToMorning() {
                            state.requestedTab = 0
                            LiveActivityService.shared.endCurrentSleepActivity(dismissalPolicy: .immediate)
                        }
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
                state.refreshAppBlockingShield()
                state.persist()
            case .active:
                Task { await subscriptions.refreshCustomerInfo() }
                state.evaluateTrialStatus()
                state.trackAppOpened()
                state.flushResearchData()
                state.clearObsoleteNotifications()
                if state.handleTimeZoneChangeIfNeeded() {
                    state.scheduleAllNotifications()
                }
                state.refreshAppBlockingShield()
                if !state.hasCompletedOnboarding {
                    state.resetPrepIfNeeded()
                    state.refreshPrepLiveActivityIfEligible()
                    // Apply any prep-item toggles made from the Lock Screen while the app was closed.
                    let pendingIds = LiveActivityService.shared.consumePendingToggles()
                    for id in pendingIds { state.togglePrepFromLiveActivity(id) }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        let pendingIds = LiveActivityService.shared.consumePendingToggles()
                        for id in pendingIds { state.togglePrepFromLiveActivity(id) }
                    }
                } else {
                    LiveActivityService.shared.end(dismissalPolicy: .immediate)
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
            case "BEDTIME_REMINDER":
                self.state?.requestedTab = 0
            case "WIND_DOWN_START":
                self.state?.cancelWindDownStartNotifications()
                self.state?.requestedTab = 0
            case "APP_LOCKED", "SLEEP_CONTRACT_RULE":
                self.state?.requestedTab = 0
            default:
                break
            }
        }
        completionHandler()
    }
}
