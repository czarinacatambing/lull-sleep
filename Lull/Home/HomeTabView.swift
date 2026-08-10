import SwiftUI
import FamilyControls
import ManagedSettings

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
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: Int
    @State private var currentDate = Date()
    @State private var insightsPanelTopInset: CGFloat = 0
    @State private var showFirstFireflyHandoff = false
    @State private var showFirstFireflyPrompt = false
    @State private var isFirstFireflyIntroActive = false
    @State private var firstFireflyPromptIsBelowDeck = false
    @State private var firstFireflyDeckReleased = false
    @State private var earnedFireflyEntranceToken = 0
    @State private var optimisticContractFireflyDays: Set<Date> = []
    @State private var didStartFirstFireflyHandoff = false
    @State private var childRequestsSolidTabBar = false
    @State private var contractTrendRange: ContractTrendRange = .week
    @State private var showSettings = false
    @State private var readyForBedFireflyToken = 0
    @State private var readyForBedFireflyVisible = false
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
        let persisted = state.contractAllClearEvents
            .map { calendar.startOfDay(for: $0.contractDay) }
        let earned = (persisted + Array(optimisticContractFireflyDays))
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

    private var shouldHideTodayForFirstFireflyIntro: Bool {
        selectedTab == 0 && isFirstFireflyIntroActive
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
        selectedTab == 2 ? .calendar : .cluster
    }

    private var sharedCalendarTopInset: CGFloat {
        selectedTab == 2 ? insightsPanelTopInset : 0
    }

    private var sharedCalendarRange: TodayFireflyCalendarRange {
        contractTrendRange == .week ? .week : .month
    }

    private var tabBarIsSolid: Bool {
        childRequestsSolidTabBar
    }

    private var sharedFireflyAccessibilityIdentifier: String {
        selectedTab == 2 ? "shared-firefly-scene-calendar" : "shared-firefly-scene-cluster"
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
                    calendarRange: sharedCalendarRange,
                    entranceToken: earnedFireflyEntranceToken,
                    reduceMotion: reduceMotion
                )
                .ignoresSafeArea()
                .opacity(0.86)
                .allowsHitTesting(false)
                .transition(.opacity)

                #if DEBUG
                sharedFireflyUITestMarker
                #endif
            }

            TabView(selection: $selectedTab) {
                TodayContractQueueView(
                    onAllClear: {
                        triggerContractFireflyEntrance()
                    },
                    onFirstDeckInteraction: {
                        dismissFirstFireflyPrompt(method: "interaction")
                    },
                    onSettings: {
                        showSettings = true
                    }
                )
                    .tag(0)
                RulesContractEditorView()
                    .tag(1)
                ContractTrendsView(
                    currentDate: currentDate,
                    sharedCalendarTopInset: $insightsPanelTopInset,
                    range: $contractTrendRange
                )
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .opacity(shouldHideTodayForFirstFireflyIntro ? 0 : 1)
            .allowsHitTesting(!shouldHideTodayForFirstFireflyIntro)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear
                    .frame(height: miniPlayerVisible ? SleepSoundsMiniPlayerLayout.reservedHeight : 0)
            }

            if !shouldHideTodayForFirstFireflyIntro {
                // Custom tab bar
                HStack(spacing: 0) {
                    TabBarButton(title: "Today", icon: "moon.fill", selected: selectedTab == 0) {
                        selectedTab = 0
                    }
                    TabBarButton(title: "Rules", icon: "checkmark.shield", selected: selectedTab == 1) {
                        selectedTab = 1
                    }
                    TabBarButton(title: "Trends", icon: "chart.xyaxis.line", selected: selectedTab == 2) {
                        selectedTab = 2
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .background(
                    Color.lullBg1
                        .opacity(tabBarIsSolid ? 0.98 : 0.72)
                        .ignoresSafeArea(edges: .bottom)
                )
                .overlay(alignment: .top) {
                    Color.lullLine
                        .opacity(tabBarIsSolid ? 1 : 0.72)
                        .frame(height: 1)
                }
            }

            if miniPlayerVisible && !shouldHideTodayForFirstFireflyIntro {
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
                            y: geo.size.height * 0.50
                        )
                }
                .allowsHitTesting(false)
                .transition(.opacity)
                .zIndex(3)
            }

            if readyForBedFireflyVisible && selectedTab == 0 {
                ReadyForBedFireflyEntrance(token: readyForBedFireflyToken, reduceMotion: reduceMotion)
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
        .onAppear {
            refreshClockAndDailyState()
            if let requested = state.requestedTab {
                selectedTab = requested
                state.requestedTab = nil
            }
            startFirstFireflyHandoffIfNeeded()
        }
        .onReceive(minuteTimer) { date in
            currentDate = date
            state.resetPrepIfNeeded()
            advanceFirstFireflyPromptForCurrentWindowIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            refreshClockAndDailyState()
        }
        .onChange(of: selectedTab) { _, newTab in
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
        .sheet(isPresented: $showSettings) {
            SettingsSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private func triggerContractFireflyEntrance() {
        guard let event = state.recordContractAllClearIfNeeded() else { return }
        let contractDay = Calendar.current.startOfDay(for: event.contractDay)
        guard !reduceMotion else {
            optimisticContractFireflyDays.insert(contractDay)
            return
        }

        readyForBedFireflyToken += 1
        readyForBedFireflyVisible = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 5.1) {
            optimisticContractFireflyDays.insert(contractDay)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 7.2) {
            withAnimation(.easeInOut(duration: 0.45)) {
                readyForBedFireflyVisible = false
            }
        }
    }

    #if DEBUG
    private var sharedFireflyUITestMarker: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier(sharedFireflyAccessibilityIdentifier)
    }
    #endif

    private func refreshClockAndDailyState() {
        let now = Date()
        currentDate = now
        state.resetPrepIfNeeded()
        state.refreshAppBlockingShield(now: now)
        advanceFirstFireflyPromptForCurrentWindowIfNeeded()
    }

    private func startFirstFireflyHandoffIfNeeded() {
        guard canStartFirstFireflyHandoff, !didStartFirstFireflyHandoff else { return }
        didStartFirstFireflyHandoff = true
        isFirstFireflyIntroActive = true
        showFirstFireflyHandoff = false
        firstFireflyPromptIsBelowDeck = false
        firstFireflyDeckReleased = false

        let introDelay = reduceMotion ? 0.08 : 0.22
        DispatchQueue.main.asyncAfter(deadline: .now() + introDelay) {
            guard state.isOnboardingFireflyCompanionActive,
                  state.pendingOnboardingFireflyHandoff,
                  !state.hasSeenFirstFireflyPrompt,
                  selectedTab == 0
            else {
                isFirstFireflyIntroActive = false
                return
            }

            state.trackTodayFirstFireflyPromptShown()
            withAnimation(.easeInOut(duration: 0.4)) {
                showFirstFireflyPrompt = true
            }

            let holdDuration = reduceMotion ? 1.1 : 2.2
            DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration) {
                dismissFirstFireflyPrompt(method: "auto")
            }
        }
    }

    private func advanceFirstFireflyPromptForCurrentWindowIfNeeded() {
        guard showFirstFireflyPrompt,
              firstFireflyHandoffWindow == .deck,
              !state.hasSeenFirstFireflyPrompt
        else { return }

        let centerPause = firstFireflyPromptIsBelowDeck ? (reduceMotion ? 0.12 : 0.42) : (reduceMotion ? 0.2 : 1.8)
        DispatchQueue.main.asyncAfter(deadline: .now() + centerPause) {
            guard showFirstFireflyPrompt,
                  firstFireflyHandoffWindow == .deck,
                  !state.hasSeenFirstFireflyPrompt
            else { return }

            if !firstFireflyPromptIsBelowDeck {
                withAnimation(reduceMotion ? .easeOut(duration: 0.18) : .spring(response: 0.72, dampingFraction: 0.86)) {
                    firstFireflyPromptIsBelowDeck = true
                }
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
        if firstFireflyHandoffWindow == .deck {
            let belowCardLane = geo.size.height * 0.72
            let aboveGestureHint = geo.size.height - geo.safeAreaInsets.bottom - 258
            return min(belowCardLane, aboveGestureHint)
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
            isFirstFireflyIntroActive = false
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
            return "Earn your first firefly in your meadow by clearing tonight's sleep rules.\nWe'll send you the reminders later."
        case .deck:
            return "Earn your first firefly by clearing tonight's sleep rules."
        }
    }

    var body: some View {
        Text(copy)
            .font(.system(size: 13.5, weight: .medium, design: .default))
            .foregroundColor(.lullInk2.opacity(0.78))
            .multilineTextAlignment(.center)
            .lineSpacing(window == .deck ? 2 : 4)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, window == .deck ? 12 : 18)
            .padding(.vertical, window == .deck ? 6 : 14)
    }
}

private struct ReadyForBedFireflyEntrance: View {
    let token: Int
    let reduceMotion: Bool
    @State private var sequenceVisible = true
    @State private var dotVisible = false
    @State private var dotDrifting = false

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 24.0, paused: reduceMotion)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let mascotHeight: CGFloat = 219
                let bottomEdge = geo.size.height - 88
                let videoY = bottomEdge - mascotHeight / 2
                let driftX = reduceMotion || !dotDrifting ? 0 : sin(time * 0.72) * 18 + sin(time * 1.31) * 7
                let driftY = reduceMotion || !dotDrifting ? 0 : cos(time * 0.64) * 10 + sin(time * 1.08) * 5

                ZStack {
                    if !reduceMotion {
                        FireflyMascotView(phase: 1, reduceMotion: reduceMotion, playbackSpeed: 2)
                            .opacity(sequenceVisible ? 1 : 0)
                            .position(x: geo.size.width * 0.5, y: videoY)
                    }

                    FireflyDot(index: 0, reduceMotion: reduceMotion, drifts: !reduceMotion)
                        .scaleEffect(0.72)
                        .position(
                            x: geo.size.width * 0.5 - 1 + (dotVisible ? driftX : 0),
                            y: videoY + (dotVisible ? driftY : 0)
                        )
                        .opacity(dotVisible || reduceMotion ? 1 : 0)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: reduceMotion ? 0.12 : 0.42), value: sequenceVisible)
        .animation(.easeInOut(duration: reduceMotion ? 0.12 : 0.45), value: dotVisible)
        .animation(.easeInOut(duration: reduceMotion ? 0.12 : 0.55), value: dotDrifting)
        .onAppear(perform: start)
        .onChange(of: token) { _, _ in
            start()
        }
    }

    private func start() {
        sequenceVisible = true
        dotVisible = reduceMotion
        dotDrifting = reduceMotion
        guard !reduceMotion else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 4.45) {
            withAnimation(.easeInOut(duration: 0.45)) {
                dotVisible = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.92) {
            withAnimation(.easeInOut(duration: 0.42)) {
                sequenceVisible = false
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.08) {
            withAnimation(.easeInOut(duration: 0.55)) {
                dotDrifting = true
            }
        }
    }
}

private struct TodayContractQueueView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var sleepSoundsAudio: SleepSoundsAudioStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var appBlockingAccess = AppBlockingAccessProbe.shared
    @State private var now = Date()
    @State private var didReportAllClear = false
    @State private var appPickerSelection = FamilyActivitySelection()
    @State private var showMidSleepMode = false
    let onAllClear: () -> Void
    let onFirstDeckInteraction: () -> Void
    private let contractStateTimer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()
    @State private var showAppPicker = false
    @State private var showBlockedAppsRequiredAlert = false
    @State private var showEmergencyAccess = false
    let onSettings: () -> Void

    private var allowsMidSleepAccess: Bool {
        state.hasClearedContractDay(now: now)
            || state.isSleepRuleCompleted(.inBed, now: now)
    }

    var body: some View {
        let snapshot = state.sleepContractSnapshot(now: now)
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    ContractStatusStrip(
                        snapshot: snapshot,
                        appSelection: state.appBlockingSelection,
                        hasBlockedApps: state.hasBlockedAppTargets,
                        blockingStartTime: state.effectiveSleepWindowStart(now: now),
                        canEditBlockedApps: !state.isContractEditingLocked(now: now),
                        onEditBlockedApps: {
                            openBlockedAppsPicker()
                        },
                        activeEmergencyAccessEnd: state.activeEmergencyAppAccessEnd(now: now),
                        onEmergencyAccess: {
                            showEmergencyAccess = true
                        }
                    )

                    if state.selectedSleepRules.isEmpty {
                        emptyRules
                    } else if isSleepWindow(snapshot) {
                        if state.hasClearedContractDay(now: now) {
                            sleepWindowMessage(snapshot: snapshot)
                        } else {
                            rail(snapshot: snapshot)
                        }
                    } else {
                        rail(snapshot: snapshot)
                    }

                    Spacer().frame(height: 120)
                }
                .padding(.horizontal, 22)
                .padding(.top, 54)
            }

            if allowsMidSleepAccess && !showMidSleepMode {
                midSleepSwipeHint
                    .contentShape(Rectangle())
                    .gesture(midSleepSwipeUpGesture)
            }
        }
        .preferredColorScheme(.dark)
        .accessibilityIdentifier(queueAccessibilityIdentifier)
        .animation(.spring(response: 0.48, dampingFraction: 0.84), value: showMidSleepMode)
        .fullScreenCover(isPresented: $showMidSleepMode) {
            MidSleepModeView(onExit: { showMidSleepMode = false })
                .environmentObject(state)
                .environmentObject(sleepSoundsAudio)
        }
        .accessibilityAction(named: "Show wind down tools") {
            guard allowsMidSleepAccess, !showMidSleepMode else { return }
            showMidSleepMode = true
        }
        .familyActivityPicker(isPresented: $showAppPicker, selection: $appPickerSelection)
        .sheet(isPresented: $showEmergencyAccess) {
            EmergencyAppAccessSheet { reason, duration in
                state.startEmergencyAppAccess(reason: reason, duration: duration)
                showEmergencyAccess = false
                now = Date()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .alert("Choose apps to block first", isPresented: $showBlockedAppsRequiredAlert) {
            Button("Choose apps") { openBlockedAppsPicker() }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("TenThirty needs blocked apps before rule confirmations can do anything useful.")
        }
        .onReceive(contractStateTimer) { date in
            now = date
            handleAllClearIfNeeded()
        }
        .onAppear {
            now = Date()
            appPickerSelection = state.appBlockingSelection
            handleAllClearIfNeeded()
            state.refreshAppBlockingShield(now: now)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            now = Date()
            handleAllClearIfNeeded()
            state.refreshAppBlockingShield(now: now)
        }
        .onChange(of: showAppPicker) { _, open in
            guard !open else { return }
            saveBlockedAppsSelection()
        }
    }

    private var queueAccessibilityIdentifier: String {
        #if DEBUG
        return state.uiTestHoldConfirmFixtureActive ? "uitest-hold-fixture-active" : "today-contract-queue"
        #else
        return "today-contract-queue"
        #endif
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("Today")
                .font(.serif(30))
                .foregroundColor(.lullInk0)
            Spacer()
            Button(action: onSettings) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.04))
                        .frame(width: 38, height: 38)
                    Circle()
                        .strokeBorder(Color.lullLineStrong, lineWidth: 1)
                        .frame(width: 38, height: 38)
                    Image(systemName: "gearshape")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.lullInk2)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
    }

    private var emptyRules: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No rules enabled")
                .font(.serif(24))
                .foregroundColor(.lullInk0)
            Text("Open Rules to choose the contract you want TenThirty to protect.")
                .font(.system(size: 14.5, weight: .medium))
                .foregroundColor(.lullInk2)
        }
        .padding(18)
        .contractCardBackground()
    }

    private var allClear: some View {
        VStack(spacing: 12) {
            Text("ALL CLEAR")
                .font(.system(size: 11, weight: .semibold))
                .kerning(1.8)
                .foregroundColor(.lullAmberSoft)
                .frame(maxWidth: .infinity, alignment: .center)
            Text("You cleared today's commitments.")
                .font(.serif(28))
                .foregroundColor(.lullInk0)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .center)
            Text("Your selected apps will be blocked at \(Self.timeFormatter.string(from: state.typicalBedtime)).")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.lullInk2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 30)
        .frame(minHeight: 340, alignment: .center)
    }

    private func nextCyclePreview(snapshot: SleepContractEnforcementSnapshot) -> some View {
        let pending = visiblePendingItems(snapshot).sorted(by: sleepRuleDisplaySort)
        let nextBedtime = state.effectiveSleepWindowStart(now: now)

        return VStack(spacing: 12) {
            Text("NEXT SLEEP CYCLE")
                .font(.system(size: 11, weight: .semibold))
                .kerning(1.8)
                .foregroundColor(.lullAmberSoft)
                .frame(maxWidth: .infinity, alignment: .center)
            Text("Your full rule list is back.")
                .font(.serif(28))
                .foregroundColor(.lullInk0)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .center)
            Text("Apps lock again at \(Self.timeFormatter.string(from: nextBedtime)).")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.lullInk2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .center)

            if !pending.isEmpty {
                VStack(spacing: 0) {
                    ForEach(pending) { item in
                        RuleRailRow(item: item, now: now)
                    }
                }
                .padding(.top, 8)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 30)
        .frame(minHeight: 340, alignment: .center)
    }

    private var startsTomorrow: some View {
        VStack(spacing: 12) {
            Text("STARTS TOMORROW")
                .font(.system(size: 11, weight: .semibold))
                .kerning(1.8)
                .foregroundColor(.lullAmberSoft)
                .frame(maxWidth: .infinity, alignment: .center)
            Text("We'll start with the rules you committed to tomorrow.")
                .font(.serif(28))
                .foregroundColor(.lullInk0)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .center)
            Text("Your selected apps will still be blocked during your sleep window tonight.")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.lullInk2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 30)
        .frame(minHeight: 340, alignment: .center)
    }

    private func sleepWindowMessage(snapshot: SleepContractEnforcementSnapshot) -> some View {
        VStack(spacing: 12) {
            Text("SLEEP WINDOW")
                .font(.system(size: 11, weight: .semibold))
                .kerning(1.8)
                .foregroundColor(.lullAmberSoft)
                .frame(maxWidth: .infinity, alignment: .center)
            Text("It's time for sleep.")
                .font(.serif(28))
                .foregroundColor(.lullInk0)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .center)
            Text("Your selected apps are now blocked until \(sleepWindowWakeText(snapshot: snapshot)).")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.lullInk2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 30)
        .frame(minHeight: 340, alignment: .center)
    }

    private func sleepWindowWakeText(snapshot: SleepContractEnforcementSnapshot) -> String {
        if case .sleepWindow(let until) = snapshot.lockState {
            return Self.timeFormatter.string(from: until)
        }
        return Self.timeFormatter.string(from: state.appBlockingEndTime)
    }

    private func isSleepWindow(_ snapshot: SleepContractEnforcementSnapshot) -> Bool {
        if case .sleepWindow = snapshot.lockState { return true }
        return false
    }

    private var midSleepSwipeHint: some View {
        Text("Swipe up to access tools for wind down")
            .font(.system(size: 12.5, weight: .medium))
            .foregroundColor(.lullInk2.opacity(0.72))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.bottom, 108)
            .transition(.opacity)
    }

    private var midSleepSwipeUpGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                guard allowsMidSleepAccess else { return }
                let dx = value.translation.width
                let dy = value.translation.height
                guard -dy > 80, -dy > abs(dx) else { return }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showMidSleepMode = true
            }
    }

    // MARK: Checkpoint rail

    @ViewBuilder
    private func rail(snapshot: SleepContractEnforcementSnapshot) -> some View {
        let done = doneItems(snapshot)
        let hero = heroItem(snapshot)
        let upcoming = upcomingItems(snapshot, excluding: hero)

        VStack(alignment: .leading, spacing: 0) {
            ForEach(done) { item in
                DoneRailRow(item: item)
            }

            if let hero {
                HeroRuleCard(
                    item: hero,
                    now: now,
                    canComplete: state.canCompleteSleepRule(hero, now: now),
                    requiresBlockedApps: hero.rule != .inBed && state.requiresBlockedAppsBeforeRuleActions,
                    appSelection: state.appBlockingSelection,
                    reduceMotion: reduceMotion,
                    showInlineSlipAcknowledgment: hasAnotherHeroAfterSlip(hero: hero, snapshot: snapshot),
                    onConfirm: { confirmRule(hero) },
                    onSlip: { recordSlip(hero) },
                    onChooseApps: { openBlockedAppsPicker() }
                )
                .id(hero.id)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity
                ))

                if shouldShowOtherCommitmentsStartTomorrow(hero: hero, snapshot: snapshot) {
                    otherCommitmentsStartTomorrowNote
                }

                ForEach(upcoming) { item in
                    RuleRailRow(item: item, now: now)
                }

                railFooter(cleared: done.count, total: totalCount(snapshot))
            } else {
                if allSelectedRulesStartTomorrow(snapshot) {
                    startsTomorrow
                    tomorrowFooter
                } else if state.hasClearedContractDay(now: now) {
                    allClear
                    railFooter(cleared: done.count, total: totalCount(snapshot))
                } else {
                    nextCyclePreview(snapshot: snapshot)
                    railFooter(cleared: done.count, total: totalCount(snapshot))
                }
            }
        }
        .background(alignment: .topLeading) {
            if !done.isEmpty || hero != nil {
                Rectangle()
                    .fill(Color.lullAmberDeep.opacity(0.5))
                    .frame(width: 2)
                    .offset(x: 7)
                    .padding(.vertical, 9)
            }
        }
    }

    private func railFooter(cleared: Int, total: Int) -> some View {
        Text("\(cleared) of \(total) cleared · apps blocked \(Self.timeFormatter.string(from: state.effectiveSleepWindowStart(now: now)))")
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.lullInk4)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 30)
            .padding(.top, 16)
    }

    private func confirmRule(_ item: SleepContractItem) {
        guard item.rule == .inBed || !state.requiresBlockedAppsBeforeRuleActions else {
            showBlockedAppsRequiredAlert = true
            return
        }
        onFirstDeckInteraction()
        withAnimation(reduceMotion ? .easeInOut(duration: 0.18) : .spring(response: 0.5, dampingFraction: 0.7)) {
            state.completeSleepRule(item, at: Date())
            now = Date()
        }
        handleAllClearIfNeeded()
    }

    private func hasAnotherHeroAfterSlip(hero: SleepContractItem,
                                         snapshot: SleepContractEnforcementSnapshot) -> Bool {
        visiblePendingItems(snapshot).contains { $0.id != hero.id }
    }

    private func recordSlip(_ item: SleepContractItem) {
        guard !state.requiresBlockedAppsBeforeRuleActions else {
            showBlockedAppsRequiredAlert = true
            return
        }
        onFirstDeckInteraction()
        withAnimation(reduceMotion ? .easeInOut(duration: 0.18) : .spring(response: 0.5, dampingFraction: 0.7)) {
            state.recordSleepRuleSlip(item, at: Date())
            now = Date()
        }
    }

    private func doneItems(_ snapshot: SleepContractEnforcementSnapshot) -> [SleepContractItem] {
        snapshot.allItems.filter(\.isResolved).sorted { $0.dueAt < $1.dueAt }
    }

    private func heroItem(_ snapshot: SleepContractEnforcementSnapshot) -> SleepContractItem? {
        SleepContractPresentation.heroItem(in: snapshot, sort: sleepRuleDisplaySort)
    }

    private func upcomingItems(_ snapshot: SleepContractEnforcementSnapshot,
                               excluding hero: SleepContractItem?) -> [SleepContractItem] {
        visiblePendingItems(snapshot)
            .filter { $0.id != hero?.id }
            .sorted(by: sleepRuleDisplaySort)
    }

    private func visiblePendingItems(_ snapshot: SleepContractEnforcementSnapshot) -> [SleepContractItem] {
        SleepContractPresentation.visiblePendingItems(snapshot)
    }

    private func sleepRuleDisplaySort(_ lhs: SleepContractItem, _ rhs: SleepContractItem) -> Bool {
        if lhs.rule == .inBed, rhs.rule != .inBed { return false }
        if lhs.rule != .inBed, rhs.rule == .inBed { return true }
        if lhs.graceEndsAt != rhs.graceEndsAt { return lhs.graceEndsAt < rhs.graceEndsAt }
        if lhs.dueAt != rhs.dueAt { return lhs.dueAt < rhs.dueAt }
        return lhs.rule.rawValue < rhs.rule.rawValue
    }

    private func totalCount(_ snapshot: SleepContractEnforcementSnapshot) -> Int {
        snapshot.allItems.filter { !$0.startsTomorrow }.count
    }

    private func allSelectedRulesStartTomorrow(_ snapshot: SleepContractEnforcementSnapshot) -> Bool {
        !state.selectedSleepRules.isEmpty &&
            !snapshot.allItems.isEmpty &&
            snapshot.allItems.allSatisfy(\.startsTomorrow)
    }

    private func shouldShowOtherCommitmentsStartTomorrow(hero: SleepContractItem,
                                                         snapshot: SleepContractEnforcementSnapshot) -> Bool {
        SleepContractPresentation.shouldShowOtherCommitmentsStartTomorrow(hero: hero, snapshot: snapshot)
    }

    private var otherCommitmentsStartTomorrowNote: some View {
        Text("All other commitments start tomorrow.")
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.lullInk3)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 6)
    }

    private var tomorrowFooter: some View {
        Text("Rules start tomorrow · apps blocked \(Self.timeFormatter.string(from: state.effectiveSleepWindowStart(now: now)))")
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.lullInk4)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 30)
            .padding(.top, 16)
    }

    private func handleAllClearIfNeeded() {
        guard state.hasClearedContractDay(now: now), !didReportAllClear else { return }
        didReportAllClear = true
        onAllClear()
    }

    private func openBlockedAppsPicker() {
        guard !state.isContractEditingLocked(now: now) else { return }
        appPickerSelection = state.appBlockingSelection
        Task { @MainActor in
            appBlockingAccess.refresh()
            if !appBlockingAccess.isApproved {
                state.trackHardAppBlockingPermissionRequested()
                await appBlockingAccess.requestAccess()
            }
            if appBlockingAccess.isApproved {
                showAppPicker = true
            }
        }
    }

    private func saveBlockedAppsSelection() {
        state.configureAppBlocking(
            selection: appPickerSelection,
            enabled: !appPickerSelection.applicationTokens.isEmpty || !appPickerSelection.categoryTokens.isEmpty,
            startTime: state.typicalBedtime,
            endTime: state.typicalWakeTime,
            graceMinutes: state.appBlockingGraceMinutes
        )
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
}

private struct ContractStatusStrip: View {
    private static let cardFill = Color(hex: "#332619")
    private static let cardBorder = Color(hex: "#4a3a22")
    private static let statusUnlocked = Color(hex: "#5fd08a")

    let snapshot: SleepContractEnforcementSnapshot
    let appSelection: FamilyActivitySelection
    let hasBlockedApps: Bool
    let blockingStartTime: Date
    let canEditBlockedApps: Bool
    let onEditBlockedApps: () -> Void
    let activeEmergencyAccessEnd: Date?
    let onEmergencyAccess: () -> Void

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { timeline in
            content(displayNow: timeline.date)
        }
    }

    private func content(displayNow: Date) -> some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                statusRow(displayNow: displayNow)
                appRow(displayNow: displayNow)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 14)

            if hasBlockedApps {
                Rectangle()
                    .fill(Self.cardBorder)
                    .frame(height: 0.5)

                emergencyAccessButton(displayNow: displayNow)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Self.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Self.cardBorder, lineWidth: 0.5)
                )
        )
    }

    private func statusRow(displayNow: Date) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)

            Text(title.uppercased())
                .font(.system(size: 13, weight: .medium))
                .kerning(0.78)
                .foregroundColor(statusTextColor)

            Spacer(minLength: 8)

            if let timeLabel = statusTimeLabel(displayNow: displayNow) {
                Text(timeLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.lullInk2)
                    .lineLimit(1)
            }
        }
    }

    private func appRow(displayNow: Date) -> some View {
        HStack(alignment: .center, spacing: 10) {
            ContractStatusAppIcons(selection: appSelection)

            VStack(alignment: .leading, spacing: 2) {
                Text(blockingTitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.lullInk0)
                    .lineLimit(1)
                Text(blockingSubtitle(displayNow: displayNow))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.lullInk2)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button(action: onEditBlockedApps) {
                Text(editLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(canEditBlockedApps ? Color(hex: "#e0b968") : .lullInk4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .strokeBorder(canEditBlockedApps ? Color(hex: "#6b5836") : Color.lullInk4.opacity(0.35), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canEditBlockedApps)
        }
    }

    private func emergencyAccessButton(displayNow: Date) -> some View {
        let isEnabled = canUseEmergencyAccess
        return Button(action: onEmergencyAccess) {
            HStack(spacing: 12) {
                Image(systemName: activeEmergencyAccessEnd.map { displayNow < $0 } == true ? "lock.open.fill" : "shield.lefthalf.filled")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isEnabled ? Color(hex: "#e0a338") : .lullInk4)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(isEnabled ? Color(hex: "#4a2f16") : Color.white.opacity(0.04)))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Emergency access")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(isEnabled ? .lullInk0 : .lullInk3)
                    Text(emergencyAccessText(displayNow: displayNow))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isEnabled ? .lullInk2 : .lullInk4)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isEnabled ? .lullInk3 : .lullInk4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private var canUseEmergencyAccess: Bool {
        snapshot.isLocked
    }

    private func emergencyAccessText(displayNow: Date) -> String {
        if let activeEmergencyAccessEnd, displayNow < activeEmergencyAccessEnd {
            return "Open until \(Self.timeFormatter.string(from: activeEmergencyAccessEnd))"
        }
        return "Unlock for 5–30 min"
    }

    private var dotColor: Color {
        if !hasBlockedApps { return .lullInk4 }
        switch snapshot.lockState {
        case .unlocked: return Self.statusUnlocked
        case .lockedByRule: return Color(hex: "#e89189")
        case .coolingDown: return .lullAmber
        case .sleepWindow: return .lullAmberSoft
        }
    }

    private var statusTextColor: Color {
        if !hasBlockedApps { return .lullInk2 }
        switch snapshot.lockState {
        case .unlocked: return Self.statusUnlocked
        case .lockedByRule: return Color(hex: "#e89189")
        case .coolingDown: return .lullAmber
        case .sleepWindow: return .lullAmberSoft
        }
    }

    private var title: String {
        if !hasBlockedApps && snapshot.isLocked { return "Set blocked apps" }
        switch snapshot.lockState {
        case .unlocked: return "Unlocked"
        case .lockedByRule: return "Apps are locked"
        case .coolingDown: return "Cooling down"
        case .sleepWindow: return "Sleep window"
        }
    }

    private var editLabel: String {
        guard canEditBlockedApps else { return "Locked" }
        return hasBlockedApps ? "Edit apps" : "Choose apps"
    }

    private var blockingTitle: String {
        let appCount = appSelection.applicationTokens.count
        let categoryCount = appSelection.categoryTokens.count
        let total = appCount + categoryCount
        if total == 0 { return "No apps selected" }
        if appCount > 0 && categoryCount > 0 {
            return "Blocking \(appCount) app\(appCount == 1 ? "" : "s") · \(categoryCount) categor\(categoryCount == 1 ? "y" : "ies")"
        }
        if appCount > 0 {
            return "Blocking \(appCount) app\(appCount == 1 ? "" : "s")"
        }
        return "Blocking \(categoryCount) categor\(categoryCount == 1 ? "y" : "ies")"
    }

    private func blockingSubtitle(displayNow: Date) -> String {
        if !hasBlockedApps {
            return "Choose apps so a missed rule can block them."
        }
        switch snapshot.lockState {
        case .unlocked:
            return "Starts at \(Self.timeFormatter.string(from: blockingStartTime)) tonight"
        case .lockedByRule(let item):
            return "\(item.rule.title) needs confirmation to unlock."
        case .coolingDown(let item, _):
            return "\(item.rule.title) was missed. Apps unlock in 10 min."
        case .sleepWindow(let until):
            return "Paused until \(Self.timeFormatter.string(from: until)) to protect your sleep."
        }
    }

    private func statusTimeLabel(displayNow: Date) -> String? {
        if !hasBlockedApps { return nil }
        switch snapshot.lockState {
        case .unlocked:
            return "until \(Self.timeFormatter.string(from: blockingStartTime))"
        case .lockedByRule:
            return nil
        case .coolingDown:
            return nil
        case .sleepWindow(let until):
            return "until \(Self.timeFormatter.string(from: until))"
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
}

private struct ContractStatusAppIcons: View {
    let selection: FamilyActivitySelection

    var body: some View {
        let apps = Array(selection.applicationTokens.prefix(3))
        let categoryCount = selection.categoryTokens.count

        HStack(spacing: -6) {
            ForEach(Array(apps.enumerated()), id: \.offset) { index, token in
                Label(token)
                    .labelStyle(.iconOnly)
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.25), lineWidth: 1)
                    )
                    .zIndex(Double(apps.count - index))
            }

            if apps.isEmpty, categoryCount > 0 {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.lullInk1)
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
            } else if categoryCount > 0 {
                Text("+\(categoryCount)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.lullInk1)
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.25), lineWidth: 1)
                    )
            } else if apps.isEmpty {
                Image(systemName: "apps.iphone")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.lullInk3)
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )
            }
        }
    }
}

// MARK: - App chips (real icons + names via FamilyControls Label(token))

private struct AppChips: View {
    let selection: FamilyActivitySelection

    var body: some View {
        let apps = Array(selection.applicationTokens)
        let categoryCount = selection.categoryTokens.count
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(apps, id: \.self) { token in
                    AppTokenChip(token: token)
                }
                if categoryCount > 0 {
                    ChipShell {
                        Text("+\(categoryCount) categor\(categoryCount == 1 ? "y" : "ies")")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.lullInk2)
                    }
                }
            }
        }
    }
}

private struct AppTokenChip: View {
    let token: ApplicationToken

    var body: some View {
        ChipShell {
            HStack(spacing: 6) {
                Label(token)
                    .labelStyle(.iconOnly)
                    .frame(width: 16, height: 16)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                Label(token)
                    .labelStyle(.titleOnly)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(.lullInk1)
                    .lineLimit(1)
            }
        }
    }
}

private struct ChipShell<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.white.opacity(0.03)))
            .overlay(Capsule().strokeBorder(Color.lullLineStrong, lineWidth: 1))
    }
}

// MARK: - Rule glyphs + shared formatter

private enum RuleGlyph {
    static func systemName(for rule: SleepRuleKind) -> String {
        switch rule {
        case .morningSun: return "sun.max.fill"
        case .caffeineCutoff: return "cup.and.saucer.fill"
        case .workoutCutoff: return "figure.strengthtraining.traditional"
        case .warmShower: return "shower.fill"
        case .dimLights: return "lightbulb.fill"
        case .tomorrowsPlan: return "checklist"
        case .gratitudeJournal: return "heart.text.square.fill"
        case .inBed: return "bed.double.fill"
        }
    }

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    static func scheduleText(for item: SleepContractItem) -> String {
        if item.isRange {
            return "\(timeFormatter.string(from: item.availableAt)) - \(timeFormatter.string(from: item.dueAt))"
        }
        return timeFormatter.string(from: item.dueAt)
    }
}

// MARK: - Rail bullet + rows

private struct RailBullet: View {
    enum Style { case done, active, upcoming }
    let style: Style

    var body: some View {
        Group {
            switch style {
            case .done:
                Circle().fill(Color.lullAmber)
                    .shadow(color: .lullAmberGlow, radius: 5)
            case .active:
                Circle().fill(Color.lullBg)
                    .overlay(Circle().strokeBorder(Color.lullAmber, lineWidth: 2))
                    .shadow(color: .lullAmberGlow, radius: 6)
            case .upcoming:
                Circle().fill(Color.lullBg)
                    .overlay(Circle().strokeBorder(Color.lullInk4, lineWidth: 2))
            }
        }
        .frame(width: 14, height: 14)
    }
}

private struct RailRow<Content: View>: View {
    let bullet: RailBullet.Style
    var topPad: CGFloat = 1
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            RailBullet(style: bullet)
                .padding(.top, topPad)
                .frame(width: 16, alignment: .center)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct DoneRailRow: View {
    let item: SleepContractItem

    var body: some View {
        RailRow(bullet: .done) {
            HStack {
                Text(item.rule.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.lullInk3)
                Spacer()
                Text(item.isSlipped ? "Missed" : RuleGlyph.scheduleText(for: item))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(item.isSlipped ? Color(hex: "#e89189") : .lullInk4)
            }
            .padding(.bottom, 16)
        }
        .accessibilityIdentifier("today-done-\(item.rule.rawValue)")
    }
}

private struct RuleRailRow: View {
    let item: SleepContractItem
    let now: Date

    var body: some View {
        RailRow(bullet: .upcoming) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(item.rule.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.lullInk2)
                    Spacer()
                    Text(RuleGlyph.scheduleText(for: item))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.lullInk3)
                }
                if item.startsTomorrow {
                    Text("Starts tomorrow")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.lullInk4)
                }
            }
            .opacity(item.startsTomorrow ? 0.7 : 1)
            .padding(.bottom, 16)
        }
    }
}

// MARK: - Hero rule card (hold-to-confirm + dust poof)

private struct HeroRuleCard: View {
    let item: SleepContractItem
    let now: Date
    let canComplete: Bool
    let requiresBlockedApps: Bool
    let appSelection: FamilyActivitySelection
    let reduceMotion: Bool
    let showInlineSlipAcknowledgment: Bool
    let onConfirm: () -> Void
    let onSlip: () -> Void
    let onChooseApps: () -> Void

    @State private var holdStartedAt: Date?
    @State private var isPoofing = false
    @State private var isShowingSlipAcknowledgment = false
    @State private var slipAckWorkItem: DispatchWorkItem?
    private let holdDuration: TimeInterval = 3
    private let slipAcknowledgmentDuration: TimeInterval = 1.4

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            RailBullet(style: .active)
                .padding(.top, 20)
                .frame(width: 16, alignment: .center)
            card
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var hasApps: Bool {
        !appSelection.applicationTokens.isEmpty || !appSelection.categoryTokens.isEmpty
    }

    private var card: some View {
        ZStack {
            cardBody
                .opacity(isPoofing ? 0 : (item.startsTomorrow ? 0.7 : 1))
                .scaleEffect(isPoofing ? 0.94 : 1)
                .blur(radius: isPoofing ? 6 : 0)
            if isPoofing {
                TodayCardDust()
                    .allowsHitTesting(false)
            }
        }
        .padding(.bottom, 20)
        .onDisappear {
            cancelSlipAcknowledgment(resetState: false)
        }
    }

    private var cardBody: some View {
        Group {
            if isShowingSlipAcknowledgment {
                slipAcknowledgmentBody
            } else {
                activeCardBody
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.18) : .easeInOut(duration: 0.28), value: isShowingSlipAcknowledgment)
    }

    private var activeCardBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 11) {
                // Decorative rule icon — engraved/flat so it reads as a label, not a button.
                Image(systemName: RuleGlyph.systemName(for: item.rule))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.lullAmberSoft)
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.black.opacity(0.18))
                            .overlay(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .strokeBorder(Color.lullLine, lineWidth: 1)
                            )
                    )
                    .accessibilityHidden(true)
                Text(metaText)
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(0.8)
                    .foregroundColor(statusColor)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }

            Text(item.rule.title)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.lullInk0)
                .fixedSize(horizontal: false, vertical: true)

            if item.startsTomorrow {
                Text("You joined after this checkpoint today.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.lullInk3)
                    .fixedSize(horizontal: false, vertical: true)
            } else if item.rule == .inBed {
                Text("Confirm you're ready for sleep. Then tonight's firefly is yours.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.lullInk2)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            } else if hasApps {
                Text("If missed, these get blocked:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.lullInk3)
                AppChips(selection: appSelection)
            } else {
                Text("Choose apps to block before confirming rules.")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(.lullInk3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            holdCTA

            if shouldShowSlipAction {
                slipAction
            }
        }
        .padding(16)
        .contractCardBackground(accent: canComplete)
    }

    private var slipAcknowledgmentBody: some View {
        VStack(spacing: 8) {
            Text("LOGGED")
                .font(.system(size: 11, weight: .semibold))
                .kerning(0.8)
                .foregroundColor(.lullAmberSoft)
            Text("Thanks for being honest.")
                .font(.serif(22))
                .foregroundColor(.lullInk0)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text("Apps unlock in 10 min.")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.lullInk2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 16)
        .padding(.vertical, 28)
        .contractCardBackground(accent: true)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Logged. Thanks for being honest. Apps unlock in 10 minutes.")
    }

    private var holdCTA: some View {
        Button(action: {
            if requiresBlockedApps {
                onChooseApps()
            }
        }) {
            holdCTAContent
        }
        .buttonStyle(.plain)
        .highPriorityGesture(holdDragGesture)
        .accessibilityAction {
            if requiresBlockedApps {
                onChooseApps()
            } else if canComplete {
                triggerConfirm()
            }
        }
        .onDisappear {
            cancelHold(resetProgress: false)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("today-hero-hold-confirm")
        .accessibilityLabel(holdCTAText)
        .accessibilityAddTraits(canComplete && !requiresBlockedApps ? [.isButton, .allowsDirectInteraction] : [])
    }

    private var holdCTAContent: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.white.opacity(0.045))
            TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 30.0, paused: holdStartedAt == nil)) { timeline in
                GeometryReader { proxy in
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(Color.lullAmber.opacity(0.28))
                        .frame(width: proxy.size.width * holdProgress(at: timeline.date))
                }
            }
            .allowsHitTesting(false)
            HStack {
                Spacer()
                Text(holdCTAText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(holdCTAColor)
                Spacer()
            }
            .allowsHitTesting(false)
        }
        .frame(height: 50)
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).strokeBorder(Color.lullLine, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private var shouldShowSlipAction: Bool {
        item.rule != .inBed && canComplete && !requiresBlockedApps && !item.startsTomorrow
    }

    private var slipAction: some View {
        VStack(spacing: 5) {
            Button(action: triggerSlip) {
                Text("I didn't keep it")
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundColor(.lullInk3)
                    .underline()
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("today-hero-slip")
            .disabled(isShowingSlipAcknowledgment)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
    }

    private var holdDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard !requiresBlockedApps, canComplete, !isPoofing, !isShowingSlipAcknowledgment else { return }
                if holdStartedAt == nil {
                    holdStartedAt = Date()
                }
            }
            .onEnded { _ in
                guard !requiresBlockedApps, canComplete, !isPoofing, !isShowingSlipAcknowledgment else {
                    cancelHold(resetProgress: true)
                    return
                }
                if let holdStartedAt,
                   Date().timeIntervalSince(holdStartedAt) >= holdDuration {
                    handleHoldCompleted()
                } else {
                    cancelHold(resetProgress: true)
                }
            }
    }

    private func handleHoldCompleted() {
        guard canComplete, !requiresBlockedApps, !isPoofing, !isShowingSlipAcknowledgment else { return }
        triggerConfirm()
    }

    private func cancelHold(resetProgress: Bool) {
        guard holdStartedAt != nil else { return }
        if resetProgress {
            withAnimation(.easeOut(duration: 0.18)) {
                holdStartedAt = nil
            }
        } else {
            holdStartedAt = nil
        }
    }

    private func holdProgress(at date: Date) -> CGFloat {
        guard let holdStartedAt else { return 0 }
        return min(1, max(0, CGFloat(date.timeIntervalSince(holdStartedAt) / holdDuration)))
    }

    // Poof the card into dust, then advance the queue.
    private func triggerConfirm() {
        guard !isPoofing else { return }
        if reduceMotion {
            onConfirm()
            return
        }
        withAnimation(.easeIn(duration: 0.34)) {
            isPoofing = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onConfirm()
        }
    }

    // Brief inline acknowledgment, then advance the queue (or show full slipsLogged when last).
    private func triggerSlip() {
        guard !isPoofing, !isShowingSlipAcknowledgment else { return }
        if !showInlineSlipAcknowledgment || reduceMotion {
            onSlip()
            return
        }
        cancelHold(resetProgress: true)
        isShowingSlipAcknowledgment = true
        slipAckWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            guard isShowingSlipAcknowledgment else { return }
            isShowingSlipAcknowledgment = false
            slipAckWorkItem = nil
            onSlip()
        }
        slipAckWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + slipAcknowledgmentDuration, execute: workItem)
    }

    private func cancelSlipAcknowledgment(resetState: Bool) {
        slipAckWorkItem?.cancel()
        slipAckWorkItem = nil
        if resetState {
            isShowingSlipAcknowledgment = false
        }
    }

    private var ctaText: String {
        if item.rule == .inBed { return "Hold 3 sec to confirm ready for sleep" }
        return "Hold 3 sec to confirm (I did it)"
    }

    private var holdCTAText: String {
        if requiresBlockedApps { return "Choose apps to block first" }
        return canComplete ? ctaText : "Available later"
    }

    private var holdCTAColor: Color {
        if requiresBlockedApps { return .lullAmber }
        return canComplete ? .lullAmber : .lullInk4
    }

    private var metaText: String {
        if item.startsTomorrow { return "STARTS TOMORROW" }
        let due = RuleGlyph.timeFormatter.string(from: item.dueAt)
        if item.rule == .inBed {
            return now >= item.dueAt ? "IN-BED CHECK" : "AVAILABLE AT \(due)"
        }
        if now > item.graceEndsAt {
            return "OVERDUE · WAS DUE \(due)"
        }
        let grace = RuleGlyph.timeFormatter.string(from: item.graceEndsAt)
        if item.isRange {
            let from = RuleGlyph.timeFormatter.string(from: item.availableAt)
            return "\(from.uppercased()) – \(due.uppercased())"
        }
        return "DUE \(due) · GRACE \(grace)"
    }

    private var statusColor: Color {
        now > item.graceEndsAt ? Color(hex: "#e89189") : .lullAmberSoft
    }
}

// MARK: - Dust poof (card disintegrates into amber motes)
// Forked from Components/Confetti.swift's TimelineView + Canvas engine.

private struct TodayCardDust: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            Color.clear
        } else {
            TodayCardDustCanvas()
        }
    }
}

private struct DustMote {
    let ux: CGFloat        // 0…1 origin across card width
    let uy: CGFloat        // 0…1 origin across card height
    let vx: CGFloat        // drift px
    let vy: CGFloat        // rise px (negative)
    let delay: Double      // left→right disintegration stagger
    let duration: Double
    let size: CGFloat
    let color: Color
}

private func dustSeeded(_ i: Int, _ seed: Int) -> Double {
    let raw = sin(Double(i) * 9301.0 + Double(seed) * 49297.0) * 233280.0
    return raw - floor(raw)
}

private func makeDustMotes(count: Int) -> [DustMote] {
    let palette: [Color] = [.lullAmber, .lullAmberSoft, .lullInk1, .lullInk0, .lullAmberDeep]
    return (0..<count).map { i in
        let ux = CGFloat(dustSeeded(i, 1))
        let uy = CGFloat(dustSeeded(i, 2))
        let vx = CGFloat((dustSeeded(i, 3) - 0.35) * 70)
        let vy = CGFloat(-(30 + dustSeeded(i, 4) * 80))
        let delay = Double(ux) * 0.24
        let duration = 0.42 + dustSeeded(i, 5) * 0.32
        let size = 1.2 + CGFloat(dustSeeded(i, 6)) * 2.4
        let color = palette[min(palette.count - 1, Int(dustSeeded(i, 7) * Double(palette.count)))]
        return DustMote(ux: ux, uy: uy, vx: vx, vy: vy, delay: delay, duration: duration, size: size, color: color)
    }
}

private struct TodayCardDustCanvas: View {
    @State private var motes: [DustMote] = []
    @State private var start: Date? = nil

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: start == nil)) { timeline in
            Canvas { context, size in
                guard let start else { return }
                let elapsed = timeline.date.timeIntervalSince(start)
                for mote in motes {
                    draw(mote, elapsed: elapsed, context: &context, size: size)
                }
            }
        }
        .onAppear {
            if motes.isEmpty { motes = makeDustMotes(count: 80) }
            start = Date()
        }
    }

    private func draw(_ mote: DustMote, elapsed: Double, context: inout GraphicsContext, size: CGSize) {
        let local = elapsed - mote.delay
        guard local > 0 else { return }
        let t = local / mote.duration
        guard t < 1 else { return }
        let x = mote.ux * size.width + mote.vx * CGFloat(t)
        let y = mote.uy * size.height + mote.vy * CGFloat(t) + CGFloat(t * t) * 36
        let opacity = 1 - t
        let s = max(0.5, mote.size * (1 - t * 0.55))
        context.fill(
            Path(ellipseIn: CGRect(x: x - s / 2, y: y - s / 2, width: s, height: s)),
            with: .color(mote.color.opacity(opacity))
        )
    }
}

private struct RulesContractEditorView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var appBlockingAccess = AppBlockingAccessProbe.shared
    @State private var selection = FamilyActivitySelection()
    @State private var showPicker = false
    @State private var didHydrate = false
    @State private var showBlockedAppsRequiredAlert = false
    @State private var now = Date()
    private let lockStateTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Rules")
                        .font(.serif(30))
                        .foregroundColor(.lullInk0)
                    Text("Edit your sleep contract, blocked apps, and enforcement.")
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundColor(.lullInk3)
                }

                if state.requiresBlockedAppsBeforeRuleActions {
                    blockedAppsRequiredCard
                }
                sleepWindowCard
                blockedAppsCard
                rulesList
                enforcementNote
                Spacer().frame(height: 118)
            }
            .padding(.horizontal, 22)
            .padding(.top, 54)
        }
        .preferredColorScheme(.dark)
        .familyActivityPicker(isPresented: $showPicker, selection: $selection)
        .alert("Choose apps to block first", isPresented: $showBlockedAppsRequiredAlert) {
            Button("Choose apps") { openBlockedAppsPicker() }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("Rules can be edited after TenThirty knows which apps it should lock.")
        }
        .onAppear {
            now = Date()
            hydrate()
        }
        .onReceive(lockStateTimer) { date in
            now = date
        }
        .onChange(of: showPicker) { _, open in
            guard !open else { return }
            saveBlockingSelection()
        }
    }

    private var blockedAppsRequiredCard: some View {
        Button {
            openBlockedAppsPicker()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.lullAmber)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.lullAmber.opacity(0.12)))

                VStack(alignment: .leading, spacing: 5) {
                    Text("Choose apps before editing rules")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.lullInk0)
                    Text("Your rules need something to enforce. Add blocked apps first, then you can change rule timing and grace periods.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.lullInk3)
                        .lineSpacing(3)
                }

                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.lullAmber)
                    .padding(.top, 5)
            }
            .padding(16)
            .contractCardBackground(accent: true)
        }
        .buttonStyle(.plain)
    }

    private var sleepWindowCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Kicker(text: "Sleep window", color: .lullAmberSoft)
            DatePicker("Sleep", selection: $state.typicalBedtime, displayedComponents: .hourAndMinute)
                .tint(.lullAmber)
                .disabled(isRuleConfigurationLocked)
            DatePicker("Wake", selection: $state.typicalWakeTime, displayedComponents: .hourAndMinute)
                .tint(.lullAmber)
                .disabled(isRuleConfigurationLocked)
            Text("Apps always lock during this window.")
                .font(.system(size: 13.5, weight: .medium))
                .foregroundColor(.lullInk3)
            if state.requiresBlockedAppsBeforeRuleActions {
                Text("Add apps to block before changing your sleep window.")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(.lullInk4)
                    .lineSpacing(3)
            }
            if isEditingLocked {
                Text("Sleep-window edits are available after the current lock clears.")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(.lullInk4)
                    .lineSpacing(3)
            }
        }
        .padding(18)
        .contractCardBackground()
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture {
            if state.requiresBlockedAppsBeforeRuleActions {
                showBlockedAppsRequiredAlert = true
            }
        }
        .onChange(of: state.typicalBedtime) { _, _ in state.sleepWindowWasEdited() }
        .onChange(of: state.typicalWakeTime) { _, _ in state.sleepWindowWasEdited() }
    }

    private var blockedAppsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Kicker(text: "Blocked apps", color: .lullAmberSoft)
                Spacer()
                Button("Edit apps") { openBlockedAppsPicker() }
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(isEditingLocked ? .lullInk4 : .lullAmber)
                    .buttonStyle(.plain)
                    .disabled(isEditingLocked)
            }
            Text(blockedAppSummary)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.lullInk0)
            Text("These apps lock after missed rules and during your sleep window.")
                .font(.system(size: 13.5, weight: .medium))
                .foregroundColor(.lullInk3)
                .lineSpacing(3)
            if !appBlockingAccess.isApproved {
                Text(appBlockingAccess.detailText)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(.lullInk4)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if isEditingLocked {
                Text("Blocked-app edits are available after this lock clears.")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(.lullInk4)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .contractCardBackground()
    }

    private var rulesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily rules")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.lullInk0)

            ForEach(SleepRuleKind.editableCases) { rule in
                RuleEditorRow(
                    rule: rule,
                    isEditingLocked: isEditingLocked,
                    requiresBlockedApps: state.requiresBlockedAppsBeforeRuleActions,
                    onBlockedAppsRequired: { showBlockedAppsRequiredAlert = true }
                )
                    .environmentObject(state)
            }
        }
    }

    private var enforcementNote: some View {
        Text("Complete your habit within 10 minutes to keep apps available. After that, confirm completion to unlock, or mark it missed for a 10-minute reset. During your sleep window, chosen apps pause until wake time.")
            .font(.system(size: 12.5, weight: .medium))
            .foregroundColor(.lullInk4.opacity(0.82))
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 18)
            .padding(.top, 2)
    }

    private var blockedAppSummary: String {
        let apps = selection.applicationTokens.count
        let categories = selection.categoryTokens.count
        if apps + categories == 0 { return "Choose the apps that steal your sleep." }
        if apps > 0 && categories > 0 { return "\(apps) apps · \(categories) categories selected" }
        if apps > 0 { return "\(apps) app\(apps == 1 ? "" : "s") selected" }
        return "\(categories) categor\(categories == 1 ? "y" : "ies") selected"
    }

    private func hydrate() {
        guard !didHydrate else { return }
        selection = state.appBlockingSelection
        appBlockingAccess.refresh()
        didHydrate = true
    }

    private func openBlockedAppsPicker() {
        guard !isEditingLocked else { return }
        selection = state.appBlockingSelection
        Task { @MainActor in
            appBlockingAccess.refresh()
            if !appBlockingAccess.isApproved {
                state.trackHardAppBlockingPermissionRequested()
                await appBlockingAccess.requestAccess()
            }
            if appBlockingAccess.isApproved {
                showPicker = true
            }
        }
    }

    private func saveBlockingSelection() {
        state.configureAppBlocking(
            selection: selection,
            enabled: !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty,
            startTime: state.typicalBedtime,
            endTime: state.typicalWakeTime,
            graceMinutes: state.appBlockingGraceMinutes
        )
    }

    private var isEditingLocked: Bool {
        state.isContractEditingLocked(now: now)
    }

    private var isRuleConfigurationLocked: Bool {
        isEditingLocked || state.requiresBlockedAppsBeforeRuleActions
    }
}

private struct RuleEditorRow: View {
    @EnvironmentObject private var state: AppState
    let rule: SleepRuleKind
    let isEditingLocked: Bool
    let requiresBlockedApps: Bool
    let onBlockedAppsRequired: () -> Void
    @State private var showingTimeEditor = false

    private var isEnabled: Binding<Bool> {
        Binding(
            get: { state.selectedSleepRules.contains(rule) },
            set: { enabled in
                guard !requiresBlockedApps else {
                    onBlockedAppsRequired()
                    return
                }
                if enabled != state.selectedSleepRules.contains(rule) {
                    state.toggleSleepRule(rule)
                }
            }
        )
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: { state.sleepContractPreviewItem(for: rule).dueAt },
            set: { state.setSleepRuleTime(rule, to: $0) }
        )
    }

    private var graceBinding: Binding<Int> {
        Binding(
            get: { state.sleepRuleGraceMinutes(rule) },
            set: { state.setSleepRuleGraceMinutes(rule, to: $0) }
        )
    }

    private var isConfigurationLocked: Bool {
        isEditingLocked || requiresBlockedApps
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.lullAmber)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.lullAmber.opacity(0.10)))
                VStack(alignment: .leading, spacing: 4) {
                    Text(rule.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.lullInk0)
                    Text(rule.detail)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(.lullInk3)
                        .lineSpacing(3)
                }
                Spacer()
                Toggle("", isOn: isEnabled)
                    .labelsHidden()
                    .tint(.lullAmber)
                    .disabled(isConfigurationLocked)
            }

            if isEnabled.wrappedValue {
                if rule == .morningSun {
                    Text("Active from 6:00 AM to 12:00 PM")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(.lullInk2)
                } else {
                    HStack {
                        Text("Due")
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundColor(.lullInk2)
                        Spacer()
                        Button {
                            showingTimeEditor = true
                        } label: {
                            Text(Self.timeFormatter.string(from: timeBinding.wrappedValue))
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundColor(.lullInk1)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.white.opacity(0.08))
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(isConfigurationLocked)
                    }
                    .sheet(isPresented: $showingTimeEditor) {
                        RuleDueTimeEditor(
                            rule: rule,
                            initialTime: timeBinding.wrappedValue
                        ) { confirmedTime in
                            state.setSleepRuleTime(rule, to: confirmedTime)
                        }
                    }
                }

                Stepper(value: graceBinding, in: 0...60, step: 5) {
                    Text("Grace: \(state.sleepRuleGraceMinutes(rule)) min")
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundColor(.lullInk2)
                }
                .tint(.lullAmber)
                .disabled(isConfigurationLocked)
                if requiresBlockedApps {
                    Text("Add apps to block before editing this rule.")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(.lullInk4)
                }
                if isEditingLocked {
                    Text("Rule edits start after the current lock clears.")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(.lullInk4)
                }
            }
        }
        .padding(16)
        .contractCardBackground(accent: isEnabled.wrappedValue)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture {
            if requiresBlockedApps {
                onBlockedAppsRequired()
            }
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    private var icon: String {
        switch rule {
        case .morningSun: return "sun.max.fill"
        case .caffeineCutoff: return "cup.and.saucer.fill"
        case .workoutCutoff: return "figure.strengthtraining.traditional"
        case .warmShower: return "shower.fill"
        case .dimLights: return "lightbulb.fill"
        case .tomorrowsPlan: return "checklist"
        case .gratitudeJournal: return "heart.text.square.fill"
        case .inBed: return "bed.double.fill"
        }
    }
}

private struct RuleDueTimeEditor: View {
    @Environment(\.dismiss) private var dismiss
    let rule: SleepRuleKind
    let onSave: (Date) -> Void
    @State private var selectedTime: Date

    init(rule: SleepRuleKind, initialTime: Date, onSave: @escaping (Date) -> Void) {
        self.rule = rule
        self.onSave = onSave
        _selectedTime = State(initialValue: initialTime)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Text("Choose the time you want \(rule.title.lowercased()) to be due.")
                    .font(.system(size: 14.5, weight: .medium))
                    .foregroundColor(.lullInk2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                DatePicker(
                    "Due time",
                    selection: $selectedTime,
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .datePickerStyle(.wheel)
                .tint(.lullAmber)

                Spacer(minLength: 0)
            }
            .padding(.top, 20)
            .background(Color.lullBgDeep.ignoresSafeArea())
            .navigationTitle(rule.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.lullInk2)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(selectedTime)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.lullAmber)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }
}

private enum ContractTrendRange: String, CaseIterable, Identifiable {
    case week = "Weekly"
    case month = "Monthly"
    var id: String { rawValue }
}

private struct ContractTrendsView: View {
    @EnvironmentObject private var state: AppState
    let currentDate: Date
    @Binding var sharedCalendarTopInset: CGFloat
    @Binding var range: ContractTrendRange

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                statsSection
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(key: ContractTrendsPanelHeightKey.self, value: proxy.size.height)
                        }
                    )

                trendsCalendar
                    .frame(height: calendarSpace)
                    .padding(.horizontal, 4)

                Spacer().frame(height: 118)
            }
        }
        .preferredColorScheme(.dark)
        .onPreferenceChange(ContractTrendsPanelHeightKey.self) { height in
            sharedCalendarTopInset = height + 22
        }
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Trends")
                    .font(.serif(30))
                    .foregroundColor(.lullInk0)
                Spacer()
                Picker("", selection: $range) {
                    ForEach(ContractTrendRange.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                trendStat(
                    "Nights protected",
                    value: "\(protectedNights)",
                    explanation: "The number of nights your selected apps were blocked during your sleep window."
                )
                trendStat(
                    "All-clear days",
                    value: "\(allClearDays)",
                    explanation: "Days when you completed every scheduled habit within its grace period."
                )
                trendStat(
                    "Lock activations",
                    value: "\(lockActivations)",
                    explanation: "Times your selected apps were blocked because a habit was missed."
                )
                trendStat(
                    "Late confirmations",
                    value: "\(lateConfirmations)",
                    explanation: "Habits confirmed after their grace period ended."
                )
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 54)
    }

    private var calendarSpace: CGFloat {
        range == .week ? 220 : 340
    }

    private var trendsCalendar: some View {
        Color.clear
            .accessibilityHidden(true)
    }

    private func trendStat(_ title: String, value: String, explanation: String) -> some View {
        TrendStatCard(title: title, value: value, explanation: explanation)
    }

    private var interval: DateInterval {
        let component: Calendar.Component = range == .week ? .weekOfYear : .month
        return Calendar.current.dateInterval(of: component, for: currentDate)
            ?? DateInterval(start: currentDate, duration: range == .week ? 7 * 86400 : 30 * 86400)
    }

    private var protectedNights: Int {
        sleepWindowEventDays.count
    }

    private var allClearDays: Int {
        state.contractAllClearEvents.filter {
            interval.contains($0.contractDay)
        }.count
    }

    private var lockActivations: Int {
        state.contractLockEvents.filter {
            $0.kind == .rule && interval.contains($0.occurredAt)
        }.count
    }

    private var sleepWindowEventDays: Set<Date> {
        let calendar = Calendar.current
        return Set(
            state.contractLockEvents
                .filter { $0.kind == .sleepWindow }
                .map { calendar.startOfDay(for: state.contractDay(forLockEvent: $0)) }
                .filter { interval.contains($0) }
        )
    }

    private var lateConfirmations: Int {
        state.sleepRuleCompletions.filter {
            !$0.completedWithinGrace && interval.contains($0.completedAt)
        }.count
    }

}

private struct TrendStatCard: View {
    let title: String
    let value: String
    let explanation: String
    @State private var isShowingExplanation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value)
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.lullAmber)

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(.lullInk3)
                    .lineLimit(2)
                Button {
                    isShowingExplanation = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.lullInk3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("About \(title)")
                .accessibilityHint("Shows an explanation of this statistic.")
                .popover(isPresented: $isShowingExplanation, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.lullInk0)
                        Text(explanation)
                            .font(.system(size: 14))
                            .foregroundColor(.lullInk2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .frame(width: 260, alignment: .leading)
                    .presentationCompactAdaptation(.popover)
                    .preferredColorScheme(.dark)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
        .padding(14)
        .contractCardBackground()
    }
}

private struct ContractTrendsPanelHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private extension View {
    func contractCardBackground(accent: Bool = false) -> some View {
        background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.lullBg2.opacity(0.40))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(accent ? Color.lullAmber.opacity(0.34) : Color.lullLine, lineWidth: 1)
                )
        )
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

enum SleepContractPresentation {
    static func heroItem(
        in snapshot: SleepContractEnforcementSnapshot,
        sort: (SleepContractItem, SleepContractItem) -> Bool
    ) -> SleepContractItem? {
        let pending = visiblePendingItems(snapshot)
        if let lockingItem = lockingItem(in: snapshot),
           let visibleLockingItem = pending.first(where: { $0.id == lockingItem.id }) {
            return visibleLockingItem
        }
        let visibleIDs = Set(pending.map(\.id))
        let actionable = snapshot.actionableItems
            .filter { visibleIDs.contains($0.id) }
            .sorted(by: sort)
        return actionable.first ?? pending.sorted(by: sort).first
    }

    static func deferredCommitments(in snapshot: SleepContractEnforcementSnapshot) -> [SleepContractItem] {
        snapshot.allItems.filter { item in
            item.startsTomorrow && !item.isResolved && item.rule != .inBed
        }
    }

    static func shouldShowOtherCommitmentsStartTomorrow(hero: SleepContractItem?,
                                                        snapshot: SleepContractEnforcementSnapshot) -> Bool {
        guard hero?.rule == .inBed else { return false }
        return !deferredCommitments(in: snapshot).isEmpty
    }

    static func visiblePendingItems(_ snapshot: SleepContractEnforcementSnapshot) -> [SleepContractItem] {
        let hasUnclearedRealRule = snapshot.allItems.contains {
            $0.rule.isPreBedRule && !$0.isCompleted && !$0.startsTomorrow
        }
        let hasVisibleReadyForSleep = snapshot.allItems.contains {
            $0.rule == .inBed && !$0.isResolved && !$0.startsTomorrow
        }
        let actionableIDs = Set(snapshot.actionableItems.map(\.id))
        let lockingItem = lockingItem(in: snapshot)
        var items = snapshot.allItems
        if let lockingItem, !items.contains(where: { $0.id == lockingItem.id }) {
            items.insert(lockingItem, at: 0)
        }

        return items.filter { item in
            guard !item.isResolved, !item.startsTomorrow else { return false }
            let mustRemainVisible = actionableIDs.contains(item.id) || item.id == lockingItem?.id
            if !mustRemainVisible,
               (snapshot.isSleepWindow || hasVisibleReadyForSleep),
               item.rule != .inBed,
               !item.rule.isPreBedRule {
                return false
            }
            if item.rule == .inBed, hasUnclearedRealRule {
                return false
            }
            return true
        }
    }

    private static func lockingItem(in snapshot: SleepContractEnforcementSnapshot) -> SleepContractItem? {
        switch snapshot.lockState {
        case .lockedByRule(let item):
            return item
        case .unlocked, .coolingDown, .sleepWindow:
            return nil
        }
    }
}
