import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var state: AppState
    @Binding var selectedTab: Int
    @State private var showMenu = false
    @State private var currentDate = Date()
    @State private var glowPulse = false

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEEE · h:mm a"; return f
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

    private var prepSteps: [RoutineStep] { state.preWindDownSteps }
    private var ritualSteps: [RoutineStep] { state.windDownSteps }

    private var prepDoneCount: Int {
        prepSteps.filter { state.prepDoneIds.contains($0.id) }.count
    }
    private var allPrepDone: Bool { prepDoneCount == prepSteps.count && !prepSteps.isEmpty }

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

                        // Top bar
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
                        .padding(.horizontal, Lull.horizontalPad)
                        .padding(.bottom, 8)

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

                        // Prep checklist card
                        prepChecklistCard
                            .padding(.horizontal, 22)
                            .padding(.bottom, 16)

                        // Tonight's ritual hero
                        ritualHeroCard
                            .padding(.horizontal, 22)
                            .padding(.bottom, 24)

                        // The ritual · in sequence
                        ritualSequenceSection
                            .padding(.horizontal, 24)
                            .padding(.bottom, 36)
                    }
                }
            }
            .fullScreenCover(isPresented: $state.showNightlyFlow) {
                NightlyFlowView()
            }
            .onAppear {
                currentDate = Date()
                state.resetPrepIfNeeded()
                withAnimation(.easeInOut(duration: 4.5).repeatForever(autoreverses: true)) {
                    glowPulse = true
                }
            }

            // Menu overlay
            if showMenu {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation(.easeOut(duration: 0.18)) { showMenu = false } }

                VStack(alignment: .trailing, spacing: 0) {
                    Button(action: {
                        withAnimation(.easeOut(duration: 0.18)) { showMenu = false }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            state.showMidSleepMode = true
                        }
                    }) {
                        HStack(spacing: 12) {
                            Ember(size: 5)
                            Text("Mid-Sleep Mode")
                                .font(.system(size: 14))
                                .foregroundColor(.lullInk1)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                }
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(hex: "#1a1310"))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.lullLine, lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.5), radius: 16, y: 8)
                )
                .frame(width: 190)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 68)
                .padding(.trailing, 22)
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topTrailing)))
                .zIndex(10)
            }
        }
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
        let hasExperiment = state.experimentStatus != nil

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
                    Kicker(text: hasExperiment ? "Tonight's experiment" : "Tonight's ritual",
                           color: .lullAmberSoft)
                    Spacer()
                    if hasExperiment {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.lullAmber)
                                .frame(width: 6, height: 6)
                                .shadow(color: .lullAmberGlow, radius: 4)
                                .opacity(glowPulse ? 1.0 : 0.55)
                            Text("ACTIVE TEST")
                                .font(.mono(9.5))
                                .kerning(1.4)
                                .foregroundColor(.lullAmber)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.lullAmber.opacity(0.14)))
                        .overlay(Capsule().strokeBorder(Color.lullAmber.opacity(0.4), lineWidth: 1))
                    }
                }

                // Title
                Text(state.tonightVariable)
                    .font(.serif(26))
                    .foregroundColor(.lullInk0)
                    .padding(.top, 10)

                // Night progress
                if hasExperiment {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Night ")
                                .font(.mono(11))
                                .foregroundColor(.lullInk2)
                            + Text("\(state.variableNight)")
                                .font(.mono(11))
                                .foregroundColor(.lullAmber)
                            + Text(" of 5")
                                .font(.mono(11))
                                .foregroundColor(.lullInk2)
                            Spacer()
                            Text("\(5 - state.variableNight) testing nights left")
                                .font(.mono(10.5))
                                .foregroundColor(.lullInk3)
                        }
                        HStack(spacing: 4) {
                            ForEach(0..<5, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 99)
                                    .fill(i < state.variableNight ? Color.lullAmber : Color.lullAmber.opacity(0.14))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 4)
                                    .shadow(color: i < state.variableNight ? .lullAmberGlow : .clear, radius: 4)
                            }
                        }
                    }
                    .padding(.top, 14)
                }

                // Description
                Text("We're testing if this helps you fall asleep faster. ")
                    .foregroundColor(.lullInk1)
                + Text("Rate it tomorrow morning.")
                    .foregroundColor(.lullInk2)

                // Sub-copy
                Text(allPrepDone
                     ? "Prep complete. Ready to start the wind-down sequence whenever you are."
                     : "Finish prep first (\(remaining) left), then we'll start the wind-down sequence.")
                    .font(.system(size: 12.5))
                    .foregroundColor(.lullInk2)
                    .lineSpacing(3)
                    .padding(.top, 4)

                // CTA
                PrimaryCTA(title: allPrepDone ? "Start ritual" : "Finish prep · \(remaining) left") {
                    state.showNightlyFlow = true
                }
                .disabled(!allPrepDone)
                .opacity(allPrepDone ? 1 : 0.45)
                .padding(.top, 18)
            }
            .font(.system(size: 13))
            .padding(22)
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
            HStack {
                Kicker(text: "The ritual · in sequence")
                Spacer()
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
                    HStack(spacing: 12) {
                        Text(scheduledTime(for: step))
                            .font(.mono(11))
                            .foregroundColor(.lullInk3)
                            .frame(width: 38, alignment: .leading)
                        Ember(size: 4)
                        Text(step.label)
                            .font(.system(size: 13.5))
                            .foregroundColor(.lullInk1)
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

                // Sleep target row
                HStack(spacing: 12) {
                    Text({
                        let f = DateFormatter(); f.dateFormat = "h:mm"
                        return f.string(from: state.typicalBedtime)
                    }())
                    .font(.mono(11))
                    .foregroundColor(.lullInk3)
                    .frame(width: 38, alignment: .leading)
                    Ember(size: 4)
                    Text("Sleep")
                        .font(.system(size: 13.5))
                        .foregroundColor(.lullInk1)
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
}
