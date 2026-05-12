import SwiftUI

struct MyRoutineView: View {
    @EnvironmentObject var state: AppState
    @AppStorage("routineVisitCount") private var visitCount = 0
    @State private var coachDismissed = false
    @State private var showChangeConfirm = false
    @State private var showCandidatePicker = false
    @State private var pendingCandidate: String? = nil
    @State private var showHistoryLegend = false

    private var showCoach: Bool { !coachDismissed && visitCount <= 3 }

    private var candidates: [String] {
        let inRoutine = Set(state.coreRoutine.map(\.label))
        return allBedroomPrepRemedies.filter { !inRoutine.contains($0) }
    }

    private var suggestedVariable: String? {
        let routineWithoutExperiment = state.coreRoutine.filter { $0.mode != .experiment }
        return ExperimentEngine.suggestNextVariable(
            logs: state.sleepLogs,
            coreRoutine: routineWithoutExperiment,
            remedyScores: state.remedyScores
        )
    }

    private var avgScoreText: String? {
        let scored = state.sleepLogs.filter { $0.score > 0 }
        guard !scored.isEmpty else { return nil }
        let avg = Double(scored.map(\.score).reduce(0, +)) / Double(scored.count)
        return String(format: "AVG %.1f", avg)
    }

    private var displaySlots: [DotSlot] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        let pastDayCount: Int
        if let earliest = state.sleepLogs.map(\.date).min() {
            let days = cal.dateComponents([.day], from: cal.startOfDay(for: earliest), to: today).day ?? 0
            pastDayCount = min(days, 13)
        } else {
            pastDayCount = 0
        }
        let futureDayCount = 13 - pastDayCount

        var slots: [DotSlot] = []

        for i in stride(from: pastDayCount, through: 1, by: -1) {
            let date = cal.date(byAdding: .day, value: -i, to: today)!
            let entry = state.sleepLogs.first { cal.isDate($0.date, inSameDayAs: date) }
            slots.append(DotSlot(date: date, entry: entry))
        }

        let todayEntry = state.sleepLogs.first { cal.isDateInToday($0.date) }
        slots.append(DotSlot(date: today, entry: todayEntry))

        if futureDayCount > 0 {
            for i in 1...futureDayCount {
                let date = cal.date(byAdding: .day, value: i, to: today)!
                slots.append(DotSlot(date: date, entry: nil))
            }
        }

        return slots
    }

    private func badgeText(for step: RoutineStep) -> String {
        state.scheduledRoutine.first { $0.step.id == step.id }?.badge ?? step.mode.label
    }

    var body: some View {
        LullScreen(glow: false) {
            AmberGlow(x: 0.8, y: -0.08, radius: 260, opacity: 0.55)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 16)

                    // Header
                    VStack(alignment: .leading, spacing: 6) {
                        Kicker(text: "Your routine")
                        Text("My Sleep System")
                            .font(.serif(30))
                            .fontWeight(.regular)
                            .foregroundColor(.lullInk0)
                        Text("Build your experiment. Test one change at a time. Watch your sleep improve.")
                            .font(.serifItalic(14.5))
                            .foregroundColor(.lullAmberSoft)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(3)
                            .padding(.top, 2)
                    }
                    .padding(.horizontal, Lull.horizontalPad)
                    .padding(.bottom, 18)

                    // Coach mark
                    if showCoach {
                        RoutineCoachMark { coachDismissed = true }
                            .padding(.horizontal, 22)
                            .padding(.bottom, 14)
                    }

                    // Experiment hero card
                    ExperimentHeroCard(
                        showCandidatePicker: $showCandidatePicker,
                        showChangeConfirm: $showChangeConfirm
                    )
                    .padding(.horizontal, 22)
                    .padding(.bottom, 24)
                    .alert("Change experiment?", isPresented: $showChangeConfirm) {
                        Button("Keep testing") { }
                        Button("Yes, change it", role: .destructive) { showCandidatePicker = true }
                    } message: {
                        Text("You've only tested \"\(state.tonightVariable)\" for \(state.variableNight) night\(state.variableNight == 1 ? "" : "s"). Switching now means losing that data.")
                    }
                    .sheet(isPresented: $showCandidatePicker) {
                        CandidatePickerSheet(
                            candidates: candidates,
                            suggestedVariable: suggestedVariable,
                            currentVariable: state.tonightVariable
                        ) { chosen in
                            state.changeExperimentVariable(to: chosen)
                            showCandidatePicker = false
                        }
                    }

                    // Prep checklist section
                    RoutineSectionHead(
                        title: "Prep checklist",
                        eyebrow: "Start here",
                        sub: "Do these 30–75 min before bed",
                        right: "\(state.preWindDownSteps.count) STEPS"
                    )
                    .padding(.horizontal, 22)
                    .padding(.bottom, 10)

                    List {
                        ForEach(state.preWindDownSteps) { step in
                            PrepListRow(
                                step: step,
                                isExperiment: step.mode == .experiment,
                                chip: badgeText(for: step)
                            )
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        }
                        .onMove(perform: state.movePreWindDown)
                    }
                    .environment(\.editMode, .constant(.active))
                    .scrollDisabled(true)
                    .listStyle(.plain)
                    .frame(height: CGFloat(state.preWindDownSteps.count) * 60)
                    .padding(.horizontal, 22)

                    DragHintLabel()
                        .padding(.horizontal, 22)
                        .padding(.top, 4)
                        .padding(.bottom, 24)

                    // Bedtime ritual section
                    RoutineSectionHead(
                        title: "Bedtime ritual",
                        eyebrow: "In sequence",
                        sub: "Follow in order when you're getting into bed",
                        right: "\(state.windDownSteps.count) STEPS"
                    )
                    .padding(.horizontal, 22)
                    .padding(.bottom, 10)

                    List {
                        ForEach(Array(state.windDownSteps.enumerated()), id: \.element.id) { i, step in
                            RitualListRow(number: i + 1, step: step)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        }
                        .onMove(perform: state.moveWindDown)
                    }
                    .environment(\.editMode, .constant(.active))
                    .scrollDisabled(true)
                    .listStyle(.plain)
                    .frame(height: CGFloat(state.windDownSteps.count) * 60)
                    .padding(.horizontal, 22)

                    DragHintLabel()
                        .padding(.horizontal, 22)
                        .padding(.top, 4)
                        .padding(.bottom, 28)

                    // Progress section
                    HStack(alignment: .top) {
                        RoutineSectionHead(
                            title: "Your progress",
                            eyebrow: "Last 14 nights",
                            sub: "Tap any night for details.",
                            right: avgScoreText ?? ""
                        )
                        Button { showHistoryLegend = true } label: {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 16))
                                .foregroundColor(.lullInk4)
                        }
                        .padding(.top, 3)
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 10)

                    ProgressDotsCard(
                        slots: displaySlots,
                        sleepLogs: state.sleepLogs,
                        onTap: { idx in state.selectedDotIndex = idx },
                        onTodayEmptyTap: {
                            // Create an empty entry for today so the detail sheet has something to point at.
                            state.updateTodayLog { _ in }
                            if let idx = state.sleepLogs.firstIndex(where: { $0.isToday }) {
                                state.selectedDotIndex = idx
                            }
                        }
                    )
                    .padding(.horizontal, 22)
                    .padding(.bottom, 28)

                    ExportDataFooter()
                        .padding(.horizontal, 22)
                        .padding(.bottom, 36)
                }
            }
        }
        .onAppear { visitCount = min(visitCount + 1, 99) }
        .fullScreenCover(isPresented: $state.showNightlyFlow) {
            NightlyFlowView()
        }
        .sheet(isPresented: Binding(
            get: { state.selectedDotIndex != nil },
            set: { if !$0 { state.selectedDotIndex = nil } }
        )) {
            if let index = state.selectedDotIndex {
                SleepLogDetailView(entryIndex: index)
            }
        }
        .sheet(isPresented: $showHistoryLegend) {
            SleepHistoryLegendView()
        }
    }
}

// MARK: - Coach Mark

struct RoutineCoachMark: View {
    var onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.lullAmber.opacity(0.14))
                    .frame(width: 28, height: 28)
                Image(systemName: "flask.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.lullAmber)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text("This is your sleep lab.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.lullInk0)
                Text("Test changes and build habits that actually work for you.")
                    .font(.system(size: 12))
                    .foregroundColor(.lullInk2)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11))
                    .foregroundColor(.lullInk3)
                    .padding(6)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.lullAmber.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                        )
                        .foregroundColor(Color.lullAmber.opacity(0.32))
                )
        )
    }
}

// MARK: - Experiment Hero Card

struct ExperimentHeroCard: View {
    @EnvironmentObject var state: AppState
    @Binding var showCandidatePicker: Bool
    @Binding var showChangeConfirm: Bool
    @State private var glowPulse = false
    @State private var showScience = false

    var insightLine: String {
        state.experimentStatus?.insightLine ?? "We're tracking if this moves the needle on your sleep."
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Pulsing glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.lullAmberGlow, .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 120
                    )
                )
                .frame(width: 240, height: 240)
                .offset(x: 40, y: -60)
                .scaleEffect(glowPulse ? 1.08 : 1.0)
                .opacity(glowPulse ? 0.95 : 0.55)
                .animation(.easeInOut(duration: 4.5).repeatForever(autoreverses: true), value: glowPulse)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                // Science sheet — attached here so it doesn't block button taps
                Color.clear.frame(width: 0, height: 0)
                    .sheet(isPresented: $showScience) {
                        ScienceSheet(
                            remedyName: state.tonightVariable,
                            remedyId: state.tonightRemedyId
                        )
                        .presentationDetents([.fraction(0.45)])
                        .presentationDragIndicator(.hidden)
                    }

                // Top row: kicker + badge
                HStack(alignment: .center) {
                    Kicker(text: "Tonight's experiment", color: .lullAmberSoft)
                    Spacer()
                    ActiveTestBadge()
                }
                .padding(.bottom, 10)

                // Variable name
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(state.tonightVariable)
                        .font(.serif(26))
                        .foregroundColor(.lullInk0)
                    if state.variableIsOverridden {
                        Text("EDITED")
                            .font(.mono(9))
                            .kerning(1.4)
                            .foregroundColor(.lullInk3)
                    }
                }
                .padding(.bottom, 14)

                // Night progress bar
                NightProgressBar(current: state.variableNight, total: 5)
                    .padding(.bottom, 16)

                // Insight line
                Text(insightLine)
                    .font(.system(size: 13))
                    .foregroundColor(.lullInk1)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 14)

                // Expected impact
                ExpectedImpactBox(remedyId: state.tonightRemedyId)
                    .padding(.bottom, 16)

                // Action row
                HStack(spacing: 8) {
                    // Edit button
                    ExperimentIconBtn(systemImage: "pencil") {
                        if state.variableNight > 0 {
                            showChangeConfirm = true
                        } else {
                            showCandidatePicker = true
                        }
                    }

                    // Reset button
                    ExperimentIconBtn(systemImage: "arrow.counterclockwise", disabled: !state.variableIsOverridden) {
                        state.resetToSuggestedVariable()
                    }

                    Button(action: { showScience = true }) {
                        Text("View science · why this might work")
                            .font(.system(size: 12.5))
                            .foregroundColor(.lullInk1)
                            .frame(maxWidth: .infinity)
                    }
                    .frame(height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.04))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.lullLine, lineWidth: 1))
                    )
                    .buttonStyle(.plain)
                }

                // Override note
                if state.variableIsOverridden {
                    HStack {
                        Text("You overrode Lull's suggestion.")
                            .font(.system(size: 11.5))
                            .foregroundColor(.lullInk2)
                        Spacer()
                        Button("Reset") {
                            state.resetToSuggestedVariable()
                        }
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(.lullAmber)
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.lullAmber.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                                    .foregroundColor(Color.lullAmber.opacity(0.28))
                            )
                    )
                    .padding(.top, 10)
                }
            }
            .padding(22)
        }
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.lullAmber.opacity(0.12),
                            Color.lullAmber.opacity(0.03),
                            Color.lullAmber.opacity(0.02),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26)
                        .strokeBorder(Color.lullAmber.opacity(0.32), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.45), radius: 24, y: 12)
        )
        .clipped()
        .onAppear { glowPulse = true }
    }
}

struct ActiveTestBadge: View {
    @State private var dotPulse = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.lullAmber)
                .frame(width: 6, height: 6)
                .shadow(color: .lullAmberGlow, radius: 4)
                .opacity(dotPulse ? 1.0 : 0.55)
                .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: dotPulse)
            Text("Active test")
                .font(.mono(9.5))
                .kerning(1.4)
                .foregroundColor(.lullAmber)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.lullAmber.opacity(0.14))
                .overlay(Capsule().strokeBorder(Color.lullAmber.opacity(0.4), lineWidth: 1))
        )
        .onAppear { dotPulse = true }
    }
}

struct NightProgressBar: View {
    var current: Int
    var total: Int

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                HStack(spacing: 0) {
                    Text("Night ")
                        .font(.mono(11))
                        .foregroundColor(.lullInk2)
                    Text("\(current)")
                        .font(.mono(11))
                        .foregroundColor(.lullAmber)
                    Text(" of \(total)")
                        .font(.mono(11))
                        .foregroundColor(.lullInk2)
                }
                Spacer()
                Text("\(total - current) testing nights left")
                    .font(.mono(10.5))
                    .foregroundColor(.lullInk3)
            }
            HStack(spacing: 4) {
                ForEach(0..<total, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 99)
                        .fill(i < current ? Color.lullAmber : Color.lullAmber.opacity(0.14))
                        .frame(height: 4)
                        .shadow(color: i < current ? .lullAmberGlow : .clear, radius: 4)
                }
            }
        }
    }
}

struct ExpectedImpactBox: View {
    var remedyId: RemedyID?

    private var impactData: RemedyImpact {
        remedyId?.impact ?? RemedyImpact(
            prefix: "Users like you fell asleep ",
            highlight: "−11 min",
            suffix: " faster.",
            science: ""
        )
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 14))
                .foregroundColor(.lullAmber)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text("EXPECTED IMPACT")
                    .font(.mono(9.5))
                    .kerning(1.4)
                    .foregroundColor(.lullAmberSoft)
                (Text(impactData.prefix)
                    .font(.system(size: 12.5))
                    .foregroundColor(.lullInk1)
                + Text(impactData.highlight)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(.lullAmber)
                + Text(impactData.suffix)
                    .font(.system(size: 12.5))
                    .foregroundColor(.lullInk1))
                    .lineSpacing(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.45))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.lullLine, lineWidth: 1))
        )
    }
}

struct ScienceSheet: View {
    var remedyName: String
    var remedyId: RemedyID?
    @Environment(\.dismiss) private var dismiss

    private var scienceText: String {
        remedyId?.impact.science ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Handle
            Capsule()
                .fill(Color.lullLine)
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .padding(.bottom, 24)

            // Icon + title
            HStack(spacing: 10) {
                Image(systemName: "flask")
                    .font(.system(size: 15))
                    .foregroundColor(.lullAmber)
                Text("Why this might work")
                    .font(.serif(20))
                    .foregroundColor(.lullInk0)
            }
            .padding(.bottom, 6)

            Text(remedyName)
                .font(.mono(11))
                .kerning(1.2)
                .foregroundColor(.lullAmberSoft)
                .padding(.bottom, 20)

            Text(scienceText)
                .font(.system(size: 14.5))
                .foregroundColor(.lullInk1)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(.horizontal, 26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.lullBg.ignoresSafeArea())
    }
}

struct ExperimentIconBtn: View {
    var systemImage: String
    var disabled: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13))
                .foregroundColor(disabled ? .lullInk4 : .lullInk1)
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.lullLine, lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
    }
}

// MARK: - Section Head

struct RoutineSectionHead: View {
    var title: String
    var eyebrow: String? = nil
    var sub: String? = nil
    var right: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title)
                        .font(.serif(18))
                        .fontWeight(.regular)
                        .foregroundColor(.lullInk0)
                    if let eyebrow {
                        Text("· \(eyebrow)")
                            .font(.mono(10))
                            .kerning(1.4)
                            .foregroundColor(.lullAmberSoft)
                    }
                }
                Spacer()
                if let right, !right.isEmpty {
                    Text(right)
                        .font(.mono(9.5))
                        .kerning(1.4)
                        .foregroundColor(.lullInk4)
                }
            }
            if let sub {
                Text(sub)
                    .font(.system(size: 12))
                    .foregroundColor(.lullInk3)
                    .lineSpacing(2)
            }
        }
    }
}

// MARK: - Drag Hint

struct DragHintLabel: View {
    var body: some View {
        HStack(spacing: 5) {
            Spacer()
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 9))
                .foregroundColor(.lullInk4)
            Text("DRAG TO REORDER")
                .font(.mono(9.5))
                .kerning(1.4)
                .foregroundColor(.lullInk4)
        }
    }
}

// MARK: - Prep List Row

struct PrepListRow: View {
    var step: RoutineStep
    var isExperiment: Bool
    var chip: String

    var body: some View {
        HStack(spacing: 12) {
            // Drag handle (shown by editMode)
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 13))
                .foregroundColor(.lullInk3)
                .frame(width: 20)

            Text(step.label)
                .font(.system(size: 14.5))
                .foregroundColor(.lullInk0)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(chip)
                .font(.mono(9.5))
                .kerning(0.8)
                .foregroundColor(isExperiment ? .lullAmber : .lullInk3)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(isExperiment ? Color.lullAmber.opacity(0.06) : Color.clear)
                        .overlay(
                            Capsule().strokeBorder(
                                isExperiment ? Color.lullAmber.opacity(0.35) : Color.lullLine,
                                lineWidth: 1
                            )
                        )
                )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isExperiment ? Color.lullAmber.opacity(0.06) : Color.white.opacity(0.025))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(
                            isExperiment ? Color.lullAmber.opacity(0.32) : Color.lullLine,
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - Ritual List Row

struct RitualListRow: View {
    var number: Int
    var step: RoutineStep

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 13))
                .foregroundColor(.lullInk3)
                .frame(width: 20)

            Text(step.label)
                .font(.system(size: 14.5))
                .foregroundColor(.lullInk0)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("IN SEQUENCE")
                .font(.mono(9))
                .kerning(1)
                .foregroundColor(.lullInk3)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .strokeBorder(Color.lullLine, lineWidth: 1)
                )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.025))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.lullLine, lineWidth: 1)
                )
        )
    }
}

// MARK: - Progress Dots Card

// MARK: - DotSlot

struct DotSlot {
    let date: Date
    let entry: SleepLogEntry?

    var isToday: Bool { Calendar.current.isDateInToday(date) }

    enum DotState { case inProgress, rated, unratedLocked, skipped, todayEmpty, future }

    var dotState: DotState {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        if date > todayStart { return .future }
        if cal.isDateInToday(date) && entry == nil { return .todayEmpty }
        guard let entry else { return .skipped }
        if entry.score > 0 { return .rated }
        return (cal.isDateInToday(date) || cal.isDateInYesterday(date)) ? .inProgress : .unratedLocked
    }
}

// MARK: - Progress Dots Card

struct ProgressDotsCard: View {
    var slots: [DotSlot]
    var sleepLogs: [SleepLogEntry]
    var onTap: (Int) -> Void
    var onTodayEmptyTap: () -> Void = {}

    private var loggedCount: Int { slots.filter { $0.dotState == .rated }.count }

    private var pastSlotCount: Int {
        let todayStart = Calendar.current.startOfDay(for: Date())
        return slots.filter { $0.date <= todayStart }.count
    }

    private var activeDotLabel: String? {
        let cal = Calendar.current
        if slots.contains(where: { $0.dotState == .inProgress && cal.isDateInYesterday($0.date) }) {
            return "last night · rate now"
        }
        if slots.contains(where: { $0.dotState == .inProgress && cal.isDateInToday($0.date) }) {
            return "tonight · live"
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                ForEach(Array(slots.enumerated()), id: \.offset) { _, slot in
                    let state = slot.dotState
                    let realIdx = slot.entry.flatMap { e in sleepLogs.firstIndex(where: { $0.id == e.id }) }
                    let showsAmberGlow = state == .inProgress || (slot.isToday && state != .todayEmpty)

                    VStack(spacing: 5) {
                        dotVisual(for: slot)
                            .shadow(color: showsAmberGlow ? .lullAmberGlow : .clear, radius: 6)
                        dotLabel(for: slot)
                    }
                    .onTapGesture {
                        if let idx = realIdx {
                            onTap(idx)
                        } else if state == .todayEmpty {
                            onTodayEmptyTap()
                        }
                    }
                    .allowsHitTesting(state != .skipped && state != .future)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 20)
            .padding(.bottom, 14)

            Divider()
                .background(Color.lullLine)
                .padding(.horizontal, 18)

            HStack {
                if let label = activeDotLabel {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color.lullAmber)
                            .frame(width: 6, height: 6)
                            .shadow(color: .lullAmberGlow, radius: 3)
                        Text(label)
                            .font(.mono(10.5))
                            .kerning(0.8)
                            .foregroundColor(.lullInk3)
                    }
                } else {
                    Spacer()
                }
                Spacer()
                Text("\(loggedCount) / \(pastSlotCount) logged")
                    .font(.mono(10.5))
                    .kerning(0.8)
                    .foregroundColor(.lullInk3)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.025))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.lullLine, lineWidth: 1))
        )
    }

    @ViewBuilder
    private func dotVisual(for slot: DotSlot) -> some View {
        let state = slot.dotState
        let showAmberRing = state == .inProgress || (slot.isToday && state != .todayEmpty)
        ZStack {
            // Fill layer
            switch state {
            case .inProgress:
                Circle()
                    .fill(Color.lullAmber.opacity(0.65))
                    .scaleEffect(0.45)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
            case .rated:
                Circle()
                    .fill(Color.lullAmber)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
            case .unratedLocked:
                Image(systemName: "circle.lefthalf.filled")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.lullInk3)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
            case .skipped, .todayEmpty:
                Circle()
                    .fill(Color.white.opacity(0.10))
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
            case .future:
                EmptyView()
            }

            // Ring layer
            if showAmberRing {
                Circle()
                    .strokeBorder(Color.lullAmber, lineWidth: 1.5)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
            } else if state == .todayEmpty {
                Circle()
                    .strokeBorder(Color.lullInk3.opacity(0.5), lineWidth: 1.5)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
            } else if state == .future {
                Circle()
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
            }
        }
    }

    @ViewBuilder
    private func dotLabel(for slot: DotSlot) -> some View {
        switch slot.dotState {
        case .rated:
            Text("\(slot.entry!.score)")
                .font(.mono(8))
                .foregroundColor(.lullInk3)
        case .inProgress, .unratedLocked, .todayEmpty:
            Text("·")
                .font(.mono(8))
                .foregroundColor(.lullInk3)
        case .skipped:
            Text("—")
                .font(.mono(8))
                .foregroundColor(.lullInk4)
        case .future:
            Text("–")
                .font(.mono(8))
                .foregroundColor(.lullInk4.opacity(0.4))
        }
    }
}

// MARK: - Section Header (legacy, kept for compatibility)

struct RoutineSectionHeader: View {
    var title: String
    var subtitle: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.lullInk1)
            if let subtitle {
                Text("· \(subtitle)")
                    .font(.serifItalic(13))
                    .foregroundColor(.lullInk3)
            }
            Spacer()
        }
    }
}

// MARK: - Candidate Picker Sheet

struct CandidatePickerSheet: View {
    var candidates: [String]
    var suggestedVariable: String? = nil
    var currentVariable: String = ""
    var onSelect: (String) -> Void
    @Environment(\.dismiss) var dismiss

    private var surfacedSuggestion: String? {
        guard let s = suggestedVariable,
              s != currentVariable,
              candidates.contains(s) else { return nil }
        return s
    }

    private var otherCandidates: [String] {
        candidates.filter { $0 != surfacedSuggestion }
    }

    var body: some View {
        LullScreen(glow: false) {
            VStack(spacing: 0) {
                HStack {
                    Text("PICK NEXT VARIABLE")
                        .font(.mono(10.5)).kerning(1.4).foregroundColor(.lullInk4)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14)).foregroundColor(.lullInk3)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 20)

                Text("Choose what to test next. Lull will track it for 5 nights and tell you if it moves the needle.")
                    .font(.system(size: 13.5))
                    .foregroundColor(.lullInk3)
                    .lineSpacing(3)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        if let suggestion = surfacedSuggestion {
                            Text("LULL'S PICK")
                                .font(.mono(9)).kerning(1.4)
                                .foregroundColor(.lullAmberSoft)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 22)
                                .padding(.bottom, 10)

                            Button(action: { onSelect(suggestion) }) {
                                HStack(spacing: 14) {
                                    Ember(size: 5)
                                    Text(suggestion)
                                        .font(.system(size: 15))
                                        .foregroundColor(.lullInk0)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                    Text("›")
                                        .font(.system(size: 20, weight: .light))
                                        .foregroundColor(.lullAmber)
                                }
                                .padding(.horizontal, 20).padding(.vertical, 18)
                                .background(RoundedRectangle(cornerRadius: 16).fill(Color.lullAmber.opacity(0.06)))
                                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.lullAmber.opacity(0.3), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 22)
                            .padding(.bottom, 24)

                            if !otherCandidates.isEmpty {
                                Text("ALL OPTIONS")
                                    .font(.mono(9)).kerning(1.4)
                                    .foregroundColor(.lullInk4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 22)
                                    .padding(.bottom, 10)
                            }
                        }

                        VStack(spacing: 10) {
                            ForEach(otherCandidates, id: \.self) { candidate in
                                Button(action: { onSelect(candidate) }) {
                                    HStack(spacing: 14) {
                                        Ember(size: 5)
                                        Text(candidate)
                                            .font(.system(size: 15))
                                            .foregroundColor(.lullInk0)
                                            .multilineTextAlignment(.leading)
                                        Spacer()
                                        Text("›")
                                            .font(.system(size: 20, weight: .light))
                                            .foregroundColor(.lullInk3)
                                    }
                                    .padding(.horizontal, 20).padding(.vertical, 18)
                                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.025)))
                                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.lullLine, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 22)
                    }
                }
            }
        }
    }
}

// MARK: - Export Data Footer

struct ExportDataFooter: View {
    @EnvironmentObject var state: AppState
    @State private var showResult = false
    @State private var resultMessage = ""

    private static let relativeFmt: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    private var statusLine: String {
        if state.isExporting { return "Sending…" }
        if let err = state.lastExportError { return "Last attempt failed · \(err)" }
        if let last = state.lastExportDate {
            return "Last sent \(ExportDataFooter.relativeFmt.localizedString(for: last, relativeTo: Date()))"
        }
        return "Never sent · helps us improve the app"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "paperplane")
                    .font(.system(size: 13))
                    .foregroundColor(.lullAmberSoft)
                    .frame(width: 18, height: 18)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Help us improve Lull")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.lullInk1)
                    Text("Send your anonymous sleep data to the Lull team. No name, no email — just a random ID.")
                        .font(.system(size: 12))
                        .foregroundColor(.lullInk3)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack {
                Text(statusLine)
                    .font(.mono(10))
                    .kerning(0.8)
                    .foregroundColor(state.lastExportError == nil ? .lullInk4 : .lullAmberSoft)
                Spacer()
                Button {
                    state.exportData()
                } label: {
                    HStack(spacing: 6) {
                        if state.isExporting {
                            ProgressView()
                                .scaleEffect(0.6)
                                .tint(.lullAmber)
                        }
                        Text(state.isExporting ? "Sending" : "Send now")
                            .font(.mono(11))
                            .kerning(1)
                            .foregroundColor(.lullAmber)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.lullAmber.opacity(0.10))
                            .overlay(Capsule().strokeBorder(Color.lullAmber.opacity(0.3), lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)
                .disabled(state.isExporting)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.025))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.lullLine, lineWidth: 1))
        )
    }
}
