import ActivityKit
import FamilyControls
import ManagedSettings
import RevenueCatUI
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.scenePhase) private var scenePhase
    @Binding var selectedTab: Int
    var suppressDeckForFirstFireflyPrompt: Bool = false
    var suppressMorningRateForFirstFireflyPrompt: Bool = false
    var onFirstDeckInteraction: () -> Void = {}
    var onRoutineCompleted: () -> Void = {}
    @State private var showSettings = false
    @State private var currentDate = Date()
    @State private var glowPulse = false
    @AppStorage("hasDismissedAppBlockingOffer") private var hasDismissedAppBlockingOffer = false
    private let minuteTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEEE · h:mm a"; return f
    }()

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f
    }()

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: currentDate)
        switch hour {
        case 5..<12:  return "Good morning,"
        case 12..<17: return "Good afternoon,"
        case 17..<22: return "Good evening,"
        default:      return "Hi,"
        }
    }

    // MARK: - Today state predicate

    private var shouldShowMorningRateCard: Bool {
        #if DEBUG
        if state.debugForceMorningState { return true }
        if state.debugForceEveningState { return false }
        #endif
        guard let wake = todaysWakeTime else { return false }
        return todaysRating == nil
            && currentDate >= wake
            && currentDate < nextPrepStartAfterMorningWake
    }

    private var shouldShowTodayDeck: Bool {
        #if DEBUG
        if state.debugForceMorningState { return false }
        if state.debugForceEveningState { return true }
        #endif
        return !shouldShowMorningRateCard
            && !hasFinishedTodayRoutine
            && currentDate >= firstPrepStartForNextVisibleDeck
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

        let firstLeadMinutes = prepSteps
            .map(\.resolvedLeadTimeMins)
            .max() ?? state.windDownDurationMinutes

        return cal.date(byAdding: .minute, value: -firstLeadMinutes, to: bedtime) ?? bedtime
    }

    private var nextPrepStartAfterMorningWake: Date {
        let cal = Calendar.current
        guard let wake = todaysWakeTime else { return firstPrepStartForCurrentSleepWindow }
        var nextStart = firstPrepStartForCurrentSleepWindow
        while nextStart <= wake {
            nextStart = cal.date(byAdding: .day, value: 1, to: nextStart) ?? nextStart.addingTimeInterval(24 * 60 * 60)
        }
        return nextStart
    }

    private var firstPrepStartForNextVisibleDeck: Date {
        guard let wake = todaysWakeTime, currentDate >= wake else {
            return firstPrepStartForCurrentSleepWindow
        }
        return nextPrepStartAfterMorningWake
    }

    private var nextPrepReminderText: String {
        DashboardView.timeFmt.string(from: firstPrepStartForNextVisibleDeck)
    }

    private var shouldShowNextPrepReminderMessage: Bool {
        guard let wake = todaysWakeTime else { return false }
        return currentDate >= wake
            && !shouldShowMorningRateCard
            && !shouldShowTodayDeck
            && currentDate < firstPrepStartForNextVisibleDeck
    }

    private var todayFireflyGreeting: String {
        #if DEBUG
        if state.debugForceMorningState { return "Good Morning" }
        #endif
        let hour = Calendar.current.component(.hour, from: currentDate)
        switch hour {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<22: return "Good Evening"
        default: return "Good Night"
        }
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

    private var todaysWakeTime: Date? {
        let cal = Calendar.current
        let wakeComps = cal.dateComponents([.hour, .minute], from: state.typicalWakeTime)
        var combined = cal.dateComponents([.year, .month, .day], from: currentDate)
        combined.hour = wakeComps.hour ?? 7
        combined.minute = wakeComps.minute ?? 0
        return cal.date(from: combined)
    }

    private var displayedRoutineBedtimeDay: Date {
        let cal = Calendar.current
        if let wake = todaysWakeTime,
           currentDate >= wake,
           currentDate < nextPrepStartAfterMorningWake,
           let morningBedtimeDay {
            return morningBedtimeDay
        }
        return state.bedtimeDate(for: currentDate, calendar: cal)
    }

    private var morningBedtimeDay: Date? {
        let cal = Calendar.current
        guard let wake = todaysWakeTime else { return nil }
        return state.bedtimeDate(forWakeTime: wake, calendar: cal)
    }

    // Most recent entry with a score (any date). nil if user has never rated.
    private var mostRecentRated: SleepLogEntry? {
        state.sleepLogs
            .filter { $0.score > 0 }
            .sorted { $0.date > $1.date }
            .first
    }

    // Today's rating belongs to the sleep window currently being reviewed.
    // Same-day test windows (for example 4:20-4:30 PM) and overnight windows
    // both need this date-specific lookup; a broad today/yesterday search can
    // accidentally reuse yesterday's score for the next window.
    private var todaysRatedEntry: SleepLogEntry? {
        if let primary = primarySleepWindowEntry, hasNightlyData(primary) {
            return primary.score > 0 ? primary : nil
        }
        return sleepWindowEntries
            .filter { $0.score > 0 }
            .sorted { $0.date > $1.date }
            .first
    }

    private var sleepWindowEntries: [SleepLogEntry] {
        let cal = Calendar.current
        let bedtimeDay = displayedRoutineBedtimeDay
        return state.sleepLogs.filter { cal.isDate($0.date, inSameDayAs: bedtimeDay) }
    }

    private var primarySleepWindowEntry: SleepLogEntry? {
        sleepWindowEntries.sorted { lhs, rhs in
            let lhsHasNightlyData = hasNightlyData(lhs)
            let rhsHasNightlyData = hasNightlyData(rhs)
            if lhsHasNightlyData != rhsHasNightlyData {
                return lhsHasNightlyData && !rhsHasNightlyData
            }
            return lhs.date > rhs.date
        }.first
    }

    private func hasNightlyData(_ entry: SleepLogEntry) -> Bool {
        entry.completedNightlyFlow
            || entry.actualBedtime != nil
            || !entry.stepAttempts.isEmpty
    }

    private var todaysRating: Int? {
        todaysRatedEntry?.score
    }

    // For the rate hero's delta: the most recent rated entry EXCLUDING the one
    // we're treating as "today" above.
    private var yesterdaysRating: Int? {
        let todayId = todaysRatedEntry?.id
        let rated: [SleepLogEntry] = state.sleepLogs.filter {
            $0.score > 0 && $0.id != todayId
        }
        let sorted = rated.sorted { $0.date > $1.date }
        return sorted.first?.score
    }

    private var prepSteps: [RoutineStep] { state.preWindDownSteps }
    private var ritualSteps: [RoutineStep] { state.windDownSteps }

    private var prepDoneCount: Int {
        prepSteps.filter { state.prepDoneIds.contains($0.id) }.count
    }
    private var allPrepDone: Bool { prepDoneCount == prepSteps.count && !prepSteps.isEmpty }
    private var ritualDoneCount: Int {
        ritualSteps.filter { state.ritualDoneIds.contains($0.id) }.count
    }
    private var completedWindDownTonight: Bool {
        let cal = Calendar.current
        let bedtimeDay = displayedRoutineBedtimeDay
        return state.sleepLogs.contains {
            $0.completedNightlyFlow && cal.isDate($0.date, inSameDayAs: bedtimeDay)
        }
    }
    private var allRitualStepsDone: Bool { ritualDoneCount == ritualSteps.count && !ritualSteps.isEmpty }
    private var sleepTargetDone: Bool { completedWindDownTonight || allRitualStepsDone }
    private var ritualDisplayTotal: Int { ritualSteps.count + 1 }
    private var ritualDisplayDoneCount: Int { ritualDoneCount + (sleepTargetDone ? 1 : 0) }
    private var allRitualDone: Bool { ritualDisplayDoneCount == ritualDisplayTotal }
    private var hasFinishedTodayRoutine: Bool {
        completedWindDownTonight || (allPrepDone && allRitualStepsDone)
    }

    private func scheduledTime(for step: RoutineStep) -> String {
        state.scheduledRoutine.first { $0.step.id == step.id }?.timeString ?? ""
    }
    private func leadLabel(for step: RoutineStep) -> String {
        guard let row = state.scheduledRoutine.first(where: { $0.step.id == step.id }) else { return "" }
        let mins = Int(state.typicalBedtime.timeIntervalSince(row.time) / 60)
        return mins > 0 ? "\(mins) min before bed" : "at bedtime"
    }

    private var debugForceDeckPreview: Bool {
        #if DEBUG
        state.debugForceEveningState
        #else
        false
        #endif
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 16)

                topBar
                    .padding(.horizontal, Lull.horizontalPad)
                    .padding(.bottom, 8)

                let effectiveShowsMorningRateCard = shouldShowMorningRateCard && !suppressMorningRateForFirstFireflyPrompt
                let effectiveShowsDeck = shouldShowTodayDeck && !suppressDeckForFirstFireflyPrompt

                TodayCardPreviewView(
                    selectedTab: $selectedTab,
                    currentDate: currentDate,
                    prepSteps: prepSteps,
                    ritualSteps: ritualSteps,
                    showsDeck: effectiveShowsDeck,
                    showsMorningRateCard: effectiveShowsMorningRateCard,
                    fireflyGreeting: todayFireflyGreeting,
                    isInSleepWindow: isInSleepWindow,
                    yesterdaysRating: yesterdaysRating,
                    todaysRating: todaysRating,
                    hasFinishedRoutine: hasFinishedTodayRoutine,
                    showsNextPrepReminderMessage: shouldShowNextPrepReminderMessage,
                    nextPrepReminderText: nextPrepReminderText,
                    forceDeckPreview: debugForceDeckPreview,
                    scheduledTime: scheduledTime(for:),
                    leadLabel: leadLabel(for:),
                    onFirstDeckInteraction: onFirstDeckInteraction,
                    onRoutineCompleted: onRoutineCompleted
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .foregroundColor(.lullInk1)
            .preferredColorScheme(.dark)
            .onAppear {
                currentDate = Date()
                state.resetPrepIfNeeded()
                state.presentPendingStreakMilestoneIfEligible()
                withAnimation(.easeInOut(duration: 4.5).repeatForever(autoreverses: true)) {
                    glowPulse = true
                }
                state.refreshPrepLiveActivityIfEligible()
            }
            .onReceive(minuteTimer) { date in
                currentDate = date
                state.resetPrepIfNeeded()
                state.refreshPrepLiveActivityIfEligible()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                currentDate = Date()
                state.resetPrepIfNeeded()
                state.refreshPrepLiveActivityIfEligible()
            }
            .animation(.spring(response: 0.55, dampingFraction: 0.86), value: shouldShowMorningRateCard)

            // Menu overlay
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Top bar (shared)

    private var topBar: some View {
        HStack {
            BrandMark()
            Spacer()
            Button(action: { showSettings = true }) {
                ZStack {
                    Circle()
                        .strokeBorder(Color.lullLine, lineWidth: 1)
                        .frame(width: 36, height: 36)
                    Image(systemName: "gearshape")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.lullInk2)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
    }

    // MARK: - Evening content (existing layout)

    @ViewBuilder
    private var eveningContent: some View {
        // Greeting
        VStack(alignment: .leading, spacing: 14) {
            Kicker(text: DashboardView.dateFmt.string(from: currentDate))
            VStack(alignment: .leading, spacing: 0) {
                Text(greeting)
                    .font(.serif(32))
                    .foregroundColor(.lullInk0)
                Text("let's wind down.")
                    .font(.serifItalic(32))
                    .foregroundColor(.lullInk2)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 32)
        .padding(.bottom, 24)

        StreakMoonStrip(summary: state.streakSummary, selectedTab: $selectedTab)
            .padding(.horizontal, 22)
            .padding(.bottom, 16)

        prepChecklistCard
            .padding(.horizontal, 22)
            .padding(.bottom, 16)

        ritualHeroCard
            .padding(.horizontal, 22)
            .padding(.bottom, 24)

        ritualSequenceSection
            .padding(.horizontal, 24)
            .padding(.bottom, 24)

        MidSleepPrimerCard(selectedTab: $selectedTab)
            .padding(.horizontal, 22)
            .padding(.bottom, 36)
    }

    // MARK: - Morning content

    @ViewBuilder
    private var morningContent: some View {
        // Morning greeting
        VStack(alignment: .leading, spacing: 14) {
            Kicker(text: DashboardView.dateFmt.string(from: currentDate))
            VStack(alignment: .leading, spacing: 0) {
                Text("Good morning,")
                    .font(.serif(32))
                    .foregroundColor(.lullInk0)
                Text("how did last night feel?")
                    .font(.serifItalic(32))
                    .foregroundColor(.lullInk2)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 32)
        .padding(.bottom, 22)

        if !hasFinishedTodayRoutine {
            Text("Routine wasn't completed - still want to log how you slept?")
                .font(.system(size: 13.5, weight: .medium))
                .foregroundColor(.lullInk2)
                .lineSpacing(3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 24)
                .padding(.bottom, 18)
        }

        MorningRateHero(
            wakeTime: DashboardView.timeFmt.string(from: currentDate),
            yesterday: yesterdaysRating,
            rating: todaysRating,
            variable: nil,
            testNight: 0,
            totalTestNights: 0,
            onRate: { n in
                let scoreToLog = AppState.clampedSleepScore(n)
                state.morningScore = scoreToLog
                state.logMorningScore()
                state.presentPendingStreakMilestoneIfEligible()
            }
        )
        .padding(.horizontal, 22)
        .padding(.bottom, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))

        TonightPreviewCard(
            rated: todaysRating != nil,
            variable: nil,
            testNight: 0,
            totalTestNights: 0,
            schedule: tonightScheduleRows,
            startsAt: tonightStartTime,
            onEditRoutine: { selectedTab = 1 }
        )
        .padding(.horizontal, 22)
        .padding(.bottom, 16)

        if shouldShowAppBlockingOffer {
            AppBlockingOfferCard(
                timeRange: appBlockingOfferTimeRange,
                onAdd: {
                    state.startAppBlockingOfferSetup()
                },
                onDismiss: {
                    hasDismissedAppBlockingOffer = true
                }
            )
            .padding(.horizontal, 22)
            .padding(.bottom, 16)
        }

        StreakMoonStrip(summary: state.streakSummary, selectedTab: $selectedTab)
            .padding(.horizontal, 22)
            .padding(.bottom, 36)
    }

    private var viewVerdictTile: some View {
        Button {
            state.activePaywallVerdict = state.buildVerdictSnapshotFromRecentLogs()
            state.activePaywallRoute = .verdictReplay
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Kicker(text: "Verdict unlocked", color: .lullAmberSoft)
                    Text("View your verdict")
                        .font(.serif(22))
                        .foregroundColor(.lullInk0)
                    Text("Tonight's verdict stays available because you shared.")
                        .font(.system(size: 13))
                        .foregroundColor(.lullInk3)
                        .lineSpacing(3)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.lullBgDeep)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.lullAmber))
            }
            .padding(16)
            .lullCard(radius: 16, accent: true)
        }
        .buttonStyle(.plain)
    }

    private struct AppBlockingOfferCard: View {
        let timeRange: String
        let onAdd: () -> Void
        let onDismiss: () -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 8) {
                    Kicker(text: "Unlock · app blocking", color: .lullAmberSoft)
                    Text("Premium")
                        .font(.system(size: 10.5, weight: .semibold, design: .default))
                        .foregroundColor(.lullAmber)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .overlay(
                            Capsule().stroke(Color.lullAmber.opacity(0.35), lineWidth: 1)
                        )
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.lullInk3)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss app blocking offer")
                }

                Text("Set it up before tonight.")
                    .font(.system(size: 12, weight: .semibold, design: .default))
                    .foregroundColor(.lullAmber)

                VStack(alignment: .leading, spacing: -6) {
                    Text("Lock the scroll away")
                        .font(.serif(28))
                        .foregroundColor(.lullInk0)
                    Text("tonight?")
                        .font(.serifItalic(30))
                        .foregroundColor(.lullAmber)
                }
                .lineSpacing(2)

                Text("TenThirty blocks your selected apps through the sleep window and after missed rule grace windows. Complete late rules in the app to start the 10-minute cooldown.")
                    .font(.system(size: 14.5))
                    .foregroundColor(.lullInk2)
                    .lineSpacing(4)

                HStack(spacing: 10) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.lullAmber)
                    Text(timeRange)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundColor(.lullInk1)
                    Spacer()
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.lullBg2.opacity(0.72))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.lullLineStrong, lineWidth: 1)
                )

                HStack(spacing: 10) {
                    Button(action: onAdd) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))
                            Text("Add scroll-lock")
                                .font(.system(size: 14.5, weight: .semibold))
                        }
                        .foregroundColor(.lullBgDeep)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Capsule().fill(Color.lullAmber))
                    }
                    .buttonStyle(.plain)

                    Button(action: onDismiss) {
                        Text("Not now")
                            .font(.system(size: 14.5, weight: .medium))
                            .foregroundColor(.lullInk2)
                            .frame(width: 96, height: 46)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(hex: "#18130B"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.lullAmber.opacity(0.24), lineWidth: 1)
            )
            .shadow(color: Color.lullAmber.opacity(0.08), radius: 22, x: 0, y: 12)
        }
    }

    // MARK: - Tonight preview data

    // Tonight is the NEXT test night. After rating last night, that's
    // experimentStatus.night + 1 (the upcoming night).
    private var tonightTestNight: Int {
        let baseline = state.experimentStatus?.night ?? 0
        return min(baseline + 1, 5)
    }

    private var tonightScheduleRows: [TonightPreviewCard.Row] {
        // First 3 actionable items in chronological order.
        let f = DateFormatter(); f.dateFormat = "h:mm"
        return state.scheduledRoutine.prefix(3).map { step in
            TonightPreviewCard.Row(time: f.string(from: step.time), label: step.step.label)
        }
    }

    private var tonightStartTime: String {
        if let first = state.scheduledRoutine.first {
            return DashboardView.timeFmt.string(from: first.time)
        }
        return DashboardView.timeFmt.string(from: state.typicalBedtime)
    }

    private var shouldShowAppBlockingOffer: Bool {
        state.shouldOfferAppBlockingSetup && !hasDismissedAppBlockingOffer
    }

    private var appBlockingOfferTimeRange: String {
        let start = AppState.defaultAppBlockingStart(from: state.typicalBedtime)
        let end = AppState.defaultAppBlockingEnd(from: state.typicalWakeTime)
        return "\(DashboardView.timeFmt.string(from: start)) - \(DashboardView.timeFmt.string(from: end))"
    }

    // MARK: - Prep Checklist Card

    private var prepChecklistCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .center) {
                Kicker(text: "Prep checklist")
                Spacer()
                Text("\(prepDoneCount)/\(prepSteps.count) done")
                    .font(.mono(11))
                    .foregroundColor(allPrepDone ? .lullAmber : .lullInk2)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 99)
                        .fill(Color.lullAmber.opacity(0.08))
                        .frame(height: 3)
                    RoundedRectangle(cornerRadius: 99)
                        .fill(LinearGradient(
                            colors: [Color(hex: "#a66a2a"), Color.lullAmber],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: prepSteps.isEmpty ? 0 : geo.size.width * CGFloat(prepDoneCount) / CGFloat(prepSteps.count),
                               height: 3)
                        .shadow(color: prepDoneCount > 0 ? .lullAmberGlow : .clear, radius: 6)
                        .animation(.easeInOut(duration: 0.25), value: prepDoneCount)
                }
            }
            .frame(height: 3)
            .padding(.horizontal, 20)
            .padding(.top, 10)

            // Rows
            VStack(spacing: 0) {
                ForEach(prepSteps) { step in
                    prepRow(step)
                }
            }
            .padding(.top, 14)
            .padding(.bottom, 6)
        }
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.white.opacity(0.025))
                .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color.lullLine, lineWidth: 1))
        )
    }

    private func prepRow(_ step: RoutineStep) -> some View {
        let done = state.prepDoneIds.contains(step.id)
        let isExperiment = step.mode == .experiment
        return Button(action: { state.togglePrepDone(step.id) }) {
            HStack(spacing: 12) {
                // Checkbox
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(done ? Color.lullAmber : Color.clear)
                        .frame(width: 22, height: 22)
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(
                            done ? Color.lullAmber : (isExperiment ? Color.lullAmber.opacity(0.4) : Color.white.opacity(0.22)),
                            lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(hex: "#1a0d06"))
                    }
                }
                .shadow(color: done ? .lullAmberGlow : .clear, radius: 8)

                // Time
                Text(scheduledTime(for: step))
                    .font(.mono(11))
                    .foregroundColor(.lullInk3)
                    .frame(width: 38, alignment: .leading)

                // Label
                Text(step.label)
                    .font(.system(size: 14))
                    .foregroundColor(done ? .lullInk3 : .lullInk0)
                    .strikethrough(done, color: Color.lullAmber.opacity(0.5))
                    .animation(.easeInOut(duration: 0.2), value: done)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Sub
                Text(leadLabel(for: step))
                    .font(.mono(9.5))
                    .foregroundColor(.lullInk4)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 10)
            .padding(.leading, 16)
            .padding(.trailing, 16)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tonight's Ritual Hero

    private var ritualHeroCard: some View {
        let remaining = prepSteps.count - prepDoneCount

        return ZStack(alignment: .topTrailing) {
            // Pulsing radial glow
            Circle()
                .fill(RadialGradient(colors: [Color.lullAmberGlow, .clear],
                                     center: .center, startRadius: 0, endRadius: 120))
                .frame(width: 240, height: 240)
                .scaleEffect(glowPulse ? 1.08 : 1.0)
                .opacity(glowPulse ? 0.95 : 0.55)
                .offset(x: 40, y: -40)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                // Top row: kicker + badge
                HStack(alignment: .center) {
                    Kicker(text: "Tonight's wind-down", color: .lullAmberSoft)
                    Spacer()
                }

                // Title
                Text("Earn tonight's moon")
                    .font(.serif(23))
                    .foregroundColor(.lullInk0)
                    .padding(.top, 4)

                // Description
                VStack(alignment: .leading, spacing: 10) {
                    (Text("Finish the guided wind-down to keep your bedtime rhythm alive. ")
                        .foregroundColor(.lullInk1)
                    + Text("You can skip a step and still complete the ritual.")
                        .foregroundColor(.lullInk2))
                    .font(.system(size: 13))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                    // Sub-copy
                    Text(allPrepDone
                         ? "Prep complete. Ready to start the wind-down sequence whenever you are."
                         : "Finish prep first (\(remaining) left), then we'll start the wind-down sequence.")
                        .font(.system(size: 12.5))
                        .foregroundColor(.lullInk2)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // CTA
                PrimaryCTA(title: allPrepDone ? "Start ritual" : "Finish prep · \(remaining) left") {
                    state.cancelWindDownStartNotifications()
                    LiveActivityService.shared.end(dismissalPolicy: .immediate)
                    selectedTab = 0
                    #if DEBUG
                    state.debugForceEveningState = true
                    state.debugForceMorningState = false
                    state.debugResetTodayDeckProgress()
                    #endif
                }
                .disabled(!allPrepDone)
                .opacity(allPrepDone ? 1 : 0.45)
                .padding(.top, 18)
            }
            .font(.system(size: 13))
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, 22)
        }
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(LinearGradient(
                    colors: [Color.lullAmber.opacity(0.12), Color.lullAmber.opacity(0.03), Color.lullAmber.opacity(0.02)],
                    startPoint: .top, endPoint: .bottom))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26)
                .strokeBorder(Color.lullAmber.opacity(0.32), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.45), radius: 24, y: 18)
        .clipped()
    }

    // MARK: - Ritual Sequence

    private var ritualSequenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Kicker(text: "The ritual · in sequence")
                Spacer()
                Text("\(ritualDisplayDoneCount)/\(ritualDisplayTotal) done")
                    .font(.system(size: 11.5, weight: .semibold, design: .default))
                    .foregroundColor(allRitualDone ? .lullAmber : .lullInk3)
                Button(action: { selectedTab = 1 }) {
                    Text("Edit")
                        .font(.system(size: 11.5, weight: .semibold, design: .default))
                        .foregroundColor(.lullInk3)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 8) {
                ForEach(ritualSteps) { step in
                    ritualRow(step)
                }

                // Sleep target row
                HStack(spacing: 12) {
                    Text({
                        let f = DateFormatter(); f.dateFormat = "h:mm"
                        return f.string(from: state.typicalBedtime)
                    }())
                    .font(.mono(11))
                    .foregroundColor(.lullInk3)
                    .frame(width: 38, alignment: .leading)
                    ZStack {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(sleepTargetDone ? Color.lullAmber.opacity(0.24) : Color.clear)
                            .frame(width: 22, height: 22)
                        RoundedRectangle(cornerRadius: 7)
                            .strokeBorder(sleepTargetDone ? Color.lullAmber.opacity(0.45) : Color.white.opacity(0.16), lineWidth: 1.4)
                            .frame(width: 22, height: 22)
                        if sleepTargetDone {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.lullAmber)
                        }
                    }
                    Text("Sleep")
                        .font(.system(size: 13.5))
                        .foregroundColor(sleepTargetDone ? .lullInk3 : .lullInk1)
                        .strikethrough(sleepTargetDone, color: Color.lullAmber.opacity(0.45))
                    Spacer()
                    Text("\(state.sleepDurationString) target")
                        .font(.system(size: 11, weight: .medium, design: .default))
                        .foregroundColor(.lullInk4)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.02)))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.lullLine, lineWidth: 1))
            }
        }
    }

    private func ritualRow(_ step: RoutineStep) -> some View {
        let done = state.ritualDoneIds.contains(step.id)

        return Button(action: {
            guard done else { return }
            state.unmarkRitualDone(step.id)
        }) {
            HStack(spacing: 12) {
                Text(scheduledTime(for: step))
                    .font(.mono(11))
                    .foregroundColor(.lullInk3)
                    .frame(width: 38, alignment: .leading)

                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(done ? Color.lullAmber : Color.clear)
                        .frame(width: 22, height: 22)
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(done ? Color.lullAmber : Color.white.opacity(0.22), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(hex: "#1a0d06"))
                    }
                }
                .shadow(color: done ? .lullAmberGlow : .clear, radius: 8)

                Text(step.label)
                    .font(.system(size: 13.5))
                    .foregroundColor(done ? .lullInk3 : .lullInk1)
                    .strikethrough(done, color: Color.lullAmber.opacity(0.5))
                    .animation(.easeInOut(duration: 0.2), value: done)

                Spacer()

                Text(state.scheduledRoutine.first { $0.step.id == step.id }?.badge ?? "")
                    .font(.system(size: 11, weight: .medium, design: .default))
                    .foregroundColor(.lullInk4)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.02)))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.lullLine, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityHint(done ? "Marks this ritual item incomplete" : "Complete this step in the ritual flow to check it off")
    }
}

// MARK: - Today card preview branch

private enum TodayPreviewTask: Identifiable {
    case prep(RoutineStep)
    case ritual(RoutineStep)

    var id: String {
        switch self {
        case .prep(let step): return "prep-\(step.id.uuidString)"
        case .ritual(let step): return "ritual-\(step.id.uuidString)"
        }
    }

    var label: String {
        switch self {
        case .prep(let step), .ritual(let step): return step.label
        }
    }

    var step: RoutineStep? {
        switch self {
        case .prep(let step), .ritual(let step): return step
        }
    }

    var stepType: String {
        switch self {
        case .prep: return "prep"
        case .ritual: return "in_bed"
        }
    }
}

enum TodayDeckConstants {
    static let arcR: CGFloat = 560
    static let arcStepAngle: CGFloat = 22
    static let gestureThreshold: CGFloat = 85
    static let rotationDuration: Double = 0.48
    static let fireflyPeakScale: CGFloat = 6.4
    static let fireflyRiseDuration: Double = 1.18
    static let fireflySettleDuration: Double = 1.45
    static let completedByReachingEndWithSkips = true
    static let maxVisibleFireflies = 42
    static let homePositions: [CGPoint] = [
        CGPoint(x: 0.13, y: 0.18),
        CGPoint(x: 0.84, y: 0.17),
        CGPoint(x: 0.25, y: 0.32),
        CGPoint(x: 0.70, y: 0.30),
        CGPoint(x: 0.08, y: 0.46),
        CGPoint(x: 0.92, y: 0.45),
        CGPoint(x: 0.39, y: 0.49),
        CGPoint(x: 0.58, y: 0.54),
        CGPoint(x: 0.19, y: 0.67),
        CGPoint(x: 0.78, y: 0.68),
        CGPoint(x: 0.43, y: 0.78),
        CGPoint(x: 0.63, y: 0.82),
        CGPoint(x: 0.06, y: 0.80),
        CGPoint(x: 0.92, y: 0.83),
        CGPoint(x: 0.32, y: 0.90),
        CGPoint(x: 0.73, y: 0.92)
    ]
}

private enum TodayMidSleepTactic: String, Identifiable {
    case breathing
    case boringStory
    case sleepSounds

    var id: String { rawValue }
}

private struct TodayCardPreviewView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var audioStore: SleepSoundsAudioStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var selectedTab: Int
    @AppStorage("hasDismissedAppBlockingOffer") private var hasDismissedAppBlockingOffer = false
    let currentDate: Date
    let prepSteps: [RoutineStep]
    let ritualSteps: [RoutineStep]
    let showsDeck: Bool
    let showsMorningRateCard: Bool
    let fireflyGreeting: String
    let isInSleepWindow: Bool
    let yesterdaysRating: Int?
    let todaysRating: Int?
    let hasFinishedRoutine: Bool
    let showsNextPrepReminderMessage: Bool
    let nextPrepReminderText: String
    let forceDeckPreview: Bool
    let scheduledTime: (RoutineStep) -> String
    let leadLabel: (RoutineStep) -> String
    let onFirstDeckInteraction: () -> Void
    let onRoutineCompleted: () -> Void

    @State private var currentIndex = 0
    @State private var skippedTaskIds: Set<String> = []
    @State private var clearedSkippedTaskIds: Set<String> = []
    @State private var deckCompleted = false
    @State private var didTrackStart = false
    @State private var bloomToken = 0
    @State private var showMidSleepToolkit = false
    @State private var activeMidSleepTactic: TodayMidSleepTactic?
    @State private var activeBodyScanTask: TodayPreviewTask?
    @State private var activeBreathingTask: TodayPreviewTask?
    @State private var pendingMorningRating: Int?
    @State private var isDismissingMorningRateCard = false

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f
    }()

    private var tasks: [TodayPreviewTask] {
        prepSteps.map(TodayPreviewTask.prep)
        + ritualSteps.map(TodayPreviewTask.ritual)
    }

    private var deckDoneCount: Int {
        tasks.filter(isDone).count
    }

    private var deckSkippedCount: Int {
        effectiveSkippedTaskIds.count
    }

    private var firstOpenIndex: Int {
        if forceDeckPreview { return 0 }
        return tasks.firstIndex { !isDone($0) && !effectiveSkippedTaskIds.contains($0.id) } ?? max(tasks.count - 1, 0)
    }

    private var effectiveSkippedTaskIds: Set<String> {
        persistedSkippedTaskIds
            .union(skippedTaskIds)
            .subtracting(clearedSkippedTaskIds)
    }

    private var persistedSkippedTaskIds: Set<String> {
        let calendar = Calendar.current
        let bedtimeDay = state.bedtimeDate(for: currentDate, calendar: calendar)
        guard let entry = state.sleepLogs
            .filter({ calendar.isDate($0.date, inSameDayAs: bedtimeDay) })
            .sorted(by: { $0.date > $1.date })
            .first
        else { return [] }

        return Set(tasks.compactMap { task in
            guard entry.stepAttempts.last(where: { attemptMatches($0, task: task) })?.status == .skipped else {
                return nil
            }
            return task.id
        })
    }

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { proxy in
                ZStack(alignment: .bottom) {
                    if shouldShowMeadowForeground {
                        Color.clear
                            .contentShape(Rectangle())
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .zIndex(1)
                    }

                    if shouldShowMeadowForeground {
                        meadowForeground(maxToolkitHeight: max(300, proxy.size.height - 190))
                            .padding(.horizontal, 22)
                            .padding(.top, 70)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .zIndex(2)
                    }

                    if showsDeck && !deckCompleted {
                        TodayDeckProgressSegments(
                            tasks: tasks,
                            currentIndex: currentIndex,
                            skippedIds: effectiveSkippedTaskIds,
                            isDone: isDone
                        )
                        .padding(.horizontal, 24)
                        .padding(.top, 14)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .zIndex(3)

                        TodayCardStack(
                            tasks: tasks,
                            currentIndex: $currentIndex,
                            folded: false,
                            reduceMotion: reduceMotion,
                            size: proxy.size,
                            isDone: isDone,
                            externalDonePrepId: state.prepCompletionAnimationRequest,
                            scheduledTime: scheduledTime,
                            leadLabel: leadLabel,
                            onDone: complete,
                            onSkip: skip,
                            onBack: goBack,
                            onInteract: onFirstDeckInteraction,
                            onExternalDonePrepHandled: state.clearPrepCompletionAnimationRequest,
                            onOpenSleepSounds: { state.showSleepSounds = true },
                            onOpenBreathing: { activeBreathingTask = $0 },
                            onOpenBodyScan: { activeBodyScanTask = $0 }
                        )
                        .environmentObject(audioStore)
                        .padding(.bottom, 70)

                        addStepControl
                            .padding(.horizontal, 24)
                            .padding(.bottom, 20)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    TodayCompletionBloom(token: bloomToken, reduceMotion: reduceMotion)
                        .allowsHitTesting(false)

                    if showsDeck && !deckCompleted {
                        swipeHint
                            .padding(.horizontal, 24)
                            .padding(.bottom, 66)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                }
            }
        }
        .padding(.bottom, 82)
        .onAppear {
            currentIndex = firstOpenIndex
            trackStartIfNeeded()
        }
        .onChange(of: showsDeck) { _, newValue in
            if newValue {
                currentIndex = firstOpenIndex
                deckCompleted = false
                showMidSleepToolkit = false
                trackStartIfNeeded()
            } else {
                showMidSleepToolkit = false
            }
        }
        .onChange(of: tasks.count) { _, _ in clampCurrentIndex() }
        .onChange(of: state.prepDoneIds) { _, _ in clampCurrentIndex() }
        .onChange(of: state.ritualDoneIds) { _, _ in clampCurrentIndex() }
        .animation(.spring(response: 0.50, dampingFraction: 0.80), value: currentIndex)
        .animation(.easeInOut(duration: 0.24), value: deckCompleted)
        .animation(.easeInOut(duration: 0.35), value: showsDeck)
        .animation(.spring(response: 0.56, dampingFraction: 0.82), value: shouldShowMorningRateCardVisual)
        .animation(.spring(response: 0.48, dampingFraction: 0.84), value: showMidSleepToolkit)
        .contentShape(Rectangle())
        .highPriorityGesture(midSleepSwipeGesture)
        .fullScreenCover(item: $activeMidSleepTactic) { tactic in
            switch tactic {
            case .breathing:
                NightlyBreathingView(isMidSleep: true)
                    .environmentObject(state)
            case .boringStory:
                MidSleepBoringStoryView()
            case .sleepSounds:
                NightlySleepSoundsView(isMidSleep: true)
                    .environmentObject(state)
                    .environmentObject(audioStore)
            }
        }
        .fullScreenCover(item: $activeBodyScanTask) { task in
            NightlyBodyScanView(
                isMidSleep: true,
                onComplete: {
                    activeBodyScanTask = nil
                    complete(task)
                },
                onExit: {
                    activeBodyScanTask = nil
                }
            )
            .environmentObject(state)
        }
        .fullScreenCover(item: $activeBreathingTask) { task in
            NightlyBreathingView(
                isMidSleep: true,
                onComplete: {
                    activeBreathingTask = nil
                    complete(task)
                },
                onExit: {
                    activeBreathingTask = nil
                }
            )
            .environmentObject(state)
        }
    }

    private var shouldShowMeadowForeground: Bool {
        deckCompleted || !showsDeck || shouldShowMorningRateCardVisual
    }

    private var shouldShowMorningRateCardVisual: Bool {
        showsMorningRateCard || isDismissingMorningRateCard
    }

    private var allowsMidSleepSwipe: Bool {
        shouldShowMeadowForeground
            && !showsMorningRateCard
            && (isInSleepWindow || hasFinishedRoutine)
    }

    private var nextPrepReminderMessage: some View {
        Text("First reminder should show up at \(nextPrepReminderText)")
            .font(.system(size: 13.5, weight: .medium, design: .default))
            .foregroundColor(.lullInk2.opacity(0.78))
            .lineSpacing(3)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 280)
            .padding(.horizontal, 24)
    }

    private var midSleepSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                guard allowsMidSleepSwipe else { return }
                let dx = value.translation.width
                let dy = value.translation.height

                if showMidSleepToolkit {
                    guard dy > 80, dy > abs(dx) else { return }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showMidSleepToolkit = false
                    return
                }

                guard -dy > 80, -dy > abs(dx) else { return }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showMidSleepToolkit = true
            }
    }

    private func openMidSleepTactic(_ tactic: TodayMidSleepTactic) {
        switch tactic {
        case .breathing:
            break
        case .boringStory:
            guard state.canUseContentLibrary else {
                showMidSleepToolkit = false
                state.presentUpgradePaywall()
                return
            }
        case .sleepSounds:
            guard state.canUseSleepSounds else {
                showMidSleepToolkit = false
                state.presentUpgradePaywall()
                return
            }
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        showMidSleepToolkit = false
        activeMidSleepTactic = tactic
    }

    private func meadowForeground(maxToolkitHeight: CGFloat) -> some View {
        VStack(spacing: shouldShowMorningRateCardVisual ? 12 : 22) {
            TodayContractStatusPanel(
                title: contractStatusTitle,
                detail: contractStatusDetail,
                icon: contractStatusIcon,
                accent: contractStatusAccent,
                progressText: contractProgressText
            )
            .transition(.opacity.combined(with: .move(edge: .top)))

            if shouldShowMorningRateCardVisual {
                morningRateCard
                    .offset(y: isDismissingMorningRateCard ? 58 : 0)
                    .opacity(isDismissingMorningRateCard ? 0 : 1)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if shouldShowAppBlockingOffer {
                TodayAppBlockingOfferCard(
                    timeRange: appBlockingOfferTimeRange,
                    onAdd: {
                        state.startAppBlockingOfferSetup()
                    },
                    onDismiss: {
                        hasDismissedAppBlockingOffer = true
                    }
                )
                .frame(maxWidth: .infinity)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if showMidSleepToolkit && allowsMidSleepSwipe {
                TodayMidSleepToolkitCard(maxHeight: maxToolkitHeight) {
                    openMidSleepTactic($0)
                } onDismiss: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showMidSleepToolkit = false
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(2)
            }

            if showsNextPrepReminderMessage {
                Spacer(minLength: 0)
                nextPrepReminderMessage
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)
            }

            if allowsMidSleepSwipe && !showMidSleepToolkit {
                Text("Swipe up for tools to help you fall back asleep")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(.lullInk2.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 12)
                    .transition(.opacity)
            }
        }
        .accessibilityAction(named: "Show Mid-sleep options") {
            guard allowsMidSleepSwipe else { return }
            showMidSleepToolkit = true
        }
        .accessibilityAction(named: "Hide Mid-sleep options") {
            guard showMidSleepToolkit else { return }
            showMidSleepToolkit = false
        }
    }

    private var contractStatusTitle: String {
        if isInSleepWindow {
            return "Sleep window active"
        }
        if hasFinishedRoutine || deckCompleted {
            return "Scroll-lock is ready"
        }
        if let item = state.currentSleepRulePromptItem {
            return item.rule.title
        }
        return "Tonight's contract"
    }

    private var contractStatusDetail: String {
        if isInSleepWindow {
            return "Scroll apps locked until \(Self.timeFmt.string(from: state.appBlockingEndTime)) - no 1 AM scroll tonight."
        }
        if hasFinishedRoutine || deckCompleted {
            return "Your rules are cleared. Scroll-lock starts at \(Self.timeFmt.string(from: state.typicalBedtime))."
        }
        if let item = state.currentSleepRulePromptItem {
            return "Due \(Self.timeFmt.string(from: item.dueAt)) - grace until \(Self.timeFmt.string(from: item.graceEndsAt))."
        }
        return "Clear your next rule to keep distracting apps unlocked."
    }

    private var contractStatusIcon: String {
        if isInSleepWindow { return "moon.fill" }
        if hasFinishedRoutine || deckCompleted { return "checkmark.shield.fill" }
        return "lock.shield"
    }

    private var contractStatusAccent: Color {
        if isInSleepWindow { return Color(red: 0.78, green: 0.68, blue: 0.95) }
        if hasFinishedRoutine || deckCompleted { return .lullAmber }
        return .lullAmberSoft
    }

    private var contractProgressText: String {
        let total = max(tasks.count, 1)
        let cleared = min(total, deckDoneCount + deckSkippedCount)
        let remaining = max(total - cleared, 0)
        return "\(cleared) cleared earlier today · \(remaining) to go"
    }

    private var morningRateCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !hasFinishedRoutine {
                Text("Routine wasn't completed - still want to log how you slept?")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.lullInk2)
                    .lineSpacing(3)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 10)
            }

            MorningRateHero(
                wakeTime: Self.timeFmt.string(from: currentDate),
                yesterday: yesterdaysRating,
                rating: pendingMorningRating ?? todaysRating,
                variable: nil,
                testNight: 0,
                totalTestNights: 0,
                onRate: handleMorningRating
            )
        }
    }

    private var shouldShowAppBlockingOffer: Bool {
        state.shouldOfferAppBlockingSetup && !hasDismissedAppBlockingOffer
    }

    private var appBlockingOfferTimeRange: String {
        let start = AppState.defaultAppBlockingStart(from: state.typicalBedtime)
        let end = AppState.defaultAppBlockingEnd(from: state.typicalWakeTime)
        return "\(Self.timeFmt.string(from: start)) - \(Self.timeFmt.string(from: end))"
    }

    private func handleMorningRating(_ n: Int) {
        guard !isDismissingMorningRateCard else { return }
        let scoreToLog = AppState.clampedSleepScore(n)
        pendingMorningRating = scoreToLog

        let dismissDuration = reduceMotion ? 0.18 : 0.72
        withAnimation(reduceMotion ? .easeOut(duration: dismissDuration) : .easeInOut(duration: dismissDuration)) {
            isDismissingMorningRateCard = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + dismissDuration * 0.74) {
            state.morningScore = scoreToLog
            state.logMorningScore()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + dismissDuration + 0.14) {
            pendingMorningRating = nil
            isDismissingMorningRateCard = false
            state.presentPendingStreakMilestoneIfEligible()
        }
    }

    private var swipeHint: some View {
        HStack(spacing: 10) {
            swipeHintItem("left", "back")
            Capsule()
                .fill(Color.lullLine)
                .frame(width: 1, height: 16)
            swipeHintItem("up", "undo")
            Capsule()
                .fill(Color.lullLine)
                .frame(width: 1, height: 16)
            swipeHintItem("down", "skip")
            Capsule()
                .fill(Color.lullLine)
                .frame(width: 1, height: 16)
            swipeHintItem("right", "done")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .foregroundColor(.lullInk4)
    }

    private func swipeHintItem(_ direction: String, _ action: String) -> some View {
        HStack(spacing: 5) {
            Text(direction)
                .font(.system(size: 11, weight: .medium, design: .default))
            Text(action)
                .font(.system(size: 11, weight: .semibold, design: .default))
                .foregroundColor(action == "done" ? .lullAmberSoft : .lullInk4)
        }
    }

    private var addStepControl: some View {
        HStack {
            Spacer()
            Button {
                onFirstDeckInteraction()
                selectedTab = 1
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.lullAmber)
                    .frame(width: 50, height: 44)
                    .background(Capsule().fill(Color.white.opacity(0.055)))
                    .overlay(Capsule().strokeBorder(Color.lullLine, lineWidth: 1))
                    .accessibilityLabel("Add step")
            }
            .buttonStyle(.plain)
            Spacer()
        }
    }

    private func isDone(_ task: TodayPreviewTask) -> Bool {
        switch task {
        case .prep(let step):
            return state.prepDoneIds.contains(step.id)
        case .ritual(let step):
            return state.ritualDoneIds.contains(step.id)
        }
    }

    private func complete(_ task: TodayPreviewTask) {
        onFirstDeckInteraction()
        switch task {
        case .prep(let step):
            if !state.prepDoneIds.contains(step.id) {
                state.togglePrepDone(step.id)
            }
        case .ritual(let step):
            if !state.ritualDoneIds.contains(step.id) {
                state.markRitualDone(step.id)
            }
        }

        skippedTaskIds.remove(task.id)
        clearedSkippedTaskIds.insert(task.id)
        if let step = task.step {
            state.trackTodayDeckStep(step: step, status: .completed, stepType: task.stepType, index: currentIndex)
            if isPhoneStep(step) {
                state.refreshAppBlockingShield()
            }
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        bloomToken += 1
        advanceOrComplete()
    }

    private func skip(_ task: TodayPreviewTask) {
        guard tasks.indices.contains(currentIndex) else { return }
        onFirstDeckInteraction()
        skippedTaskIds.insert(task.id)
        clearedSkippedTaskIds.remove(task.id)
        if let step = task.step {
            state.trackTodayDeckStep(step: step, status: .skipped, stepType: task.stepType, index: currentIndex)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        advanceOrComplete()
    }

    private func advanceOrComplete() {
        if currentIndex < tasks.count - 1 {
            currentIndex += 1
        } else {
            completeDeck()
        }
    }

    private func goBack() {
        guard !tasks.isEmpty else { return }
        onFirstDeckInteraction()
        if currentIndex > 0 {
            let previous = tasks[currentIndex - 1]
            uncomplete(previous)
            skippedTaskIds.remove(previous.id)
            clearedSkippedTaskIds.insert(previous.id)
            currentIndex -= 1
        } else if tasks.indices.contains(currentIndex) {
            uncomplete(tasks[currentIndex])
            skippedTaskIds.remove(tasks[currentIndex].id)
            clearedSkippedTaskIds.insert(tasks[currentIndex].id)
        }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    private func uncomplete(_ task: TodayPreviewTask) {
        switch task {
        case .prep(let step):
            if state.prepDoneIds.contains(step.id) {
                state.togglePrepDone(step.id)
            }
        case .ritual(let step):
            if state.ritualDoneIds.contains(step.id) {
                state.unmarkRitualDone(step.id)
            }
        }
    }

    private func completeDeck() {
        guard !deckCompleted else { return }
        deckCompleted = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        state.trackTodayDeckCompleted(completedCount: deckDoneCount, skippedCount: deckSkippedCount)
        onRoutineCompleted()
    }

    private func clampCurrentIndex() {
        guard !tasks.isEmpty else {
            currentIndex = 0
            return
        }
        currentIndex = min(max(currentIndex, 0), tasks.count - 1)
    }

    private func trackStartIfNeeded() {
        guard showsDeck, !didTrackStart else { return }
        didTrackStart = true
        state.trackTodayDeckStarted(stepCount: tasks.count)
    }

    private func isPhoneStep(_ step: RoutineStep) -> Bool {
        step.remedyId == .noScreens
        || step.remedyId == .appBlocking
        || step.label == R.noScreens
        || step.label == R.appBlocking
    }

    private func attemptMatches(_ attempt: StepAttempt, task: TodayPreviewTask) -> Bool {
        guard let step = task.step else { return false }
        if let attemptRemedy = attempt.remedyId,
           let stepRemedy = step.remedyId ?? RemedyID.fromLabel(step.label),
           attemptRemedy == stepRemedy {
            return true
        }
        return attempt.labelSnapshot == step.label
    }
}

private struct TodayContractStatusPanel: View {
    let title: String
    let detail: String
    let icon: String
    let accent: Color
    let progressText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                    Text(title.uppercased())
                        .font(.mono(12))
                        .kerning(1.5)
                }
                .foregroundColor(accent)

                Text(detail)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.lullInk1)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.lullBg2.opacity(0.40))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(accent.opacity(0.42), lineWidth: 1)
                    )
            )

            Text(progressText)
                .font(.system(size: 19, weight: .bold, design: .default))
                .foregroundColor(.lullInk2)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TodayAppBlockingOfferCard: View {
    let timeRange: String
    let onAdd: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.lullAmber)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.lullAmber.opacity(0.12)))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Lock the scroll away tonight?")
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundColor(.lullInk0)
                    Text(timeRange)
                        .font(.system(size: 12))
                        .foregroundColor(.lullInk3)
                }

                Spacer(minLength: 0)

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.lullInk3)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss app blocking offer")
            }

            Text("TenThirty can block selected apps during your sleep window once you choose what to block.")
                .font(.system(size: 12.5))
                .foregroundColor(.lullInk2)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button(action: onAdd) {
                    HStack(spacing: 7) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("Add app blocking")
                            .font(.system(size: 13.5, weight: .semibold))
                    }
                    .foregroundColor(.lullBgDeep)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Capsule().fill(Color.lullAmber))
                }
                .buttonStyle(.plain)

                Button("Not now", action: onDismiss)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundColor(.lullInk2)
                    .frame(width: 84, height: 40)
                    .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.lullAmber.opacity(0.22), lineWidth: 1)
                )
        )
    }
}

struct TodayInsightsTabView: View {
    @EnvironmentObject private var state: AppState
    let currentDate: Date
    @Binding var sharedCalendarTopInset: CGFloat

    private var routineSteps: [RoutineStep] {
        state.routinePrepSteps + state.routineRitualSteps
    }

    private var currentMonthLoggedEntries: [SleepLogEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: currentDate)
        return state.sleepLogs.filter { entry in
            let day = calendar.startOfDay(for: entry.date)
            return calendar.isDate(day, equalTo: currentDate, toGranularity: .month)
                && day < today
        }
    }

    private var currentMonthHabitEntries: [SleepLogEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: currentDate)
        return state.sleepLogs.filter { entry in
            let day = calendar.startOfDay(for: entry.date)
            return calendar.isDate(day, equalTo: currentDate, toGranularity: .month)
                && day <= today
        }
    }

    private var insightsBetterHabitNightsValue: String {
        "\(currentMonthCompletedNights)"
    }

    private var insightsBetterHabitNightsDetail: String {
        let nightWord = currentMonthCompletedNights == 1 ? "night" : "nights"
        return "\(nightWord) of better habits this month"
    }

    private var currentMonthCompletedNights: Int {
        currentMonthHabitEntries.filter(\.completedNightlyFlow).count
    }

    private var insightsMorningRatingValue: String {
        let ratings = currentMonthLoggedEntries.map(\.score).filter { $0 > 0 }
        guard ratings.count >= 3 else { return "--" }
        let average = Double(ratings.reduce(0, +)) / Double(ratings.count)
        return String(format: "%.1f", average)
    }

    private var insightsMorningRatingDetail: String {
        let count = currentMonthLoggedEntries.map(\.score).filter { $0 > 0 }.count
        return count >= 3 ? "\(count) ratings this month" : "Not enough ratings yet"
    }

    var body: some View {
        VStack(spacing: 0) {
            TodayCurrentRoutineInsightsOverlay(
                routineSteps: routineSteps,
                betterHabitNightsValue: insightsBetterHabitNightsValue,
                betterHabitNightsDetail: insightsBetterHabitNightsDetail,
                morningRatingValue: insightsMorningRatingValue,
                morningRatingDetail: insightsMorningRatingDetail
            )
            .padding(.horizontal, 22)
            .padding(.top, 30)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: TodayInsightsPanelHeightKey.self,
                        value: proxy.size.height
                    )
                }
            )
            .frame(maxWidth: .infinity, alignment: .top)

            Spacer(minLength: 0)
        }
        .padding(.bottom, 118)
        .preferredColorScheme(.dark)
        .onAppear {
            state.trackTodayDeckInsightsOpened()
        }
        .onPreferenceChange(TodayInsightsPanelHeightKey.self) { height in
            sharedCalendarTopInset = height + 58
        }
    }
}

private struct TodayInsightsPanelHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct RoutineChipWrapLayout: Layout {
    var horizontalSpacing: CGFloat = 8
    var verticalSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? subviews.reduce(CGFloat.zero) {
            $0 + $1.sizeThatFits(.unspecified).width + horizontalSpacing
        }
        let rows = arrangedRows(maxWidth: maxWidth, subviews: subviews)
        let height = rows.reduce(CGFloat.zero) { total, row in
            total + row.height + (row.index == rows.last?.index ? 0 : verticalSpacing)
        }
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrangedRows(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: item.size.width, height: item.size.height)
                )
                x += item.size.width + horizontalSpacing
            }
            y += row.height + verticalSpacing
        }
    }

    private func arrangedRows(maxWidth: CGFloat, subviews: Subviews) -> [RoutineChipRow] {
        let availableWidth = max(maxWidth, 1)
        var rows: [RoutineChipRow] = []
        var currentItems: [RoutineChipRow.Item] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0

        for index in subviews.indices {
            let measured = subviews[index].sizeThatFits(ProposedViewSize(width: availableWidth, height: nil))
            let size = CGSize(width: min(measured.width, availableWidth), height: measured.height)
            let proposedWidth = currentItems.isEmpty ? size.width : currentWidth + horizontalSpacing + size.width

            if !currentItems.isEmpty && proposedWidth > availableWidth {
                rows.append(RoutineChipRow(index: rows.count, items: currentItems, height: currentHeight))
                currentItems = []
                currentWidth = 0
                currentHeight = 0
            }

            currentItems.append(.init(index: index, size: size))
            currentWidth = currentItems.count == 1 ? size.width : currentWidth + horizontalSpacing + size.width
            currentHeight = max(currentHeight, size.height)
        }

        if !currentItems.isEmpty {
            rows.append(RoutineChipRow(index: rows.count, items: currentItems, height: currentHeight))
        }
        return rows
    }
}

private struct RoutineChipRow {
    struct Item {
        let index: Int
        let size: CGSize
    }

    let index: Int
    let items: [Item]
    let height: CGFloat
}

private struct TodayCurrentRoutineInsightsOverlay: View {
    let routineSteps: [RoutineStep]
    let betterHabitNightsValue: String
    let betterHabitNightsDetail: String
    let morningRatingValue: String
    let morningRatingDetail: String

    var body: some View {
        currentRoutineCard
            .frame(maxWidth: .infinity, alignment: .top)
    }

    private var currentRoutineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Kicker(text: "Current routine", color: .lullAmberSoft)
                    Text("Tonight's setup")
                        .font(.serif(24))
                        .foregroundColor(.lullInk0)
                }
                Spacer()
            }

            RoutineChipWrapLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(routineSteps) { step in
                    Text(step.label)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(.lullInk1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.055))
                                .overlay(Capsule().strokeBorder(Color.lullLineStrong, lineWidth: 1))
                        )
                }
            }

            HStack(spacing: 10) {
                insightStat(
                    title: "Better habits",
                    value: betterHabitNightsValue,
                    detail: betterHabitNightsDetail,
                    primary: true
                )
                insightStat(
                    title: "Morning rating",
                    value: morningRatingValue,
                    detail: morningRatingDetail,
                    primary: false
                )
            }
        }
        .padding(16)
        .background(insightGlass(cornerRadius: 20, opacity: 0.075))
    }

    private func insightStat(title: String, value: String, detail: String, primary: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .default))
                .foregroundColor(.lullInk4)
            Text(value)
                .font(primary ? .serif(30) : .serif(24))
                .foregroundColor(primary ? .lullAmber : .lullInk0)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(detail)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(.lullInk3)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
                .minimumScaleFactor(0.9)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(primary ? 0.055 : 0.035))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.lullLine, lineWidth: 1))
        )
    }

    private func insightGlass(cornerRadius: CGFloat, opacity: Double) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(hex: "#4c351d").opacity(opacity + 0.04),
                        Color(hex: "#160d08").opacity(opacity)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.lullLineStrong, lineWidth: 1)
            )
    }
}

private struct TodayDeckProgressSegments: View {
    let tasks: [TodayPreviewTask]
    let currentIndex: Int
    let skippedIds: Set<String>
    let isDone: (TodayPreviewTask) -> Bool

    var body: some View {
        HStack(spacing: 5) {
            ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                Capsule()
                    .fill(fill(for: task, index: index))
                    .frame(height: 5)
                    .overlay(
                        Capsule()
                            .strokeBorder(index == currentIndex ? Color.lullAmber : Color.clear, lineWidth: 1.2)
                    )
                    .shadow(color: isDone(task) ? .lullAmberGlow : .clear, radius: 5)
            }
        }
        .frame(height: 6)
        .accessibilityLabel("Ritual progress")
    }

    private func fill(for task: TodayPreviewTask, index: Int) -> Color {
        if isDone(task) { return .lullAmber }
        if skippedIds.contains(task.id) { return Color.white.opacity(0.22) }
        if index == currentIndex { return Color.lullAmber.opacity(0.18) }
        return Color.white.opacity(0.06)
    }
}

private struct TodayCompletionBloom: View {
    let token: Int
    let reduceMotion: Bool
    @State private var active = false

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color.lullAmber.opacity(0.32), Color.lullAmber.opacity(0.12), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 90
                )
            )
            .frame(width: 170, height: 170)
            .scaleEffect(active ? 7 : 0.3)
            .opacity(active ? 0 : 0.82)
            .onChange(of: token) { _, newValue in
                guard newValue > 0 else { return }
                active = false
                let duration = reduceMotion ? 0.18 : 0.70
                withAnimation(.easeOut(duration: duration)) {
                    active = true
                }
            }
    }
}

private struct TodayMidSleepToolkitCard: View {
    let maxHeight: CGFloat
    let onOpen: (TodayMidSleepTactic) -> Void
    let onDismiss: () -> Void

    private let options: [TodayMidSleepOption] = [
        TodayMidSleepOption(
            tactic: .breathing,
            title: "4.7.8 breath",
            access: "Free",
            detail: "In · hold · out · preview"
        ),
        TodayMidSleepOption(
            tactic: .boringStory,
            title: "Boring story",
            access: "Premium",
            detail: "random · audio · preview"
        ),
        TodayMidSleepOption(
            tactic: .sleepSounds,
            title: "Sleep sounds",
            access: "Premium",
            detail: "rain · noise · water · preview"
        )
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Capsule()
                    .fill(Color.lullInk3.opacity(0.34))
                    .frame(width: 38, height: 4)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 2)

                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Mid-sleep mode")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.lullAmber)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Swipe down to close")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(.lullInk3)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.lullInk2)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.white.opacity(0.045)))
                            .overlay(Circle().strokeBorder(Color.lullLine, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close Mid-sleep mode")
                }

                VStack(spacing: 12) {
                    ForEach(options) { option in
                        Button(action: { onOpen(option.tactic) }) {
                            TodayMidSleepToolkitRow(option: option)
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("If you're still awake after 20 min")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.lullInk2)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("TenThirty can surface a get-up protocol - a short reset in another room so your brain keeps associating bed with sleep, not frustration.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.lullInk1)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.lullBg1.opacity(0.64))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [7, 6]))
                        .foregroundColor(.lullLine.opacity(0.86))
                )
            }
            .padding(22)
        }
        .frame(maxHeight: maxHeight)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#2a1a14").opacity(0.40),
                            Color(hex: "#120c09").opacity(0.40)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.lullLine.opacity(0.86), lineWidth: 1.2)
        )
        .shadow(color: .black.opacity(0.62), radius: 30, x: 0, y: 18)
        .contentShape(Rectangle())
        .simultaneousGesture(dismissGesture)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Mid-sleep mode options")
        .accessibilityAction(named: "Close", onDismiss)
    }

    private var dismissGesture: some Gesture {
        DragGesture(minimumDistance: 18)
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                guard dy > 70, dy > abs(dx) else { return }
                onDismiss()
            }
    }
}

private struct TodayMidSleepOption: Identifiable {
    let id = UUID()
    let tactic: TodayMidSleepTactic
    let title: String
    let access: String
    let detail: String
}

private struct TodayMidSleepToolkitRow: View {
    let option: TodayMidSleepOption

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.035))
                Circle()
                    .stroke(Color.lullLine.opacity(0.78), lineWidth: 1)
                Circle()
                    .fill(Color.lullAmber)
                    .frame(width: 8, height: 8)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(option.title)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(.lullInk1)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)

                    Text(option.access)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(option.access == "Free" ? .lullInk2 : .lullAmber)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.lullBg1.opacity(0.55))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.lullLine.opacity(0.85), lineWidth: 1)
                        )
                }

                Text(option.detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.lullInk2)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.lullInk2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color(hex: "#17100c").opacity(0.40))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.lullLine.opacity(0.88), lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}

enum TodayFireflyMode: Equatable {
    case cluster
    case calendar
}

enum TodayFireflyCalendarRange: Equatable {
    case week
    case month
}

struct TodayMeadowBackdrop: View {
    var body: some View {
        GeometryReader { geo in
            let largestSide = max(geo.size.width, geo.size.height)

            ZStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#2a1d11"),
                                Color(hex: "#20170e"),
                                Color(hex: "#141009"),
                                Color(hex: "#070604")
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Rectangle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "#6f4b25").opacity(0.26), .clear],
                            center: UnitPoint(x: 0.50, y: 0.52),
                            startRadius: 0,
                            endRadius: largestSide * 0.72
                        )
                    )

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#493317").opacity(0.00),
                                Color(hex: "#38401f").opacity(0.20),
                                Color(hex: "#1d2110").opacity(0.54),
                                Color(hex: "#070604").opacity(0.92)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: geo.size.height * 0.52)
                    .frame(maxHeight: .infinity, alignment: .bottom)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#d7a35a").opacity(0.18),
                                Color(hex: "#7d6e38").opacity(0.12),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * 0.92, height: 2)
                    .blur(radius: 2)
                    .position(x: geo.size.width * 0.5, y: geo.size.height * 0.55)

                TodayMeadowFieldTexture()
                    .opacity(0.92)

                TodayMeadowGlowField()

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "#f4d49a").opacity(0.26),
                                Color.lullAmber.opacity(0.07),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 72
                        )
                    )
                    .frame(width: 134, height: 134)
                    .blur(radius: 3)
                    .position(x: geo.size.width * 0.78, y: geo.size.height * 0.18)
                    .opacity(0.62)

                Rectangle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "#33220f").opacity(0.30), .clear],
                            center: UnitPoint(x: 0.5, y: 0.86),
                            startRadius: 0,
                            endRadius: largestSide * 0.42
                        )
                    )

                TodayMeadowGrassLayer(
                    density: 1.35,
                    heightScale: 0.82,
                    opacityScale: 0.88
                )
                .frame(height: geo.size.height * 0.23)
                .padding(.bottom, 76)
                .frame(maxHeight: .infinity, alignment: .bottom)

                TodayMeadowGrassLayer(
                    density: 2.2,
                    heightScale: 1.0,
                    opacityScale: 1.0
                )
                .frame(height: geo.size.height * 0.20)
                .padding(.bottom, 58)
                .frame(maxHeight: .infinity, alignment: .bottom)

                Rectangle()
                    .fill(
                        RadialGradient(
                            colors: [.clear, Color(hex: "#120c07").opacity(0.18)],
                            center: .center,
                            startRadius: largestSide * 0.20,
                            endRadius: largestSide * 0.70
                        )
                    )
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .ignoresSafeArea()
    }
}

private struct TodayMeadowGlowField: View {
    private let glows: [(x: CGFloat, y: CGFloat, radius: CGFloat, opacity: Double)] = [
        (0.12, 0.22, 44, 0.14),
        (0.36, 0.35, 34, 0.10),
        (0.73, 0.33, 40, 0.12),
        (0.18, 0.62, 30, 0.12),
        (0.88, 0.61, 38, 0.13),
        (0.50, 0.72, 46, 0.08)
    ]

    var body: some View {
        GeometryReader { geo in
            ForEach(glows.indices, id: \.self) { index in
                let glow = glows[index]
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.lullAmber.opacity(glow.opacity),
                                Color.lullAmber.opacity(glow.opacity * 0.32),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: glow.radius
                        )
                    )
                    .frame(width: glow.radius * 2, height: glow.radius * 2)
                    .blur(radius: 5)
                    .position(x: geo.size.width * glow.x, y: geo.size.height * glow.y)
            }
        }
    }
}

private struct TodayMeadowFieldTexture: View {
    private let grassPatches = 130

    var body: some View {
        Canvas { context, size in
            let horizon = size.height * 0.53
            let hills: [(y: CGFloat, crest: CGFloat, color: Color)] = [
                (0.58, 0.48, Color(hex: "#46502a").opacity(0.34)),
                (0.66, 0.55, Color(hex: "#2d351c").opacity(0.54)),
                (0.77, 0.64, Color(hex: "#14180d").opacity(0.82))
            ]

            for (index, hill) in hills.enumerated() {
                let baseY = size.height * hill.y
                let crestY = size.height * hill.crest
                var path = Path()
                path.move(to: CGPoint(x: -24, y: size.height + 20))
                path.addLine(to: CGPoint(x: -24, y: baseY))
                path.addQuadCurve(
                    to: CGPoint(x: size.width + 24, y: baseY + size.height * 0.02),
                    control: CGPoint(
                        x: size.width * (0.30 + CGFloat(index) * 0.18),
                        y: crestY
                    )
                )
                path.addLine(to: CGPoint(x: size.width + 24, y: size.height + 20))
                path.closeSubpath()
                context.fill(path, with: .color(hill.color))
            }

            var horizonLine = Path()
            horizonLine.move(to: CGPoint(x: -20, y: horizon))
            horizonLine.addQuadCurve(
                to: CGPoint(x: size.width + 20, y: horizon + size.height * 0.015),
                control: CGPoint(x: size.width * 0.48, y: horizon - size.height * 0.035)
            )
            context.stroke(
                horizonLine,
                with: .color(Color(hex: "#c6974e").opacity(0.16)),
                lineWidth: 1.4
            )

            for index in 0..<grassPatches {
                let seed = CGFloat((index * 73) % 997) / 997
                let seedB = CGFloat((index * 157) % 991) / 991
                let seedC = CGFloat((index * 211) % 983) / 983
                let x = size.width * seed
                let y = size.height * (0.62 + seedB * 0.30)
                let height = size.height * (0.012 + seedC * 0.026)
                let spread = size.width * (0.007 + seedB * 0.014)
                let color = index.isMultiple(of: 3)
                    ? Color(hex: "#a18c4b").opacity(0.20)
                    : Color(hex: "#5f5a2e").opacity(0.22)

                for blade in -1...1 {
                    let bladeOffset = CGFloat(blade) * spread
                    var bladePath = Path()
                    bladePath.move(to: CGPoint(x: x + bladeOffset, y: y + height))
                    bladePath.addQuadCurve(
                        to: CGPoint(x: x + bladeOffset + CGFloat(blade) * spread * 0.65, y: y - height * 0.35),
                        control: CGPoint(
                            x: x + bladeOffset + CGFloat(blade) * spread * 0.28,
                            y: y + height * 0.18
                        )
                    )
                    context.stroke(bladePath, with: .color(color), lineWidth: 1.25)
                }

                if index.isMultiple(of: 11) {
                    let dotRect = CGRect(x: x - 1.8, y: y - height * 0.52, width: 3.6, height: 3.6)
                    context.fill(Path(ellipseIn: dotRect), with: .color(Color.lullAmber.opacity(0.20)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct TodayMeadowGrassLayer: View {
    let density: CGFloat
    let heightScale: CGFloat
    let opacityScale: Double

    init(
        density: CGFloat = 1,
        heightScale: CGFloat = 1,
        opacityScale: Double = 1
    ) {
        self.density = density
        self.heightScale = heightScale
        self.opacityScale = opacityScale
    }

    private struct Layer {
        let count: Int
        let minHeight: CGFloat
        let maxHeight: CGFloat
        let minWidth: CGFloat
        let maxWidth: CGFloat
        let color: Color
        let opacity: Double
        let curve: CGFloat
    }

    private let layers: [Layer] = [
        Layer(count: 126, minHeight: 7, maxHeight: 16, minWidth: 0.9, maxWidth: 1.6, color: Color(hex: "#6b4f2b"), opacity: 0.30, curve: 7),
        Layer(count: 142, minHeight: 10, maxHeight: 23, minWidth: 1.0, maxWidth: 1.9, color: Color(hex: "#4c3a21"), opacity: 0.44, curve: 9),
        Layer(count: 154, minHeight: 12, maxHeight: 31, minWidth: 1.1, maxWidth: 2.2, color: Color(hex: "#302516"), opacity: 0.60, curve: 10),
        Layer(count: 138, minHeight: 16, maxHeight: 39, minWidth: 1.2, maxWidth: 2.5, color: Color(hex: "#1b150d"), opacity: 0.76, curve: 12),
        Layer(count: 116, minHeight: 20, maxHeight: 48, minWidth: 1.4, maxWidth: 2.8, color: Color(hex: "#0d0a06"), opacity: 0.88, curve: 13)
    ]

    var body: some View {
        Canvas { context, size in
            let baseY = size.height + 8

            for (layerIndex, layer) in layers.enumerated() {
                let count = max(1, Int((CGFloat(layer.count) * density).rounded()))
                for bladeIndex in 0..<count {
                    let seed = CGFloat((bladeIndex * 73 + layerIndex * 191) % 997) / 997
                    let seedB = CGFloat((bladeIndex * 47 + layerIndex * 109) % 991) / 991
                    let seedC = CGFloat((bladeIndex * 89 + layerIndex * 41) % 983) / 983

                    let x = -14 + (size.width + 28) * seed
                    let height = (layer.minHeight + (layer.maxHeight - layer.minHeight) * seedB) * heightScale
                    let width = layer.minWidth + (layer.maxWidth - layer.minWidth) * seedC
                    let curve = (seedC - 0.5) * layer.curve
                    let top = CGPoint(x: x + curve, y: baseY - height)
                    let mid = CGPoint(x: x + curve * 0.42, y: baseY - height * 0.52)

                    var path = Path()
                    path.move(to: CGPoint(x: x - width * 0.5, y: baseY))
                    path.addQuadCurve(to: top, control: CGPoint(x: mid.x - width * 0.15, y: mid.y))
                    path.addQuadCurve(to: CGPoint(x: x + width * 0.5, y: baseY), control: CGPoint(x: mid.x + width * 0.15, y: mid.y))
                    path.closeSubpath()

                    context.fill(path, with: .color(layer.color.opacity(layer.opacity * opacityScale)))
                }
            }

        }
    }
}

struct TodayFireflyScene: View {
    let mode: TodayFireflyMode
    let dates: [Date]
    let currentDate: Date
    let loggedShadeDates: Set<Date>
    let calendarTopInset: CGFloat
    let calendarRange: TodayFireflyCalendarRange
    let entranceToken: Int
    let reduceMotion: Bool
    @State private var entrancePhase = 2
    @State private var handledEntranceToken = 0

    private var monthSymbols: [String] {
        Calendar.current.shortStandaloneWeekdaySymbols.map { String($0.prefix(1)) }
    }

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 24.0, paused: false)) { timeline in
                ZStack {
                    if mode == .calendar {
                        calendarGrid(size: geo.size)
                            .transition(.opacity)
                    }

                    ForEach(Array(dates.enumerated()), id: \.element) { index, date in
                        let newest = index == dates.count - 1
                        let entering = isEnteringNewestFirefly(newest)
                        let position = fireflyPosition(
                            index: index,
                            date: date,
                            size: geo.size,
                            isNewest: newest,
                            time: timeline.date.timeIntervalSinceReferenceDate
                        )
                        Group {
                            if entering {
                                EarnedFireflyEntranceDot(
                                    phase: entrancePhase,
                                    reduceMotion: reduceMotion
                                )
                            } else {
                                FireflyDot(index: index, reduceMotion: reduceMotion, drifts: mode == .cluster)
                            }
                        }
                        .scaleEffect(fireflyScale(isNewest: newest))
                        .opacity(fireflyOpacity(isNewest: newest))
                        .position(position)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.95), value: mode)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .onChange(of: entranceToken) { _, newToken in
                prepareEntranceIfNeeded(newToken)
            }
        }
    }

    private func prepareEntranceIfNeeded(_ token: Int) {
        guard mode == .cluster, token > handledEntranceToken, !dates.isEmpty else { return }
        handledEntranceToken = token
        if reduceMotion {
            entrancePhase = 2
            return
        }
        entrancePhase = 0
        withAnimation(.spring(response: TodayDeckConstants.fireflyRiseDuration, dampingFraction: 0.72)) {
            entrancePhase = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + TodayDeckConstants.fireflyRiseDuration) {
            withAnimation(.easeInOut(duration: TodayDeckConstants.fireflySettleDuration)) {
                entrancePhase = 2
            }
        }
    }

    private func fireflyPosition(index: Int, date: Date, size: CGSize, isNewest: Bool, time: TimeInterval) -> CGPoint {
        if isNewest, mode == .cluster, entranceToken > 0, entrancePhase < 2, !reduceMotion {
            let phasePoint = entrancePhase == 0
                ? CGPoint(x: 0.50, y: 1.16)
                : CGPoint(x: 0.55, y: 0.47)
            return CGPoint(x: phasePoint.x * size.width, y: phasePoint.y * size.height)
        }

        let unit: CGPoint
        switch mode {
        case .cluster:
            unit = reduceMotion
                ? TodayDeckConstants.homePositions[index % TodayDeckConstants.homePositions.count]
                : wanderingUnitPosition(index: index, time: time)
        case .calendar:
            unit = calendarUnitPosition(for: date, size: size) ?? offCalendarUnitPosition(index: index, size: size)
        }
        return CGPoint(x: unit.x * size.width, y: unit.y * size.height)
    }

    private func wanderingUnitPosition(index: Int, time: TimeInterval) -> CGPoint {
        let home = TodayDeckConstants.homePositions[index % TodayDeckConstants.homePositions.count]
        let phase = Double(index) * 1.731
        let slow = time / (8.0 + Double(index % 5) * 1.1)
        let medium = time / (4.8 + Double(index % 4) * 0.7)
        let edgeBias = edgeBias(for: index)

        let x = home.x
            + CGFloat(sin(slow + phase)) * (0.14 + edgeBias.x)
            + CGFloat(sin(medium * 0.73 + phase * 0.41)) * 0.055
        let y = home.y
            + CGFloat(cos(slow * 0.84 + phase * 0.67)) * (0.12 + edgeBias.y)
            + CGFloat(sin(medium + phase * 0.29)) * 0.05

        return CGPoint(
            x: min(max(x, 0.055), 0.945),
            y: min(max(y, 0.15), 0.92)
        )
    }

    private func edgeBias(for index: Int) -> CGPoint {
        switch index % 4 {
        case 0: return CGPoint(x: 0.05, y: 0.02)
        case 1: return CGPoint(x: 0.03, y: 0.06)
        case 2: return CGPoint(x: 0.07, y: 0.04)
        default: return CGPoint(x: 0.04, y: 0.07)
        }
    }

    private func offCalendarUnitPosition(index: Int, size: CGSize) -> CGPoint {
        let metrics = calendarMetrics(size: size)
        let railX: CGFloat = index.isMultiple(of: 2) ? 0.045 : 0.955
        let rows = calendarRange == .week ? 1 : calendarRows
        let slot = CGFloat((index / 2) % max(rows, 1))
        let rowStep = rows > 1 ? (metrics.y1 - metrics.y0) / CGFloat(rows - 1) : 0
        return CGPoint(x: railX, y: metrics.y0 + slot * rowStep)
    }

    private func fireflyScale(isNewest: Bool) -> CGFloat {
        guard isNewest, mode == .cluster, entranceToken > 0, !reduceMotion else { return 1 }
        if entrancePhase == 1 { return TodayDeckConstants.fireflyPeakScale }
        return entrancePhase == 0 ? 0.45 : 1
    }

    private func fireflyOpacity(isNewest: Bool) -> Double {
        guard isNewest, mode == .cluster, entranceToken > 0, !reduceMotion else { return 1 }
        return entrancePhase == 0 ? 0 : 1
    }

    private func isEnteringNewestFirefly(_ isNewest: Bool) -> Bool {
        isNewest
            && mode == .cluster
            && entranceToken > 0
            && entrancePhase < 2
            && !reduceMotion
    }

    private func calendarGrid(size: CGSize) -> some View {
        Group {
            switch calendarRange {
            case .week:
                weekCalendarGrid(size: size)
            case .month:
                monthCalendarGrid(size: size)
            }
        }
    }

    private func monthCalendarGrid(size: CGSize) -> some View {
        ZStack {
            weekdayHeader(size: size)

            ForEach(0..<calendarRows, id: \.self) { row in
                Text("W\(row + 1)")
                    .font(.mono(9))
                    .foregroundColor(.lullInk4)
                    .position(weekLabelPosition(row: row, size: size))
            }

            ForEach(1...daysInMonth, id: \.self) { day in
                calendarCell(
                    fill: monthCellFill(day: day),
                    stroke: monthCellStroke(day: day),
                    lineWidth: monthCellLineWidth(day: day),
                    size: 26
                )
                .position(dayCellPosition(day: day, size: size))
            }

            calendarCaption(currentDate.formatted(.dateTime.month(.wide).year()), size: size)
        }
    }

    private func weekCalendarGrid(size: CGSize) -> some View {
        ZStack {
            weekdayHeader(size: size)

            ForEach(Array(weekDates.enumerated()), id: \.offset) { index, date in
                calendarCell(
                    fill: weekCellFill(date: date),
                    stroke: weekCellStroke(date: date),
                    lineWidth: weekCellLineWidth(date: date),
                    size: 32
                )
                .position(weekDayCellPosition(index: index, size: size))

                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.mono(9))
                    .foregroundColor(.lullInk3)
                    .position(weekDayNumberPosition(index: index, size: size))
            }

            calendarCaption(weekCaption, size: size)
        }
    }

    private func weekdayHeader(size: CGSize) -> some View {
        ForEach(0..<monthSymbols.count, id: \.self) { index in
            Text(monthSymbols[index])
                .font(.mono(9.5))
                .foregroundColor(.lullInk3)
                .position(weekdayPosition(index: index, size: size))
        }
    }

    private func calendarCell(fill: Color, stroke: Color, lineWidth: CGFloat, size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(fill)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(stroke, lineWidth: lineWidth)
            )
            .frame(width: size, height: size)
    }

    private func calendarCaption(_ text: String, size: CGSize) -> some View {
        Text(text)
            .font(.serif(19))
            .foregroundColor(.lullInk1)
            .position(x: size.width * 0.5, y: size.height * calendarMetrics(size: size).monthY)
    }

    private var weekDates: [Date] {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: currentDate)?.start ?? currentDate
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private var weekCaption: String {
        guard let start = weekDates.first else { return "This week" }
        return "Week of \(start.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private func isShadedDate(_ date: Date) -> Bool {
        loggedShadeDates.contains(Calendar.current.startOfDay(for: date))
    }

    private func weekCellFill(date: Date) -> Color {
        if Calendar.current.isDate(date, inSameDayAs: currentDate) {
            return Color.lullAmber.opacity(0.10)
        }
        if isShadedDate(date) {
            return Color.lullAmber.opacity(0.18)
        }
        return Color.white.opacity(0.015)
    }

    private func weekCellStroke(date: Date) -> Color {
        if Calendar.current.isDate(date, inSameDayAs: currentDate) {
            return Color.lullAmber.opacity(0.72)
        }
        if isShadedDate(date) {
            return Color.lullAmber.opacity(0.25)
        }
        return Color.white.opacity(0.13)
    }

    private func weekCellLineWidth(date: Date) -> CGFloat {
        Calendar.current.isDate(date, inSameDayAs: currentDate) ? 1.8 : 1
    }

    private var monthStart: Date {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: currentDate)
        return calendar.date(from: comps) ?? currentDate
    }

    private var firstWeekdayIndex: Int {
        Calendar.current.component(.weekday, from: monthStart) - 1
    }

    private var daysInMonth: Int {
        Calendar.current.range(of: .day, in: .month, for: currentDate)?.count ?? 30
    }

    private var calendarRows: Int {
        Int(ceil(Double(firstWeekdayIndex + daysInMonth) / 7.0))
    }

    private func dateForDay(_ day: Int) -> Date? {
        Calendar.current.date(byAdding: .day, value: day - 1, to: monthStart)
    }

    private func isShadedDay(_ day: Int) -> Bool {
        guard let date = dateForDay(day) else { return false }
        return loggedShadeDates.contains(Calendar.current.startOfDay(for: date))
    }

    private func isTodayDay(_ day: Int) -> Bool {
        guard let date = dateForDay(day) else { return false }
        return Calendar.current.isDate(date, inSameDayAs: currentDate)
    }

    private func monthCellFill(day: Int) -> Color {
        if isTodayDay(day) {
            return Color.lullAmber.opacity(0.10)
        }
        if isShadedDay(day) {
            return Color.lullAmber.opacity(0.18)
        }
        return Color.white.opacity(0.015)
    }

    private func monthCellStroke(day: Int) -> Color {
        if isTodayDay(day) {
            return Color.lullAmber.opacity(0.72)
        }
        if isShadedDay(day) {
            return Color.lullAmber.opacity(0.25)
        }
        return Color.white.opacity(0.13)
    }

    private func monthCellLineWidth(day: Int) -> CGFloat {
        isTodayDay(day) ? 1.8 : 1
    }

    private func calendarUnitPosition(for date: Date, size: CGSize) -> CGPoint? {
        let calendar = Calendar.current
        switch calendarRange {
        case .week:
            guard let index = weekDates.firstIndex(where: { calendar.isDate($0, inSameDayAs: date) }) else {
                return nil
            }
            return weekDayCellUnitPosition(index: index, size: size)
        case .month:
            guard calendar.isDate(date, equalTo: currentDate, toGranularity: .month),
                  let day = calendar.dateComponents([.day], from: date).day else {
                return nil
            }
            return dayCellUnitPosition(day: day, size: size)
        }
    }

    private func dayCellPosition(day: Int, size: CGSize) -> CGPoint {
        let unit = dayCellUnitPosition(day: day, size: size)
        return CGPoint(x: unit.x * size.width, y: unit.y * size.height)
    }

    private func weekDayCellPosition(index: Int, size: CGSize) -> CGPoint {
        let unit = weekDayCellUnitPosition(index: index, size: size)
        return CGPoint(x: unit.x * size.width, y: unit.y * size.height)
    }

    private func weekDayNumberPosition(index: Int, size: CGSize) -> CGPoint {
        let unit = weekDayCellUnitPosition(index: index, size: size)
        return CGPoint(x: unit.x * size.width, y: min(size.height * 0.86, unit.y * size.height + 28))
    }

    private func dayCellUnitPosition(day: Int, size: CGSize) -> CGPoint {
        let metrics = calendarMetrics(size: size)
        let slot = firstWeekdayIndex + day - 1
        let col = slot % 7
        let row = slot / 7
        let x0: CGFloat = 0.14
        let x1: CGFloat = 0.86
        let colStep = (x1 - x0) / 6
        let rowStep = calendarRows > 1 ? (metrics.y1 - metrics.y0) / CGFloat(calendarRows - 1) : 0
        return CGPoint(x: x0 + CGFloat(col) * colStep, y: metrics.y0 + CGFloat(row) * rowStep)
    }

    private func weekDayCellUnitPosition(index: Int, size: CGSize) -> CGPoint {
        let metrics = calendarMetrics(size: size)
        let x0: CGFloat = 0.14
        let x1: CGFloat = 0.86
        let colStep = (x1 - x0) / 6
        return CGPoint(x: x0 + CGFloat(index) * colStep, y: metrics.y0 + 0.06)
    }

    private func weekdayPosition(index: Int, size: CGSize) -> CGPoint {
        let unit = CGPoint(
            x: 0.14 + CGFloat(index) * ((0.86 - 0.14) / 6),
            y: calendarMetrics(size: size).weekdayY
        )
        return CGPoint(x: unit.x * size.width, y: unit.y * size.height)
    }

    private func weekLabelPosition(row: Int, size: CGSize) -> CGPoint {
        let metrics = calendarMetrics(size: size)
        let rowStep = calendarRows > 1 ? (metrics.y1 - metrics.y0) / CGFloat(calendarRows - 1) : 0
        let unit = CGPoint(x: 0.07, y: metrics.y0 + CGFloat(row) * rowStep)
        return CGPoint(x: unit.x * size.width, y: unit.y * size.height)
    }

    private func calendarMetrics(size: CGSize) -> (weekdayY: CGFloat, y0: CGFloat, y1: CGFloat, monthY: CGFloat) {
        let height = max(size.height, 1)
        let reservedTop = (calendarTopInset + 18) / height
        let weekdayY = min(0.68, max(0.39, reservedTop))
        let y0 = min(0.74, weekdayY + 0.055)
        let monthY: CGFloat = 0.90
        let rowBottomLimit = monthY - 0.12
        let availableSpan = max(0.14, min(0.30, rowBottomLimit - y0))
        let y1 = min(rowBottomLimit, y0 + availableSpan)
        return (weekdayY, y0, y1, monthY)
    }
}

struct FireflyDot: View {
    let index: Int
    let reduceMotion: Bool
    let drifts: Bool
    @State private var pulse = false

    private var glowSize: CGFloat {
        [36, 42, 34, 48, 38, 44][index % 6]
    }

    private var coreSize: CGFloat {
        [6.5, 7.5, 6, 8, 7, 7.5][index % 6]
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [Color.lullAmber.opacity(0.42), Color.lullAmber.opacity(0.09), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 18
                ))
                .frame(width: glowSize, height: glowSize)

            Circle()
                .fill(Color.lullAmber)
                .frame(width: coreSize, height: coreSize)
                .shadow(color: .lullAmberGlow, radius: 12)
        }
        .scaleEffect(reduceMotion || !drifts ? 1 : (pulse ? 1.10 : 0.94))
        .opacity(reduceMotion || !drifts ? 1 : (pulse ? 1 : 0.82))
        .onAppear {
            guard !reduceMotion, drifts else { return }
            withAnimation(.easeInOut(duration: 1.9 + Double(index % 5) * 0.22).repeatForever(autoreverses: true)) {
                pulse.toggle()
            }
        }
    }
}

private struct EarnedFireflyEntranceDot: View {
    let phase: Int
    let reduceMotion: Bool
    @State private var wingFlutter = false

    private var wingOpacity: Double {
        phase == 1 ? 0.26 : 0.16
    }

    private var glowScale: CGFloat {
        phase == 1 ? 1.22 : 0.92
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.lullAmber.opacity(0.34),
                            Color.lullAmber.opacity(0.16),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 32
                    )
                )
                .frame(width: 72, height: 72)
                .scaleEffect(glowScale)
                .blur(radius: 1.2)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.86),
                            Color.lullAmber.opacity(0.96),
                            Color.lullAmber.opacity(0.24),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 19
                    )
                )
                .frame(width: 34, height: 34)
                .shadow(color: .lullAmberGlow, radius: 18)

            ZStack {
                wing
                    .rotationEffect(.degrees(wingFlutter ? -24 : -17), anchor: .leading)
                    .offset(x: 0, y: -9)
                wing
                    .scaleEffect(x: 1, y: -1)
                    .rotationEffect(.degrees(wingFlutter ? 24 : 17), anchor: .leading)
                    .offset(x: 0, y: 9)
            }
            .offset(x: -1, y: -2)
            .opacity(0.38)

            insectBody
                .scaleEffect(0.58)
                .opacity(0.24)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.18).repeatForever(autoreverses: true)) {
                wingFlutter.toggle()
            }
        }
    }

    private var wing: some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [
                        Color.lullInk0.opacity(wingOpacity),
                            Color.lullAmber.opacity(0.08),
                        .clear
                    ],
                    center: .leading,
                    startRadius: 1,
                    endRadius: 22
                )
            )
            .frame(width: 32, height: 17)
            .overlay(
                Ellipse()
                    .stroke(Color.lullInk0.opacity(wingOpacity * 0.45), lineWidth: 0.6)
            )
            .blur(radius: 0.12)
    }

    private var insectBody: some View {
        ZStack {
            antenna
                .stroke(Color.black.opacity(0.70), lineWidth: 0.9)
                .frame(width: 18, height: 10)
                .offset(x: -21, y: -8)

            Capsule()
                .fill(Color.black.opacity(0.84))
                .frame(width: 32, height: 8.5)
                .offset(x: -1, y: -1)

            Ellipse()
                .fill(Color.black.opacity(0.88))
                .frame(width: 13, height: 11)
                .offset(x: -15, y: -2)

            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.92),
                            Color.lullAmber.opacity(0.95),
                            Color.lullAmber.opacity(0.12)
                        ],
                        center: .leading,
                        startRadius: 0,
                        endRadius: 17
                    )
                )
                .frame(width: 27, height: 17)
                .offset(x: 15, y: 1)
                .shadow(color: .lullAmberGlow, radius: 18)

            VStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { _ in
                    Capsule()
                        .fill(Color.black.opacity(0.18))
                        .frame(width: 1.2, height: 12)
                }
            }
            .rotationEffect(.degrees(90))
            .offset(x: 14, y: 1)

            Circle()
                .fill(Color.white.opacity(0.72))
                .frame(width: 4.5, height: 4.5)
                .offset(x: 6, y: -3)
        }
        .rotationEffect(.degrees(-4))
    }

    private var antenna: Path {
        var path = Path()
        path.move(to: CGPoint(x: 16, y: 8))
        path.addCurve(to: CGPoint(x: 3, y: 2), control1: CGPoint(x: 12, y: 4), control2: CGPoint(x: 8, y: 2))
        path.move(to: CGPoint(x: 16, y: 8))
        path.addCurve(to: CGPoint(x: 5, y: 9), control1: CGPoint(x: 12, y: 9), control2: CGPoint(x: 8, y: 10))
        return path
    }
}

private struct FireflyGreetingText: View {
    let text: String
    @State private var visible = false

    var body: some View {
        Text(text)
            .font(.serif(32))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .foregroundColor(.lullInk0)
            .opacity(visible ? 1 : 0)
            .onAppear {
                visible = false
                withAnimation(.easeIn(duration: 0.65)) {
                    visible = true
                }
            }
            .onChange(of: text) { _, _ in
                visible = false
                withAnimation(.easeIn(duration: 0.65)) {
                    visible = true
                }
            }
    }
}

private struct TodayCardStack: View {
    @EnvironmentObject private var audioStore: SleepSoundsAudioStore
    let tasks: [TodayPreviewTask]
    @Binding var currentIndex: Int
    let folded: Bool
    let reduceMotion: Bool
    let size: CGSize
    let isDone: (TodayPreviewTask) -> Bool
    let externalDonePrepId: UUID?
    let scheduledTime: (RoutineStep) -> String
    let leadLabel: (RoutineStep) -> String
    let onDone: (TodayPreviewTask) -> Void
    let onSkip: (TodayPreviewTask) -> Void
    let onBack: () -> Void
    let onInteract: () -> Void
    let onExternalDonePrepHandled: (UUID) -> Void
    let onOpenSleepSounds: () -> Void
    let onOpenBreathing: (TodayPreviewTask) -> Void
    let onOpenBodyScan: (TodayPreviewTask) -> Void
    @State private var dragOffset: CGSize = .zero
    @State private var exitRotation: Double = 0
    @State private var handlingExternalDonePrepId: UUID? = nil

    var body: some View {
        ZStack {
            ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                let placement = placement(for: index)
                let active = index == currentIndex && !folded
                if placement.shouldRender {
                    TodayTaskContentCard(
                        task: task,
                        index: index,
                        total: tasks.count,
                        done: isDone(task),
                        isActive: active,
                        dragOffset: active ? dragOffset : .zero,
                        scheduledTime: scheduledTime,
                        leadLabel: leadLabel,
                        onDone: { onDone(task) },
                        onSkip: { onSkip(task) },
                        onBack: onBack,
                        onInteract: onInteract,
                        onOpenSleepSounds: onOpenSleepSounds,
                        onOpenBreathing: { onOpenBreathing(task) },
                        onOpenBodyScan: { onOpenBodyScan(task) }
                    )
                    .environmentObject(audioStore)
                    .frame(width: folded ? min(size.width - 44, 330) : min(size.width - 44, 348))
                    .scaleEffect(placement.scale)
                    .brightness(placement.brightness)
                    .rotationEffect(.degrees(placement.rotation + (active ? activeDragRotation + exitRotation : 0)))
                    .offset(
                        CGSize(
                            width: placement.offset.width + (active ? dragOffset.width : 0),
                            height: placement.offset.height + (active ? dragOffset.height : 0)
                        )
                    )
                    .opacity(placement.opacity)
                    .zIndex(placement.zIndex)
                    .allowsHitTesting(index == currentIndex && !folded)
                    .simultaneousGesture(dragGesture(for: task))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .onAppear {
            handleExternalDonePrepIfNeeded(externalDonePrepId)
        }
        .onChange(of: externalDonePrepId) { _, newValue in
            handleExternalDonePrepIfNeeded(newValue)
        }
    }

    private var activeDragRotation: Double {
        Double(dragOffset.width / 22)
    }

    private func dragGesture(for task: TodayPreviewTask) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                onInteract()
                dragOffset = value.translation
            }
            .onEnded { value in
                let translation = value.translation
                let horizontal = abs(translation.width)
                let vertical = abs(translation.height)
                let threshold = TodayDeckConstants.gestureThreshold

                if translation.width > threshold && horizontal > vertical {
                    withAnimation(.easeOut(duration: 0.22)) {
                        dragOffset = CGSize(width: size.width * 1.65, height: max(18, translation.height * 0.25))
                        exitRotation = 10
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                        dragOffset = .zero
                        exitRotation = 0
                        onDone(task)
                    }
                } else if translation.width < -threshold && horizontal > vertical {
                    withAnimation(.spring(response: 0.50, dampingFraction: 0.80)) {
                        dragOffset = .zero
                        exitRotation = 0
                    }
                    onBack()
                } else if translation.height > threshold && vertical > horizontal {
                    withAnimation(.easeOut(duration: 0.22)) {
                        dragOffset = CGSize(width: translation.width * 0.18, height: size.height * 1.50)
                        exitRotation = 4
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                        dragOffset = .zero
                        exitRotation = 0
                        onSkip(task)
                    }
                } else if translation.height < -threshold && vertical > horizontal {
                    withAnimation(.spring(response: 0.50, dampingFraction: 0.80)) {
                        dragOffset = .zero
                        exitRotation = 0
                    }
                    onBack()
                } else {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
                        dragOffset = .zero
                        exitRotation = 0
                    }
                }
            }
    }

    private func handleExternalDonePrepIfNeeded(_ id: UUID?) {
        guard let id else { return }
        guard handlingExternalDonePrepId != id else { return }

        guard let index = tasks.firstIndex(where: { task in
            if case .prep(let step) = task {
                return step.id == id
            }
            return false
        }) else {
            onExternalDonePrepHandled(id)
            return
        }

        let task = tasks[index]
        handlingExternalDonePrepId = id
        if currentIndex != index {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                currentIndex = index
            }
        }

        let focusDelay = currentIndex == index ? 0.05 : 0.28
        DispatchQueue.main.asyncAfter(deadline: .now() + focusDelay) {
            withAnimation(.easeOut(duration: 0.22)) {
                dragOffset = CGSize(width: size.width * 1.65, height: 18)
                exitRotation = 10
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                dragOffset = .zero
                exitRotation = 0
                onDone(task)
                onExternalDonePrepHandled(id)
                handlingExternalDonePrepId = nil
            }
        }
    }

    private func placement(for index: Int) -> TodayCardPlacement {
        if folded {
            let spread = CGFloat(index - currentIndex)
            return TodayCardPlacement(
                offset: reduceMotion
                    ? CGSize(width: 0, height: size.height * 0.48)
                    : CGSize(width: spread * 8, height: size.height * 0.48 + abs(spread) * 3),
                rotation: Double(spread) * 2.0,
                scale: reduceMotion ? 0.18 : 0.22,
                opacity: index == currentIndex ? 0.28 : 0.12,
                brightness: -0.18,
                zIndex: Double(tasks.count - abs(index - currentIndex)),
                shouldRender: abs(index - currentIndex) <= 3
            )
        }

        let relative = currentIndex - index
        let absRelative = abs(relative)
        guard [-2, -1, 0, 1].contains(relative) else {
            return TodayCardPlacement(
                offset: CGSize(width: CGFloat(relative) * 180, height: size.height * 0.36),
                rotation: Double(relative) * 13,
                scale: 0.82,
                opacity: 0,
                brightness: -0.30,
                zIndex: 0,
                shouldRender: false
            )
        }

        let radius = TodayDeckConstants.arcR
        let angle = CGFloat(relative) * TodayDeckConstants.arcStepAngle * .pi / 180
        let x = sin(angle) * radius
        let y = (1 - cos(angle)) * radius

        return TodayCardPlacement(
            offset: CGSize(width: x, height: y),
            rotation: Double(CGFloat(relative) * TodayDeckConstants.arcStepAngle * 0.55),
            scale: relative == 0 ? 1 : 0.90,
            opacity: relative == 0 ? 1 : (absRelative == 1 ? 0.42 : 0),
            brightness: relative == 0 ? 0 : -0.22,
            zIndex: Double(100 - absRelative),
            shouldRender: true
        )
    }
}

private struct TodayCardPlacement {
    let offset: CGSize
    let rotation: Double
    let scale: CGFloat
    let opacity: Double
    let brightness: Double
    let zIndex: Double
    let shouldRender: Bool
}

private struct TodayTaskContentCard: View {
    @EnvironmentObject private var audioStore: SleepSoundsAudioStore
    let task: TodayPreviewTask
    let index: Int
    let total: Int
    let done: Bool
    let isActive: Bool
    let dragOffset: CGSize
    let scheduledTime: (RoutineStep) -> String
    let leadLabel: (RoutineStep) -> String
    let onDone: () -> Void
    let onSkip: () -> Void
    let onBack: () -> Void
    let onInteract: () -> Void
    let onOpenSleepSounds: () -> Void
    let onOpenBreathing: () -> Void
    let onOpenBodyScan: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Kicker(text: eyebrow, color: done ? .lullInk4 : .lullAmberSoft)
                Spacer()
                Text("\(index + 1)/\(total)")
                    .font(.system(size: 11, weight: .semibold, design: .default))
                    .foregroundColor(.lullInk4)
            }

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: titleSubtitleSpacing) {
                    Text(title)
                        .font(.serif(27))
                        .foregroundColor(done ? .lullInk3 : .lullInk0)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)

                    Text(subtitle)
                        .font(.system(size: 13.5))
                        .foregroundColor(.lullInk2)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(done ? .lullBgDeep : .lullAmber)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(done ? Color.lullAmber : Color.lullAmber.opacity(0.12)))
                    .overlay(Circle().strokeBorder(Color.lullAmber.opacity(done ? 0.0 : 0.28), lineWidth: 1))
            }
            .padding(.top, headerTopPadding)

            content
                .padding(.top, contentTopPadding)

            Spacer(minLength: footerMinSpacing)

            swipeCue
        }
        .padding(22)
        .frame(height: 338)
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.lullAmber.opacity(done ? 0.18 : 0.34), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.55), radius: 28, x: 0, y: 18)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title). \(subtitle)")
        .accessibilityHint("Swipe right for Done, swipe down to Skip, or swipe left or up to go Back.")
        .accessibilityAction(named: "Done", onDone)
        .accessibilityAction(named: "Skip", onSkip)
        .accessibilityAction(named: "Back", onBack)
    }

    @ViewBuilder
    private var swipeCue: some View {
        if isActive {
            HStack(spacing: 8) {
                Image(systemName: cueIcon)
                    .font(.system(size: 12, weight: .bold))
                Text(cueText)
                    .font(.system(size: 11.5, weight: .semibold, design: .default))
            }
            .foregroundColor(cueColor)
            .frame(maxWidth: .infinity, alignment: .center)
            .opacity(cueOpacity)
            .padding(.top, 4)
            .animation(.easeOut(duration: 0.12), value: cueOpacity)
        }
    }

    private var cueText: String {
        if dragOffset.width > 18 { return "DONE" }
        if dragOffset.width < -18 { return "BACK / UNDO" }
        if dragOffset.height > 18 { return "SKIP" }
        if dragOffset.height < -18 { return "BACK / UNDO" }
        return "SWIPE"
    }

    private var cueIcon: String {
        if dragOffset.width > 18 { return "checkmark" }
        if dragOffset.width < -18 { return "arrow.uturn.left" }
        if dragOffset.height > 18 { return "arrow.down" }
        if dragOffset.height < -18 { return "arrow.uturn.left" }
        return "hand.draw"
    }

    private var cueColor: Color {
        if dragOffset.width > 18 { return .lullAmber }
        return .lullInk4
    }

    private var cueOpacity: Double {
        let distance = max(abs(dragOffset.width), abs(dragOffset.height))
        return min(1, max(0.18, Double(distance / 92)))
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(hex: "#2a2118").opacity(0.40),
                        Color(hex: "#15100c").opacity(0.40)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(alignment: .topLeading) {
                RadialGradient(
                    colors: [Color.lullAmber.opacity(done ? 0.08 : 0.17), .clear],
                    center: .topLeading,
                    startRadius: 8,
                    endRadius: 210
                )
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            }
    }

    private var eyebrow: String {
        switch task {
        case .prep(let step):
            return scheduledTime(step).isEmpty ? "Prep" : "\(scheduledTime(step)) - Prep"
        case .ritual(let step):
            return scheduledTime(step).isEmpty ? "Ritual" : "\(scheduledTime(step)) - Ritual"
        }
    }

    private var title: String { task.label }

    private var usesCompactContentSpacing: Bool {
        switch task {
        case .ritual(let step):
            return step.isScreenBlockingConfigurationStep || step.label == R.appBlocking
        default:
            return false
        }
    }

    private var titleSubtitleSpacing: CGFloat { usesCompactContentSpacing ? 4 : 8 }
    private var headerTopPadding: CGFloat { usesCompactContentSpacing ? 12 : 18 }
    private var contentTopPadding: CGFloat { usesCompactContentSpacing ? 12 : 20 }
    private var footerMinSpacing: CGFloat { usesCompactContentSpacing ? 8 : 16 }

    private var subtitle: String {
        switch task {
        case .prep(let step):
            let lead = leadLabel(step)
            return lead.isEmpty ? "A gentle setup task before the in-bed sequence." : lead
        case .ritual(let step):
            return step.durationLabel ?? "\(NightlyStepKind.forLabel(step.label)?.estimatedMinutes ?? 5) min"
        }
    }

    private var icon: String {
        switch task {
        case .prep(let step), .ritual(let step):
            return iconName(for: step.label)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch task {
        case .prep(let step):
            PrepCardContent(step: step, leadLabel: leadLabel(step))
        case .ritual(let step) where step.label == R.brainDump:
            BrainDumpCardContent(isActive: isActive, onInteract: onInteract)
        case .ritual(let step) where step.label == R.sleepSounds:
            SleepSoundCardContent(step: step, isActive: isActive, onInteract: onInteract, onOpen: onOpenSleepSounds)
                .environmentObject(audioStore)
        case .ritual(let step) where step.label == R.boringStory:
            BoringStoryCardContent(step: step, isActive: isActive, onInteract: onInteract, onFinish: onDone)
        case .ritual(let step) where isBreathing478Label(step.label):
            Breathing478CardContent(onInteract: onInteract, onOpen: onOpenBreathing)
        case .ritual(let step) where step.label == R.bodyScan:
            BodyScanCardContent(onInteract: onInteract, onOpen: onOpenBodyScan)
        case .ritual(let step) where step.isScreenBlockingConfigurationStep || step.label == R.appBlocking:
            AppBlockingCardContent()
        case .ritual(let step) where step.label == "Brightness check":
            BrightnessCheckCardContent(isActive: isActive, onInteract: onInteract)
        case .ritual(let step) where step.label == "Temperature check":
            TemperatureCheckCardContent(onInteract: onInteract)
        case .ritual(let step):
            RitualCardContent(step: step)
        }
    }

    private func iconName(for label: String) -> String {
        switch label {
        case R.sleepSounds: return "water.waves"
        case R.brainDump: return "mic.fill"
        case R.boringStory: return "book.closed.fill"
        case let label where isBreathing478Label(label): return "wind"
        case R.gratitudeJournal: return "text.book.closed.fill"
        case R.gentleStretching: return "figure.flexibility"
        case R.pmr: return "figure.mind.and.body"
        case R.bodyScan: return "sparkles"
        case "Brightness check": return "sun.max.fill"
        case "Temperature check": return "thermometer.medium"
        case R.noScreens: return "iphone.slash"
        case R.dimTheLights: return "lightbulb.fill"
        case R.warmShower: return "shower.fill"
        case R.weightedBlanket: return "bed.double.fill"
        case R.herbalTea: return "mug.fill"
        case R.magnesium: return "pills.fill"
        case R.coldRoomPrep: return "thermometer.snowflake"
        case R.blackoutCurtains: return "curtains.closed"
        default: return "checklist"
        }
    }

    private func isBreathing478Label(_ label: String) -> Bool {
        let normalized = label
            .lowercased()
            .replacingOccurrences(of: "·", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
        return normalized.contains("478breathing")
    }
}

private struct PrepCardContent: View {
    let step: RoutineStep
    let leadLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "bell.badge")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.lullAmber)
                Text("Reminder card")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.lullInk1)
                Spacer()
            }

            Text(prepCopy)
                .font(.system(size: 13))
                .foregroundColor(.lullInk2)
                .lineSpacing(3)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.lullLine, lineWidth: 1))
    }

    private var prepCopy: String {
        switch step.label {
        case R.noScreens:
            return "Move the phone out of reach and let the screen go quiet."
        case R.dimTheLights:
            return "Lower lamps and screens so your body gets the night signal."
        case R.warmShower:
            return "The cooling-off afterward is the part that helps sleep arrive."
        case R.weightedBlanket:
            return "Set it out before bed so the in-bed sequence stays frictionless."
        default:
            return leadLabel.isEmpty ? "This item gets the room and body ready for the ritual." : "Scheduled \(leadLabel.lowercased())."
        }
    }
}

private struct BrainDumpCardContent: View {
    @EnvironmentObject private var state: AppState
    @StateObject private var recorder = AudioRecordingService()
    @State private var statusText = "Tap the wave to start a voice note."
    @State private var saved = false
    let isActive: Bool
    let onInteract: () -> Void

    private var isRecording: Bool {
        recorder.recordingState == .recording
    }

    private var durationText: String {
        recorder.duration.lullTimeString
    }

    var body: some View {
        Button {
            onInteract()
            toggleRecording()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    BrainDumpWaveform(
                        isRecording: isRecording,
                        averagePower: recorder.averagePower
                    )
                    .frame(height: 42)
                    .layoutPriority(1)

                    VStack(alignment: .trailing, spacing: 3) {
                        Image(systemName: saved ? "checkmark.circle.fill" : (isRecording ? "stop.fill" : "mic.fill"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(saved ? .lullAmber : .lullBgDeep)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.lullAmber))
                            .shadow(color: isRecording ? .lullAmberGlow : .clear, radius: 10)
                        recordLabel
                    }
                }

                Text(statusText)
                    .font(.system(size: 13))
                    .foregroundColor(.lullInk2)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(borderColor, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Double tap to start or stop recording a brain dump.")
        .task {
            await recorder.checkPermission()
            updateInitialStatus()
        }
        .onChange(of: isActive) { _, active in
            guard !active, isRecording else { return }
            saveRecording()
        }
        .onDisappear {
            guard isRecording else { return }
            saveRecording()
        }
    }

    private var recordLabel: some View {
        ViewThatFits(in: .horizontal) {
            Text(isRecording ? durationText : (saved ? "Saved" : "Record"))
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundColor(.lullInk3)
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            EmptyView()
        }
        .frame(width: 46, alignment: .center)
    }

    private var borderColor: Color {
        if isRecording { return .lullAmber.opacity(0.56) }
        if saved { return .lullAmber.opacity(0.40) }
        return .lullLine
    }

    private var accessibilityLabel: String {
        if isRecording { return "Brain dump recording, \(durationText)" }
        if saved { return "Brain dump voice note saved" }
        return "Brain dump voice note recorder"
    }

    private func updateInitialStatus() {
        if recorder.permission == .denied {
            statusText = "Microphone access is off. Enable it in Settings to record this note."
        } else {
            statusText = "Voice-note whatever is still spinning. Tap to start, tap again to save."
        }
    }

    private func toggleRecording() {
        guard !saved else {
            statusText = "Voice note saved. Swipe right when you're ready to mark this done."
            return
        }

        if isRecording {
            saveRecording()
            return
        }

        Task {
            if recorder.permission != .granted {
                await recorder.checkPermission()
            }

            guard recorder.permission == .granted else {
                statusText = "Microphone access is off. Enable it in Settings to record this note."
                return
            }

            if recorder.start() {
                state.brainDumpRecording = true
                statusText = "Recording. Say the loop out loud, then tap again to save it."
            } else {
                state.brainDumpRecording = false
                statusText = "Recording could not start. Check microphone access and try again."
            }
        }
    }

    private func saveRecording() {
        let finalDuration = max(1, Int(ceil(recorder.duration)))
        let savedURL = recorder.stopAndSave(date: Date())
        let relativePath = savedURL.map(Self.relativeDocumentsPath)

        state.brainDumpRecording = false

        guard let relativePath else {
            state.brainDumpSeconds = 0
            saved = false
            statusText = "No audio was saved. Tap to try again."
            return
        }

        state.brainDumpSeconds = finalDuration
        state.updateTodayLog {
            $0.brainDumpDurationSec = finalDuration
            $0.brainDumpFilePath = relativePath
        }
        state.recordBrainDumpSession(durationSeconds: finalDuration, hasRecording: true)

        saved = true
        statusText = "Saved. Swipe right when you're ready to mark this done."
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private static func relativeDocumentsPath(for url: URL) -> String {
        let docsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path
        guard url.path.hasPrefix(docsPath + "/") else { return url.lastPathComponent }
        return String(url.path.dropFirst(docsPath.count + 1))
    }
}

private struct BrainDumpWaveform: View {
    let isRecording: Bool
    let averagePower: Float

    private let baseHeights: [CGFloat] = [12, 20, 28, 16, 24, 34, 18, 30]

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 5) {
                ForEach(0..<24, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor(index: index))
                        .frame(width: 3, height: barHeight(index: index, time: time))
                        .animation(.easeInOut(duration: 0.12), value: averagePower)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(isRecording ? 1 : 0.82)
    }

    private func barColor(index: Int) -> Color {
        if isRecording {
            return index % 3 == 0 ? .lullAmber : Color.lullAmber.opacity(0.72)
        }
        return index % 4 == 0 ? Color.lullAmber : Color.lullInk3.opacity(0.55)
    }

    private func barHeight(index: Int, time: TimeInterval) -> CGFloat {
        let base = baseHeights[index % baseHeights.count]
        guard isRecording else { return base }
        let normalizedPower = max(0, min(1, (CGFloat(averagePower) + 55) / 45))
        let wave = CGFloat(sin(time * 8 + Double(index) * 0.72))
        let shimmer = (wave + 1) * 0.5
        return max(8, base * (0.72 + normalizedPower * 0.78 + shimmer * 0.34))
    }
}

private struct BrightnessCheckCardContent: View {
    @EnvironmentObject private var state: AppState
    @StateObject private var lightService = AmbientLightService()
    @State private var selectedLevel: Int? = nil
    @State private var autoDetectedLevel: Int? = nil
    @State private var detectedSource: LightsLevelSource = .selfReported
    @State private var didReadLight = false
    let isActive: Bool
    let onInteract: () -> Void

    private let levels: [(label: String, hint: String, icon: String)] = [
        ("Bright", "full overhead lights", "sun.max"),
        ("Half-dim", "some lamps off", "sun.min"),
        ("Warm dim", "just warm bulbs", "moon"),
        ("Mostly dark", "nearly lights-out", "moon.fill")
    ]

    private var brightnessSuggestion: String? {
        guard let selectedLevel, selectedLevel <= 1 else { return nil }
        return selectedLevel == 0
            ? "Turn off overhead lights or dim lamps now."
            : "Dim the remaining lamps if you can."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Kicker(text: lightService.isReading ? "Detecting..." : (lightService.confidence == .high ? "Auto-detected" : "Quick check"))
                    Text(prompt)
                        .font(.system(size: 13))
                        .foregroundColor(.lullInk2)
                        .lineSpacing(2)
                }
                Spacer(minLength: 0)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(Array(levels.enumerated()), id: \.offset) { i, level in
                    brightnessOption(index: i, level: level)
                }
            }

            if let brightnessSuggestion {
                TodayDeckSuggestionCard(
                    icon: "lightbulb.min",
                    title: "Lower the light",
                    message: brightnessSuggestion
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.lullLine, lineWidth: 1))
        .task(id: isActive) {
            guard isActive, !didReadLight else { return }
            didReadLight = true
            let result = await lightService.read()
            if result.confidence == .high {
                selectedLevel = result.lightsLevel
                autoDetectedLevel = result.lightsLevel
                detectedSource = .sensor
                save(level: result.lightsLevel, source: .sensor)
            }
        }
    }

    private var prompt: String {
        if lightService.isReading { return "Reading the room..." }
        if lightService.confidence == .high, let selectedLevel {
            return "We detected: \(levels[selectedLevel].label)"
        }
        return "How bright is it in here?"
    }

    private func brightnessOption(index: Int, level: (label: String, hint: String, icon: String)) -> some View {
        Button {
            onInteract()
            let source: LightsLevelSource = (lightService.confidence == .high && autoDetectedLevel == index) ? .sensor : .selfReported
            selectedLevel = index
            detectedSource = source
            save(level: index, source: source)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: level.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(selectedLevel == index ? .lullAmber : .lullInk3)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text(level.label)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(selectedLevel == index ? .lullInk0 : .lullInk1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    Text(level.hint)
                        .font(.system(size: 10.5))
                        .foregroundColor(.lullInk3)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                Spacer(minLength: 0)
                if selectedLevel == index { Ember(size: 5) }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(selectedLevel == index ? Color.lullAmber.opacity(0.10) : Color.white.opacity(0.025))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(selectedLevel == index ? Color.lullAmber.opacity(0.5) : Color.lullLine, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func save(level: Int, source: LightsLevelSource) {
        state.updateTodayLog {
            $0.lightsLevel = level
            $0.lightsLevelSource = source
        }
    }
}

private struct TemperatureCheckCardContent: View {
    @EnvironmentObject private var state: AppState
    let onInteract: () -> Void

    private let options: [(label: String, colorHex: String)] = [
        ("Cool", "#7ba2c7"),
        ("Just right", "#f0b96b"),
        ("Warm", "#d99a4a"),
        ("Hot", "#c66f4a")
    ]

    private var temperatureSuggestion: (icon: String, title: String, message: String)? {
        switch state.selectedTemp {
        case 0:
            return ("thermometer.low", "Add a little warmth", "Use thicker blankets, another layer, or slightly turn up the heat.")
        case 3:
            return ("fan", "Cool the room down", "Try a fan or AC, or switch to lighter clothing.")
        default:
            return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Kicker(text: "Quick log")
                Text("How does the room feel?")
                    .font(.system(size: 13))
                    .foregroundColor(.lullInk2)
                    .lineSpacing(2)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(Array(options.enumerated()), id: \.offset) { i, option in
                    temperatureOption(index: i, option: option)
                }
            }

            if let suggestion = temperatureSuggestion {
                TodayDeckSuggestionCard(
                    icon: suggestion.icon,
                    title: suggestion.title,
                    message: suggestion.message
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.lullLine, lineWidth: 1))
        .onAppear {
            state.updateTodayLog { $0.perceivedTemp = state.selectedTemp }
        }
    }

    private func temperatureOption(index: Int, option: (label: String, colorHex: String)) -> some View {
        Button {
            onInteract()
            state.selectedTemp = index
            state.updateTodayLog { $0.perceivedTemp = index }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(RadialGradient(
                        colors: [Color(hex: option.colorHex), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 14
                    ))
                    .frame(width: 24, height: 24)
                    .opacity(0.9)
                Text(option.label)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(state.selectedTemp == index ? .lullInk0 : .lullInk1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Spacer(minLength: 0)
                if state.selectedTemp == index { Ember(size: 5) }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(state.selectedTemp == index ? Color.lullAmber.opacity(0.10) : Color.white.opacity(0.025))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(state.selectedTemp == index ? Color.lullAmber.opacity(0.5) : Color.lullLine, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct TodayDeckSuggestionCard: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(.lullAmber)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.lullAmber.opacity(0.12)))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(.lullInk0)
                Text(message)
                    .font(.system(size: 11.5))
                    .foregroundColor(.lullInk2)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.white.opacity(0.035))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(Color.lullAmber.opacity(0.20), lineWidth: 1)
                )
        )
    }
}

private struct AppBlockingCardContent: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var appBlockingAccess = AppBlockingAccessProbe.shared
    @State private var selection = FamilyActivitySelection()
    @State private var enabled = true
    @State private var startTime = Date()
    @State private var endTime = Date()
    @State private var graceMinutes = 5
    @State private var showPicker = false
    @State private var didHydrate = false

    private var appCount: Int { selection.applicationTokens.count }
    private var categoryCount: Int { selection.categoryTokens.count }
    private var totalCount: Int { appCount + categoryCount }
    private var hasConfiguration: Bool { enabled && totalCount > 0 }

    private var wakeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: endTime)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: hasConfiguration ? 10 : 8) {
            if hasConfiguration {
                configuredContent
            } else {
                setupContent
            }
        }
        .padding(hasConfiguration ? 14 : 12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.lullLine, lineWidth: 1))
        .familyActivityPicker(isPresented: $showPicker, selection: $selection)
        .onAppear(perform: hydrate)
        .onChange(of: showPicker) { _, isPresented in
            guard !isPresented else { return }
            save()
        }
        .onChange(of: enabled) { _, _ in save() }
    }

    private var configuredContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.lullAmber)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.lullAmber.opacity(0.12)))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Scroll-lock is ready")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(.lullInk1)
                    Text(contractStatusText)
                        .font(.system(size: 12))
                        .foregroundColor(.lullInk3)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }

            if let item = state.currentSleepRulePromptItem {
                sleepRuleConfirmRow(item)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(selection.applicationTokens), id: \.self) { token in
                        AppBlockingTokenBadge(token: token)
                    }

                    if selection.applicationTokens.isEmpty {
                        ForEach(Array(selection.categoryTokens), id: \.self) { token in
                            AppBlockingCategoryBadge(token: token)
                        }
                    }

                    Button {
                        openBlockedAppsPicker()
                    } label: {
                        AppBlockingEditBadge()
                    }
                    .buttonStyle(.plain)
                    .disabled(isEditingLocked)
                }
                .padding(.vertical, 1)
            }
        }
    }

    private func sleepRuleConfirmRow(_ item: SleepContractItem) -> some View {
        let canComplete = state.canCompleteSleepRule(item)
        return HStack(spacing: 10) {
            Image(systemName: canComplete ? "hand.tap.fill" : "clock")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.lullAmber)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.lullAmber.opacity(0.12)))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.rule.completionPrompt)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(.lullInk1)
                Text(canComplete ? "Hold to confirm. Late rules cool down for 10 minutes." : "Available at the rule time.")
                    .font(.system(size: 11.5))
                    .foregroundColor(.lullInk3)
            }

            Spacer(minLength: 0)
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.lullAmber.opacity(canComplete ? 0.07 : 0.035))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(Color.lullAmber.opacity(canComplete ? 0.24 : 0.12), lineWidth: 1)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .onLongPressGesture(minimumDuration: 0.7) {
            guard canComplete else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            state.completeSleepRule(item)
        }
        .opacity(canComplete ? 1 : 0.72)
    }

    private var setupContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.lullAmber)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.lullAmber.opacity(0.12)))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Choose apps to lock tonight")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(.lullInk1)
                    Text("TenThirty will protect your sleep window and your rule timing.")
                        .font(.system(size: 12))
                        .foregroundColor(.lullInk3)
                        .lineLimit(2)
                }
            }

            Button {
                openBlockedAppsPicker()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                    Text(totalCount == 0 ? "Select apps" : "Edit blocked apps")
                        .font(.system(size: 13.5, weight: .semibold))
                    Spacer(minLength: 0)
                    if totalCount > 0 {
                        Text("\(totalCount)")
                            .font(.mono(10))
                    }
                }
                .foregroundColor(.lullBgDeep)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .padding(.horizontal, 14)
                .background(Capsule().fill(Color.lullAmber))
            }
            .buttonStyle(.plain)
            .disabled(isEditingLocked)
            .opacity(isEditingLocked ? 0.55 : 1)

            HStack(spacing: 10) {
                AppBlockingMiniTile(title: "LOCK", value: timeText(state.canUseHardAppBlocking ? startTime : state.typicalBedtime))
                AppBlockingMiniTile(title: "UNLOCK", value: wakeText)
            }

            HStack {
                Text("ENABLE")
                    .font(.mono(10))
                    .kerning(1.5)
                    .foregroundColor(.lullInk3)
                Spacer()
                Toggle("", isOn: $enabled)
                    .labelsHidden()
                    .tint(.lullAmber)
            }
        }
    }

    private func hydrate() {
        selection = state.appBlockingSelection
        appBlockingAccess.refresh()
        enabled = state.appBlockingEnabled || (!state.appBlockingSelection.applicationTokens.isEmpty || !state.appBlockingSelection.categoryTokens.isEmpty)
        startTime = state.appBlockingStartTime
        endTime = state.appBlockingEndTime
        graceMinutes = state.appBlockingGraceMinutes
        if !didHydrate, endTime.timeIntervalSinceReferenceDate == 0 {
            endTime = state.typicalWakeTime
        }
        didHydrate = true
    }

    private var contractStatusText: String {
        guard let next = state.nextSleepContractItem else {
            return "Sleep-window lock runs until your \(wakeText) wake time."
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "Next rule: \(next.rule.title) by \(formatter.string(from: next.dueAt))."
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

    private var isEditingLocked: Bool {
        state.isContractEditingLocked()
    }

    private func save() {
        guard didHydrate else { return }
        state.configureAppBlocking(
            selection: selection,
            enabled: enabled,
            startTime: state.canUseHardAppBlocking ? startTime : state.typicalBedtime,
            endTime: endTime,
            graceMinutes: graceMinutes
        )
    }

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

private struct AppBlockingTokenBadge: View {
    let token: ApplicationToken

    var body: some View {
        VStack(spacing: 5) {
            Label(token)
                .labelStyle(.iconOnly)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.lullAmber.opacity(0.10))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.lullAmber.opacity(0.22), lineWidth: 1))
                )
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "lock.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.lullAmber)
                        .offset(x: 5, y: -5)
                }

            Label(token)
                .labelStyle(.titleOnly)
                .font(.system(size: 10.5))
                .foregroundColor(.lullInk3)
                .lineLimit(1)
                .frame(width: 54)
        }
    }
}

private struct AppBlockingCategoryBadge: View {
    let token: ActivityCategoryToken

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.lullAmber)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.lullAmber.opacity(0.10))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.lullAmber.opacity(0.22), lineWidth: 1))
                )
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "lock.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.lullAmber)
                        .offset(x: 5, y: -5)
                }

            Text("Category")
                .font(.system(size: 10.5))
                .foregroundColor(.lullInk3)
                .lineLimit(1)
                .frame(width: 54)
        }
    }
}

private struct AppBlockingEditBadge: View {
    var body: some View {
        VStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundColor(Color.lullAmber.opacity(0.45))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.lullAmber)
                )
            Text("Edit")
                .font(.system(size: 10.5))
                .foregroundColor(.lullAmberSoft)
                .frame(width: 54)
        }
    }
}

private struct AppBlockingMiniTile: View {
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.mono(9))
                .kerning(1.2)
                .foregroundColor(.lullInk4)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.lullInk1)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.035))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.lullLine, lineWidth: 1))
        )
    }
}

private struct RitualCardContent: View {
    let step: RoutineStep

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if step.label == R.boringStory {
                mediaRow(title: "Sleep story", subtitle: step.boringStoryConfig?.title ?? "quiet narration")
            } else if step.label == R.breathing478 {
                breathingRow
            } else {
                Text(ritualCopy)
                    .font(.system(size: 13))
                    .foregroundColor(.lullInk2)
                    .lineSpacing(3)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.lullLine, lineWidth: 1))
    }

    private var breathingRow: some View {
        HStack(spacing: 12) {
            ForEach(["4", "7", "8"], id: \.self) { number in
                Text(number)
                    .font(.serif(24))
                    .foregroundColor(.lullAmber)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(Color.lullAmber.opacity(0.10)))
                    .overlay(Circle().strokeBorder(Color.lullAmber.opacity(0.22), lineWidth: 1))
            }
            Spacer()
        }
    }

    private func mediaRow(title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "play.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.lullBgDeep)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color.lullAmber))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(.lullInk1)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.lullInk3)
                    .lineLimit(1)
            }
            Spacer()
        }
    }

    private var ritualCopy: String {
        switch step.label {
        case "Brightness check":
            return "Check the room and phone brightness, then lower anything still sending a daytime signal."
        case "Temperature check":
            return "Log whether the room feels cool, just right, warm, or hot before you settle in."
        case R.weightedBlanket:
            return "Get under it and let the pressure do some of the settling for you."
        case R.bodyScan:
            return "Move attention slowly through the body, one small region at a time."
        case R.gentleStretching:
            return "A low-effort reset for the places that stay braced at night."
        case R.gratitudeJournal:
            return "Three small things from today. Specific beats impressive."
        default:
            return step.notes ?? "This is part of the guided in-bed sequence."
        }
    }
}

private struct Breathing478CardContent: View {
    let onInteract: () -> Void
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                onInteract()
                onOpen()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.lullAmber.opacity(0.14))
                            .frame(width: 46, height: 46)
                        Image(systemName: "play.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.lullBgDeep)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.lullAmber))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Guided breathing")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.lullInk1)
                        Text("Audio · 5 min · pause/play + speed")
                            .font(.system(size: 12))
                            .foregroundColor(.lullInk3)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.lullInk3)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Play guided 4 7 8 breathing")

            Text("Follow the guided inhale, hold, and exhale counts without watching the clock.")
                .font(.system(size: 13))
                .foregroundColor(.lullInk2)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.lullLine, lineWidth: 1))
    }
}

private struct BodyScanCardContent: View {
    let onInteract: () -> Void
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                onInteract()
                onOpen()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.lullAmber.opacity(0.14))
                            .frame(width: 46, height: 46)
                        Image(systemName: "play.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.lullBgDeep)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.lullAmber))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Guided body scan")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.lullInk1)
                        Text("Audio · 5 min · opens player")
                            .font(.system(size: 12))
                            .foregroundColor(.lullInk3)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.lullInk3)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Play guided body scan")

            Text("Move attention slowly through the body, one small region at a time.")
                .font(.system(size: 13))
                .foregroundColor(.lullInk2)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.lullLine, lineWidth: 1))
    }
}

private struct BoringStoryCardContent: View {
    @EnvironmentObject private var state: AppState
    @StateObject private var playback = AudioPlaybackService()
    let step: RoutineStep
    let isActive: Bool
    let onInteract: () -> Void
    let onFinish: () -> Void
    @State private var didScheduleAutoplay = false
    @State private var hasLoadedStory = false
    @State private var hasFinishedStory = false
    @State private var activeStoryId: String?
    @State private var startPlaybackTask: Task<Void, Never>?

    private var config: BoringStoryStepConfig {
        step.boringStoryConfig ?? .fresh
    }

    private var story: BoringStoryId {
        config.storyId
    }

    private var elapsedSeconds: Int {
        Int(playback.elapsed.rounded(.down))
    }

    private var durationSeconds: Int {
        playback.duration > 0 ? Int(playback.duration.rounded(.up)) : story.durationSeconds
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.lullAmber.opacity(0.14))
                        .frame(width: 44, height: 44)
                    Circle()
                        .fill(Color.lullAmber)
                        .frame(width: 9, height: 9)
                        .shadow(color: .lullAmberGlow, radius: playback.isPlaying ? 14 : 6)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(story.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.lullInk1)
                        .lineLimit(1)
                    Text("quiet narration")
                        .font(.system(size: 12))
                        .foregroundColor(.lullInk3)
                }

                Spacer()

                Text("\(timeString(elapsedSeconds)) / \(timeString(durationSeconds))")
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundColor(.lullInk3)
                    .monospacedDigit()
            }

            GeometryReader { geo in
                let pct = min(1, CGFloat(elapsedSeconds) / CGFloat(max(1, durationSeconds)))
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(Color.lullAmber.opacity(0.72))
                        .frame(width: geo.size.width * pct)
                }
            }
            .frame(height: 3)
            .animation(.linear(duration: 0.25), value: elapsedSeconds)

            HStack(spacing: 10) {
                storyControl(icon: playback.isPlaying ? "pause.fill" : "play.fill", size: 13) {
                    onInteract()
                    cancelPendingAutoplay()
                    didScheduleAutoplay = true
                    if playback.isPlaying {
                        playback.pause()
                    } else if hasLoadedStory {
                        playback.play()
                    } else {
                        startStory()
                    }
                }
                .accessibilityLabel(playback.isPlaying ? "Pause story" : "Play story")

                Spacer(minLength: 8)

                storyControl(icon: "minus", size: 13, disabled: !playback.canSlowDown) {
                    onInteract()
                    playback.speedDown()
                }
                .accessibilityLabel("Slow story down")

                Text(rateText(playback.playbackRate))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.lullInk3)
                    .frame(width: 38)

                storyControl(icon: "plus", size: 13, disabled: !playback.canSpeedUp) {
                    onInteract()
                    playback.speedUp()
                }
                .accessibilityLabel("Speed story up")
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.lullLine, lineWidth: 1))
        .onAppear {
            handleActiveChange()
        }
        .onChange(of: isActive) { _, _ in
            handleActiveChange()
        }
        .onDisappear {
            cleanupStory()
        }
    }

    private func storyControl(icon: String, size: CGFloat, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .semibold))
                .foregroundColor(disabled ? .lullInk4 : .lullInk2)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color.white.opacity(0.035)))
                .overlay(Circle().strokeBorder(Color.lullLine, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
    }

    private func handleActiveChange() {
        guard isActive else {
            cleanupStory(resetAutoplay: true)
            return
        }

        guard !didScheduleAutoplay else { return }
        didScheduleAutoplay = true
        startPlaybackTask?.cancel()
        startPlaybackTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard isActive, !hasLoadedStory else { return }
                startStory()
            }
        }
    }

    private func startStory() {
        guard let asset = BoringStoryAudioLibrary.asset(for: config) else { return }
        activeStoryId = asset.story.rawValue
        hasFinishedStory = false
        hasLoadedStory = true
        playback.load(url: asset.url)
        playback.onFinish = finishStory
        playback.play()
    }

    private func cleanupStory(resetAutoplay: Bool = false) {
        cancelPendingAutoplay()
        playback.onFinish = nil
        playback.stop()
        hasLoadedStory = false
        hasFinishedStory = false
        activeStoryId = nil
        if resetAutoplay {
            didScheduleAutoplay = false
        }
    }

    private func cancelPendingAutoplay() {
        startPlaybackTask?.cancel()
        startPlaybackTask = nil
    }

    private func finishStory() {
        guard !hasFinishedStory else { return }
        hasFinishedStory = true
        state.recordBoringStoryMediaSession(
            contentId: activeStoryId,
            listenedSeconds: elapsedSeconds,
            totalDurationSeconds: durationSeconds,
            completed: true
        )
        onFinish()
    }

    private func timeString(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func rateText(_ rate: Float) -> String {
        switch rate {
        case 0.75: return ".75x"
        case 0.9: return ".9x"
        case 1.0: return "1x"
        case 1.5: return "1.5x"
        default: return "\(rate)x"
        }
    }
}

private struct SleepSoundCardContent: View {
    @EnvironmentObject private var audioStore: SleepSoundsAudioStore
    let step: RoutineStep
    let isActive: Bool
    let onInteract: () -> Void
    let onOpen: () -> Void
    @State private var didScheduleAutoplay = false
    @State private var startPlaybackTask: Task<Void, Never>?
    @State private var overrideConfig: SleepSoundStepConfig?
    @State private var activePanel: TodaySleepSoundPanel?

    private var config: SleepSoundStepConfig {
        var next = overrideConfig ?? step.sleepSoundConfig ?? .fresh
        if next.soundId == nil { next.soundId = .heavyRain }
        if !next.infinite && next.durationMinutes == nil { next.durationMinutes = 60 }
        return next
    }

    private var sound: SoundId {
        config.soundId ?? .heavyRain
    }

    private var playingThisSound: Bool {
        audioStore.currentConfig?.soundId == sound && audioStore.isPlaying
    }

    private var isPausedThisSound: Bool {
        audioStore.currentConfig?.soundId == sound && !audioStore.isPlaying
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 13) {
                ZStack {
                    Circle()
                        .fill(soundColor.opacity(0.18))
                        .frame(width: 58, height: 58)
                    Image(systemName: sound.symbol)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(soundColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(sound.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.lullInk0)
                    Text(timerLabel)
                        .font(.system(size: 12.5))
                        .foregroundColor(.lullInk3)
                }

                Spacer()

                Button {
                    onInteract()
                    startPlaybackTask?.cancel()
                    startPlaybackTask = nil
                    didScheduleAutoplay = true
                    if playingThisSound {
                        audioStore.pause()
                    } else if audioStore.currentConfig?.soundId == sound {
                        audioStore.resume()
                    } else {
                        audioStore.play(config: config)
                    }
                } label: {
                    Image(systemName: playingThisSound ? "pause.fill" : "play.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.lullBgDeep)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(Color.lullAmber))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(playingThisSound ? "Pause sleep sound" : "Play sleep sound")
            }

            HStack(alignment: .center, spacing: 10) {
                HStack(spacing: 7) {
                    ForEach(0..<22, id: \.self) { index in
                        Capsule()
                            .fill(index % 5 == 0 ? soundColor : Color.lullInk4.opacity(0.55))
                            .frame(width: 3, height: CGFloat([10, 16, 26, 14, 21, 32, 18][index % 7]))
                    }
                }
                .frame(height: 36)
                .frame(maxWidth: .infinity, alignment: .leading)

                sleepSoundControl(icon: "music.note.list", label: "Switch") {
                    onInteract()
                    activePanel = .switchSound
                }

                sleepSoundControl(icon: "timer", label: "Timer") {
                    onInteract()
                    activePanel = .timer
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.lullLine, lineWidth: 1))
        .onAppear {
            scheduleAutoplayIfNeeded()
        }
        .onChange(of: isActive) { _, _ in
            scheduleAutoplayIfNeeded()
        }
        .onDisappear {
            startPlaybackTask?.cancel()
            startPlaybackTask = nil
        }
        .sheet(item: $activePanel) { panel in
            switch panel {
            case .switchSound:
                NightlySoundSwitchSheet(current: sound) { newSound in
                    startPlaybackTask?.cancel()
                    startPlaybackTask = nil
                    var updated = config
                    updated.soundId = newSound
                    overrideConfig = audioStore.switchSound(to: newSound, fallbackConfig: updated)
                    activePanel = nil
                }
            case .timer:
                NightlySoundTimerSheet(config: config) { updated in
                    overrideConfig = updated
                    activePanel = nil
                    restartSleepSound(with: updated, delay: 250_000_000)
                }
            }
        }
    }

    private var timerLabel: String {
        if isPausedThisSound { return "paused" }
        if config.infinite { return "Until I wake" }
        guard let seconds = audioStore.remainingSeconds, audioStore.currentConfig?.soundId == sound else {
            return SleepSoundStepConfig.durationText(minutes: config.durationMinutes ?? 60)
        }
        if seconds >= 3600 {
            return String(format: "%d:%02d:%02d left", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
        }
        return String(format: "%02d:%02d left", seconds / 60, seconds % 60)
    }

    private func sleepSoundControl(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.lullInk2)
                    .frame(width: 34, height: 30)
                    .background(Capsule().fill(Color.white.opacity(0.035)))
                    .overlay(Capsule().strokeBorder(Color.lullLine, lineWidth: 1))
                Text(label)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(.lullInk3)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func scheduleAutoplayIfNeeded() {
        guard isActive else {
            if audioStore.currentConfig?.soundId != sound {
                didScheduleAutoplay = false
            }
            startPlaybackTask?.cancel()
            startPlaybackTask = nil
            return
        }
        guard isActive, !didScheduleAutoplay else { return }
        didScheduleAutoplay = true
        startPlaybackTask?.cancel()
        audioStore.play(config: config)
    }

    private func applyConfigUpdate(_ update: (inout SleepSoundStepConfig) -> Void) {
        var updated = config
        update(&updated)
        overrideConfig = updated
        activePanel = nil
        restartSleepSound(with: updated, delay: 350_000_000)
    }

    private func restartSleepSound(with updated: SleepSoundStepConfig, delay: UInt64) {
        startPlaybackTask?.cancel()
        startPlaybackTask = Task {
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                audioStore.play(config: updated)
            }
        }
    }

    private var soundColor: Color {
        switch sound {
        case .heavyRain, .lake: return Color(hex: "#8DB8D8")
        case .ambient: return Color(hex: "#D0A5FF")
        case .greenNoise: return Color(hex: "#9AD6A0")
        case .minSolf, .solf: return Color.lullAmber
        case .birds: return Color(hex: "#C8D48A")
        }
    }
}

private enum TodaySleepSoundPanel: Identifiable {
    case switchSound
    case timer

    var id: String {
        switch self {
        case .switchSound: return "switch"
        case .timer: return "timer"
        }
    }
}

private struct SleepTargetCardContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.lullAmber)
                Text("When you are ready, this completes tonight's ritual.")
                    .font(.system(size: 13))
                    .foregroundColor(.lullInk2)
                    .lineSpacing(3)
            }

            HStack(spacing: 9) {
                ForEach(0..<5, id: \.self) { index in
                    Circle()
                        .fill(index == 4 ? Color.lullAmber : Color.lullAmber.opacity(0.18))
                        .frame(width: index == 4 ? 14 : 9, height: index == 4 ? 14 : 9)
                        .shadow(color: index == 4 ? .lullAmberGlow : .clear, radius: 7)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.lullLine, lineWidth: 1))
    }
}

private struct TodayInsightsPreview: View {
    @EnvironmentObject private var state: AppState
    @Binding var selectedTab: Int
    let progress: CGFloat
    let completedCount: Int
    let totalCount: Int
    let currentDate: Date

    private var recentLogs: [SleepLogEntry] {
        Array(state.sleepLogs.sorted { $0.date > $1.date }.prefix(14))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Kicker(text: "Insights", color: .lullAmberSoft)
                        Text("Your night signal")
                            .font(.serif(25))
                            .foregroundColor(.lullInk0)
                    }
                    Spacer()
                    Text("\(Int((progress * 100).rounded()))%")
                        .font(.mono(13))
                        .foregroundColor(.lullAmber)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color.lullAmber.opacity(0.12)))
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center) {
                        Text("\(completedCount) of \(totalCount) cards complete")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.lullInk1)
                        Spacer()
                        Button { selectedTab = 1 } label: {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.lullBgDeep)
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(Color.lullAmber))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open routine")
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.06))
                            Capsule()
                                .fill(Color.lullAmber)
                                .frame(width: geo.size.width * progress)
                        }
                    }
                    .frame(height: 5)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.035)))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.lullLine, lineWidth: 1))

                insightsCalendar

                StreakStatusCard(
                    summary: state.streakSummary,
                    selectedTab: $selectedTab,
                    prominent: false
                )
            }
            .padding(.top, 12)
            .padding(.bottom, 116)
        }
    }

    private var insightsCalendar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Kicker(text: currentDate.formatted(.dateTime.month(.wide).year()))
                Spacer()
                Text("last 14")
                    .font(.system(size: 11, weight: .medium, design: .default))
                    .foregroundColor(.lullInk4)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 7), spacing: 7) {
                ForEach(calendarSlots, id: \.self) { slot in
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(slotFill(for: slot))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .strokeBorder(slot == 0 ? Color.lullAmber.opacity(0.45) : Color.lullLine, lineWidth: 1)
                        )
                        .frame(height: 28)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.03)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.lullLine, lineWidth: 1))
    }

    private var calendarSlots: [Int] {
        Array((0..<14).reversed())
    }

    private func slotFill(for offset: Int) -> Color {
        let calendar = Calendar.current
        guard let date = calendar.date(byAdding: .day, value: -offset, to: currentDate) else {
            return Color.white.opacity(0.025)
        }
        if recentLogs.contains(where: { calendar.isDate($0.date, inSameDayAs: date) && $0.completedNightlyFlow }) {
            return Color.lullAmber.opacity(0.75)
        }
        if recentLogs.contains(where: { calendar.isDate($0.date, inSameDayAs: date) && $0.score > 0 }) {
            return Color.lullAmber.opacity(0.28)
        }
        if offset == 0 {
            return Color.lullAmber.opacity(0.10)
        }
        return Color.white.opacity(0.025)
    }
}

// MARK: - Streak Card

struct StreakStatusCard: View {
    var summary: StreakSummary
    @Binding var selectedTab: Int
    var prominent: Bool
    var progressAvgScoreText: String? = nil
    var progressSlots: [DotSlot] = []
    var progressSleepLogs: [SleepLogEntry] = []
    var progressOnInfo: (() -> Void)? = nil
    var progressOnTap: ((Int) -> Void)? = nil
    var progressOnTodayEmptyTap: (() -> Void)? = nil

    private var title: String {
        if summary.completedNights == 0 { return "Start your streak tonight" }
        return "\(summary.completedNights)-night streak"
    }

    private var subtitle: String {
        guard summary.expectedNights > 0 else {
            return "Reach the end of the guided wind-down to earn your first moon."
        }
        return "\(summary.completedNights) of \(summary.expectedNights) nights completed"
    }

    private var showsProgress: Bool {
        !progressSlots.isEmpty
    }

    var body: some View {
        Group {
            if showsProgress {
                cardContent
            } else {
                Button { selectedTab = 1 } label: {
                    cardContent
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: prominent ? 10 : 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: prominent ? 5 : 8) {
                    Kicker(text: "Current streak", color: .lullAmberSoft)
                    Text(title)
                        .font(.serif(prominent ? 26 : 22))
                        .foregroundColor(.lullInk0)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                Spacer()
                Text(summary.expectedNights == 0 ? "--" : "\(summary.completionRate)%")
                    .font(.mono(11))
                    .kerning(1)
                    .foregroundColor(.lullAmberSoft)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.lullAmber.opacity(0.12)))
            }

            if !showsProgress {
                StreakMoonRow(nights: summary.last13, large: prominent)
            }

            HStack(alignment: .center) {
                Text(subtitle)
                    .font(.system(size: prominent ? 13.5 : 12.5))
                    .foregroundColor(.lullInk2)
                    .lineSpacing(3)
                    .lineLimit(2)
                Spacer()
                Text("Rules")
                    .font(.system(size: 11, weight: .semibold, design: .default))
                    .foregroundColor(.lullInk4)
            }

            if showsProgress {
                Divider()
                    .background(Color.lullLine)

                HStack(alignment: .center, spacing: 8) {
                    Text("Last 14 nights")
                        .font(.system(size: 11, weight: .medium, design: .default))
                        .foregroundColor(.lullInk4)
                    if let progressAvgScoreText {
                        Text(progressAvgScoreText)
                            .font(.system(size: 10.5, weight: .medium, design: .default))
                            .foregroundColor(.lullInk4)
                    }
                    Spacer()
                    if let progressOnInfo {
                        Button(action: progressOnInfo) {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.lullInk4)
                                .frame(width: 24, height: 24)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                ProgressDotsCard(
                    slots: progressSlots,
                    sleepLogs: progressSleepLogs,
                    onTap: progressOnTap ?? { _ in },
                    onTodayEmptyTap: progressOnTodayEmptyTap ?? {},
                    showsFrame: false,
                    compact: prominent
                )
            }
        }
        .padding(.horizontal, prominent ? 16 : 16)
        .padding(.vertical, prominent ? 14 : 16)
        .background(
            RoundedRectangle(cornerRadius: prominent ? 24 : 18)
                .fill(LinearGradient(
                    colors: [Color.lullAmber.opacity(prominent ? 0.14 : 0.08), Color.lullAmber.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .overlay(
                    RoundedRectangle(cornerRadius: prominent ? 24 : 18)
                        .strokeBorder(Color.lullAmber.opacity(prominent ? 0.34 : 0.24), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(prominent ? 0.42 : 0.24), radius: prominent ? 24 : 14, y: prominent ? 16 : 8)
    }
}

private struct StreakMoonStrip: View {
    var summary: StreakSummary
    @Binding var selectedTab: Int

    private var caption: String {
        if summary.expectedNights == 0 {
            return "Tonight can earn your first moon"
        }
        return "\(summary.completedNights) of \(summary.expectedNights) nights"
    }

    var body: some View {
        Button { selectedTab = 1 } label: {
            HStack(spacing: 12) {
                StreakMoonRow(nights: summary.last13, large: false)
                Text(caption)
                    .font(.mono(10.5))
                    .kerning(0.7)
                    .foregroundColor(.lullInk3)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.lullInk4)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

private struct StreakMoonRow: View {
    var nights: [StreakNight]
    var large: Bool

    var body: some View {
        HStack(spacing: large ? 6 : 5) {
            ForEach(nights) { night in
                moon(for: night.state)
            }
        }
    }

    @ViewBuilder
    private func moon(for state: StreakNight.State) -> some View {
        let size: CGFloat = large ? 13 : 10
        switch state {
        case .completed:
            Circle()
                .fill(Color.lullAmber)
                .frame(width: size, height: size)
                .shadow(color: .lullAmberGlow, radius: large ? 5 : 3)
        case .missed:
            Circle()
                .strokeBorder(Color.lullInk4.opacity(0.38), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                .frame(width: size, height: size)
        case .tonight:
            Circle()
                .strokeBorder(Color.lullAmber, lineWidth: 1.3)
                .background(Circle().fill(Color.lullAmber.opacity(0.08)))
                .frame(width: size + 2, height: size + 2)
                .shadow(color: .lullAmberGlow, radius: large ? 5 : 3)
        case .future:
            Circle()
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                .frame(width: size, height: size)
        }
    }
}

// MARK: - Streak Strip

struct StreakStrip: View {
    @EnvironmentObject var state: AppState
    @Binding var selectedTab: Int

    private var last7Slots: [DotSlot] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<7).reversed().map { offset in
            let date = cal.date(byAdding: .day, value: -offset, to: today)!
            let entry = state.sleepLogs.first { cal.isDate($0.date, inSameDayAs: date) }
            return DotSlot(date: date, entry: entry)
        }
    }

    private var loggedCount: Int {
        state.sleepLogs.filter { $0.score > 0 }.count
    }

    private var currentStreak: Int {
        let cal = Calendar.current
        var count = 0
        var cursor = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: Date()))!
        while true {
            let rated = state.sleepLogs.contains {
                cal.isDate($0.date, inSameDayAs: cursor) && $0.score > 0
            }
            if rated {
                count += 1
                cursor = cal.date(byAdding: .day, value: -1, to: cursor)!
            } else {
                break
            }
        }
        return count
    }

    private var captionText: String {
        let nights = loggedCount == 1 ? "1 night" : "\(loggedCount) nights"
        if currentStreak >= 2 {
            return "\(nights) logged · \(currentStreak)-night streak"
        }
        return "\(nights) logged"
    }

    var body: some View {
        if loggedCount == 0 {
            Text("Tonight kicks off your first cycle.")
                .font(.mono(11))
                .kerning(0.6)
                .foregroundColor(.lullInk4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
        } else {
            Button { selectedTab = 1 } label: {
                HStack(spacing: 14) {
                    HStack(spacing: 5) {
                        ForEach(Array(last7Slots.enumerated()), id: \.offset) { _, slot in
                            miniDot(for: slot.dotState)
                        }
                    }

                    Text(captionText)
                        .font(.mono(10.5))
                        .kerning(0.6)
                        .foregroundColor(.lullInk3)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.lullInk4)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.02))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.lullLine, lineWidth: 1))
                )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func miniDot(for state: DotSlot.DotState) -> some View {
        switch state {
        case .rated:
            Circle()
                .fill(Color.lullAmber)
                .frame(width: 8, height: 8)
        case .inProgress, .todayEmpty:
            Circle()
                .strokeBorder(Color.lullAmber, lineWidth: 1)
                .frame(width: 8, height: 8)
                .shadow(color: .lullAmberGlow, radius: 3)
        case .unratedLocked:
            Circle()
                .fill(Color.lullInk3.opacity(0.35))
                .frame(width: 8, height: 8)
        case .skipped, .future:
            Circle()
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                .frame(width: 8, height: 8)
        }
    }
}

// MARK: - Settings Sheet

struct SettingsSheet: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject private var subscriptions: LullSubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var showCustomerCenter = false
    #if DEBUG
    @State private var seededNightCount: Int? = nil
    #endif
    @State private var liveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
    @State private var initialSleepScheduleSignature: String? = nil

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f
    }()

    private var sleepDurationText: String {
        let mins = AppState.clockDurationMinutes(from: state.typicalBedtime, to: state.typicalWakeTime)
        let h = mins / 60
        let m = mins % 60
        return m == 0 ? "\(h) hr" : "\(h) hr \(m) min"
    }

    private func formatted(_ date: Date) -> String {
        Self.timeFmt.string(from: date)
    }

    private var sleepScheduleSignature: String {
        let cal = Calendar.autoupdatingCurrent
        let bed = cal.dateComponents([.hour, .minute], from: state.typicalBedtime)
        let wake = cal.dateComponents([.hour, .minute], from: state.typicalWakeTime)
        return "\(bed.hour ?? 0):\(bed.minute ?? 0)-\(wake.hour ?? 0):\(wake.minute ?? 0)"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.lullBg.ignoresSafeArea()
                AmberGlow(x: 0.5, y: -0.05, radius: 220, opacity: 0.5)
                    .ignoresSafeArea()

                settingsHome
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.lullInk1)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(Color.white.opacity(0.07)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close settings")
                }
            }
            .toolbarBackground(Color.lullBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .onDisappear {
            if initialSleepScheduleSignature != sleepScheduleSignature {
                state.sleepWindowWasEdited()
            } else {
                state.persist()
                state.scheduleAllNotifications()
            }
        }
        .onAppear {
            initialSleepScheduleSignature = sleepScheduleSignature
            refreshLiveActivitiesStatus()
        }
        .task {
            await subscriptions.refreshCustomerInfo()
            state.applyRevenueCatEntitlement(isActive: subscriptions.isLullProActive)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                refreshLiveActivitiesStatus()
            }
        }
        .sheet(isPresented: $showCustomerCenter) {
            CustomerCenterView()
                .onCustomerCenterRestoreCompleted { customerInfo in
                    subscriptions.apply(customerInfo: customerInfo)
                }
                .onCustomerCenterRestoreFailed { error in
                    subscriptions.lastErrorMessage = error.localizedDescription
                }
        }
    }

    private var settingsHome: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 26) {
                premiumCard

                settingsSection(title: nil) {
                    NavigationLink {
                        sleepWindowEditor
                            .navigationTitle("Adjust Sleep Window")
                            .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        SettingsRowContent(
                            icon: "moon.zzz.fill",
                            title: "Adjust Sleep Window",
                            subtitle: sleepDurationText,
                            accessory: .chevron
                        )
                    }
                    .buttonStyle(.plain)
                }

                settingsSection(title: "About") {
                    ShareLink(
                        item: Self.appStoreURL,
                        subject: Text("TenThirty"),
                        message: Text("I'm using TenThirty to help improve my sleep. Try it tonight.")
                    ) {
                        SettingsRowContent(icon: "square.and.arrow.up", title: "Share TenThirty")
                    }
                    .buttonStyle(.plain)

                    settingsDivider

                    settingsButton(icon: "star", title: "Leave a Review") {
                        open(Self.reviewURL)
                    }

                    settingsDivider

                    settingsButton(icon: "envelope", title: "Send Feedback") {
                        open(Self.feedbackURL)
                    }

                    settingsDivider

                    settingsButton(icon: "link", title: "Visit TryTenThirty.com", accessory: .external) {
                        open(Self.websiteURL)
                    }
                }

                settingsSection(title: "Legal") {
                    settingsButton(icon: "hand.raised", title: "Privacy Policy", accessory: .external) {
                        open(Self.privacyURL)
                    }

                    settingsDivider

                    settingsButton(icon: "doc.text", title: "Terms of Use", accessory: .external) {
                        open(Self.termsURL)
                    }
                }

                #if DEBUG
                VStack(alignment: .leading, spacing: 12) {
                    SettingsSectionTitle("Debug")
                    debugSeedButton(count: 3, kind: .milestone)
                    debugSeedButton(count: 6, kind: .activeTrial)
                    debugSeedButton(count: 7, kind: .paywall)
                }
                #endif

                Spacer().frame(height: 28)
            }
            .padding(.horizontal, 22)
            .padding(.top, 12)
        }
    }

    private var premiumCard: some View {
        NavigationLink {
            subscriptionDetails
                .navigationTitle("Manage my subscription")
                .navigationBarTitleDisplayMode(.inline)
        } label: {
            SettingsRowContent(
                icon: "creditcard.fill",
                title: "Manage my subscription",
                subtitle: subscriptions.currentSubscriptionDetails?.planName ?? "View your current plan",
                accessory: .chevron
            )
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .background(settingsCardBackground)
    }

    private var subscriptionDetails: some View {
        ZStack {
            Color.lullBg.ignoresSafeArea()
            AmberGlow(x: 0.5, y: -0.05, radius: 220, opacity: 0.5)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Kicker(text: "Subscription")
                        Text("Manage my subscription")
                            .font(.serif(24))
                            .foregroundColor(.lullInk0)
                    }
                    .padding(.horizontal, 4)

                    settingsSection(title: nil) {
                        SettingsRowContent(
                            icon: "sparkles",
                            title: subscriptions.currentSubscriptionDetails?.planName ?? "TenThirty Premium",
                            subtitle: subscriptions.currentSubscriptionDetails?.statusText ?? "Loading subscription details...",
                            accessory: .none
                        )

                        settingsDivider

                        SettingsRowContent(
                            icon: "calendar",
                            title: subscriptions.currentSubscriptionDetails?.billingTitle ?? "Next billing period starts",
                            subtitle: subscriptions.currentSubscriptionDetails?.billingText ?? "Loading billing date...",
                            accessory: .none
                        )
                    }

                    Button {
                        showCustomerCenter = true
                    } label: {
                        Text("Open Apple subscription settings")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "#1A0D06"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(
                                Capsule()
                                    .fill(Color.lullAmber)
                                    .shadow(color: .lullAmberGlow, radius: 14, y: 6)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)

                    if let message = subscriptions.lastErrorMessage {
                        Text(message)
                            .font(.system(size: 12.5))
                            .foregroundColor(.lullInk3)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer().frame(height: 30)
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)
            }
        }
        .task {
            await subscriptions.refreshCustomerInfo()
            state.applyRevenueCatEntitlement(isActive: subscriptions.isLullProActive)
        }
    }

    private var sleepWindowEditor: some View {
        ZStack {
            Color.lullBg.ignoresSafeArea()
            AmberGlow(x: 0.5, y: -0.05, radius: 220, opacity: 0.5)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        Kicker(text: "Sleep window")
                        Text("When do you usually sleep?")
                            .font(.serif(22))
                            .foregroundColor(.lullInk0)
                    }
                    .padding(.horizontal, 26)
                    .padding(.top, 8)
                    .padding(.bottom, 20)

                    VStack(spacing: 3) {
                        Text(sleepDurationText)
                            .font(.serif(34))
                            .foregroundColor(.lullInk0)
                        Text("Typical window")
                            .font(.mono(10))
                            .kerning(1.6)
                            .foregroundColor(.lullInk3)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 16)

                    SleepArcClock(bedtime: $state.typicalBedtime, wakeTime: $state.typicalWakeTime)
                        .frame(width: 260, height: 260)
                        .frame(maxWidth: .infinity)

                    HStack {
                        VStack(spacing: 4) {
                            Image(systemName: "moon.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.lullAmber)
                            Text(formatted(state.typicalBedtime))
                                .font(.serif(18))
                                .foregroundColor(.lullInk0)
                            Text("Usually asleep")
                                .font(.mono(10))
                                .kerning(1.2)
                                .foregroundColor(.lullInk3)
                        }
                        Spacer()
                        VStack(spacing: 4) {
                            Image(systemName: "sun.horizon.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.lullAmber)
                            Text(formatted(state.typicalWakeTime))
                                .font(.serif(18))
                                .foregroundColor(.lullInk0)
                            Text("Usually up")
                                .font(.mono(10))
                                .kerning(1.2)
                                .foregroundColor(.lullInk3)
                        }
                    }
                    .padding(.horizontal, 52)
                    .padding(.top, 12)
                    .padding(.bottom, 36)

                    Spacer().frame(height: 40)
                }
            }
        }
    }

    private func settingsSection<Content: View>(title: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                SettingsSectionTitle(title)
            }
            VStack(spacing: 0) {
                content()
            }
            .background(settingsCardBackground)
        }
    }

    private func settingsButton(
        icon: String,
        title: String,
        subtitle: String? = nil,
        accessory: SettingsRowAccessory = .chevron,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            SettingsRowContent(icon: icon, title: title, subtitle: subtitle, accessory: accessory)
        }
        .buttonStyle(.plain)
    }

    private var settingsDivider: some View {
        Divider()
            .background(Color.white.opacity(0.08))
            .padding(.leading, 64)
    }

    private var settingsCardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.white.opacity(0.055))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
    }

    private func open(_ url: URL) {
        openURL(url)
    }

    private static let appStoreURL = URL(string: "https://apps.apple.com/us/app/tenthirty-smart-sleep-plan/id6768480598")!
    private static let reviewURL = URL(string: "https://apps.apple.com/us/app/tenthirty-smart-sleep-plan/id6768480598?action=write-review")!
    private static let feedbackURL = URL(string: "mailto:czarinacatambing@gmail.com?subject=Feedback")!
    private static let websiteURL = URL(string: "https://trytenthirty.com")!
    private static let privacyURL = URL(string: "https://trytenthirty.com/privacy")!
    private static let termsURL = URL(string: "https://trytenthirty.com/terms")!

    #if DEBUG
    private enum DebugSeedKind {
        case activeTrial
        case milestone
        case paywall
    }

    private func debugSeedButton(count: Int, kind: DebugSeedKind) -> some View {
        let didSeed = seededNightCount == count
        return Button {
            state.debugSeedCompletedNightsAndExpireTrial(
                count: count,
                presentMilestone: kind == .milestone,
                expireTrial: kind == .paywall
            )
            seededNightCount = count
        } label: {
            HStack(spacing: 12) {
                Image(systemName: didSeed ? "checkmark.circle.fill" : "timer")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.lullAmber)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 4) {
                    Text(debugSeedTitle(count: count, kind: kind))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.lullInk0)
                    Text(didSeed
                         ? debugSeedCompleteText(count: count, kind: kind)
                         : debugSeedDescription(count: count, kind: kind))
                        .font(.system(size: 12.5))
                        .foregroundColor(.lullInk3)
                        .lineSpacing(2)
                }
                Spacer()
            }
            .padding(14)
            .lullCard(radius: 14, accent: didSeed)
        }
        .buttonStyle(.plain)
    }

    private func debugSeedDescription(count: Int, kind: DebugSeedKind) -> String {
        switch kind {
        case .activeTrial:
            return "Creates \(count) completed nights with ratings and keeps the trial active."
        case .milestone:
            return "Creates \(count) completed nights with ratings, then shows the milestone card."
        case .paywall:
            return "Creates \(count) completed nights with ratings, then expires the trial."
        }
    }

    private func debugSeedTitle(count: Int, kind: DebugSeedKind) -> String {
        switch kind {
        case .activeTrial:
            return "Seed \(count)-night active trial test"
        case .milestone:
            return "Seed \(count)-night milestone test"
        case .paywall:
            return "Seed \(count)-night paywall test"
        }
    }

    private func debugSeedCompleteText(count: Int, kind: DebugSeedKind) -> String {
        switch kind {
        case .activeTrial:
            return "\(count) nights seeded. Trial remains active."
        case .milestone:
            return "\(count) nights seeded. Milestone card requested."
        case .paywall:
            return "\(count) nights seeded. RevenueCat paywall requested."
        }
    }
    #endif

    private func refreshLiveActivitiesStatus() {
        liveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
    }
}

private enum SettingsRowAccessory {
    case chevron
    case external
    case none
}

private struct SettingsSectionTitle: View {
    var title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.lullInk3)
            .padding(.horizontal, 2)
    }
}

private struct SettingsRowContent: View {
    var icon: String
    var title: String
    var subtitle: String? = nil
    var accessory: SettingsRowAccessory = .chevron

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .regular))
                .foregroundColor(.lullAmber)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.lullInk0)
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 14.5, weight: .regular))
                        .foregroundColor(.lullInk3)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            switch accessory {
            case .chevron:
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.lullInk4)
            case .external:
                Image(systemName: "arrow.up.forward")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.lullInk4)
            case .none:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .contentShape(Rectangle())
    }
}

private struct LiveActivitiesSettingsCard: View {
    var isEnabled: Bool
    var onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill((isEnabled ? Color.lullAmber : Color.white).opacity(isEnabled ? 0.14 : 0.05))
                        .frame(width: 38, height: 38)
                    Image(systemName: isEnabled ? "livephoto" : "livephoto.slash")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isEnabled ? .lullAmber : .lullInk3)
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text("Live Activities")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.lullInk0)
                        Text(isEnabled ? "ON" : "OFF")
                            .font(.mono(9.5))
                            .kerning(1.1)
                            .foregroundColor(isEnabled ? .lullAmber : Color(hex: "#e89189"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill((isEnabled ? Color.lullAmber : Color(hex: "#e89189")).opacity(0.10))
                            )
                    }

                    Text(isEnabled
                         ? "Mid-Sleep mode can appear from the Lock Screen after your ritual."
                         : "Turn this on in iOS Settings so Mid-Sleep mode can appear after your ritual.")
                        .font(.system(size: 12.5))
                        .foregroundColor(.lullInk3)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            Button(action: onOpenSettings) {
                HStack {
                    Text("Open iOS Settings")
                        .font(.system(size: 14, weight: .medium))
                    Spacer()
                    Image(systemName: "arrow.up.forward")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.lullBgDeep)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .frame(height: 46)
                .background(Capsule().fill(Color.lullAmber))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .lullCard(radius: 16, accent: !isEnabled)
    }
}

// MARK: - Mid-Sleep Primer Card

struct MidSleepPrimerCard: View {
    @Binding var selectedTab: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "#b4a0dc").opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#b9aedc"))
                }
                Text("Mid-sleep mode")
                    .font(.system(size: 12, weight: .semibold, design: .default))
                    .foregroundColor(Color(hex: "#b9aedc"))
                Spacer()
            }
            .padding(.bottom, 16)

            // Single activation row
            HStack(spacing: 14) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "#b9aedc"))
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Swipe up during Good Night")
                        .font(.serif(15))
                        .foregroundColor(.lullInk0)
                    Text("Today opens the toolkit only when you ask for it")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.lullInk3)
                }
                Spacer()
            }
            .padding(.bottom, 18)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "#b4a0dc").opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color(hex: "#b4a0dc").opacity(0.14), lineWidth: 1)
                )
        )
    }
}
