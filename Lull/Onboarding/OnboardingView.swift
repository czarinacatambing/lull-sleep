import SwiftUI
import FamilyControls
import PostHog

// Onboarding coordinator — a quick profile, then a generated routine.
struct OnboardingView: View {
    @EnvironmentObject var state: AppState
    @State private var step = 0
    @State private var didTrackStart = false

    var body: some View {
        ZStack {
            switch step {
            case 0: OnbSleepProblemView(step: $step)
            case 1: OnbBaselineRatingView(step: $step)
            case 2: OnbPromiseView(step: $step)
            case 3: OnbBedtimeView(
                step: $step,
                kind: .target,
                bedtime: $state.targetBedtime,
                wakeTime: $state.targetWakeTime
            )
            case 4: OnbPreBedView(step: $step)
            case 5: OnbMethodologyView(step: $step)
            case 6: OnbRoutineReadyView(step: $step)
            case 7: OnbCommitmentView(step: $step)
            case 8: OnbAppBlockingCommitmentView(step: $step)
            case 9: OnbTrialPaywallView()
            default: EmptyView()
            }
        }
        .animation(step == 6 ? .easeInOut(duration: 0.7) : .easeInOut(duration: 0.28), value: step)
        .transition(.opacity)
        .postHogNoMask()
        .onAppear {
            if !didTrackStart {
                didTrackStart = true
                state.trackOnboardingStarted()
            }
            state.trackOnboardingScreen(screenName(for: step))
        }
        .onChange(of: step) { _, newStep in
            state.trackOnboardingScreen(screenName(for: newStep))
        }
    }

    private func screenName(for step: Int) -> String {
        switch step {
        case 0: return "sleep_problem"
        case 1: return "baseline_rating"
        case 2: return "promise"
        case 3: return "bedtime"
        case 4: return "pre_bed"
        case 5: return "methodology"
        case 6: return "routine_ready"
        case 7: return "commitment"
        case 8: return "app_blocking_commitment"
        case 9: return "trial_paywall"
        default: return "unknown"
        }
    }
}

// MARK: - Screen 0: Welcome

struct OnbWelcomeView: View {
    @Binding var step: Int

    var body: some View {
        LullScreen(glow: false) {
            AmberGlow(x: 0.5, y: 0.42, radius: 340, opacity: 0.95)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 56)
                BrandMark(large: true)

                Spacer()

                VStack(spacing: 20) {
                    Kicker(text: "Tonight", color: .lullAmberSoft)
                    VStack(spacing: 0) {
                        Text("Help me sleep")
                            .font(.serif(46))
                            .foregroundColor(.lullInk0)
                        Text("tonight.")
                            .font(.serifItalic(46))
                            .foregroundColor(.lullAmber)
                    }
                    Text("One minute of breathing first. Then we'll build the routine that gets you back to great sleep.")
                        .font(.system(size: 14.5))
                        .foregroundColor(.lullInk2)
                        .lineSpacing(4)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 290)
                }
                .padding(.horizontal, 28)

                Spacer()

                PrimaryCTA(title: "Help me sleep tonight") {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    step = 1
                }
                .padding(.horizontal, 20)

                Text("~ 2 MIN · NO SIGNUP")
                    .font(.mono(10))
                    .kerning(2)
                    .foregroundColor(.lullInk4)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
            }
        }
    }
}

// MARK: - Screen 1: Promise

struct OnbPromiseView: View {
    @Binding var step: Int
    @State private var sparkle = false

    var body: some View {
        LullScreen(glow: false) {
            AmberGlow(x: 0.08, y: 0.92, radius: 330, opacity: 0.5)
                .ignoresSafeArea()
            AmberGlow(x: 0.92, y: 0.02, radius: 260, opacity: 0.32)
                .ignoresSafeArea()

            GeometryReader { geo in
                let compact = geo.size.height < 720
                let stageHeight = max(compact ? 286 : 348, geo.size.height * (compact ? 0.38 : 0.44))

                VStack(spacing: 0) {
                    Spacer().frame(height: compact ? 22 : 30)

                    HStack {
                        Spacer()
                        BrandMark()
                        Spacer()
                    }
                    .padding(.horizontal, Lull.horizontalPad)
                    .padding(.bottom, compact ? 22 : 30)

                    VStack(spacing: 14) {
                        (Text("Unlock the power of a ")
                            .foregroundColor(.lullInk0)
                         + Text("wind-down ritual")
                            .font(.serifItalic(compact ? 25 : 27))
                            .foregroundColor(.lullAmber))
                            .font(.serif(compact ? 25 : 27, weight: .semibold))
                            .lineSpacing(4)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 330)

                        Text("A guided routine quiets the overthinking, locks away the doomscroll, and walks you to sleep - night after night.")
                            .font(.system(size: compact ? 13.5 : 14.5))
                            .foregroundColor(.lullInk2)
                            .lineSpacing(4)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 306)
                    }
                    .padding(.horizontal, 24)

                    PromiseStage(sparkle: sparkle)
                        .frame(height: stageHeight)
                        .padding(.horizontal, 18)
                        .padding(.top, compact ? 8 : 18)

                    Spacer(minLength: compact ? 10 : 18)

                    PrimaryCTA(title: "Let's continue") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        step = 3
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, compact ? 24 : 34)
                }
            }
        }
        .onAppear {
            sparkle = false
            withAnimation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true)) {
                sparkle = true
            }
        }
    }
}

private struct PromiseStage: View {
    var sparkle: Bool

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let cardWidth = min(170, width * 0.48)
            let cardHeight = min(236, height * 0.72)
            let todayX = width * 0.02
            let todayY = height - cardHeight - 10
            let weekX = width - cardWidth - 2
            let weekY = max(8, height * 0.02)

            ZStack(alignment: .topLeading) {
                PromiseSparkle(size: 13)
                    .position(x: width * 0.13, y: height * 0.25)
                    .opacity(sparkle ? 0.9 : 0.18)
                    .scaleEffect(sparkle ? 1.1 : 0.72)

                PromiseSparkle(size: 18)
                    .position(x: width * 0.86, y: height * 0.17)
                    .opacity(sparkle ? 0.22 : 0.95)
                    .scaleEffect(sparkle ? 0.74 : 1.08)

                PromiseSparkle(size: 12)
                    .position(x: width * 0.91, y: height * 0.77)
                    .opacity(sparkle ? 0.82 : 0.14)
                    .scaleEffect(sparkle ? 1.04 : 0.68)

                PromiseCard(
                    title: "You tonight",
                    meta: "12:47 AM",
                    style: .tonight
                )
                .frame(width: cardWidth, height: cardHeight)
                .position(x: todayX + cardWidth / 2, y: todayY + cardHeight / 2)

                PromiseCard(
                    title: "You in a week",
                    meta: "ASLEEP - 10:40 PM",
                    style: .week
                )
                .frame(width: cardWidth, height: cardHeight)
                .position(x: weekX + cardWidth / 2, y: weekY + cardHeight / 2)

                PromiseArrow()
                    .stroke(Color.lullAmber, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .frame(width: 48, height: 42)
                    .shadow(color: .lullAmberGlow, radius: 8)
                    .position(x: width * 0.52, y: height * 0.54 + (sparkle ? -5 : 3))
            }
        }
    }
}

private enum PromiseCardStyle {
    case tonight
    case week
}

private struct PromiseCard: View {
    var title: String
    var meta: String
    var style: PromiseCardStyle

    private var isWeek: Bool { style == .week }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(meta)
                .font(.mono(9))
                .kerning(1.0)
                .foregroundColor(isWeek ? .lullAmberSoft : Color(hex: "#6f7d8d"))
                .padding(.top, 14)
                .padding(.horizontal, 15)

            Text(title)
                .font(.serifItalic(18))
                .foregroundColor(isWeek ? .lullAmber : Color(hex: "#9fb0c4"))
                .padding(.top, 4)
                .padding(.horizontal, 15)

            Spacer()

            ZStack {
                if isWeek {
                    Circle()
                        .fill(Color.lullAmber.opacity(0.16))
                        .frame(width: 112, height: 112)
                        .blur(radius: 6)
                }

                SleepyFace(isAsleep: isWeek)
                    .frame(width: 118, height: 118)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 16)
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(isWeek ? Color.lullAmber.opacity(0.18) : Color.white.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: isWeek ? Color.lullAmber.opacity(0.22) : Color.black.opacity(0.45), radius: 24, y: 18)
    }

    private var cardBackground: some ShapeStyle {
        if isWeek {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color(hex: "#241809"), Color(hex: "#160f06")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }

        return AnyShapeStyle(Color(hex: "#13100f"))
    }
}

private struct SleepyFace: View {
    var isAsleep: Bool

    var body: some View {
        ZStack {
            if !isAsleep {
                ForEach([-1, 1], id: \.self) { side in
                    Path { path in
                        let x: CGFloat = side < 0 ? 30 : 88
                        let direction = CGFloat(side)
                        path.move(to: CGPoint(x: x, y: 24))
                        path.addLine(to: CGPoint(x: x + 6 * direction, y: 33))
                        path.addLine(to: CGPoint(x: x - 4 * direction, y: 39))
                        path.addLine(to: CGPoint(x: x + 4 * direction, y: 50))
                    }
                    .stroke(Color(hex: "#7f93a8"), style: StrokeStyle(lineWidth: 2.3, lineCap: .round, lineJoin: .round))
                }
            }

            if isAsleep {
                Path { path in
                    path.move(to: CGPoint(x: 40, y: 50))
                    path.addQuadCurve(to: CGPoint(x: 80, y: 50), control: CGPoint(x: 60, y: 20))
                    path.closeSubpath()
                }
                .fill(Color.lullAmber)

                Circle()
                    .fill(Color.lullInk0)
                    .frame(width: 9, height: 9)
                    .position(x: 80, y: 48)
            }

            Ellipse()
                .fill(isAsleep ? Color(hex: "#caa06a") : Color(hex: "#2c3a49"))
                .frame(width: 68, height: 60)
                .position(x: 60, y: 76)

            if isAsleep {
                closedEye(x: 48)
                closedEye(x: 72)
                Path { path in
                    path.move(to: CGPoint(x: 52, y: 86))
                    path.addQuadCurve(to: CGPoint(x: 68, y: 86), control: CGPoint(x: 60, y: 92))
                }
                .stroke(Color(hex: "#3a2a16"), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))

                Text("z")
                    .font(.serif(13))
                    .foregroundColor(.lullAmber)
                    .position(x: 94, y: 38)
                Text("z")
                    .font(.serif(10))
                    .foregroundColor(.lullAmber.opacity(0.75))
                    .position(x: 102, y: 28)
            } else {
                awakeEye(x: 48)
                awakeEye(x: 72)
                Path { path in
                    path.move(to: CGPoint(x: 50, y: 88))
                    path.addQuadCurve(to: CGPoint(x: 70, y: 88), control: CGPoint(x: 60, y: 82))
                }
                .stroke(Color(hex: "#8aa0ad"), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))

                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(hex: "#9fd0ff").opacity(0.85))
                    .frame(width: 13, height: 20)
                    .rotationEffect(.degrees(18))
                    .position(x: 84, y: 96)
            }
        }
    }

    private func awakeEye(x: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color(hex: "#dfe8f1"))
                .frame(width: 22, height: 22)
            Circle()
                .fill(Color(hex: "#10171f"))
                .frame(width: 10, height: 10)
            Circle()
                .fill(Color.white)
                .frame(width: 3, height: 3)
                .offset(x: 2, y: -2)
        }
        .position(x: x, y: 68)
    }

    private func closedEye(x: CGFloat) -> some View {
        Path { path in
            path.move(to: CGPoint(x: x - 6, y: 72))
            path.addQuadCurve(to: CGPoint(x: x + 6, y: 72), control: CGPoint(x: x, y: 78))
        }
        .stroke(Color(hex: "#3a2a16"), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
    }
}

private struct PromiseSparkle: View {
    var size: CGFloat

    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: size, weight: .regular))
            .foregroundColor(.lullAmber)
    }
}

private struct PromiseArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 4, y: rect.maxY - 10))
        path.addCurve(
            to: CGPoint(x: rect.maxX - 8, y: rect.minY + 12),
            control1: CGPoint(x: rect.minX + 14, y: rect.minY + 14),
            control2: CGPoint(x: rect.maxX - 20, y: rect.minY + 4)
        )
        path.move(to: CGPoint(x: rect.maxX - 8, y: rect.minY + 12))
        path.addLine(to: CGPoint(x: rect.maxX - 18, y: rect.minY + 10))
        path.move(to: CGPoint(x: rect.maxX - 8, y: rect.minY + 12))
        path.addLine(to: CGPoint(x: rect.maxX - 12, y: rect.minY + 24))
        return path
    }
}

// MARK: - Screen 2: Transition

struct OnbTransitionView: View {
    @Binding var step: Int
    @State private var showQuestion = false
    @State private var questionOut = false
    @State private var showFirstLine = false
    @State private var showSecondLine = false

    var body: some View {
        LullScreen(glow: false) {
            AmberGlow(x: 0.5, y: 0.3, radius: 280, opacity: 0.6)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 16)
                HStack { BrandMark(); Spacer() }
                    .padding(.horizontal, Lull.horizontalPad)

                Spacer()

                ZStack {
                    Text("Feel calmer?")
                        .font(.serif(44))
                        .foregroundColor(.lullInk0)
                        .multilineTextAlignment(.center)
                        .scaleEffect(showQuestion ? (questionOut ? 0.97 : 1.0) : 0.94)
                        .opacity(showQuestion && !questionOut ? 1 : 0)

                    VStack(spacing: 12) {
                        Text("That tool is now yours — anytime you need it.")
                            .opacity(showFirstLine ? 1 : 0)
                            .offset(y: showFirstLine ? 0 : 12)
                        Text("Let's build the rest of your routine.")
                            .opacity(showSecondLine ? 1 : 0)
                            .offset(y: showSecondLine ? 0 : 12)
                    }
                    .font(.serif(29))
                    .foregroundColor(.lullInk0)
                    .lineSpacing(8)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 310)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 28)

                Spacer()

                PrimaryCTA(title: "Next") {
                    step = 3
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 36)
            }
        }
        .onAppear { runAnimation() }
    }

    private func runAnimation() {
        showQuestion = false
        questionOut = false
        showFirstLine = false
        showSecondLine = false

        withAnimation(.easeOut(duration: 0.8).delay(0.15)) {
            showQuestion = true
        }
        withAnimation(.easeIn(duration: 0.7).delay(1.7)) {
            questionOut = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.65) {
            withAnimation(.easeOut(duration: 0.7)) {
                showFirstLine = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.55) {
            withAnimation(.easeOut(duration: 0.7)) {
                showSecondLine = true
            }
        }
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
        "Other",
    ]

    var body: some View {
        LullScreen(glow: false, glowX: 0.2, glowY: -0.1, glowRadius: 210, glowOpacity: 0.7) {
            AmberGlow(x: 0.2, y: -0.1, radius: 210, opacity: 0.7)
                .ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 16)
                    OnbTopBar(step: 1, total: 4, showBack: false)
                    StepProgress(step: 1, total: 4)

                    VStack(alignment: .leading, spacing: 10) {
                        Kicker(text: "Step one · what's keeping you up")
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
                        PrimaryCTA(title: "Continue", disabled: state.selectedSleepProblems.isEmpty) { step = 1 }
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
                    OnbTopBar(step: 3, total: 6, onBack: { step = 4 })
                    StepProgress(step: 3, total: 6)

                    VStack(alignment: .leading, spacing: 10) {
                        Kicker(text: "Step three · your situation")
                        Text("What's life like\naround your sleep?")
                            .font(.serif(30))
                            .foregroundColor(.lullInk0)
                            .padding(.top, 10)
                        Text("We use this to read your sleep pattern and which leaks matter most. Pick anything that fits.")
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

                    PrimaryCTA(title: "Continue", disabled: state.selectedWakes.isEmpty) { step = 6 }
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
                OnbTopBar(step: 2, total: 4, onBack: { step = 0 })
                StepProgress(step: 2, total: 4)

                VStack(alignment: .leading, spacing: 10) {
                    Kicker(text: "Step two · your baseline")
                    Text("How satisfied are\nyou with your sleep?")
                        .font(.serif(28))
                        .foregroundColor(.lullInk0)
                        .padding(.top, 10)
                    Text("This gives us a starting point, so you can see what's actually working.")
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
                    state.baselineScore = AppState.clampedSleepScore(score)
                    step = 2
                }
                .opacity(score == 0 ? 0.45 : 1)
                .padding(.horizontal, 20)
                .padding(.bottom, 36)
            }
        }
        .onAppear {
            score = state.baselineScore
        }
    }
}

// MARK: - Screens 7/8: Sleep Window

enum OnbBedtimeKind: Equatable {
    case current
    case target

    var progressStep: Int { 3 }
    var kicker: String {
        self == .current ? "Step three · right now" : "Step three · sleep window"
    }
    var title: String {
        self == .current
            ? "When does sleep\nactually happen?"
            : "What's your preferred\nsleeping schedule?"
    }
    var subcopy: String {
        self == .current
            ? "On an average night right now, when do you actually fall asleep and wake up?"
            : "Your routine will aim you toward this."
    }
    var durationLabel: String {
        self == .current ? "Current window" : "Target window"
    }
    var bedLabel: String {
        self == .current ? "Usually asleep" : "Target asleep"
    }
    var wakeLabel: String {
        self == .current ? "Usually up" : "Target wake"
    }
}

struct OnbBedtimeView: View {
    @Binding var step: Int
    var kind: OnbBedtimeKind
    @Binding var bedtime: Date
    @Binding var wakeTime: Date
    @EnvironmentObject var state: AppState

    private func hourFrac(_ d: Date) -> Double {
        let c = Calendar.current
        return Double(c.component(.hour, from: d) * 60 + c.component(.minute, from: d)) / (24.0 * 60.0)
    }

    private var sleepDurationText: String {
        var dur = hourFrac(wakeTime) - hourFrac(bedtime)
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
            GeometryReader { geo in
                let veryCompact = geo.size.height < 650
                let compact = geo.size.height < 740
                let clockSize: CGFloat = veryCompact ? 170 : (compact ? 220 : 260)
                let titleSize: CGFloat = veryCompact ? 24 : 28
                let durationSize: CGFloat = veryCompact ? 30 : 38
                let textBottom: CGFloat = veryCompact ? 8 : (compact ? 12 : 20)
                let labelTop: CGFloat = veryCompact ? 8 : 20
                let ctaBottom: CGFloat = veryCompact ? 20 : 36

                VStack(spacing: 0) {
                Spacer().frame(height: 16)
                OnbTopBar(step: kind.progressStep, total: 4, onBack: { step = 2 })
                StepProgress(step: kind.progressStep, total: 4)

                VStack(alignment: .leading, spacing: 10) {
                    Kicker(text: kind.kicker)
                    Text(kind.title)
                        .font(.serif(titleSize))
                        .foregroundColor(.lullInk0)
                        .padding(.top, 10)
                    Text(kind.subcopy)
                        .font(.system(size: 14))
                        .foregroundColor(.lullInk2)
                        .lineSpacing(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Lull.horizontalPad)
                .padding(.top, 10)
                .padding(.bottom, textBottom)

                // Duration
                VStack(spacing: 3) {
                    Text(sleepDurationText)
                        .font(.serif(durationSize))
                        .foregroundColor(.lullInk0)
                    Text(kind.durationLabel)
                        .font(.mono(10))
                        .kerning(1.6)
                        .foregroundColor(.lullInk3)
                }
                .padding(.bottom, veryCompact ? 8 : 16)

                // Arc clock
                SleepArcClock(bedtime: $bedtime, wakeTime: $wakeTime)
                    .frame(width: clockSize, height: clockSize)

                // Bedtime / Wake labels
                HStack {
                    VStack(spacing: 4) {
                        Image(systemName: "moon.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.lullAmber)
                        Text(formatted(bedtime))
                            .font(.serif(20))
                            .foregroundColor(.lullInk0)
                        Text(kind.bedLabel)
                            .font(.mono(10))
                            .kerning(1.2)
                            .foregroundColor(.lullInk3)
                    }
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.lullAmber)
                        Text(formatted(wakeTime))
                            .font(.serif(20))
                            .foregroundColor(.lullInk0)
                        Text(kind.wakeLabel)
                            .font(.mono(10))
                            .kerning(1.2)
                            .foregroundColor(.lullInk3)
                    }
                }
                .padding(.horizontal, 52)
                .padding(.top, labelTop)

                Spacer()

                PrimaryCTA(title: "Continue") {
                    if kind == .current {
                        state.targetBedtime = state.currentBedtime
                        state.targetWakeTime = state.currentWakeTime
                        step = 4
                    } else {
                        state.currentBedtime = state.targetBedtime
                        state.currentWakeTime = state.targetWakeTime
                        state.typicalBedtime = state.targetBedtime
                        state.typicalWakeTime = state.targetWakeTime
                        state.refreshOnboardingClassifications()
                        step = 4
                    }
                }
                    .padding(.horizontal, 20)
                    .padding(.bottom, ctaBottom)
                }
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
    private let snapMinutes = 10

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
        let dayMinutes = 24 * 60
        let rawMins = frac * Double(dayMinutes)
        let mins = (Int((rawMins / Double(snapMinutes)).rounded()) * snapMinutes) % dayMinutes
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
                        let snapped = snapDate(frac: fracFrom(pos: v.location, center: cx), ref: bedtime)
                        if !Calendar.current.isDate(snapped, equalTo: bedtime, toGranularity: .minute) {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        bedtime = snapped
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
                        let snapped = snapDate(frac: fracFrom(pos: v.location, center: cx), ref: wakeTime)
                        if !Calendar.current.isDate(snapped, equalTo: wakeTime, toGranularity: .minute) {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        wakeTime = snapped
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
        "Exercise (evening workout)",
        "Eat or have a snack",
        "Drink coffee",
        "Work",
        "Have a nightcap or alcohol",
        "None of the above",
    ]

    private var noneIndex: Int { options.count - 1 }

    var body: some View {
        LullScreen(glow: false) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 16)
                    OnbTopBar(step: 4, total: 4, onBack: { step = 3 })
                    StepProgress(step: 4, total: 4)

                    VStack(alignment: .leading, spacing: 10) {
                        Kicker(text: "Step three · the last 3 hours")
                        Text("What do you do in\nthe last 3 hours\nbefore bed?")
                            .font(.serif(28))
                            .foregroundColor(.lullInk0)
                            .padding(.top, 10)
                        Text("Just the habits that tend to work against sleep — pick any that sound like you.")
                            .font(.system(size: 14))
                            .foregroundColor(.lullInk2)
                            .lineSpacing(3)
                    }
                    .padding(.horizontal, Lull.horizontalPad)
                    .padding(.top, 10)
                    .padding(.bottom, 24)

                    VStack(spacing: 10) {
                        ForEach(Array(options.enumerated()), id: \.offset) { i, text in
                            ChoiceRow(
                                text: text,
                                selected: state.selectedPreBedActivities.contains(i),
                                onTap: { togglePreBed(i) }
                            )
                        }
                    }
                    .padding(.horizontal, 20)

                    PrimaryCTA(title: "Build my routine", disabled: state.selectedPreBedActivities.isEmpty) {
                        step = 5
                    }
                        .padding(.horizontal, 20)
                        .padding(.top, 32)
                        .padding(.bottom, 36)
                }
            }
        }
    }

    private func togglePreBed(_ index: Int) {
        if index == noneIndex {
            state.selectedPreBedActivities = state.selectedPreBedActivities.contains(index) ? [] : [index]
            return
        }

        state.selectedPreBedActivities.remove(noneIndex)
        toggle(&state.selectedPreBedActivities, index)
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
        "None of these",
    ]

    private var noneIndex: Int { options.count - 1 }

    var body: some View {
        LullScreen(glow: false) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 16)
                    OnbTopBar(step: 6, total: 6, onBack: { step = 9 })

                    VStack(alignment: .leading, spacing: 10) {
                        Kicker(text: "Last check · what you've tried")
                        Text("What have you tried\nbefore?")
                            .font(.serif(28))
                            .foregroundColor(.lullInk0)
                            .padding(.top, 10)
                        Text("This helps us avoid giving you something that already didn't help.")
                            .font(.system(size: 14))
                            .foregroundColor(.lullInk2)
                            .lineSpacing(3)
                    }
                    .padding(.horizontal, Lull.horizontalPad)
                    .padding(.top, 10)
                    .padding(.bottom, 24)

                    VStack(spacing: 10) {
                        ForEach(Array(options.enumerated()), id: \.offset) { i, text in
                            ChoiceRow(
                                text: text,
                                selected: state.selectedTriedThings.contains(i),
                                onTap: { toggleTried(i) }
                            )
                        }
                    }
                    .padding(.horizontal, 20)

                    PrimaryCTA(title: "Build my routine", disabled: state.selectedTriedThings.isEmpty) {
                        step = 11
                    }
                        .padding(.horizontal, 20)
                        .padding(.top, 32)
                        .padding(.bottom, 36)
                }
            }
        }
    }

    private func toggleTried(_ index: Int) {
        if index == noneIndex {
            state.selectedTriedThings = state.selectedTriedThings.contains(index) ? [] : [index]
            return
        }

        state.selectedTriedThings.remove(noneIndex)
        toggle(&state.selectedTriedThings, index)
    }
}

// MARK: - Screen 9: Pattern Reveal

struct ChipFlow: Layout {
    var spacing: CGFloat = 8
    var rowSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 320
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + rowSpacing
                rowHeight = 0
            }
            x += size.width + (x == 0 ? 0 : spacing)
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + rowSpacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: size.width, height: size.height))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Screen 11: Methodology

struct OnbMethodologyView: View {
    @Binding var step: Int
    @EnvironmentObject var state: AppState
    @State private var orbExpanded = false
    @State private var canProceed = false
    @State private var didPlayGeneratedHaptic = false

    private static let bedtimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm"
        return f
    }()

    private let sleepProblemLabels = [
        0: "Struggling to fall asleep",
        1: "racing mind",
        2: "can’t fall back asleep",
        3: "waking up unrefreshed",
        4: "something else",
    ]

    private let preBedActivityLabels = [
        0: "using your phone or scrolling",
        1: "watching TV or screens",
        2: "exercising in the evening",
        3: "eating or snacking",
        4: "drinking coffee",
        5: "working",
        6: "having a nightcap or alcohol",
    ]

    private var bedtimeText: String {
        Self.bedtimeFormatter.string(from: state.targetBedtime)
    }

    private var flaggedLabels: [String] {
        let problemLabels = state.selectedSleepProblems
            .sorted()
            .compactMap { sleepProblemLabels[$0] }
        let activityLabels = state.selectedPreBedActivities
            .sorted()
            .compactMap { preBedActivityLabels[$0] }
        return problemLabels + activityLabels
    }

    private var flaggedText: String {
        let labels = flaggedLabels
        guard !labels.isEmpty else { return "your sleep pattern." }
        return labels.joined(separator: ", ") + "."
    }

    var body: some View {
        LullScreen(glowX: 0.5, glowY: 0.18, glowRadius: 280, glowOpacity: 0.52) {
            GeometryReader { geo in
                let compact = geo.size.height < 760
                let orbSize: CGFloat = compact ? 136 : 156
                let titleSize: CGFloat = compact ? 25 : 27
                let bodySize: CGFloat = compact ? 13.5 : 14.5

                VStack(spacing: 0) {
                    Spacer().frame(height: compact ? 24 : 40)

                    BrandMark(large: false)

                    Spacer(minLength: compact ? 36 : 70)

                    Circle()
                        .fill(RadialGradient(
                            stops: [
                                .init(color: Color(hex: "#ffc370"), location: 0),
                                .init(color: Color.lullAmberSoft, location: 0.55),
                                .init(color: Color.lullAmberDeep, location: 1),
                            ],
                            center: UnitPoint(x: 0.48, y: 0.34),
                            startRadius: 0,
                            endRadius: orbSize * 0.5
                        ))
                        .frame(width: orbSize, height: orbSize)
                        .overlay(alignment: .topLeading) {
                            Ellipse()
                                .fill(Color.white.opacity(0.46))
                                .frame(width: orbSize * 0.38, height: orbSize * 0.22)
                                .rotationEffect(.degrees(2))
                                .offset(x: orbSize * 0.14, y: orbSize * 0.14)
                                .blur(radius: 0.4)
                        }
                        .shadow(color: .lullAmberGlow, radius: orbExpanded ? 42 : 24)
                        .scaleEffect(orbExpanded ? 1.04 : 0.94)
                        .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: orbExpanded)

                    Spacer(minLength: compact ? 58 : 90)

                    VStack(spacing: 14) {
                        Text("Built around your \(bedtimeText)\nbedtime —")
                            .font(.serif(titleSize, weight: .semibold))
                            .foregroundColor(.lullInk0)
                            .lineSpacing(4)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.82)
                            .frame(maxWidth: 330)

                        (
                            Text("shaped by what you flagged:\n")
                                .foregroundColor(.lullInk2)
                            + Text(flaggedText)
                                .foregroundColor(.lullAmber)
                        )
                        .font(.system(size: bodySize, weight: .regular))
                        .lineSpacing(4)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 306)
                    }
                    .padding(.horizontal, Lull.horizontalPad)

                    Spacer()

                    PrimaryCTA(title: "Show my routine", disabled: !canProceed) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        step = 6
                    }
                    .opacity(canProceed ? 1 : 0.58)
                    .padding(.horizontal, Lull.horizontalPad)

                    Kicker(text: "Informed by CBT-I", color: .lullInk3)
                        .padding(.top, 26)
                        .padding(.bottom, compact ? 24 : 34)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .onAppear {
            state.selectedWakes = []
            state.selectedTriedThings = []
            state.currentBedtime = state.targetBedtime
            state.currentWakeTime = state.targetWakeTime
            state.typicalBedtime = state.targetBedtime
            state.typicalWakeTime = state.targetWakeTime
            state.refreshOnboardingClassifications()
            let answers = OnboardingAnswers(from: state)
            state.applyGeneratedRoutine(generateStartingRoutine(from: answers), scheduleNotifications: false)
            let generatedFeedback = UINotificationFeedbackGenerator()
            generatedFeedback.prepare()
            orbExpanded = true
            canProceed = false
            didPlayGeneratedHaptic = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 0.35)) {
                    canProceed = true
                }
                if !didPlayGeneratedHaptic {
                    generatedFeedback.notificationOccurred(.success)
                    didPlayGeneratedHaptic = true
                }
            }
        }
    }

}

// MARK: - Routine Ready (payoff screen)

struct OnbRoutineReadyView: View {
    @Binding var step: Int
    @EnvironmentObject var state: AppState

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
        routineContent
        .onAppear {
            playRevealHaptic()
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
                            VStack(alignment: .leading, spacing: 6) {
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
                                Text(whyLine(for: row.step.label))
                                    .font(.system(size: 12))
                                    .foregroundColor(.lullInk3)
                                    .lineLimit(2)
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
                            title: state.shouldOfferImmediateOnboardingRitual ? "Continue" : "Set tonight's reminder"
                        ) {
                            step = 7
                        }
                        GhostButton(title: "Customize first") {
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

    private func whyLine(for label: String) -> String {
        RemedyID.fromLabel(label)?.routineRevealBenefit
            ?? "Supports the sleep pattern we found in your answers."
    }

    private func playRevealHaptic() {
        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.prepare()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            feedback.impactOccurred(intensity: 0.65)
        }
    }
}

// MARK: - Commitment

struct OnbCommitmentView: View {
    @Binding var step: Int
    @EnvironmentObject var state: AppState
    @State private var isConfirming = false

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    private var reminderTime: Date { state.firstBedtimePrepDueTime }

    private var timeString: String { OnbCommitmentView.timeFmt.string(from: reminderTime) }

    private var nextStep: Int {
        9
    }

    var body: some View {
        LullScreen(glow: true, glowX: 0.48, glowY: 0.16, glowRadius: 290, glowOpacity: 0.64) {
            GeometryReader { geo in
                let compact = geo.size.height < 740

                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: compact ? 18 : 22) {
                            Spacer().frame(height: compact ? 20 : 34)
                            BrandMark(large: false)

                            VStack(spacing: 12) {
                                Kicker(text: "Tonight's commitment", color: .lullAmberSoft)

                                VStack(spacing: 0) {
                                    Text("We'll send you")
                                        .font(.serif(compact ? 32 : 36, weight: .semibold))
                                        .foregroundColor(.lullInk0)
                                    Text("a reminder")
                                        .font(.serifItalic(compact ? 34 : 38))
                                        .foregroundColor(.lullAmber)
                                }
                                .multilineTextAlignment(.center)

                                Text("Then the app will walk you through your ritual.")
                                    .font(.system(size: 14.5))
                                    .foregroundColor(.lullInk2)
                                    .lineSpacing(4)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: 310)
                            }
                            .padding(.top, compact ? 12 : 22)

                            VStack(spacing: 20) {
                                HStack(spacing: 12) {
                                    Image(systemName: "bell.badge")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.lullAmber)
                                        .frame(width: 38, height: 38)
                                        .background(Circle().fill(Color.lullAmber.opacity(0.12)))

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("First bedtime prep")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.lullInk1)
                                        Text(timeString)
                                            .font(.mono(12))
                                            .kerning(0.7)
                                            .foregroundColor(.lullInk3)
                                    }

                                    Spacer()

                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.lullInk4)
                                }

                                Text(timeString.lowercased())
                                    .font(.serifItalic(compact ? 54 : 64))
                                    .foregroundColor(.lullAmber)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .minimumScaleFactor(0.86)
                                    .lineLimit(1)

                                HStack(spacing: 8) {
                                    Image(systemName: "sparkle")
                                        .font(.system(size: 11, weight: .regular))
                                        .foregroundColor(.lullAmberSoft)
                                    Text("Locked to your first bedtime prep step")
                                        .font(.mono(10))
                                        .kerning(0.7)
                                        .foregroundColor(.lullInk3)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(22)
                            .background(
                                RoundedRectangle(cornerRadius: 22)
                                    .fill(Color.white.opacity(0.04))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 22)
                                    .strokeBorder(Color.lullAmber.opacity(0.16), lineWidth: 1)
                            )
                            .padding(.horizontal, Lull.horizontalPad)

                            Text("No streak pressure. No daily nagging. Just a specific time so tonight's plan has a place to land.")
                                .font(.mono(11))
                                .foregroundColor(.lullInk3)
                                .lineSpacing(4)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 310)

                            if isConfirming {
                                confirmation
                            }

                            Spacer().frame(height: 122)
                        }
                        .frame(maxWidth: 430)
                        .frame(maxWidth: .infinity)
                    }

                    bottomBar
                }
            }
        }
    }

    private var confirmation: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.lullAmber)
            Text("Time saved for \(timeString)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.lullInk1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Capsule().fill(Color.lullAmber.opacity(0.11)))
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            PrimaryCTA(title: isConfirming ? "Saving..." : "Yes, remind me", disabled: isConfirming) {
                guard !isConfirming else { return }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                isConfirming = true
                state.commitRoutineReminder(at: reminderTime)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
                    step = nextStep
                }
            }

            GhostButton(title: "Not tonight") {
                step = nextStep
            }
        }
        .padding(.horizontal, Lull.horizontalPad)
        .padding(.top, 18)
        .padding(.bottom, 34)
        .background(
            LinearGradient(
                colors: [Color.lullBg.opacity(0), Color.lullBg.opacity(0.96), Color.lullBg],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }
}

// MARK: - App-Blocking Commitment

struct OnbAppBlockingCommitmentView: View {
    @Binding var step: Int
    @EnvironmentObject var state: AppState
    @ObservedObject private var probe = AppBlockingAccessProbe.shared
    @State private var selection = FamilyActivitySelection()
    @State private var showPicker = false
    @State private var isSaving = false

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    private var lockAt: Date { state.typicalBedtime }
    private var unlockAt: Date { state.typicalWakeTime }
    private var appCount: Int { selection.applicationTokens.count }
    private var categoryCount: Int { selection.categoryTokens.count }
    private var selectedCount: Int { appCount + categoryCount }
    private var hasSelection: Bool { selectedCount > 0 }

    var body: some View {
        LullScreen(glow: true, glowX: 0.48, glowY: 0.16, glowRadius: 290, glowOpacity: 0.64) {
            GeometryReader { geo in
                let compact = geo.size.height < 740

                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: compact ? 14 : 18) {
                            Spacer().frame(height: compact ? 18 : 30)
                            BrandMark(large: false)

                            VStack(spacing: 12) {
                                HStack(spacing: 8) {
                                    Kicker(text: "Tonight's commitment", color: .lullAmberSoft)
                                    OnbPremiumChip()
                                }
                                (Text("What should TenThirty ")
                                    .foregroundColor(.lullInk0)
                                 + Text("lock away?")
                                    .font(.serifItalic(compact ? 34 : 38))
                                    .foregroundColor(.lullAmber))
                                    .font(.serif(compact ? 32 : 36, weight: .semibold))
                                    .multilineTextAlignment(.center)

                                Text("During your sleep window, TenThirty blocks the apps that keep you scrolling. It only runs at night, and you can bypass it any night you need to.")
                                    .font(.system(size: 14.5))
                                    .foregroundColor(.lullInk2)
                                    .lineSpacing(4)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: 318)
                            }
                            .padding(.top, compact ? 10 : 18)

                            HStack(spacing: 10) {
                                OnbBlockingTimeTile(
                                    title: "LOCK AT",
                                    value: Self.timeFmt.string(from: lockAt)
                                )
                                OnbBlockingTimeTile(
                                    title: "UNLOCK AT",
                                    value: Self.timeFmt.string(from: unlockAt)
                                )
                            }
                            .padding(.horizontal, Lull.horizontalPad)

                            accessCard
                                .padding(.horizontal, Lull.horizontalPad)

                            appPickerCard
                                .padding(.horizontal, Lull.horizontalPad)

                            Spacer().frame(height: hasSelection && probe.isApproved ? 128 : 92)
                        }
                        .frame(maxWidth: 430)
                        .frame(maxWidth: .infinity)
                    }

                    bottomBar
                }
            }
        }
        .familyActivityPicker(isPresented: $showPicker, selection: $selection)
        .onAppear {
            selection = state.appBlockingSelection
            probe.refresh()
        }
    }

    private var accessCard: some View {
        VStack(alignment: .leading, spacing: probe.isApproved ? 0 : 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("STEP 1 · APP BLOCKING")
                    .font(.mono(10))
                    .kerning(1.3)
                    .foregroundColor(.lullInk3)
                Spacer()
                Text(probe.isApproved ? "ACCESS APPROVED" : probe.statusText.uppercased())
                    .font(.mono(9.5))
                    .kerning(1)
                    .foregroundColor(probe.isApproved ? Color(hex: "#8fce93") : .lullAmber)
            }

            if !probe.isApproved {
                Text(probe.detailText)
                    .font(.system(size: 13))
                    .foregroundColor(.lullInk2)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    Task { await probe.requestAccess() }
                } label: {
                    HStack(spacing: 8) {
                        if probe.isChecking {
                            ProgressView()
                                .tint(.lullBgDeep)
                        } else {
                            Image(systemName: "lock.shield")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        Text("Check access")
                            .font(.system(size: 14.5, weight: .semibold))
                    }
                    .foregroundColor(.lullBgDeep)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Capsule().fill(Color.lullAmber))
                    .shadow(color: .lullAmberGlow, radius: 12, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(probe.isChecking)
                .opacity(probe.isChecking ? 0.75 : 1)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(probe.isApproved ? Color(hex: "#8fce93").opacity(0.25) : Color.lullAmber.opacity(0.16), lineWidth: 1)
        )
    }

    private var appPickerCard: some View {
        Button {
            guard probe.isApproved else { return }
            showPicker = true
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Text("STEP 2 · CHOOSE APPS")
                        .font(.mono(10))
                        .kerning(1.3)
                        .foregroundColor(probe.isApproved ? .lullInk1 : .lullInk3)
                    if selectedCount > 0 {
                        Text("· \(selectedCount) SELECTED")
                            .font(.mono(10))
                            .kerning(1.0)
                            .foregroundColor(.lullAmber)
                    }
                    Spacer()
                    Image(systemName: probe.isApproved ? "chevron.right" : "lock.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(probe.isApproved ? .lullAmber : .lullInk4)
                }

                HStack(spacing: 10) {
                    ForEach(selectionSlots, id: \.self) { slot in
                        OnbBlockingSelectionSlot(kind: slot)
                    }
                }

                if selectedCount > 0 {
                    Text(selectionSummary)
                        .font(.system(size: 12.5))
                        .foregroundColor(.lullInk3)
                        .lineSpacing(3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(probe.isApproved ? Color.white.opacity(0.04) : Color.white.opacity(0.025))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(
                        probe.isApproved ? Color.lullAmber.opacity(0.16) : Color.lullLineStrong,
                        style: StrokeStyle(lineWidth: 1, dash: probe.isApproved ? [] : [5, 5])
                    )
            )
            .opacity(probe.isApproved ? 1 : 0.52)
        }
        .buttonStyle(.plain)
        .disabled(!probe.isApproved)
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            if probe.isApproved && hasSelection {
                PrimaryCTA(title: isSaving ? "Saving..." : "Lock it in for tonight", disabled: isSaving) {
                    guard !isSaving else { return }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    isSaving = true
                    state.configureAppBlocking(
                        selection: selection,
                        enabled: true,
                        startTime: lockAt,
                        endTime: unlockAt,
                        graceMinutes: state.appBlockingGraceMinutes
                    )
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
                        step = 9
                    }
                }
            }

            GhostButton(title: "Not tonight") {
                step = 9
            }
        }
        .padding(.horizontal, Lull.horizontalPad)
        .padding(.top, 18)
        .padding(.bottom, 34)
        .background(
            LinearGradient(
                colors: [Color.lullBg.opacity(0), Color.lullBg.opacity(0.96), Color.lullBg],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private var selectionSlots: [OnbBlockingSelectionSlot.Kind] {
        var slots: [OnbBlockingSelectionSlot.Kind] = []
        let tokenCount = min(selectedCount, 3)
        for index in 0..<tokenCount {
            slots.append(index < appCount ? .app : .category)
        }
        while slots.count < 3 {
            slots.append(.empty)
        }
        return slots
    }

    private var selectionSummary: String {
        var parts: [String] = []
        if appCount > 0 {
            parts.append("\(appCount) \(appCount == 1 ? "app" : "apps")")
        }
        if categoryCount > 0 {
            parts.append("\(categoryCount) \(categoryCount == 1 ? "category" : "categories")")
        }
        return parts.joined(separator: " · ")
    }
}

private struct OnbBlockingTimeTile: View {
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.mono(10))
                .kerning(1.2)
                .foregroundColor(.lullInk4)
            Text(value)
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(.lullInk1)
                .minimumScaleFactor(0.82)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.lullLineStrong, lineWidth: 1)
        )
    }
}

private struct OnbPremiumChip: View {
    var body: some View {
        Text("PREMIUM")
            .font(.mono(8.5))
            .kerning(1.1)
            .foregroundColor(.lullAmber)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.lullAmber.opacity(0.10)))
            .overlay(Capsule().strokeBorder(Color.lullAmber.opacity(0.28), lineWidth: 1))
    }
}

private struct OnbBlockingSelectionSlot: View {
    enum Kind: Hashable {
        case app
        case category
        case empty
    }

    var kind: Kind

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(background)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(border, style: StrokeStyle(lineWidth: 1, dash: kind == .empty ? [5, 5] : []))
                )
                .frame(width: 50, height: 50)

            Image(systemName: icon)
                .font(.system(size: kind == .empty ? 17 : 16, weight: .semibold))
                .foregroundColor(iconColor)
        }
    }

    private var icon: String {
        switch kind {
        case .app: return "app.fill"
        case .category: return "square.grid.2x2.fill"
        case .empty: return "plus"
        }
    }

    private var background: Color {
        kind == .empty ? Color.clear : Color.lullAmber.opacity(0.10)
    }

    private var border: Color {
        kind == .empty ? Color.lullLineStrong : Color.lullAmber.opacity(0.30)
    }

    private var iconColor: Color {
        kind == .empty ? .lullInk4 : .lullAmber
    }
}

// MARK: - Trial Paywall

struct OnbTrialPaywallView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject private var subscriptions: LullSubscriptionManager
    @Environment(\.openURL) private var openURL
    @State private var statusMessage: String?

    var body: some View {
        LullScreen(glow: true, glowX: 0.5, glowY: 0.04, glowRadius: 320, glowOpacity: 0.62) {
            GeometryReader { geo in
                let compact = geo.size.height < 760
                let bottomInset = max(geo.safeAreaInsets.bottom, 12)

                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: compact ? 18 : 22) {
                            Spacer().frame(height: compact ? 18 : 28)
                            BrandMark(large: false)
                                .padding(.bottom, compact ? 4 : 8)

                            trialHero(compact: compact)
                            TrialQuoteCard()
                            trialBenefits(compact: compact)
                            TrialReassuranceCard()

                            Text("Free for 7 nights. No card, no charge.\nAfter that, TenThirty is $49.99/yr only if you choose to stay.")
                                .font(.system(size: 13))
                                .foregroundColor(.lullInk3)
                                .lineSpacing(4)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)

                            if let statusMessage {
                                Text(statusMessage)
                                    .font(.system(size: 12))
                                    .foregroundColor(.lullAmberSoft)
                                    .lineSpacing(3)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                            }

                            Spacer().frame(height: compact ? 116 : 128)
                        }
                        .padding(.horizontal, Lull.horizontalPad)
                        .frame(maxWidth: 430)
                        .frame(maxWidth: .infinity)
                    }

                    bottomBar(bottomInset: bottomInset)
                }
            }
        }
    }

    private func trialHero(compact: Bool) -> some View {
        VStack(spacing: 10) {
            Kicker(text: "Your first week", color: .lullAmberSoft)

            VStack(spacing: -2) {
                Text("Try 7 nights")
                    .font(.serif(compact ? 38 : 44, weight: .semibold))
                    .foregroundColor(.lullInk0)
                    .minimumScaleFactor(0.86)
                    .lineLimit(1)
                Text("free")
                    .font(.serifItalic(compact ? 40 : 46))
                    .foregroundColor(.lullAmber)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)

            Text("Start your wind-down ritual tonight, then decide after you've actually slept.")
                .font(.system(size: 14.5))
                .foregroundColor(.lullInk2)
                .lineSpacing(4)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 310)
        }
        .frame(maxWidth: .infinity)
    }

    private func trialBenefits(compact: Bool) -> some View {
        VStack(spacing: compact ? 10 : 12) {
            TrialBenefit(
                title: "A routine built for your brain",
                detail: "Personalized to what actually keeps you up"
            )
            TrialBenefit(
                title: "Block the 1am scroll",
                detail: "Lock distracting apps through your sleep window"
            )
            TrialBenefit(
                title: "Quiet the overthinking",
                detail: "Brain dump + guided breathing, step by step"
            )
            TrialBenefit(
                title: "A nudge when it's time",
                detail: "Gentle reminders that keep you on track"
            )
            TrialBenefit(
                title: "Drift off, then silence",
                detail: "Sleep sounds that fade out on their own"
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.lullAmber.opacity(0.16), lineWidth: 1)
        )
    }

    private func bottomBar(bottomInset: CGFloat) -> some View {
        VStack(spacing: 12) {
            TrialCTA {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                state.completeOnboarding()
            }

            HStack(spacing: 26) {
                footerButton("Terms") {
                    open("https://tenthirty.app/terms")
                }
                footerButton("Privacy") {
                    open("https://tenthirty.app/privacy")
                }
                footerButton(subscriptions.isLoading ? "Restoring" : "Restore") {
                    Task { await restore() }
                }
            }
        }
        .padding(.horizontal, Lull.horizontalPad)
        .padding(.top, 22)
        .padding(.bottom, bottomInset + 6)
        .background(
            LinearGradient(
                colors: [Color.lullBg.opacity(0.0), Color.lullBg.opacity(0.96), Color.lullBg],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private func footerButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.mono(10))
                .kerning(0.8)
                .foregroundColor(.lullInk3)
        }
        .buttonStyle(.plain)
        .disabled(title == "Restoring")
    }

    private func open(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        openURL(url)
    }

    @MainActor
    private func restore() async {
        statusMessage = nil
        await subscriptions.restorePurchases()
        if subscriptions.isLullProActive {
            state.applyRevenueCatEntitlement(isActive: true)
            state.completeOnboarding()
        } else {
            statusMessage = subscriptions.lastErrorMessage ?? "No active TenThirty Premium purchase was found."
        }
    }
}

private struct TrialBenefit: View {
    var title: String
    var detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.lullAmber.opacity(0.12))
                    .frame(width: 22, height: 22)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.lullAmber)
            }
            .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.lullInk0)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.system(size: 12.5))
                    .foregroundColor(.lullInk2)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TrialQuoteCard: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("★★★★★")
                .font(.system(size: 12, weight: .semibold))
                .kerning(1.2)
                .foregroundColor(.lullAmber)
                .lineLimit(1)
                .layoutPriority(1)

            Text("\"It's been great for me\"")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.lullInk0)
                .lineLimit(1)
                .minimumScaleFactor(0.86)

            Text("- Beth M.")
                .font(.system(size: 12))
                .foregroundColor(.lullInk3)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Capsule().fill(Color.white.opacity(0.045)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }
}

private struct TrialReassuranceCard: View {
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.lullAmber.opacity(0.10))
                    .frame(width: 34, height: 34)
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.lullAmber)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Nothing to enter. Nothing to cancel.")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.lullInk0)
                Text("We won't ask for payment details to start your trial. Decide if TenThirty's worth it after you've actually slept.")
                    .font(.system(size: 12))
                    .foregroundColor(.lullInk2)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [Color.lullAmber.opacity(0.09), Color.white.opacity(0.025)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.lullAmber.opacity(0.22), lineWidth: 1)
        )
    }
}

private struct TrialCTA: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text("Start my free week")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.lullBgDeep)
                Text("No payment info needed")
                    .font(.mono(9.5))
                    .kerning(0.8)
                    .foregroundColor(.lullBgDeep.opacity(0.72))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(Capsule().fill(Color.lullAmber))
            .shadow(color: Color.lullAmberGlow, radius: 16)
            .shadow(color: Color.black.opacity(0.4), radius: 12, y: 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Helpers

private func toggle(_ set: inout Set<Int>, _ value: Int) {
    if set.contains(value) { set.remove(value) } else { set.insert(value) }
}
