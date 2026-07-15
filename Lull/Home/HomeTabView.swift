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
                    calendarRange: sharedCalendarRange,
                    entranceToken: earnedFireflyEntranceToken,
                    reduceMotion: reduceMotion
                )
                .ignoresSafeArea()
                .opacity(0.86)
                .allowsHitTesting(false)
                .transition(.opacity)
            }

            TabView(selection: $selectedTab) {
                TodayContractQueueView(
                    onAllClear: {
                        triggerContractFireflyEntrance()
                    },
                    onFirstDeckInteraction: {
                        dismissFirstFireflyPrompt(method: "interaction")
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

            if selectedTab == 3 {
                MidSleepModeView {
                    selectedTab = 0
                }
                    .transition(.opacity)
                    .zIndex(1)
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

    private func triggerContractFireflyEntrance() {
        guard let event = state.recordContractAllClearIfNeeded() else { return }
        optimisticContractFireflyDays.insert(Calendar.current.startOfDay(for: event.contractDay))
        DispatchQueue.main.async {
            earnedFireflyEntranceToken += 1
        }
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

private struct TodayContractQueueView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var appBlockingAccess = AppBlockingAccessProbe.shared
    @State private var now = Date()
    @State private var didReportAllClear = false
    @State private var appPickerSelection = FamilyActivitySelection()
    let onAllClear: () -> Void
    let onFirstDeckInteraction: () -> Void
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var showAppPicker = false

    var body: some View {
        let snapshot = state.sleepContractSnapshot(now: now)
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                header
                ContractStatusStrip(
                    snapshot: snapshot,
                    appSelection: state.appBlockingSelection,
                    appSummary: appSummary,
                    hasBlockedApps: state.hasBlockedAppTargets,
                    canEditBlockedApps: !state.isContractEditingLocked(now: now),
                    onEditBlockedApps: {
                        openBlockedAppsPicker()
                    }
                )

                if state.selectedSleepRules.isEmpty {
                    emptyRules
                } else if isSleepWindow(snapshot) {
                    sleepWindowState(snapshot: snapshot)
                    if !state.hasClearedContractDay(now: now) {
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
        .preferredColorScheme(.dark)
        .contentShape(Rectangle())
        .familyActivityPicker(isPresented: $showAppPicker, selection: $appPickerSelection)
        .onReceive(timer) { date in
            now = date
            handleAllClearIfNeeded()
            state.refreshAppBlockingShield(now: date)
        }
        .onAppear {
            appPickerSelection = state.appBlockingSelection
            handleAllClearIfNeeded()
            state.refreshAppBlockingShield(now: now)
        }
        .onChange(of: showAppPicker) { _, open in
            guard !open else { return }
            saveBlockedAppsSelection()
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Tonight")
                .font(.serif(30))
                .foregroundColor(.lullInk0)
            Spacer()
            Text(Self.timeFormatter.string(from: now))
                .font(.system(size: 22, weight: .regular))
                .monospacedDigit()
                .foregroundColor(.lullInk1)
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
            Text("You cleared today's commitments.")
                .font(.serif(28))
                .foregroundColor(.lullInk0)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text("Your selected apps will be blocked at \(Self.timeFormatter.string(from: state.typicalBedtime)).")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.lullInk2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 30)
        .padding(.top, 28)
    }

    private func sleepWindowState(snapshot: SleepContractEnforcementSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Kicker(text: "Sleep window active", color: .lullAmberSoft)
            Text(state.hasBlockedAppTargets ? "Apps are blocked tonight." : "Choose blocked apps to protect this window.")
                .font(.serif(26))
                .foregroundColor(.lullInk0)
            Text(sleepWindowDetail(snapshot: snapshot))
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.lullInk2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .contractCardBackground(accent: state.hasBlockedAppTargets)
    }

    private func sleepWindowDetail(snapshot: SleepContractEnforcementSnapshot) -> String {
        guard state.hasBlockedAppTargets else {
            return "Rules still track here, but TenThirty cannot lock apps until you select them in Rules."
        }
        if case .sleepWindow(let until) = snapshot.lockState {
            return "Apps are blocked until \(Self.timeFormatter.string(from: until))."
        }
        return "Apps are blocked until wake."
    }

    private func isSleepWindow(_ snapshot: SleepContractEnforcementSnapshot) -> Bool {
        if case .sleepWindow = snapshot.lockState { return true }
        return false
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
                    appSelection: state.appBlockingSelection,
                    reduceMotion: reduceMotion,
                    onConfirm: { confirmRule(hero) }
                )
                .id(hero.id)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity
                ))

                ForEach(upcoming) { item in
                    RuleRailRow(item: item, now: now)
                }

                railFooter(cleared: done.count, total: totalCount(snapshot))
            } else {
                allClear
                railFooter(cleared: done.count, total: totalCount(snapshot))
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
        Text("\(cleared) of \(total) cleared · apps blocked \(Self.timeFormatter.string(from: state.typicalBedtime))")
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.lullInk4)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 30)
            .padding(.top, 16)
    }

    private func confirmRule(_ item: SleepContractItem) {
        onFirstDeckInteraction()
        withAnimation(reduceMotion ? .easeInOut(duration: 0.18) : .spring(response: 0.5, dampingFraction: 0.7)) {
            state.completeSleepRule(item, at: Date())
            now = Date()
        }
        handleAllClearIfNeeded()
    }

    private func doneItems(_ snapshot: SleepContractEnforcementSnapshot) -> [SleepContractItem] {
        snapshot.allItems.filter(\.isCompleted).sorted { $0.dueAt < $1.dueAt }
    }

    private func heroItem(_ snapshot: SleepContractEnforcementSnapshot) -> SleepContractItem? {
        let pending = snapshot.allItems.filter { !$0.isCompleted && !$0.startsTomorrow }
        let actionable = pending
            .filter { $0.availableAt <= now }
            .sorted { $0.graceEndsAt < $1.graceEndsAt }
        return actionable.first ?? pending.sorted { $0.dueAt < $1.dueAt }.first
    }

    private func upcomingItems(_ snapshot: SleepContractEnforcementSnapshot,
                               excluding hero: SleepContractItem?) -> [SleepContractItem] {
        snapshot.allItems
            .filter { !$0.isCompleted && $0.id != hero?.id }
            .sorted { $0.dueAt < $1.dueAt }
    }

    private func totalCount(_ snapshot: SleepContractEnforcementSnapshot) -> Int {
        snapshot.allItems.filter { !$0.startsTomorrow }.count
    }

    private var appSummary: String {
        let appCount = state.appBlockingSelection.applicationTokens.count
        let categoryCount = state.appBlockingSelection.categoryTokens.count
        let total = appCount + categoryCount
        if total == 0 { return "No apps selected yet" }
        if appCount > 0 && categoryCount > 0 { return "\(appCount) apps · \(categoryCount) categories" }
        if appCount > 0 { return "\(appCount) app\(appCount == 1 ? "" : "s") selected" }
        return "\(categoryCount) categor\(categoryCount == 1 ? "y" : "ies") selected"
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
    let snapshot: SleepContractEnforcementSnapshot
    let appSelection: FamilyActivitySelection
    let appSummary: String
    let hasBlockedApps: Bool
    let canEditBlockedApps: Bool
    let onEditBlockedApps: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: dotColor.opacity(0.7), radius: 5)
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .kerning(0.8)
                    .foregroundColor(.lullInk1)
                Spacer(minLength: 8)
                if hasBlockedApps {
                    Text(appSummary)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.lullInk3)
                        .lineLimit(1)
                }
                Button(action: onEditBlockedApps) {
                    Text(editLabel)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(canEditBlockedApps ? .lullAmber : .lullInk4)
                }
                .buttonStyle(.plain)
                .disabled(!canEditBlockedApps)
            }
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(.lullInk3)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contractCardBackground(accent: snapshot.isLocked && hasBlockedApps)
    }

    private var dotColor: Color {
        if !hasBlockedApps { return .lullInk4 }
        switch snapshot.lockState {
        case .unlocked: return Color(hex: "#7ed4a0")
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
        return hasBlockedApps ? "Edit" : "Choose apps"
    }

    private var subtitle: String? {
        if !canEditBlockedApps {
            return "Blocked-app edits unlock after this lock clears."
        }
        if !hasBlockedApps {
            return "Choose apps so a missed rule can block them."
        }
        switch snapshot.lockState {
        case .unlocked:
            return nil
        case .lockedByRule(let item):
            return "\(item.rule.title) was missed. Hold below to confirm late."
        case .coolingDown(let item, let until):
            return "Apps unlock in \(Self.countdown(until, from: snapshot.now)). \(item.rule.title) was late."
        case .sleepWindow(let until):
            return "Apps are blocked until \(Self.timeFormatter.string(from: until))."
        }
    }

    private static func countdown(_ end: Date, from start: Date) -> String {
        let seconds = max(0, Int(end.timeIntervalSince(start)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
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
                    .font(.system(size: 12, weight: .medium))
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
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
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
        }
    }

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
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
                Text(RuleGlyph.timeFormatter.string(from: item.dueAt))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.lullInk4)
            }
            .padding(.bottom, 16)
        }
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
                    Text(RuleGlyph.timeFormatter.string(from: item.dueAt))
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
    let appSelection: FamilyActivitySelection
    let reduceMotion: Bool
    let onConfirm: () -> Void

    @State private var holdProgress: CGFloat = 0
    @State private var isHolding = false
    @State private var holdWorkItem: DispatchWorkItem?
    @State private var isPoofing = false
    private let holdDuration: TimeInterval = 3

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
    }

    private var cardBody: some View {
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
            } else if hasApps {
                Text("If missed, these get blocked:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.lullInk3)
                AppChips(selection: appSelection)
            } else {
                Text("Choose apps in the strip above so this rule can protect them.")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(.lullInk3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            holdCTA
        }
        .padding(16)
        .contractCardBackground(accent: canComplete)
    }

    private var holdCTA: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.white.opacity(0.045))
            GeometryReader { proxy in
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Color.lullAmber.opacity(0.28))
                    .frame(width: proxy.size.width * holdProgress)
            }
            HStack {
                Spacer()
                Text(canComplete ? ctaText : "Available later")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(canComplete ? .lullAmber : .lullInk4)
                Spacer()
            }
        }
        .frame(height: 50)
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).strokeBorder(Color.lullLine, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .highPriorityGesture(holdGesture)
        .accessibilityAction {
            guard canComplete else { return }
            triggerConfirm()
        }
        .onDisappear {
            cancelHold(resetProgress: false)
        }
    }

    private var holdGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                startHoldIfNeeded()
            }
            .onEnded { _ in
                cancelHold(resetProgress: true)
            }
    }

    private func startHoldIfNeeded() {
        guard canComplete, !isHolding, !isPoofing else { return }
        isHolding = true
        holdWorkItem?.cancel()
        holdProgress = 0
        withAnimation(.linear(duration: holdDuration)) {
            holdProgress = 1
        }

        let workItem = DispatchWorkItem {
            guard isHolding else { return }
            isHolding = false
            holdWorkItem = nil
            holdProgress = 0
            triggerConfirm()
        }
        holdWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration, execute: workItem)
    }

    private func cancelHold(resetProgress: Bool) {
        guard isHolding || holdWorkItem != nil else { return }
        isHolding = false
        holdWorkItem?.cancel()
        holdWorkItem = nil
        if resetProgress {
            withAnimation(.easeOut(duration: 0.18)) {
                holdProgress = 0
            }
        } else {
            holdProgress = 0
        }
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

    private var ctaText: String {
        now > item.graceEndsAt ? "Hold 3 sec to confirm late" : "Hold 3 sec to confirm"
    }

    private var metaText: String {
        if item.startsTomorrow { return "STARTS TOMORROW" }
        let due = RuleGlyph.timeFormatter.string(from: item.dueAt)
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

private struct ContractSleepToolsCard: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Kicker(text: "Sleep tools", color: .lullAmberSoft)
                Spacer()
            }
            toolsButton("Breathing", icon: "wind") {
                state.showMidSleepMode = true
            }
            toolsButton("Sleep sounds", icon: "waveform") {
                if state.canUseSleepSounds {
                    state.showSleepSounds = true
                } else {
                    state.presentUpgradePaywall()
                }
            }
            toolsButton("Mid-sleep mode", icon: "moon.zzz.fill") {
                state.showMidSleepMode = true
            }
        }
        .padding(18)
        .contractCardBackground()
    }

    private func toolsButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.lullAmber)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.lullAmber.opacity(0.10)))
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.lullInk0)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.lullInk4)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.035)))
        }
        .buttonStyle(.plain)
    }
}

private struct RulesContractEditorView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var appBlockingAccess = AppBlockingAccessProbe.shared
    @State private var selection = FamilyActivitySelection()
    @State private var showPicker = false
    @State private var didHydrate = false

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

                sleepWindowCard
                blockedAppsCard
                rulesList
                enforcementCard
                Spacer().frame(height: 118)
            }
            .padding(.horizontal, 22)
            .padding(.top, 54)
        }
        .preferredColorScheme(.dark)
        .familyActivityPicker(isPresented: $showPicker, selection: $selection)
        .onAppear(perform: hydrate)
        .onChange(of: showPicker) { _, open in
            guard !open else { return }
            saveBlockingSelection()
        }
    }

    private var sleepWindowCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Kicker(text: "Sleep window", color: .lullAmberSoft)
            DatePicker("Sleep", selection: $state.typicalBedtime, displayedComponents: .hourAndMinute)
                .tint(.lullAmber)
                .disabled(isEditingLocked)
            DatePicker("Wake", selection: $state.typicalWakeTime, displayedComponents: .hourAndMinute)
                .tint(.lullAmber)
                .disabled(isEditingLocked)
            Text("Apps always lock during this window.")
                .font(.system(size: 13.5, weight: .medium))
                .foregroundColor(.lullInk3)
            if isEditingLocked {
                Text("Sleep-window edits are available after the current lock clears.")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(.lullInk4)
                    .lineSpacing(3)
            }
        }
        .padding(18)
        .contractCardBackground()
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

            ForEach(SleepRuleKind.allCases) { rule in
                RuleEditorRow(rule: rule, isEditingLocked: isEditingLocked)
                    .environmentObject(state)
            }
        }
    }

    private var enforcementCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Kicker(text: "How enforcement works", color: .lullAmberSoft)
            Text("Miss a rule -> apps lock.")
            Text("Confirm late -> 10-minute cooldown.")
            Text("Sleep window -> apps stay locked until wake time.")
        }
        .font(.system(size: 14.5, weight: .medium))
        .foregroundColor(.lullInk2)
        .padding(18)
        .contractCardBackground()
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
        state.isContractEditingLocked()
    }
}

private struct RuleEditorRow: View {
    @EnvironmentObject private var state: AppState
    let rule: SleepRuleKind
    let isEditingLocked: Bool

    private var isEnabled: Binding<Bool> {
        Binding(
            get: { state.selectedSleepRules.contains(rule) },
            set: { enabled in
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
                    .disabled(isEditingLocked)
            }

            if isEnabled.wrappedValue {
                if rule == .morningSun {
                    Text("Active from wake time to 12:00 PM")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(.lullInk2)
                } else {
                    DatePicker("Due", selection: timeBinding, displayedComponents: .hourAndMinute)
                        .tint(.lullAmber)
                        .disabled(isEditingLocked)
                }

                Stepper(value: graceBinding, in: 0...60, step: 5) {
                    Text("Grace: \(state.sleepRuleGraceMinutes(rule)) min")
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundColor(.lullInk2)
                }
                .tint(.lullAmber)
                .disabled(isEditingLocked)
                if isEditingLocked {
                    Text("Rule edits start after the current lock clears.")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(.lullInk4)
                }
            }
        }
        .padding(16)
        .contractCardBackground(accent: isEnabled.wrappedValue)
    }

    private var icon: String {
        switch rule {
        case .morningSun: return "sun.max.fill"
        case .caffeineCutoff: return "cup.and.saucer.fill"
        case .workoutCutoff: return "figure.strengthtraining.traditional"
        case .warmShower: return "shower.fill"
        case .dimLights: return "lightbulb.fill"
        case .tomorrowsPlan: return "checklist"
        case .gratitudeJournal: return "heart.text.square.fill"
        }
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
        VStack(spacing: 0) {
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
                    trendStat("Nights protected", value: "\(protectedNights)")
                    trendStat("All-clear days", value: "\(allClearDays)")
                    trendStat("Lock activations", value: "\(lockActivations)")
                    trendStat("Late confirmations", value: "\(lateConfirmations)")
                }

                VStack(alignment: .leading, spacing: 10) {
                    Kicker(text: "Rule insights", color: .lullAmberSoft)
                    Text("Best rule")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(.lullInk4)
                    Text(bestRuleText)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.lullInk0)
                    Divider().overlay(Color.lullLine)
                    Text("Needs work")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(.lullInk4)
                    Text(needsWorkText)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.lullInk0)
                }
                .padding(16)
                .contractCardBackground()
            }
            .padding(.horizontal, 22)
            .padding(.top, 54)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: ContractTrendsPanelHeightKey.self, value: proxy.size.height)
                }
            )

            Spacer(minLength: 0)
        }
        .padding(.bottom, 118)
        .preferredColorScheme(.dark)
        .onPreferenceChange(ContractTrendsPanelHeightKey.self) { height in
            sharedCalendarTopInset = height + 78
        }
    }

    private func trendStat(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value)
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.lullAmber)
            Text(title)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(.lullInk3)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
        .padding(14)
        .contractCardBackground()
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
            interval.contains($0.occurredAt)
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

    private var bestRuleText: String {
        let completions = completionsByRule
        guard let best = completions.max(by: { $0.value < $1.value }) else { return "Complete a few rules to see a pattern." }
        return "\(best.key.title) · completed \(best.value) time\(best.value == 1 ? "" : "s")"
    }

    private var needsWorkText: String {
        let late = Dictionary(grouping: state.sleepRuleCompletions.filter {
            !$0.completedWithinGrace && interval.contains($0.completedAt)
        }, by: \.rule).mapValues(\.count)
        guard let worst = late.max(by: { $0.value < $1.value }) else { return "No late pattern yet." }
        return "\(worst.key.title) · \(worst.value) late confirmation\(worst.value == 1 ? "" : "s")"
    }

    private var completionsByRule: [SleepRuleKind: Int] {
        Dictionary(grouping: state.sleepRuleCompletions.filter {
            $0.completedWithinGrace && interval.contains($0.completedAt)
        }, by: \.rule).mapValues(\.count)
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
