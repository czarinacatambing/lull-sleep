import SwiftUI

// Onboarding coordinator — 6 screens plus the Routine Ready payoff.
struct OnboardingView: View {
    @EnvironmentObject var state: AppState
    @State private var step = 1

    var body: some View {
        ZStack {
            switch step {
            case 1: OnbSleepProblemView(step: $step)
            case 2: OnbWhatWakesView(step: $step)
            case 3: OnbBaselineRatingView(step: $step)
            case 4: OnbBedtimeView(step: $step)
            case 5: OnbPreBedView(step: $step)
            case 6: OnbTriedView(step: $step)
            case 7: OnbRoutineReadyView()
            default: EmptyView()
            }
        }
        .animation(step == 7 ? .easeInOut(duration: 0.7) : .easeInOut(duration: 0.28), value: step)
        .transition(.opacity)
    }
}

// MARK: - Screen 1: Sleep Problem

struct OnbSleepProblemView: View {
    @Binding var step: Int
    @EnvironmentObject var state: AppState

    private let options = [
        "I struggle to fall asleep even when I'm tired",
        "My brain races the moment I lie down",
        "I wake during the night and can't fall back asleep",
        "I wake up feeling unrefreshed",
    ]

    var body: some View {
        LullScreen(glow: false, glowX: 0.2, glowY: -0.1, glowRadius: 210, glowOpacity: 0.7) {
            AmberGlow(x: 0.2, y: -0.1, radius: 210, opacity: 0.7)
                .ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 16)
                    OnbTopBar(step: 1, total: 6, showBack: false)
                    StepProgress(step: 1, total: 6)

                    VStack(alignment: .leading, spacing: 10) {
                        Kicker(text: "Step one")
                        Text("What's keeping you\nfrom sleep?")
                            .font(.serif(30))
                            .foregroundColor(.lullInk0)
                            .padding(.top, 10)
                        Text("Pick anything that sounds like you. Multiple is fine.")
                            .font(.system(size: 14))
                            .foregroundColor(.lullInk2)
                            .lineSpacing(4)
                    }
                    .padding(.horizontal, Lull.horizontalPad)
                    .padding(.top, 10)
                    .padding(.bottom, 24)

                    VStack(spacing: 10) {
                        ForEach(Array(options.enumerated()), id: \.offset) { i, text in
                            ChoiceRow(
                                text: text,
                                selected: state.selectedSleepProblems.contains(i),
                                onTap: { toggle(&state.selectedSleepProblems, i) }
                            )
                        }
                        ChoiceRow(
                            text: "All of the above",
                            hint: "Pick this if everything resonates",
                            selected: state.selectedSleepProblems.count == options.count,
                            onTap: {
                                if state.selectedSleepProblems.count == options.count {
                                    state.selectedSleepProblems = []
                                } else {
                                    state.selectedSleepProblems = Set(0..<options.count)
                                }
                            }
                        )
                    }
                    .padding(.horizontal, 20)

                    VStack(spacing: 0) {
                        PrimaryCTA(title: "Continue", disabled: state.selectedSleepProblems.isEmpty) { step = 2 }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 32)
                    .padding(.bottom, 36)
                }
            }
        }
    }
}

// MARK: - Screen 2: What Wakes You

struct OnbWhatWakesView: View {
    @Binding var step: Int
    @EnvironmentObject var state: AppState

    private let options = [
        "New parent / postpartum",
        "Shift work or irregular schedule",
        "High-stress job / founder / on-call",
        "ADHD or racing mind",
        "Anxiety or worry",
        "Physical discomfort",
        "I suspect a medical issue",
        "None of the above",
    ]

    var body: some View {
        LullScreen(glow: false) {
            AmberGlow(x: 0.8, y: 0.0, radius: 250, opacity: 0.6)
                .ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 16)
                    OnbTopBar(step: 2, total: 6, onBack: { step = 1 })
                    StepProgress(step: 2, total: 6)

                    VStack(alignment: .leading, spacing: 10) {
                        Kicker(text: "Step two")
                        Text("What's your situation?")
                            .font(.serif(30))
                            .foregroundColor(.lullInk0)
                            .padding(.top, 10)
                        Text("Select everything that applies.")
                            .font(.system(size: 14))
                            .foregroundColor(.lullInk2)
                    }
                    .padding(.horizontal, Lull.horizontalPad)
                    .padding(.top, 10)
                    .padding(.bottom, 24)

                    VStack(spacing: 10) {
                        ForEach(Array(options.enumerated()), id: \.offset) { i, text in
                            ChoiceRow(
                                text: text,
                                selected: state.selectedWakes.contains(i),
                                onTap: { toggle(&state.selectedWakes, i) }
                            )
                        }
                    }
                    .padding(.horizontal, 20)

                    PrimaryCTA(title: "Continue", disabled: state.selectedWakes.isEmpty) { step = 3 }
                        .padding(.horizontal, 20)
                        .padding(.top, 32)
                        .padding(.bottom, 36)
                }
            }
        }
    }
}

// MARK: - Screen 3: Your Window

struct OnbBaselineRatingView: View {
    @Binding var step: Int
    @EnvironmentObject var state: AppState
    @State private var score: Int = 0

    var body: some View {
        LullScreen(glow: false) {
            AmberGlow(x: 0.5, y: 0.0, radius: 280, opacity: 0.55)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer().frame(height: 16)
                OnbTopBar(step: 3, total: 6, onBack: { step = 2 })
                StepProgress(step: 3, total: 6)

                VStack(alignment: .leading, spacing: 10) {
                    Kicker(text: "Step three")
                    Text("Rate your sleep\nin the last 5 days.")
                        .font(.serif(28))
                        .foregroundColor(.lullInk0)
                        .padding(.top, 10)
                    Text("Out of 5, with 5 as great sleep. We'll use this as a starting point so you can see what's actually working.")
                        .font(.system(size: 14))
                        .foregroundColor(.lullInk2)
                        .lineSpacing(3)
                }
                .padding(.horizontal, Lull.horizontalPad)
                .padding(.top, 10)
                .padding(.bottom, 36)

                SleepScoreSelector(score: $score)

                Spacer()

                PrimaryCTA(title: "Continue", disabled: score == 0) {
                    state.baselineScore = score
                    step = 4
                }
                .opacity(score == 0 ? 0.45 : 1)
                .padding(.horizontal, 20)
                .padding(.bottom, 36)
            }
        }
    }
}

// MARK: - Screen 4: Last Night's Sleep

struct OnbBedtimeView: View {
    @Binding var step: Int
    @EnvironmentObject var state: AppState

    private func hourFrac(_ d: Date) -> Double {
        let c = Calendar.current
        return Double(c.component(.hour, from: d) * 60 + c.component(.minute, from: d)) / (24.0 * 60.0)
    }

    private var sleepDurationText: String {
        var dur = hourFrac(state.typicalWakeTime) - hourFrac(state.typicalBedtime)
        if dur <= 0 { dur += 1.0 }
        let mins = Int(dur * 24 * 60)
        return "\(mins / 60)h \(mins % 60)m"
    }

    private func formatted(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "h:mm a"
        return f.string(from: d)
    }

    var body: some View {
        LullScreen(glow: false) {
            AmberGlow(x: 0.5, y: 0.2, radius: 260, opacity: 0.45)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer().frame(height: 16)
                OnbTopBar(step: 4, total: 6, onBack: { step = 3 })
                StepProgress(step: 4, total: 6)

                VStack(alignment: .leading, spacing: 10) {
                    Kicker(text: "Step four")
                    Text("What's your typical\nsleep window?")
                        .font(.serif(28))
                        .foregroundColor(.lullInk0)
                        .padding(.top, 10)
                    Text("When do you usually go to bed and wake up?")
                        .font(.system(size: 14))
                        .foregroundColor(.lullInk2)
                        .lineSpacing(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Lull.horizontalPad)
                .padding(.top, 10)
                .padding(.bottom, 20)

                // Duration
                VStack(spacing: 3) {
                    Text(sleepDurationText)
                        .font(.serif(38))
                        .foregroundColor(.lullInk0)
                    Text("Typical window")
                        .font(.mono(10))
                        .kerning(1.6)
                        .foregroundColor(.lullInk3)
                }
                .padding(.bottom, 16)

                // Arc clock
                SleepArcClock(bedtime: $state.typicalBedtime, wakeTime: $state.typicalWakeTime)
                    .frame(width: 260, height: 260)

                // Bedtime / Wake labels
                HStack {
                    VStack(spacing: 4) {
                        Image(systemName: "moon.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.lullAmber)
                        Text(formatted(state.typicalBedtime))
                            .font(.serif(20))
                            .foregroundColor(.lullInk0)
                        Text("Usually asleep")
                            .font(.mono(10))
                            .kerning(1.2)
                            .foregroundColor(.lullInk3)
                    }
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.lullAmber)
                        Text(formatted(state.typicalWakeTime))
                            .font(.serif(20))
                            .foregroundColor(.lullInk0)
                        Text("Usually up")
                            .font(.mono(10))
                            .kerning(1.2)
                            .foregroundColor(.lullInk3)
                    }
                }
                .padding(.horizontal, 52)
                .padding(.top, 20)

                Spacer()

                PrimaryCTA(title: "Continue") { step = 5 }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 36)
            }
        }
    }
}

// MARK: - Sleep Arc Clock

struct SleepArcClock: View {
    @Binding var bedtime: Date
    @Binding var wakeTime: Date

    private let clockR: CGFloat  = 100
    private let trackW: CGFloat  = 26
    private let handleR: CGFloat = 15

    private func hourFrac(_ d: Date) -> Double {
        let c = Calendar.current
        return Double(c.component(.hour, from: d) * 60 + c.component(.minute, from: d)) / (24.0 * 60.0)
    }

    private func ringPt(frac: Double, r: CGFloat, center: CGPoint) -> CGPoint {
        let a = frac * 2 * .pi - .pi / 2
        return CGPoint(x: center.x + r * cos(a), y: center.y + r * sin(a))
    }

    private func fracFrom(pos: CGPoint, center: CGPoint) -> Double {
        var a = atan2(pos.y - center.y, pos.x - center.x) + .pi / 2
        if a < 0 { a += 2 * .pi }
        return a / (2 * .pi)
    }

    private func snapDate(frac: Double, ref: Date) -> Date {
        let mins = Int(frac * 24 * 60) % (24 * 60)
        return Calendar.current.date(bySettingHour: mins / 60, minute: mins % 60, second: 0, of: ref) ?? ref
    }

    var body: some View {
        GeometryReader { geo in
            let cx = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let bf = hourFrac(bedtime)
            let wf = hourFrac(wakeTime)
            ZStack {
                // Track
                Circle()
                    .stroke(Color.white.opacity(0.07), lineWidth: trackW)
                    .frame(width: clockR * 2, height: clockR * 2)
                    .position(cx)

                // Sleep arc
                SleepArcShape(startFrac: bf, endFrac: wf)
                    .stroke(
                        LinearGradient(colors: [Color.lullAmber.opacity(0.55), Color.lullAmber.opacity(0.9)],
                                       startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: trackW, lineCap: .round)
                    )
                    .frame(width: clockR * 2, height: clockR * 2)
                    .position(cx)

                // Hour labels
                ForEach(Array(stride(from: 0, to: 24, by: 2)), id: \.self) { h in
                    let frac = Double(h) / 24.0
                    let pos  = ringPt(frac: frac, r: clockR - trackW / 2 - 13, center: cx)
                    let lbl: String = {
                        if h == 0  { return "12a" }
                        if h == 6  { return "6a"  }
                        if h == 12 { return "12p" }
                        if h == 18 { return "6p"  }
                        return "\(h > 12 ? h - 12 : h)"
                    }()
                    Text(lbl)
                        .font(.system(size: h % 6 == 0 ? 9 : 8))
                        .foregroundColor(h % 6 == 0 ? Color.lullInk2 : Color.lullInk3)
                        .position(pos)
                }

                // Bedtime handle (moon)
                let bPos = ringPt(frac: bf, r: clockR, center: cx)
                ZStack {
                    Circle().fill(Color.lullAmber).frame(width: handleR * 2, height: handleR * 2)
                    Image(systemName: "moon.fill").font(.system(size: 10)).foregroundColor(.lullBg)
                }
                .position(bPos)
                .shadow(color: .lullAmberGlow, radius: 8)
                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("sleepClock"))
                    .onChanged { v in
                        bedtime = snapDate(frac: fracFrom(pos: v.location, center: cx), ref: bedtime)
                    })

                // Wake handle (sun)
                let wPos = ringPt(frac: wf, r: clockR, center: cx)
                ZStack {
                    Circle().fill(Color.lullAmber).frame(width: handleR * 2, height: handleR * 2)
                    Image(systemName: "sun.max.fill").font(.system(size: 10)).foregroundColor(.lullBg)
                }
                .position(wPos)
                .shadow(color: .lullAmberGlow, radius: 8)
                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("sleepClock"))
                    .onChanged { v in
                        wakeTime = snapDate(frac: fracFrom(pos: v.location, center: cx), ref: wakeTime)
                    })
            }
        }
        .coordinateSpace(name: "sleepClock")
    }
}

struct SleepArcShape: Shape {
    var startFrac: Double
    var endFrac: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(startFrac, endFrac) }
        set { startFrac = newValue.first; endFrac = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(center: CGPoint(x: rect.midX, y: rect.midY),
                 radius: min(rect.width, rect.height) / 2,
                 startAngle: .degrees(startFrac * 360 - 90),
                 endAngle:   .degrees(endFrac   * 360 - 90),
                 clockwise: false)
        return p
    }
}

// MARK: - Screen 5: Pre-Bed Activities

struct OnbPreBedView: View {
    @Binding var step: Int
    @EnvironmentObject var state: AppState

    private let options = [
        "Use my phone or scroll",
        "Watch TV or screens",
        "Read a physical book",
        "Talk or socialize",
        "Dim the lights or use warm lighting",
        "Have a shower or bath",
        "Exercise (evening workout)",
        "Eat or have a snack",
        "Nothing specific — I just wind down",
    ]

    var body: some View {
        LullScreen(glow: false) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 16)
                    OnbTopBar(step: 5, total: 6, onBack: { step = 4 })
                    StepProgress(step: 5, total: 6)

                    VStack(alignment: .leading, spacing: 10) {
                        Kicker(text: "Step five")
                        Text("What do you usually do\nthe hour before bed?")
                            .font(.serif(28))
                            .foregroundColor(.lullInk0)
                            .padding(.top, 10)
                        Text("Select everything that applies.")
                            .font(.system(size: 14))
                            .foregroundColor(.lullInk2)
                    }
                    .padding(.horizontal, Lull.horizontalPad)
                    .padding(.top, 10)
                    .padding(.bottom, 24)

                    VStack(spacing: 10) {
                        ForEach(Array(options.enumerated()), id: \.offset) { i, text in
                            ChoiceRow(
                                text: text,
                                selected: state.selectedPreBedActivities.contains(i),
                                onTap: { toggle(&state.selectedPreBedActivities, i) }
                            )
                        }
                    }
                    .padding(.horizontal, 20)

                    PrimaryCTA(title: "Continue", disabled: state.selectedPreBedActivities.isEmpty) { step = 6 }
                        .padding(.horizontal, 20)
                        .padding(.top, 32)
                        .padding(.bottom, 36)
                }
            }
        }
    }
}

// MARK: - Screen 5: What You've Tried

struct OnbTriedView: View {
    @Binding var step: Int
    @EnvironmentObject var state: AppState

    private let options = [
        "Melatonin",
        "Meditation",
        "Light dinner",
        "Journaling",
        "Therapy",
        "CBT-I",
        "Warm bath",
    ]

    var body: some View {
        LullScreen(glow: false) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 16)
                    OnbTopBar(step: 6, total: 6, onBack: { step = 5 })
                    StepProgress(step: 6, total: 6)

                    VStack(alignment: .leading, spacing: 10) {
                        Kicker(text: "Step six")
                        Text("What have you tried\nbefore?")
                            .font(.serif(28))
                            .foregroundColor(.lullInk0)
                            .padding(.top, 10)
                        Text("Helps us know what's already familiar.")
                            .font(.system(size: 14))
                            .foregroundColor(.lullInk2)
                    }
                    .padding(.horizontal, Lull.horizontalPad)
                    .padding(.top, 10)
                    .padding(.bottom, 24)

                    VStack(spacing: 10) {
                        ForEach(Array(options.enumerated()), id: \.offset) { i, text in
                            ChoiceRow(
                                text: text,
                                selected: state.selectedTriedThings.contains(i),
                                onTap: { toggle(&state.selectedTriedThings, i) }
                            )
                        }
                    }
                    .padding(.horizontal, 20)

                    PrimaryCTA(title: "Build my routine", disabled: state.selectedTriedThings.isEmpty) {
                        let answers = OnboardingAnswers(from: state)
                        state.applyGeneratedRoutine(generateStartingRoutine(from: answers))
                        step = 7
                    }
                        .padding(.horizontal, 20)
                        .padding(.top, 32)
                        .padding(.bottom, 36)
                }
            }
        }
    }
}

// MARK: - Routine Ready (payoff screen)

struct OnbRoutineReadyView: View {
    @EnvironmentObject var state: AppState
    @State private var showContent = false
    @State private var orbScale: CGFloat = 1.0

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "h:mm"; return f
    }()

    private var headlineSub: String {
        let windDownMins = state.coreRoutine
            .filter { $0.mode == .inSequence }
            .reduce(0) { $0 + (NightlyStepKind.forLabel($1.label)?.estimatedMinutes ?? 5) }
        let count = state.scheduledRoutine.count
        return "\(windDownMins) min wind-down. \(count) steps. We kept what works and quietly dropped what doesn't."
    }

    var body: some View {
        ZStack {
            if showContent {
                routineContent
                    .transition(.opacity)
            } else {
                orbIntro
            }
        }
        .animation(.easeInOut(duration: 0.6), value: showContent)
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                orbScale = 1.35
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showContent = true
            }
        }
    }

    private var orbIntro: some View {
        ZStack {
            Color(hex: "#0c0807").ignoresSafeArea()

            VStack(spacing: 40) {
                ZStack {
                    // Outer ambient glow
                    Circle()
                        .fill(Color.lullAmber.opacity(0.18))
                        .frame(width: 340, height: 340)
                        .blur(radius: 48)
                        .scaleEffect(orbScale)

                    // 3D sphere: dark base + radial highlight offset toward upper-left
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(hex: "#d4924a"),
                                    Color(hex: "#b8732e"),
                                    Color(hex: "#7a3e10"),
                                ],
                                center: UnitPoint(x: 0.38, y: 0.32),
                                startRadius: 10,
                                endRadius: 130
                            )
                        )
                        .frame(width: 240, height: 240)
                        .scaleEffect(orbScale)
                }
                .frame(width: 340, height: 340)

                Text("Planning your first night right now...")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.lullInk3)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var routineContent: some View {
        LullScreen(glowX: 0.5, glowY: 0.22, glowRadius: 260, glowOpacity: 0.85) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 24)

                    // Brand
                    HStack { Spacer(); BrandMark(large: true); Spacer() }
                        .padding(.horizontal, 28)

                    // Copy
                    VStack(spacing: 16) {
                        Kicker(
                            text: state.routineShouldStartNow ? "Your routine is ready for tonight!" : "Your routine is ready",
                            color: .lullAmberSoft
                        )
                        VStack(spacing: 0) {
                            Text("Tonight's plan,")
                                .font(.serif(32))
                                .foregroundColor(.lullInk0)
                            Text("built for your brain.")
                                .font(.serifItalic(32))
                                .foregroundColor(.lullAmber)
                        }
                        Text(headlineSub)
                            .font(.system(size: 14))
                            .foregroundColor(.lullInk2)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .frame(maxWidth: 280)
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 8)

                    // Personalized routine card
                    let displayRoutine = state.scheduledRoutine.filter {
                        $0.step.label != "Brightness check" && $0.step.label != "Temperature check"
                    }
                    VStack(spacing: 0) {
                        ForEach(Array(displayRoutine.enumerated()), id: \.offset) { i, row in
                            HStack(spacing: 14) {
                                Text(row.timeString)
                                    .font(.mono(11))
                                    .kerning(0.6)
                                    .foregroundColor(.lullInk3)
                                    .frame(width: 50, alignment: .leading)
                                Ember(size: 5)
                                Text(row.step.label)
                                    .font(.system(size: 14))
                                    .foregroundColor(.lullInk1)
                                Spacer()
                                Text(row.badge)
                                    .font(.mono(9))
                                    .kerning(0.4)
                                    .foregroundColor(.lullInk4)
                                    .lineLimit(1)
                            }
                            .padding(.vertical, 12)
                            Divider().background(Color.lullLine)
                        }
                        // Target sleep time
                        HStack(spacing: 14) {
                            Text(OnbRoutineReadyView.timeFmt.string(from: state.typicalBedtime))
                                .font(.mono(11))
                                .kerning(0.6)
                                .foregroundColor(.lullInk3)
                                .frame(width: 50, alignment: .leading)
                            Image(systemName: "moon.fill")
                                .font(.system(size: 7))
                                .foregroundColor(.lullAmber)
                            Text("Sleep")
                                .font(.system(size: 14))
                                .foregroundColor(.lullInk1)
                            Spacer()
                            Text("Target")
                                .font(.mono(9))
                                .kerning(0.4)
                                .foregroundColor(.lullInk4)
                        }
                        .padding(.vertical, 12)
                    }
                    .padding(22)
                    .background(
                        RoundedRectangle(cornerRadius: 22)
                            .fill(LinearGradient(
                                colors: [Color.white.opacity(0.05), Color.white.opacity(0.015)],
                                startPoint: .top, endPoint: .bottom))
                    )
                    .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color.lullLineStrong, lineWidth: 1))
                    .padding(.horizontal, 24)
                    .padding(.top, 32)

                    // Gentle Reset explanation
                    if !state.routineExplanation.isEmpty {
                        Text(state.routineExplanation)
                            .font(.system(size: 13))
                            .foregroundColor(.lullInk3)
                            .lineSpacing(4)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 28)
                            .padding(.top, 18)
                    }

                    VStack(spacing: 0) {
                        PrimaryCTA(
                            title: state.routineShouldStartNow ? "Start Routine Now" : "Try it tonight"
                        ) {
                            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
                            state.completeOnboarding()
                        }
                        GhostButton(title: "Customize first") {
                            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
                            state.completeOnboardingToRoutine()
                        }
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 28)
                    .padding(.bottom, 36)
                }
            }
        }
    }
}

// MARK: - Helpers

private func toggle(_ set: inout Set<Int>, _ value: Int) {
    if set.contains(value) { set.remove(value) } else { set.insert(value) }
}
