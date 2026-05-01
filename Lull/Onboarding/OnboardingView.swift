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
            case 3: OnbWindowView(step: $step)
            case 4: OnbBedtimeView(step: $step)
            case 5: OnbPreBedView(step: $step)
            case 6: OnbTriedView(step: $step)
            case 7: OnbEnvironmentView(step: $step)
            case 8: OnbRoutineReadyView()
            default: EmptyView()
            }
        }
        .animation(.easeInOut(duration: 0.28), value: step)
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
                    OnbTopBar(step: 1, total: 7, showBack: false)
                    StepProgress(step: 1, total: 7)

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
                        PrimaryCTA(title: "Continue") { step = 2 }
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
                    OnbTopBar(step: 2, total: 7, onBack: { step = 1 })
                    StepProgress(step: 2, total: 7)

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

                    PrimaryCTA(title: "Continue") { step = 3 }
                        .padding(.horizontal, 20)
                        .padding(.top, 32)
                        .padding(.bottom, 36)
                }
            }
        }
    }
}

// MARK: - Screen 3: Your Window

struct OnbWindowView: View {
    @Binding var step: Int
    @EnvironmentObject var state: AppState

    private let windows = ["Under 10 minutes", "10–20 minutes", "20–30 minutes", "30+ minutes or varies"]
    private let windowValues = [7, 15, 25, 35]

    var body: some View {
        LullScreen(glow: false) {
            AmberGlow(x: 0.5, y: 0.0, radius: 280, opacity: 0.55)
                .ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 16)
                    OnbTopBar(step: 3, total: 7, onBack: { step = 2 })
                    StepProgress(step: 3, total: 7)

                    VStack(alignment: .leading, spacing: 10) {
                        Kicker(text: "Step three")
                        Text("How long do you usually\nhave to fall asleep?")
                            .font(.serif(28))
                            .foregroundColor(.lullInk0)
                            .padding(.top, 10)
                        Text("This shapes your routine length.")
                            .font(.system(size: 14))
                            .foregroundColor(.lullInk2)
                    }
                    .padding(.horizontal, Lull.horizontalPad)
                    .padding(.top, 10)
                    .padding(.bottom, 24)

                    VStack(spacing: 10) {
                        ForEach(Array(windows.enumerated()), id: \.offset) { i, label in
                            ChoiceRow(
                                text: label,
                                selected: state.sleepWindowMinutes == windowValues[i],
                                big: true,
                                onTap: { state.sleepWindowMinutes = windowValues[i] }
                            )
                        }
                    }
                    .padding(.horizontal, 20)

                    PrimaryCTA(title: "Continue") { step = 4 }
                        .padding(.horizontal, 20)
                        .padding(.top, 32)
                        .padding(.bottom, 36)
                }
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
                OnbTopBar(step: 4, total: 7, onBack: { step = 3 })
                StepProgress(step: 4, total: 7)

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
                    OnbTopBar(step: 5, total: 7, onBack: { step = 4 })
                    StepProgress(step: 5, total: 7)

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

                    PrimaryCTA(title: "Continue") { step = 6 }
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
                    OnbTopBar(step: 6, total: 7, onBack: { step = 5 })
                    StepProgress(step: 6, total: 7)

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

                    PrimaryCTA(title: "Continue") { step = 7 }
                        .padding(.horizontal, 20)
                        .padding(.top, 32)
                        .padding(.bottom, 36)
                }
            }
        }
    }
}

// MARK: - Screen 6: Environment Check (evening)

struct OnbEnvironmentView: View {
    @Binding var step: Int
    @EnvironmentObject var state: AppState

    private let lightLabels = ["Bright", "Half-dim", "Warm dim", "Mostly dark"]
    private let lightColors: [Color] = [
        Color(hex: "#f5e7d7"),
        Color(hex: "#d99a4a"),
        Color(hex: "#a66a2a"),
        Color(hex: "#3a2317"),
    ]

    var body: some View {
        LullScreen(glow: false) {
            AmberGlow(x: 0.8, y: 0.0, radius: 250, opacity: 0.6)
                .ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 16)
                    OnbTopBar(step: 7, total: 7, onBack: { step = 6 })
                    StepProgress(step: 7, total: 7)

                    VStack(alignment: .leading, spacing: 10) {
                        Kicker(text: "Last step · evening check")
                        Group {
                            Text("One quick read of ")
                                .foregroundColor(.lullInk0)
                            + Text("tonight's room.")
                                .foregroundColor(.lullAmber)
                        }
                        .font(.serif(28))
                        .padding(.top, 10)

                        Text("Lull will use this to dial in tonight's routine — and learn what works for your body over time.")
                            .font(.system(size: 13.5))
                            .foregroundColor(.lullInk2)
                            .lineSpacing(3)
                    }
                    .padding(.horizontal, Lull.horizontalPad)
                    .padding(.top, 10)
                    .padding(.bottom, 22)

                    // Temperature card
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .lastTextBaseline) {
                            Kicker(text: "Bedroom temperature")
                            Spacer()
                            Text("°F")
                                .font(.mono(11))
                                .foregroundColor(.lullInk3)
                        }

                        HStack(alignment: .lastTextBaseline, spacing: 10) {
                            Text("\(Int(state.bedroomTempF))")
                                .font(.serif(56))
                                .foregroundColor(.lullInk0)
                                .kerning(-1.5)
                            Text(tempLabel)
                                .font(.system(size: 13))
                                .foregroundColor(.lullInk3)
                                .padding(.bottom, 12)
                        }

                        // Slider
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(hex: "#78a0c8").opacity(0.25),
                                            Color.lullAmber.opacity(0.4),
                                            Color(hex: "#dc5a3c").opacity(0.35),
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(height: 2)

                            GeometryReader { geo in
                                let pct = (state.bedroomTempF - 60) / (75 - 60)
                                Circle()
                                    .fill(Color.lullAmber)
                                    .frame(width: 16, height: 16)
                                    .shadow(color: .lullAmberGlow, radius: 9)
                                    .shadow(color: Color(hex: "#0c0807").opacity(0.9), radius: 0)
                                    .offset(x: geo.size.width * CGFloat(pct) - 8, y: -5)
                            }
                            .frame(height: 6)
                        }
                        .frame(height: 10)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { v in
                                    let cardW = UIScreen.main.bounds.width - 88
                                    let pct = min(1, max(0, v.location.x / cardW))
                                    state.bedroomTempF = 60 + pct * 15
                                }
                        )

                        HStack {
                            ForEach(["60°", "65°", "70°", "75°"], id: \.self) { t in
                                Text(t).font(.mono(10)).foregroundColor(.lullInk4).kerning(1)
                                if t != "75°" { Spacer() }
                            }
                        }
                        .padding(.top, 8)
                    }
                    .padding(22)
                    .lullCard(radius: 22)
                    .padding(.horizontal, 20)

                    // Lights card
                    VStack(alignment: .leading, spacing: 14) {
                        Kicker(text: "Lights right now")

                        HStack(spacing: 8) {
                            ForEach(0..<4) { i in
                                let active = state.lightsLevel == i
                                Button(action: { state.lightsLevel = i }) {
                                    VStack(spacing: 8) {
                                        Circle()
                                            .fill(lightColors[i])
                                            .frame(width: 16, height: 16)
                                            .shadow(color: active ? .lullAmberGlow : .clear, radius: 5)
                                        Text(lightLabels[i])
                                            .font(.system(size: 12))
                                            .foregroundColor(active ? .lullInk0 : .lullInk2)
                                            .multilineTextAlignment(.center)
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 6)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(active ? Color.lullAmber.opacity(0.10) : Color.clear)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(active ? Color.lullAmber.opacity(0.5) : Color.lullLine, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(20)
                    .lullCard(radius: 22)
                    .padding(.horizontal, 20)
                    .padding(.top, 14)

                    VStack(spacing: 0) {
                        PrimaryCTA(title: "Build my routine") {
                            let answers = OnboardingAnswers(from: state)
                            state.applyGeneratedRoutine(generateStartingRoutine(from: answers))
                            step = 8
                        }
                        GhostButton(title: "Ask me again at bedtime") {}
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
                    .padding(.bottom, 36)
                }
            }
        }
    }

    private var tempLabel: String {
        switch state.bedroomTempF {
        case ..<63: return "a bit cool"
        case 63..<69: return "about right"
        case 69..<73: return "slightly warm"
        default:     return "pretty warm"
        }
    }
}

// MARK: - Routine Ready (payoff screen)

struct OnbRoutineReadyView: View {
    @EnvironmentObject var state: AppState

    // Work backwards from bedtime to assign a start time to each step.
    // reminderOnly steps are pinned 15 min before the first sequenced step.
    private var scheduledSteps: [(time: String, label: String)] {
        guard let routine = state.generatedRoutine else { return [] }
        let fmt = DateFormatter(); fmt.dateFormat = "h:mm a"
        let cal = Calendar.current
        var cursor = state.typicalBedtime
        var pairs: [(Date, NightlyStepKind)] = []
        for step in routine.steps.reversed() {
            cursor = cal.date(byAdding: .minute, value: -step.estimatedMinutes, to: cursor) ?? cursor
            pairs.insert((cursor, step), at: 0)
        }
        let routineStart = pairs.first(where: { $0.1.routineMode != .reminderOnly })?.0 ?? cursor
        return pairs.map { time, step in
            let displayTime = step.routineMode == .reminderOnly
                ? (cal.date(byAdding: .minute, value: -15, to: routineStart) ?? routineStart)
                : time
            let durationSuffix = step.estimatedMinutes > 1 ? " · \(step.estimatedMinutes) min" : ""
            return (fmt.string(from: displayTime), step.displayLabel + durationSuffix)
        }
    }

    private var headlineSub: String {
        let total = state.generatedRoutine?.totalMinutes ?? 10
        return "\(total) minutes. \(scheduledSteps.count) steps. We kept what works and quietly dropped what doesn't."
    }

    var body: some View {
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
                    VStack(spacing: 0) {
                        ForEach(Array(scheduledSteps.enumerated()), id: \.offset) { i, row in
                            HStack(spacing: 14) {
                                Text(row.time)
                                    .font(.mono(11))
                                    .kerning(0.6)
                                    .foregroundColor(.lullInk3)
                                    .frame(width: 64, alignment: .leading)
                                Ember(size: 5)
                                Text(row.label)
                                    .font(.system(size: 14))
                                    .foregroundColor(.lullInk1)
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            if i < scheduledSteps.count - 1 {
                                Divider().background(Color.lullLine)
                            }
                        }
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

                    // Widget nudge
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(LinearGradient(colors: [Color(hex: "#1a110e"), Color(hex: "#0c0807")],
                                                     startPoint: .top, endPoint: .bottom))
                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.lullLine, lineWidth: 1))
                                .frame(width: 38, height: 38)
                            Ember(size: 8)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add the lock-screen widget")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.lullInk0)
                            Text("One tap at 3am — no unlock, no app open.")
                                .font(.system(size: 11.5))
                                .foregroundColor(.lullInk3)
                        }
                        Spacer()
                        Text("Add")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.lullAmber)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.02)))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.lullLineStrong, style: StrokeStyle(lineWidth: 1, dash: [4])))
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                    VStack(spacing: 0) {
                        PrimaryCTA(
                            title: state.routineShouldStartNow ? "Start Routine Now" : "Try it tonight"
                        ) { state.completeOnboarding() }
                        GhostButton(title: "Customize first") { state.completeOnboarding() }
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
