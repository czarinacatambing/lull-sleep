import SwiftUI

private struct SolidTabBarPreferenceKey: PreferenceKey {
    static var defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

private enum FirstFireflyHandoffWindow: Equatable {
    case wake
    case deck
}

extension View {
    func requestsSolidTabBar(_ active: Bool) -> some View {
        preference(key: SolidTabBarPreferenceKey.self, value: active)
    }
}

struct HomeTabView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject private var sleepSoundsAudio: SleepSoundsAudioStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedTab: Int
    @State private var currentDate = Date()
    @State private var insightsPanelTopInset: CGFloat = 0
    @State private var showFirstFireflyHandoff = false
    @State private var showFirstFireflyPrompt = false
    @State private var firstFireflyPromptIsBelowDeck = false
    @State private var firstFireflyDeckReleased = false
    @State private var earnedFireflyEntranceToken = 0
    @State private var didStartFirstFireflyHandoff = false
    @State private var childRequestsSolidTabBar = false
    private let minuteTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    init() { _selectedTab = State(initialValue: 0) }
    init(initialTab: Int) { _selectedTab = State(initialValue: initialTab) }

    private var miniPlayerVisible: Bool {
        sleepSoundsAudio.isPlaying
    }

    private var showsSharedMeadow: Bool {
        selectedTab == 0 || selectedTab == 1 || selectedTab == 2
    }

    private var sharedFireflyDates: [Date] {
        if shouldKeepFirstMeadowEmpty {
            return []
        }

        let calendar = Calendar.current
        var seen: Set<Date> = []
        let earned = state.sleepLogs
            .filter { $0.completedNightlyFlow }
            .map { calendar.startOfDay(for: $0.date) }
            .sorted()
            .filter { date in
                seen.insert(date).inserted
            }

        return Array(earned.suffix(TodayDeckConstants.maxVisibleFireflies))
    }

    private var shouldKeepFirstMeadowEmpty: Bool {
        state.isOnboardingFireflyCompanionActive
            && state.pendingOnboardingFireflyHandoff
            && !state.hasSeenFirstFireflyPrompt
    }

    private var canStartFirstFireflyHandoff: Bool {
        shouldKeepFirstMeadowEmpty && selectedTab == 0
    }

    private var firstFireflyHandoffWindow: FirstFireflyHandoffWindow {
        if isInSleepWindow || currentDate >= firstPrepStartForCurrentSleepWindow {
            return .deck
        }
        return .wake
    }

    private var shouldHoldDashboardDeckForFirstFireflyPrompt: Bool {
        shouldKeepFirstMeadowEmpty
            && firstFireflyHandoffWindow == .deck
            && !firstFireflyDeckReleased
    }

    private var shouldSuppressMorningForFirstFireflyPrompt: Bool {
        shouldKeepFirstMeadowEmpty
            && firstFireflyHandoffWindow == .wake
    }

    private var firstPrepStartForCurrentSleepWindow: Date {
        let cal = Calendar.current
        let bedComponents = cal.dateComponents([.hour, .minute], from: state.typicalBedtime)
        let bedAnchor = state.bedtimeDate(for: currentDate, calendar: cal)

        let bedtime = cal.date(
            bySettingHour: bedComponents.hour ?? 22,
            minute: bedComponents.minute ?? 30,
            second: 0,
            of: bedAnchor
        ) ?? state.typicalBedtime

        let firstLeadMinutes = state.preWindDownSteps
            .map(\.resolvedLeadTimeMins)
            .max() ?? state.windDownDurationMinutes

        return cal.date(byAdding: .minute, value: -firstLeadMinutes, to: bedtime) ?? bedtime
    }

    private var isInSleepWindow: Bool {
        let cal = Calendar.current
        let nowMins = cal.component(.hour, from: currentDate) * 60 + cal.component(.minute, from: currentDate)
        let bedMins = cal.component(.hour, from: state.typicalBedtime) * 60 + cal.component(.minute, from: state.typicalBedtime)
        let wakeMins = cal.component(.hour, from: state.typicalWakeTime) * 60 + cal.component(.minute, from: state.typicalWakeTime)

        if bedMins > wakeMins {
            return nowMins >= bedMins || nowMins < wakeMins
        }
        return nowMins >= bedMins && nowMins < wakeMins
    }

    private var sharedLoggedShadeDates: Set<Date> {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: currentDate)
        return Set(state.sleepLogs.compactMap { entry in
            let day = calendar.startOfDay(for: entry.date)
            guard calendar.isDate(day, equalTo: currentDate, toGranularity: .month),
                  day < today
            else { return nil }
            return day
        })
    }

    private var sharedFireflyMode: TodayFireflyMode {
        selectedTab == 1 ? .calendar : .cluster
    }

    private var sharedCalendarTopInset: CGFloat {
        selectedTab == 1 ? insightsPanelTopInset : 0
    }

    private var tabBarIsSolid: Bool {
        childRequestsSolidTabBar || selectedTab == 3
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if showsSharedMeadow {
                TodayMeadowBackdrop()
                    .ignoresSafeArea()
                    .transition(.opacity)

                AmberGlow(x: 0.5, y: -0.05, radius: 260, opacity: 0.55)
                    .ignoresSafeArea()
                    .transition(.opacity)

                TodayFireflyScene(
                    mode: sharedFireflyMode,
                    dates: sharedFireflyDates,
                    currentDate: currentDate,
                    loggedShadeDates: sharedLoggedShadeDates,
                    calendarTopInset: sharedCalendarTopInset,
                    entranceToken: earnedFireflyEntranceToken,
                    reduceMotion: reduceMotion
                )
                .ignoresSafeArea()
                .opacity(0.86)
                .allowsHitTesting(false)
                .transition(.opacity)
            }

            TabView(selection: $selectedTab) {
                DashboardView(
                    selectedTab: $selectedTab,
                    suppressDeckForFirstFireflyPrompt: shouldHoldDashboardDeckForFirstFireflyPrompt,
                    suppressMorningRateForFirstFireflyPrompt: shouldSuppressMorningForFirstFireflyPrompt,
                    onFirstDeckInteraction: {
                        dismissFirstFireflyPrompt(method: "interaction")
                    },
                    onRoutineCompleted: {
                        earnedFireflyEntranceToken += 1
                    }
                )
                    .tag(0)
                TodayInsightsTabView(
                    currentDate: currentDate,
                    sharedCalendarTopInset: $insightsPanelTopInset
                )
                    .tag(1)
                MyRoutineView()
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear
                    .frame(height: miniPlayerVisible ? SleepSoundsMiniPlayerLayout.reservedHeight : 0)
            }

            if selectedTab == 3 {
                MidSleepModeView {
                    selectedTab = 0
                }
                    .transition(.opacity)
                    .zIndex(1)
            }

            // Custom tab bar
            HStack(spacing: 0) {
                TabBarButton(title: "Today", icon: "moon.fill", selected: selectedTab == 0) {
                    selectedTab = 0
                }
                TabBarButton(title: "Insights", icon: "chart.xyaxis.line", selected: selectedTab == 1) {
                    selectedTab = 1
                }
                TabBarButton(title: "Routine", icon: "moon.stars.fill", selected: selectedTab == 2) {
                    selectedTab = 2
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            .background(
                Color.lullBg1
                    .opacity(tabBarIsSolid ? 0.98 : 0.18)
                    .ignoresSafeArea(edges: .bottom)
            )
            .overlay(alignment: .top) {
                Color.lullLine
                    .opacity(tabBarIsSolid ? 1 : 0.72)
                    .frame(height: 1)
            }

            if miniPlayerVisible {
                SleepSoundsMiniPlayer {
                    state.showSleepSounds = true
                }
                .padding(.horizontal, 16)
                .padding(.bottom, SleepSoundsMiniPlayerLayout.bottomAboveTabBar)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(2)
            }

            if showFirstFireflyHandoff && selectedTab == 0 {
                TodayFirstFireflyFlyAway(reduceMotion: reduceMotion)
                    .allowsHitTesting(false)
                    .transition(.opacity)
                    .zIndex(3)
            }

            if showFirstFireflyPrompt && selectedTab == 0 {
                GeometryReader { geo in
                    TodayFirstFireflyCoachmark(window: firstFireflyHandoffWindow)
                        .frame(width: min(geo.size.width - 58, 330))
                        .position(
                            x: geo.size.width / 2,
                            y: firstFireflyPromptY(in: geo)
                        )
                }
                .allowsHitTesting(false)
                .transition(.opacity)
                .zIndex(3)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .animation(.easeInOut(duration: 0.22), value: miniPlayerVisible)
        .animation(.easeInOut(duration: 0.24), value: showsSharedMeadow)
        .animation(.easeInOut(duration: 0.18), value: tabBarIsSolid)
        .animation(.easeInOut(duration: 0.28), value: showFirstFireflyPrompt)
        .onPreferenceChange(SolidTabBarPreferenceKey.self) { childRequestsSolidTabBar = $0 }
        // Shake / programmatic activation -> jump to hidden Mid-sleep page.
        .onChange(of: state.showMidSleepMode) { _, active in
            if active {
                sleepSoundsAudio.stop()
                selectedTab = 3
                state.showMidSleepMode = false
            }
        }
        // Catch the cold-launch race: if the Live Activity / URL handler set
        // showMidSleepMode = true before this view mounted (welcome splash up),
        // onChange never fired. Pick it up on first appear.
        .onAppear {
            if state.showMidSleepMode {
                sleepSoundsAudio.stop()
                selectedTab = 3
                state.showMidSleepMode = false
            }
            if let requested = state.requestedTab {
                selectedTab = requested
                state.requestedTab = nil
            }
            startFirstFireflyHandoffIfNeeded()
        }
        .onReceive(minuteTimer) { date in
            currentDate = date
            advanceFirstFireflyPromptForCurrentWindowIfNeeded()
        }
        // Restore brightness when navigating away from Mid-sleep
        .onChange(of: selectedTab) { oldTab, newTab in
            if newTab == 3 {
                sleepSoundsAudio.stop()
            }
            if oldTab == 3 && newTab != 3 {
                state.restoreBrightnessAfterMidSleep()
            }
            if newTab == 0 {
                startFirstFireflyHandoffIfNeeded()
            }
        }
        // External tab-switch requests (e.g. after dismissing the promotion celebration)
        .onChange(of: state.requestedTab) { _, requested in
            if let requested {
                selectedTab = requested
                state.requestedTab = nil
            }
        }
        .onChange(of: state.pendingOnboardingFireflyHandoff) { _, _ in
            startFirstFireflyHandoffIfNeeded()
        }
        .onChange(of: firstFireflyHandoffWindow) { _, _ in
            advanceFirstFireflyPromptForCurrentWindowIfNeeded()
        }
    }

    private func startFirstFireflyHandoffIfNeeded() {
        guard canStartFirstFireflyHandoff, !didStartFirstFireflyHandoff else { return }
        didStartFirstFireflyHandoff = true
        showFirstFireflyHandoff = true
        firstFireflyPromptIsBelowDeck = false
        firstFireflyDeckReleased = false

        let flyDuration = reduceMotion ? 0.36 : 1.45
        DispatchQueue.main.asyncAfter(deadline: .now() + flyDuration) {
            showFirstFireflyHandoff = false
            guard state.isOnboardingFireflyCompanionActive,
                  state.pendingOnboardingFireflyHandoff,
                  !state.hasSeenFirstFireflyPrompt,
                  selectedTab == 0
            else { return }

            state.trackTodayFirstFireflyPromptShown()
            withAnimation(.easeInOut(duration: 0.4)) {
                showFirstFireflyPrompt = true
            }

            advanceFirstFireflyPromptForCurrentWindowIfNeeded()
        }
    }

    private func advanceFirstFireflyPromptForCurrentWindowIfNeeded() {
        guard showFirstFireflyPrompt,
              firstFireflyHandoffWindow == .deck,
              !firstFireflyPromptIsBelowDeck,
              !state.hasSeenFirstFireflyPrompt
        else { return }

        let centerPause = reduceMotion ? 0.2 : 1.8
        DispatchQueue.main.asyncAfter(deadline: .now() + centerPause) {
            guard showFirstFireflyPrompt,
                  firstFireflyHandoffWindow == .deck,
                  !firstFireflyPromptIsBelowDeck,
                  !state.hasSeenFirstFireflyPrompt
            else { return }

            withAnimation(reduceMotion ? .easeOut(duration: 0.18) : .spring(response: 0.72, dampingFraction: 0.86)) {
                firstFireflyPromptIsBelowDeck = true
            }

            let deckDelay = reduceMotion ? 0.12 : 0.62
            DispatchQueue.main.asyncAfter(deadline: .now() + deckDelay) {
                guard showFirstFireflyPrompt,
                      firstFireflyHandoffWindow == .deck,
                      !state.hasSeenFirstFireflyPrompt
                else { return }
                withAnimation(.easeInOut(duration: reduceMotion ? 0.16 : 0.32)) {
                    firstFireflyDeckReleased = true
                }
            }
        }
    }

    private func firstFireflyPromptY(in geo: GeometryProxy) -> CGFloat {
        if firstFireflyHandoffWindow == .deck && firstFireflyPromptIsBelowDeck {
            return min(geo.size.height - geo.safeAreaInsets.bottom - 168, geo.size.height * 0.77)
        }
        return geo.size.height * 0.50
    }

    private func dismissFirstFireflyPrompt(method: String) {
        guard state.isOnboardingFireflyCompanionActive,
              !state.hasSeenFirstFireflyPrompt,
              (showFirstFireflyPrompt || showFirstFireflyHandoff || state.pendingOnboardingFireflyHandoff)
        else { return }

        withAnimation(.easeOut(duration: 0.22)) {
            showFirstFireflyPrompt = false
            showFirstFireflyHandoff = false
            firstFireflyPromptIsBelowDeck = false
            firstFireflyDeckReleased = true
        }
        state.hasSeenFirstFireflyPrompt = true
        state.pendingOnboardingFireflyHandoff = false
        state.trackTodayFirstFireflyPromptDismissed(method: method)
    }
}

private struct TodayFirstFireflyFlyAway: View {
    let reduceMotion: Bool
    @State private var leaving = false

    var body: some View {
        GeometryReader { geo in
            let safeBottom = geo.safeAreaInsets.bottom
            let start = CGPoint(
                x: geo.size.width - 58,
                y: geo.size.height - safeBottom - 116
            )
            let end = CGPoint(
                x: geo.size.width * 0.62,
                y: -42
            )

            FireflyDot(index: 0, reduceMotion: true, drifts: false)
                .scaleEffect(reduceMotion ? 1.0 : (leaving ? 0.75 : 1.18))
                .opacity(leaving ? 0 : 1)
                .position(reduceMotion ? start : (leaving ? end : start))
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.34) : .easeIn(duration: 1.45)) {
                leaving = true
            }
        }
    }
}

private struct TodayFirstFireflyCoachmark: View {
    let window: FirstFireflyHandoffWindow

    private var copy: String {
        switch window {
        case .wake:
            return "Earn your first firefly in your meadow by completing tonight's sleep routine.\nWe'll send you the reminders later."
        case .deck:
            return "Earn your first firefly by completing tonight's sleep routine. Customize the routine as needed in the Routine tab."
        }
    }

    var body: some View {
        Text(copy)
            .font(.system(size: 13.5, weight: .medium, design: .default))
            .foregroundColor(.lullInk2.opacity(0.78))
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
    }
}

struct TabBarButton: View {
    var title: String
    var icon: String
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(selected ? .lullAmber : .lullInk3)
                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(selected ? .lullAmber : .lullInk3)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }
}
