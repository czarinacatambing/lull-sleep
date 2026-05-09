import SwiftUI

struct MyRoutineView: View {
    @EnvironmentObject var state: AppState
    @State private var showChangeConfirm = false
    @State private var showCandidatePicker = false
    @State private var heroGlow = false
    @AppStorage("routineCoachMarkCount") private var coachMarkCount = 0
    @State private var showCoachMark = false

    // MARK: - Computed

    private var candidates: [String] {
        let inRoutine = Set(state.coreRoutine.map(\.label))
        return allBedroomPrepRemedies.filter { !inRoutine.contains($0) }
    }

    private var suggestedVariable: String? {
        ExperimentEngine.suggestNextVariable(
            logs: state.sleepLogs,
            coreRoutine: state.coreRoutine.filter { $0.mode != .experiment },
            remedyScores: state.remedyScores
        )
    }

    private var avgScoreText: String? {
        let scored = state.sleepLogs.filter { $0.score > 0 }
        guard !scored.isEmpty else { return nil }
        let avg = Double(scored.map(\.score).reduce(0, +)) / Double(scored.count)
        return String(format: "AVG %.1f", avg)
    }

    private var displaySlots: [SleepLogEntry?] {
        let logs = state.sleepLogs
        if logs.count >= 14 { return logs.suffix(14).map { Optional($0) } }
        return Array(repeating: nil, count: 14 - logs.count) + logs.map { Optional($0) }
    }

    private func badgeText(for step: RoutineStep) -> String {
        state.scheduledRoutine.first { $0.step.id == step.id }?.badge ?? step.mode.label
    }

    private func expectedImpact(for label: String) -> String? {
        let map: [String: String] = [
            "Dim the lights":        "Triggers melatonin production roughly 90 min early.",
            "Warm shower or bath":   "Post-shower temperature drop is one of the strongest sleep-onset cues.",
            "Cold room prep":        "Cooler rooms (65–68°F) are linked to deeper, longer sleep.",
            "No screens":            "Blue light delays melatonin release by up to 90 minutes.",
            "No caffeine":           "Caffeine's half-life is 5–6 hours — it lingers longer than it feels.",
            "No heavy snacks":       "Digestion competes with sleep — a quiet gut helps.",
            "Herbal tea":            "The ritual and mild calming compounds both signal wind-down.",
            "Magnesium glycinate":   "Shown to improve sleep quality in randomised controlled trials.",
            "Brain Dump":            "Offloading worries before bed reduces racing-mind episodes.",
            "4-7-8 Breathing":       "Activates the parasympathetic nervous system within 2–3 cycles.",
            "Boring Story":          "Passive listening disengages the planning mind gently.",
            "Weighted blanket":      "Deep pressure stimulation activates the parasympathetic system.",
            "Finish workouts":       "Late exercise raises core temperature, delaying sleep onset.",
            "App blocking":          "Removes the scroll reflex so wind-down actually happens.",
            "No alcohol":            "Alcohol fragments sleep architecture in the second half of the night.",
        ]
        return map[label]
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            LullScreen(glow: false) {
                AmberGlow(x: 0.8, y: -0.1, radius: 210, opacity: 0.45)
                    .ignoresSafeArea()

                List {
                    // ── Header ─────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 6) {
                        Spacer().frame(height: 8)
                        Kicker(text: "Your routine")
                        Text("My Sleep System")
                            .font(.serif(26))
                            .foregroundColor(.lullInk0)
                        Text("Build your experiment. Test one change at a time. Watch your sleep improve.")
                            .font(.system(size: 12.5))
                            .foregroundColor(.lullAmberSoft)
                            .lineSpacing(3)
                            .padding(.top, 2)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: Lull.horizontalPad, bottom: 20, trailing: Lull.horizontalPad))

                    // ── Tonight's Experiment (hero card) ───────────────
                    ZStack(alignment: .topTrailing) {
                        // Pulsing ambient glow
                        Circle()
                            .fill(Color.lullAmberGlow.opacity(heroGlow ? 0.20 : 0.06))
                            .frame(width: 240)
                            .blur(radius: 45)
                            .offset(x: 40, y: -20)
                            .allowsHitTesting(false)
                            .animation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true), value: heroGlow)

                        HStack(alignment: .top, spacing: 0) {
                            VStack(alignment: .leading, spacing: 9) {
                                // Kicker + badge
                                HStack(spacing: 8) {
                                    Kicker(text: "Tonight's Experiment", color: .lullAmberSoft)
                                    Spacer()
                                    Text("ACTIVE TEST")
                                        .font(.mono(7.5))
                                        .kerning(1)
                                        .foregroundColor(.lullAmber)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(Color.lullAmber.opacity(0.12)))
                                        .overlay(Capsule().strokeBorder(Color.lullAmber.opacity(0.4), lineWidth: 1))
                                }

                                Text(state.tonightVariable)
                                    .font(.serifItalic(20))
                                    .foregroundColor(.lullInk0)

                                // Night counter + progress bar
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack(spacing: 0) {
                                        Text("Night \(state.variableNight) of 5  ·  ")
                                            .font(.system(size: 12))
                                            .foregroundColor(.lullInk2)
                                        Text(state.variableScore)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.lullAmber)
                                    }
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(Color.lullAmber.opacity(0.15))
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(Color.lullAmber.opacity(0.75))
                                                .frame(width: geo.size.width * min(1.0, Double(state.variableNight) / 5.0))
                                        }
                                        .frame(height: 3)
                                    }
                                    .frame(height: 3)
                                }

                                Text("We're testing if this improves your sleep. Rate it tomorrow morning.")
                                    .font(.system(size: 11.5))
                                    .foregroundColor(.lullInk3)
                                    .lineSpacing(2)

                                // Expected impact
                                if let impact = expectedImpact(for: state.tonightVariable) {
                                    HStack(spacing: 5) {
                                        Image(systemName: "waveform.path.ecg")
                                            .font(.system(size: 9))
                                            .foregroundColor(.lullAmberSoft)
                                        Text(impact)
                                            .font(.system(size: 11))
                                            .foregroundColor(.lullInk3)
                                            .lineSpacing(2)
                                    }
                                }

                                // Override hint
                                if let suggestion = suggestedVariable, suggestion != state.tonightVariable {
                                    Text("Lull suggests: \(suggestion)")
                                        .font(.system(size: 11.5))
                                        .foregroundColor(.lullInk3)
                                }
                            }

                            // Swap button
                            Button(action: {
                                if state.variableNight > 0 { showChangeConfirm = true }
                                else { showCandidatePicker = true }
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
                            .padding(.leading, 12)
                        }
                        .padding(18)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.lullAmber.opacity(0.07))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .strokeBorder(Color.lullAmber.opacity(heroGlow ? 0.35 : 0.20), lineWidth: 1)
                            )
                    )
                    .shadow(color: Color.lullAmberGlow.opacity(heroGlow ? 0.28 : 0.08), radius: 20, y: 8)
                    .animation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true), value: heroGlow)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 22, bottom: 0, trailing: 22))
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

                    // ── Prep Checklist ─────────────────────────────────
                    Section {
                        ForEach(Array(state.preWindDownSteps.enumerated()), id: \.element.id) { i, step in
                            PrepRow(index: i + 1, step: step, badgeText: badgeText(for: step))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 3, leading: 22, bottom: 3, trailing: 22))
                        }
                        .onMove { state.movePreWindDown(from: $0, to: $1) }

                        Text("drag to reorder")
                            .font(.system(size: 10))
                            .foregroundColor(.lullInk4)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 0, leading: 22, bottom: 4, trailing: 10))
                    } header: {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("Prep Checklist")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.lullInk1)
                                Text("· Start Here")
                                    .font(.serifItalic(13))
                                    .foregroundColor(.lullInk3)
                            }
                            Text("Do these 30–75 min before bed")
                                .font(.system(size: 11))
                                .foregroundColor(.lullInk4)
                        }
                        .textCase(nil)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 20)
                        .padding(.bottom, 8)
                    }
                    .listSectionSeparator(.hidden)

                    // ── Bedtime Ritual ─────────────────────────────────
                    Section {
                        ForEach(Array(state.windDownSteps.enumerated()), id: \.element.id) { i, step in
                            RitualRow(number: i + 1, step: step)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 3, leading: 22, bottom: 3, trailing: 22))
                        }
                        .onMove { state.moveWindDown(from: $0, to: $1) }

                        Text("drag to reorder")
                            .font(.system(size: 10))
                            .foregroundColor(.lullInk4)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 0, leading: 22, bottom: 4, trailing: 10))
                    } header: {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("Bedtime Ritual")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.lullInk1)
                                Text("· In Sequence")
                                    .font(.serifItalic(13))
                                    .foregroundColor(.lullInk3)
                            }
                            Text("Follow in order when you're getting into bed")
                                .font(.system(size: 11))
                                .foregroundColor(.lullInk4)
                        }
                        .textCase(nil)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 20)
                        .padding(.bottom, 8)
                    }
                    .listSectionSeparator(.hidden)

                    // ── Progress Divider ───────────────────────────────
                    HStack(spacing: 12) {
                        Rectangle().fill(Color.lullLine).frame(height: 1)
                        Text("YOUR PROGRESS")
                            .font(.mono(9)).kerning(1.4).foregroundColor(.lullInk4).fixedSize()
                        Rectangle().fill(Color.lullLine).frame(height: 1)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 20, leading: 22, bottom: 20, trailing: 22))

                    // ── Sleep History ──────────────────────────────────
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Kicker(text: "Last 14 nights")
                            Spacer()
                            if let avg = avgScoreText {
                                Text(avg)
                                    .font(.mono(10)).kerning(1).foregroundColor(.lullInk3)
                            }
                        }
                        Text("Tap any night for details.")
                            .font(.system(size: 11))
                            .foregroundColor(.lullInk4)
                            .padding(.top, -6)

                        HStack(spacing: 6) {
                            ForEach(Array(displaySlots.enumerated()), id: \.offset) { _, maybeEntry in
                                if let entry = maybeEntry {
                                    let isToday = entry.isToday
                                    let rated = entry.score > 0
                                    let realIdx = state.sleepLogs.firstIndex(where: { $0.id == entry.id })
                                    VStack(spacing: 4) {
                                        ZStack {
                                            if isToday {
                                                Circle()
                                                    .strokeBorder(Color.lullAmber, lineWidth: 1.5)
                                                    .frame(maxWidth: .infinity)
                                                    .aspectRatio(1, contentMode: .fit)
                                                Circle().fill(Color.lullAmber).scaleEffect(0.38)
                                            } else {
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
                                    VStack(spacing: 4) {
                                        Circle()
                                            .fill(Color.white.opacity(0.06))
                                            .frame(maxWidth: .infinity)
                                            .aspectRatio(1, contentMode: .fit)
                                        Text("·").font(.mono(8)).foregroundColor(.lullInk4)
                                    }
                                }
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 22, bottom: 40, trailing: 22))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.editMode, .constant(.active))
                .fullScreenCover(isPresented: $state.showNightlyFlow) { NightlyFlowView() }
                .sheet(isPresented: Binding(
                    get: { state.selectedDotIndex != nil },
                    set: { if !$0 { state.selectedDotIndex = nil } }
                )) {
                    if let index = state.selectedDotIndex { SleepLogDetailView(entryIndex: index) }
                }
            }

            // ── First-visit coach mark ─────────────────────────────
            if showCoachMark {
                Color.black.opacity(0.65)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { showCoachMark = false } }

                VStack {
                    Spacer()
                    VStack(alignment: .leading, spacing: 16) {
                        Text("This is your sleep lab.")
                            .font(.serif(22))
                            .foregroundColor(.lullInk0)
                        Text("Test one change at a time. Rate your sleep each morning. See what actually works for you.")
                            .font(.system(size: 14))
                            .foregroundColor(.lullInk2)
                            .lineSpacing(4)
                        Button(action: { withAnimation(.easeOut(duration: 0.2)) { showCoachMark = false } }) {
                            Text("Got it →")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.lullBg)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(RoundedRectangle(cornerRadius: 16).fill(Color.lullAmber))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(28)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color(hex: "#1a1310"))
                            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Color.lullLine, lineWidth: 1))
                    )
                    .shadow(color: Color.black.opacity(0.5), radius: 30, y: 10)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 52)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .zIndex(20)
            }
        }
        .onAppear {
            heroGlow = true
            if coachMarkCount < 3 {
                coachMarkCount += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.spring(response: 0.4)) { showCoachMark = true }
                }
            }
        }
    }
}

// MARK: - Prep Row

struct PrepRow: View {
    var index: Int
    var step: RoutineStep
    var badgeText: String

    private var isExperiment: Bool { step.mode == .experiment }

    var body: some View {
        HStack(spacing: 12) {
            Text(String(format: "%02d", index))
                .font(.mono(11))
                .foregroundColor(isExperiment ? .lullAmber : .lullInk3)
                .frame(width: 22, alignment: .leading)

            Text(step.label)
                .font(.system(size: 14))
                .foregroundColor(.lullInk0)

            Spacer()

            Text(badgeText)
                .font(.mono(9))
                .kerning(0.8)
                .foregroundColor(isExperiment ? .lullAmberSoft : .lullInk3)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(isExperiment ? Color.lullAmber.opacity(0.1) : Color.white.opacity(0.04)))
                .overlay(Capsule().strokeBorder(isExperiment ? Color.lullAmber.opacity(0.3) : Color.lullLine, lineWidth: 1))
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isExperiment ? Color.lullAmber.opacity(0.05) : Color.white.opacity(0.025))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isExperiment ? Color.lullAmber.opacity(0.3) : Color.lullLine, lineWidth: 1))
        )
    }
}

// MARK: - Ritual Row

struct RitualRow: View {
    var number: Int
    var step: RoutineStep

    var body: some View {
        HStack(spacing: 14) {
            Text(String(format: "%02d", number))
                .font(.mono(11))
                .foregroundColor(.lullAmber)
                .frame(width: 22, alignment: .leading)

            Text(step.label)
                .font(.system(size: 14))
                .foregroundColor(.lullInk0)

            Spacer()

            Text("IN SEQUENCE")
                .font(.mono(9))
                .kerning(1)
                .foregroundColor(.lullInk3)
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.025))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.lullLine, lineWidth: 1))
        )
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
