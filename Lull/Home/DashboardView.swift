import ActivityKit
import RevenueCatUI
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var state: AppState
    @Binding var selectedTab: Int
    @State private var showMenu = false
    @State private var showSettings = false
    @State private var showBrainDumps = false
    @State private var currentDate = Date()
    @State private var glowPulse = false

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

    // MARK: - Morning state predicate

    private var isMorningState: Bool {
        if state.debugForceMorningState { return true }
        if state.debugForceEveningState { return false }
        guard let wake = todaysWakeTime else { return false }
        let cal = Calendar.current
        // Upper bound: the later of wake + 4h OR 11 AM. This keeps the morning
        // hero available through breakfast hours for users with very early
        // wake times, while preserving a 4-hour minimum for late wakers.
        let plusFour = cal.date(byAdding: .hour, value: 4, to: wake) ?? wake
        var elevenComps = cal.dateComponents([.year, .month, .day], from: currentDate)
        elevenComps.hour = 11
        elevenComps.minute = 0
        let elevenAm = cal.date(from: elevenComps) ?? plusFour
        let windowEnd = max(plusFour, elevenAm)
        return currentDate >= wake && currentDate < windowEnd
    }

    private var todaysWakeTime: Date? {
        let cal = Calendar.current
        let wakeComps = cal.dateComponents([.hour, .minute], from: state.typicalWakeTime)
        var combined = cal.dateComponents([.year, .month, .day], from: currentDate)
        combined.hour = wakeComps.hour ?? 7
        combined.minute = wakeComps.minute ?? 0
        return cal.date(from: combined)
    }

    // Most recent entry with a score (any date). nil if user has never rated.
    private var mostRecentRated: SleepLogEntry? {
        state.sleepLogs
            .filter { $0.score > 0 }
            .sorted { $0.date > $1.date }
            .first
    }

    // Today's rating = the most recent rated entry within the today/yesterday
    // window. We have to use that window (not strictly yesterday) because the
    // rating can land on a today-dated entry when the user did wind-down after
    // midnight OR when a today-dated ghost entry already exists.
    private var todaysRatedEntry: SleepLogEntry? {
        let cal = Calendar.current
        return state.sleepLogs
            .filter { $0.score > 0 && (cal.isDateInToday($0.date) || cal.isDateInYesterday($0.date)) }
            .sorted { $0.date > $1.date }
            .first
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
    private var allRitualDone: Bool { ritualDoneCount == ritualSteps.count && !ritualSteps.isEmpty }

    private func scheduledTime(for step: RoutineStep) -> String {
        state.scheduledRoutine.first { $0.step.id == step.id }?.timeString ?? ""
    }
    private func leadLabel(for step: RoutineStep) -> String {
        guard let row = state.scheduledRoutine.first(where: { $0.step.id == step.id }) else { return "" }
        let mins = Int(state.typicalBedtime.timeIntervalSince(row.time) / 60)
        return mins > 0 ? "\(mins) min before bed" : "at bedtime"
    }

    var body: some View {
        ZStack {
            LullScreen(glow: false) {
                AmberGlow(x: 0.5, y: -0.05, radius: 260, opacity: 0.7)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Spacer().frame(height: 16)

                        topBar
                            .padding(.horizontal, Lull.horizontalPad)
                            .padding(.bottom, 8)

                        if isMorningState {
                            morningContent
                        } else {
                            eveningContent
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $state.showNightlyFlow) {
                NightlyFlowView()
            }
            .onAppear {
                currentDate = Date()
                state.resetPrepIfNeeded()
                state.presentPendingStreakMilestoneIfEligible()
                withAnimation(.easeInOut(duration: 4.5).repeatForever(autoreverses: true)) {
                    glowPulse = true
                }
                if !isMorningState && !state.preWindDownSteps.isEmpty && !state.suppressPrepLiveActivityForSession {
                    LiveActivityService.shared.startIfNeeded(
                        prepSteps: state.preWindDownSteps,
                        doneIds: state.prepDoneIds,
                        bedtime: state.typicalBedtime,
                        leadTimes: AppState.prepLeadTimes
                    )
                }
            }

            // Menu overlay
            if showMenu {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation(.easeOut(duration: 0.18)) { showMenu = false } }

                VStack(alignment: .leading, spacing: 0) {
                    Button(action: {
                        withAnimation(.easeOut(duration: 0.18)) { showMenu = false }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            showSettings = true
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 13))
                                .foregroundColor(.lullInk2)
                                .frame(width: 18)
                            Text("Settings")
                                .font(.system(size: 14))
                                .foregroundColor(.lullInk1)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        withAnimation(.easeOut(duration: 0.18)) { showMenu = false }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            showBrainDumps = true
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.lullInk2)
                                .frame(width: 18)
                            Text("Brain Dumps")
                                .font(.system(size: 14))
                                .foregroundColor(.lullInk1)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)

                    Divider().background(Color.lullLine).padding(.horizontal, 12)

                    debugMenuItem(
                        label: "Force morning state",
                        active: state.debugForceMorningState
                    ) {
                        state.debugForceMorningState.toggle()
                        if state.debugForceMorningState {
                            state.debugForceEveningState = false
                        }
                    }
                    debugMenuItem(
                        label: "Force evening state",
                        active: state.debugForceEveningState
                    ) {
                        state.debugForceEveningState.toggle()
                        if state.debugForceEveningState {
                            state.debugForceMorningState = false
                        }
                    }
                    debugMenuItem(
                        label: "Clear today's rating",
                        active: false
                    ) {
                        state.debugClearTodaysRating()
                        withAnimation(.easeOut(duration: 0.18)) { showMenu = false }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(hex: "#1a1310"))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.lullLine, lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.5), radius: 16, y: 8)
                )
                .frame(width: 220)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 68)
                .padding(.trailing, 22)
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topTrailing)))
                .zIndex(10)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showBrainDumps) {
            BrainDumpsBrowser()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private func debugMenuItem(label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: active ? "checkmark.circle.fill" : "wrench.adjustable")
                    .font(.system(size: 12))
                    .foregroundColor(active ? .lullAmber : .lullInk3)
                    .frame(width: 10)
                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(active ? .lullAmber : .lullInk2)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Top bar (shared)

    private var topBar: some View {
        HStack {
            BrandMark()
            Spacer()
            Button(action: { withAnimation(.easeOut(duration: 0.18)) { showMenu.toggle() } }) {
                ZStack {
                    Circle()
                        .strokeBorder(Color.lullLine, lineWidth: 1)
                        .frame(width: 36, height: 36)
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.lullInk2)
                }
            }
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

        StreakStatusCard(summary: state.streakSummary, selectedTab: $selectedTab, prominent: true)
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
                Text("how did you sleep?")
                    .font(.serifItalic(32))
                    .foregroundColor(.lullInk2)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 32)
        .padding(.bottom, 22)

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

        StreakStatusCard(summary: state.streakSummary, selectedTab: $selectedTab, prominent: false)
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
                    .font(.serif(26))
                    .foregroundColor(.lullInk0)
                    .padding(.top, 10)

                // Description
                VStack(alignment: .leading, spacing: 8) {
                    (Text("Finish the guided wind-down to keep your bedtime rhythm alive. ")
                        .foregroundColor(.lullInk1)
                    + Text("You can skip a step and still complete the ritual.")
                        .foregroundColor(.lullInk2))
                    .font(.system(size: 13.5))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                    // Sub-copy
                    Text(allPrepDone
                         ? "Prep complete. Ready to start the wind-down sequence whenever you are."
                         : "Finish prep first (\(remaining) left), then we'll start the wind-down sequence.")
                        .font(.system(size: 12.5))
                        .foregroundColor(.lullInk2)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // CTA
                PrimaryCTA(title: allPrepDone ? "Start ritual" : "Finish prep · \(remaining) left") {
                    state.cancelWindDownStartNotifications()
                    LiveActivityService.shared.end(dismissalPolicy: .immediate)
                    state.showNightlyFlow = true
                }
                .disabled(!allPrepDone)
                .opacity(allPrepDone ? 1 : 0.45)
                .padding(.top, 24)
            }
            .font(.system(size: 13))
            .padding(.horizontal, 22)
            .padding(.top, 22)
            .padding(.bottom, 24)
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
                Text("\(ritualDoneCount)/\(ritualSteps.count) done")
                    .font(.mono(10.5))
                    .kerning(0.6)
                    .foregroundColor(allRitualDone ? .lullAmber : .lullInk3)
                Button(action: { selectedTab = 1 }) {
                    Text("EDIT")
                        .font(.mono(10.5))
                        .kerning(1)
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
                            .fill(allRitualDone ? Color.lullAmber.opacity(0.24) : Color.clear)
                            .frame(width: 22, height: 22)
                        RoundedRectangle(cornerRadius: 7)
                            .strokeBorder(allRitualDone ? Color.lullAmber.opacity(0.45) : Color.white.opacity(0.16), lineWidth: 1.4)
                            .frame(width: 22, height: 22)
                        if allRitualDone {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.lullAmber)
                        }
                    }
                    Text("Sleep")
                        .font(.system(size: 13.5))
                        .foregroundColor(allRitualDone ? .lullInk3 : .lullInk1)
                        .strikethrough(allRitualDone, color: Color.lullAmber.opacity(0.45))
                    Spacer()
                    Text("\(state.sleepDurationString) target")
                        .font(.mono(10))
                        .kerning(0.6)
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
                    .font(.mono(10))
                    .kerning(0.6)
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

// MARK: - Streak Card

struct StreakStatusCard: View {
    var summary: StreakSummary
    @Binding var selectedTab: Int
    var prominent: Bool

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

    var body: some View {
        Button { selectedTab = 1 } label: {
            VStack(alignment: .leading, spacing: prominent ? 16 : 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Kicker(text: "Current streak", color: .lullAmberSoft)
                        Text(title)
                            .font(.serif(prominent ? 32 : 22))
                            .foregroundColor(.lullInk0)
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

                StreakMoonRow(nights: summary.last13, large: prominent)

                HStack(alignment: .center) {
                    Text(subtitle)
                        .font(.system(size: prominent ? 13.5 : 12.5))
                        .foregroundColor(.lullInk2)
                        .lineSpacing(3)
                    Spacer()
                    Text("ROUTINE")
                        .font(.mono(9.5))
                        .kerning(1.2)
                        .foregroundColor(.lullInk4)
                }
            }
            .padding(.horizontal, prominent ? 20 : 16)
            .padding(.vertical, prominent ? 20 : 16)
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
    @Environment(\.scenePhase) private var scenePhase
    @State private var showCustomerCenter = false
    @State private var didExpireTrial = false
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

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Sleep window section
                        VStack(alignment: .leading, spacing: 6) {
                            Kicker(text: "Sleep window")
                            Text("When do you usually sleep?")
                                .font(.serif(22))
                                .foregroundColor(.lullInk0)
                        }
                        .padding(.horizontal, 26)
                        .padding(.top, 8)
                        .padding(.bottom, 20)

                        // Duration readout
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

                        // Arc clock
                        SleepArcClock(bedtime: $state.typicalBedtime, wakeTime: $state.typicalWakeTime)
                            .frame(width: 260, height: 260)
                            .frame(maxWidth: .infinity)

                        // Bedtime / Wake labels
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

                        Divider()
                            .background(Color.lullLine)
                            .padding(.horizontal, 26)
                            .padding(.bottom, 28)

                        LiveActivitiesSettingsCard(isEnabled: liveActivitiesEnabled) {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.bottom, 24)

                        #if DEBUG
                        VStack(alignment: .leading, spacing: 12) {
                            Kicker(text: "Debug")
                            Button {
                                state.debugSeedSevenNightsAndExpireTrial()
                                didExpireTrial = true
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: didExpireTrial ? "checkmark.circle.fill" : "timer")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.lullAmber)
                                        .frame(width: 22)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Seed 7-night paywall test")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.lullInk0)
                                        Text(didExpireTrial
                                             ? "Seven nights seeded. RevenueCat paywall requested."
                                             : "Creates 7 completed nights with ratings, then expires the trial.")
                                            .font(.system(size: 12.5))
                                            .foregroundColor(.lullInk3)
                                            .lineSpacing(2)
                                    }
                                    Spacer()
                                }
                                .padding(14)
                                .lullCard(radius: 14, accent: didExpireTrial)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 22)
                        .padding(.bottom, 22)
                        #endif

                        // Help improve Lull card
                        Button {
                            if state.isPaidPremium {
                                showCustomerCenter = true
                            } else {
                                state.presentUpgradePaywall()
                            }
                        } label: {
                            HStack {
                                Text(state.isPaidPremium ? "Manage Lull Premium" : "Upgrade to Lull Premium")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.lullInk0)
                                Spacer()
                                Text(state.isPaidPremium ? "ACTIVE →" : (state.trialDaysRemainingText ?? "PRO →"))
                                    .font(.mono(10.5))
                                    .kerning(1.1)
                                    .foregroundColor(.lullAmber)
                            }
                            .padding(16)
                            .lullCard(radius: 16, accent: true)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 22)
                        .padding(.bottom, 18)

                        ExportDataFooter()
                            .padding(.horizontal, 22)

                        Spacer().frame(height: 40)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.lullAmber)
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

    private func refreshLiveActivitiesStatus() {
        liveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
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
                Text("MID-SLEEP MODE")
                    .font(.mono(10))
                    .kerning(10 * 0.12)
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
                    Text("Tap the Mid-sleep tab")
                        .font(.serif(15))
                        .foregroundColor(.lullInk0)
                    Text("From any screen, any time of night")
                        .font(.mono(10))
                        .kerning(10 * 0.06)
                        .foregroundColor(.lullInk3)
                }
                Spacer()
            }
            .padding(.bottom, 18)

            // Try it now button
            Button(action: { selectedTab = 2 }) {
                HStack(spacing: 6) {
                    Text("Try it now")
                        .font(.mono(11))
                        .foregroundColor(Color(hex: "#b9aedc"))
                    Text("·")
                        .foregroundColor(Color(hex: "#b9aedc").opacity(0.5))
                    Text("preview")
                        .font(.mono(11))
                        .foregroundColor(Color(hex: "#b9aedc").opacity(0.6))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(hex: "#b4a0dc").opacity(0.08))
                .overlay(
                    Capsule().strokeBorder(Color(hex: "#b4a0dc").opacity(0.20), lineWidth: 1)
                )
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
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
