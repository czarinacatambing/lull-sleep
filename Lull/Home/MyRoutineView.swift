import SwiftUI

struct MyRoutineView: View {
    @EnvironmentObject var state: AppState

    private var preWindDownSteps: [RoutineStep] {
        state.coreRoutine.filter { $0.mode == .reminderOnly || $0.mode == .experiment }
    }

    private var windDownSteps: [RoutineStep] {
        state.coreRoutine.filter { $0.mode == .inSequence }
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

                    // Start CTA
                    Button(action: { state.showNightlyFlow = true }) {
                        HStack(spacing: 10) {
                            Image(systemName: "moon.stars.fill")
                                .font(.system(size: 14))
                            Text("Start Tonight's Routine")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(Color(hex: "#0c0807"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(LinearGradient(
                                    colors: [Color.lullAmber, Color(hex: "#c8923a")],
                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                        )
                        .shadow(color: Color.lullAmberGlow.opacity(0.5), radius: 12, y: 4)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 20)

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
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(hex: "#0c0807").opacity(0.6))
                                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.lullLine, lineWidth: 1))
                                .frame(width: 44, height: 44)
                            Ember(size: 10)
                        }
                    }
                    .padding(18)
                    .lullCard(radius: 20, accent: true)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 24)

                    // Pre-Wind Down section
                    RoutineSectionHeader(title: "Pre-Wind Down")
                        .padding(.horizontal, 22)
                        .padding(.bottom, 10)

                    VStack(spacing: 0) {
                        ForEach(Array(preWindDownSteps.enumerated()), id: \.element.id) { i, step in
                            PreWindDownRow(
                                step: step,
                                badgeText: badgeText(for: step)
                            )
                            if i < preWindDownSteps.count - 1 {
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
                        ForEach(Array(windDownSteps.enumerated()), id: \.element.id) { i, step in
                            WindDownRow(number: i + 1, step: step)
                            if i < windDownSteps.count - 1 {
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

                    // History dots
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Kicker(text: "Last 14 nights")
                            Spacer()
                            Text("AVG 7.2")
                                .font(.mono(10))
                                .kerning(1)
                                .foregroundColor(.lullInk3)
                        }

                        HStack(spacing: 6) {
                            ForEach(Array(state.sleepLogs.enumerated()), id: \.offset) { i, entry in
                                let isToday = entry.isToday
                                let unrated = isToday && entry.score == 0
                                VStack(spacing: 4) {
                                    Circle()
                                        .fill(isToday
                                            ? AnyShapeStyle(RadialGradient(colors: [.lullAmber, .lullAmberDeep], center: .center, startRadius: 0, endRadius: 10))
                                            : AnyShapeStyle(Color.lullAmber.opacity(0.3 + Double(entry.score) * 0.05)))
                                        .frame(maxWidth: .infinity)
                                        .aspectRatio(1, contentMode: .fit)
                                        .shadow(color: isToday ? .lullAmberGlow : .clear, radius: 7)
                                        .overlay(
                                            isToday ? Circle().strokeBorder(Color.lullAmber.opacity(0.6), lineWidth: 1.5) : nil
                                        )
                                    Text(unrated ? "·" : "\(entry.score)")
                                        .font(.mono(8))
                                        .foregroundColor(isToday ? .lullAmber : .lullInk4)
                                }
                                .onTapGesture { state.selectedDotIndex = i }
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
