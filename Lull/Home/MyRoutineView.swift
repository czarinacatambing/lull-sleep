import SwiftUI

struct MyRoutineView: View {
    @EnvironmentObject var state: AppState
    @State private var showChangeConfirm = false
    @State private var showCandidatePicker = false
    @State private var pendingCandidate: String? = nil

    private var candidates: [String] {
        let inRoutine = Set(state.coreRoutine.map(\.label))
        return allBedroomPrepRemedies.filter { !inRoutine.contains($0) }
    }

    private var avgScoreText: String? {
        let scored = state.sleepLogs.filter { $0.score > 0 }
        guard !scored.isEmpty else { return nil }
        let avg = Double(scored.map(\.score).reduce(0, +)) / Double(scored.count)
        return String(format: "AVG %.1f", avg)
    }

    // Pads or trims sleep log entries to exactly 14 display slots.
    // Slots with nil represent days with no data (shown as skeleton dots).
    private var displaySlots: [SleepLogEntry?] {
        let logs = state.sleepLogs
        if logs.count >= 14 {
            return logs.suffix(14).map { Optional($0) }
        } else {
            let padding: [SleepLogEntry?] = Array(repeating: nil, count: 14 - logs.count)
            return padding + logs.map { Optional($0) }
        }
    }

    // Looks up the scheduled badge for a step from the canonical AppState schedule.
    private func badgeText(for step: RoutineStep) -> String {
        state.scheduledRoutine.first { $0.step.id == step.id }?.badge ?? step.mode.label
    }

    var body: some View {
        LullScreen(glow: false) {
            AmberGlow(x: 0.8, y: -0.1, radius: 210, opacity: 0.45)
                .ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 16)

                    // Header
                    VStack(alignment: .leading, spacing: 6) {
                        Kicker(text: "Your routine")
                        Text("My Routine")
                            .font(.serif(26))
                            .foregroundColor(.lullInk0)
                    }
                    .padding(.horizontal, Lull.horizontalPad)
                    .padding(.bottom, 16)

                    // Tonight's variable
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Kicker(text: "Tonight's variable", color: .lullAmberSoft)
                            Text(state.tonightVariable)
                                .font(.serifItalic(17))
                                .foregroundColor(.lullInk0)
                            HStack(spacing: 0) {
                                Text("Night \(state.variableNight) of 5  ·  ")
                                    .font(.system(size: 12))
                                    .foregroundColor(.lullInk2)
                                Text(state.variableScore)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.lullAmber)
                            }
                        }
                        Spacer()
                        Button(action: {
                            if state.variableNight > 0 {
                                showChangeConfirm = true
                            } else {
                                showCandidatePicker = true
                            }
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.lullBg.opacity(0.6))
                                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.lullLine, lineWidth: 1))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 14))
                                    .foregroundColor(.lullInk2)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(18)
                    .lullCard(radius: 20, accent: true)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 24)
                    .alert("Change experiment?", isPresented: $showChangeConfirm) {
                        Button("Keep testing") { }
                        Button("Yes, change it", role: .destructive) { showCandidatePicker = true }
                    } message: {
                        Text("You've only tested \"\(state.tonightVariable)\" for \(state.variableNight) night\(state.variableNight == 1 ? "" : "s"). Switching now means losing that data.")
                    }
                    .sheet(isPresented: $showCandidatePicker) {
                        CandidatePickerSheet(candidates: candidates) { chosen in
                            state.changeExperimentVariable(to: chosen)
                            showCandidatePicker = false
                        }
                    }

                    // Pre-Wind Down section
                    RoutineSectionHeader(title: "Pre-Wind Down")
                        .padding(.horizontal, 22)
                        .padding(.bottom, 10)

                    VStack(spacing: 0) {
                        ForEach(Array(state.preWindDownSteps.enumerated()), id: \.element.id) { i, step in
                            PreWindDownRow(
                                step: step,
                                badgeText: badgeText(for: step)
                            )
                            if i < state.preWindDownSteps.count - 1 {
                                Divider()
                                    .background(Color.lullLine)
                                    .padding(.leading, 36)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .lullCard(radius: 16)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 24)

                    // Wind Down section
                    RoutineSectionHeader(title: "Wind Down", subtitle: "The Ritual")
                        .padding(.horizontal, 22)
                        .padding(.bottom, 10)

                    VStack(spacing: 0) {
                        ForEach(Array(state.windDownSteps.enumerated()), id: \.element.id) { i, step in
                            WindDownRow(number: i + 1, step: step)
                            if i < state.windDownSteps.count - 1 {
                                Divider()
                                    .background(Color.lullLine)
                                    .padding(.leading, 52)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .lullCard(radius: 16)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 28)

                    // Section divider
                    HStack(spacing: 12) {
                        Rectangle()
                            .fill(Color.lullLine)
                            .frame(height: 1)
                        Text("SLEEP HISTORY")
                            .font(.mono(9))
                            .kerning(1.4)
                            .foregroundColor(.lullInk4)
                            .fixedSize()
                        Rectangle()
                            .fill(Color.lullLine)
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 24)

                    // History dots — oldest on left, today on right
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Kicker(text: "Last 14 nights")
                            Spacer()
                            if let avg = avgScoreText {
                                Text(avg)
                                    .font(.mono(10))
                                    .kerning(1)
                                    .foregroundColor(.lullInk3)
                            }
                        }

                        HStack(spacing: 6) {
                            ForEach(Array(displaySlots.enumerated()), id: \.offset) { _, maybeEntry in
                                if let entry = maybeEntry {
                                    let isToday = entry.isToday
                                    let rated   = entry.score > 0
                                    let realIdx = state.sleepLogs.firstIndex(where: { $0.id == entry.id })
                                    VStack(spacing: 4) {
                                        ZStack {
                                            if isToday {
                                                // Outer ring
                                                Circle()
                                                    .strokeBorder(Color.lullAmber, lineWidth: 1.5)
                                                    .frame(maxWidth: .infinity)
                                                    .aspectRatio(1, contentMode: .fit)
                                                // Inner filled dot
                                                Circle()
                                                    .fill(Color.lullAmber)
                                                    .scaleEffect(0.38)
                                            } else {
                                                // Solid amber for scored past days
                                                Circle()
                                                    .fill(Color.lullAmber.opacity(0.65))
                                                    .frame(maxWidth: .infinity)
                                                    .aspectRatio(1, contentMode: .fit)
                                            }
                                        }
                                        .shadow(color: isToday ? .lullAmberGlow : .clear, radius: 6)
                                        Text(rated ? "\(entry.score)" : "·")
                                            .font(.mono(8))
                                            .foregroundColor(isToday ? .lullAmber : .lullInk3)
                                    }
                                    .onTapGesture {
                                        if let idx = realIdx { state.selectedDotIndex = idx }
                                    }
                                } else {
                                    // Skeleton — no data for this day
                                    VStack(spacing: 4) {
                                        Circle()
                                            .fill(Color.white.opacity(0.06))
                                            .frame(maxWidth: .infinity)
                                            .aspectRatio(1, contentMode: .fit)
                                        Text("·")
                                            .font(.mono(8))
                                            .foregroundColor(.lullInk4)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 36)
                }
            }
        }
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
    }
}

// MARK: - Section Header

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

// MARK: - Pre-Wind Down Row (reminder / experiment steps)

struct PreWindDownRow: View {
    var step: RoutineStep
    var badgeText: String

    private var isExperiment: Bool { step.mode == .experiment }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(isExperiment ? Color.lullAmber.opacity(0.7) : Color.lullInk3.opacity(0.4))
                .frame(width: 5, height: 5)
                .padding(.leading, 16)

            Text(step.label)
                .font(.system(size: 14))
                .foregroundColor(.lullInk0)

            Spacer()

            Text(badgeText)
                .font(.mono(9.5))
                .kerning(0.8)
                .foregroundColor(isExperiment ? .lullAmberSoft : .lullInk3)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(isExperiment ? Color.lullAmber.opacity(0.1) : Color.white.opacity(0.04))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(isExperiment ? Color.lullAmber.opacity(0.3) : Color.lullLine, lineWidth: 1)
                )
                .padding(.trailing, 14)
        }
        .padding(.vertical, 13)
    }
}

// MARK: - Wind Down Row (in-sequence steps)

struct WindDownRow: View {
    var number: Int
    var step: RoutineStep

    var body: some View {
        HStack(spacing: 14) {
            Text("\(number)")
                .font(.mono(12))
                .foregroundColor(.lullAmber)
                .frame(width: 20, alignment: .center)
                .padding(.leading, 16)

            Text(step.label)
                .font(.system(size: 14))
                .foregroundColor(.lullInk0)

            Spacer()

            Text("IN SEQUENCE")
                .font(.mono(9))
                .kerning(1)
                .foregroundColor(.lullInk3)
                .padding(.trailing, 14)
        }
        .padding(.vertical, 13)
    }
}

// MARK: - Candidate Picker Sheet

struct CandidatePickerSheet: View {
    var candidates: [String]
    var onSelect: (String) -> Void
    @Environment(\.dismiss) var dismiss

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
                    VStack(spacing: 10) {
                        ForEach(candidates, id: \.self) { candidate in
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
