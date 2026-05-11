import SwiftUI

struct MidSleepModeView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    @AppStorage("hasSeenMidSleepMode") private var hasSeenMidSleepMode = false

    @State private var showBreathing    = false
    @State private var showBoringStory  = false
    @State private var showBodyScan     = false
    @State private var showGetUpPrompt  = false
    @State private var sessionStart: Date? = nil
    @State private var awakeMinutes: Int = 0
    @State private var minuteTimer: Timer? = nil
    @State private var currentDate = Date()

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()

    // True when the current clock time falls within the user's sleep window.
    private var isInSleepWindow: Bool {
        let cal = Calendar.current
        let now = Date()
        let nowH = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        let bedH = cal.component(.hour, from: state.typicalBedtime) * 60 + cal.component(.minute, from: state.typicalBedtime)
        let wakeH = cal.component(.hour, from: state.typicalWakeTime) * 60 + cal.component(.minute, from: state.typicalWakeTime)
        if bedH > wakeH {
            return nowH >= bedH || nowH < wakeH
        } else {
            return nowH >= bedH && nowH < wakeH
        }
    }

    private var pastThreshold: Bool { awakeMinutes >= 20 }

    var body: some View {
        LullScreen(glow: false) {
            // Background wash — cool moonlit in awake window, subtle amber in sleep window
            Group {
                if isInSleepWindow {
                    RadialGradient(
                        colors: [Color.lullAmber.opacity(0.05), .clear],
                        center: UnitPoint(x: 0.5, y: 0.5), startRadius: 0, endRadius: 190)
                } else {
                    RadialGradient(
                        colors: [Color(hex: "#9698dc").opacity(0.10), .clear],
                        center: UnitPoint(x: 0.5, y: 0.18), startRadius: 0, endRadius: 210)
                }
            }
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 16)

                    // Status bar row
                    HStack {
                        Text("MID-SLEEP MODE")
                            .font(.mono(10.5))
                            .kerning(1.4)
                            .foregroundColor(isInSleepWindow ? .lullInk4 : Color(hex: "#7a6f9a"))
                        Spacer()
                        Ember(size: 5)
                        Text(MidSleepModeView.timeFmt.string(from: currentDate))
                            .font(.mono(10.5))
                            .kerning(1)
                            .foregroundColor(.lullInk4)
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 18)

                    // Education card
                    MidSleepEduCard(isInSleepWindow: isInSleepWindow)
                        .padding(.horizontal, 22)
                        .padding(.bottom, 22)

                    // Toolkit
                    VStack(spacing: 10) {
                        ForEach(toolkitItems, id: \.primary) { opt in
                            Button(action: {
                                if opt.primary == "4·7·8 breath"  { showBreathing = true }
                                else if opt.primary == "Boring story" { showBoringStory = true }
                                else if opt.primary == "Body scan"    { showBodyScan = true }
                            }) {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(opt.featured
                                                ? AnyShapeStyle(RadialGradient(
                                                    colors: [.lullAmber, .lullAmberDeep],
                                                    center: .center, startRadius: 0, endRadius: 26))
                                                : AnyShapeStyle(Color.white.opacity(0.04)))
                                            .overlay(Circle().strokeBorder(
                                                opt.featured ? Color.clear : Color.lullLine, lineWidth: 1))
                                            .frame(width: 44, height: 44)
                                            .shadow(color: opt.featured ? .lullAmberGlow : .clear, radius: 8)

                                        if opt.featured {
                                            Circle().fill(Color(hex: "#1a0d06")).frame(width: 10, height: 10)
                                        } else {
                                            Ember(size: 6)
                                        }
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(opt.primary)
                                            .font(.serif(17))
                                            .foregroundColor(opt.featured ? .lullInk0 : .lullInk1)
                                        Text(opt.sub + (!isInSleepWindow ? " · PREVIEW" : ""))
                                            .font(.mono(10))
                                            .kerning(1)
                                            .foregroundColor(.lullInk3)
                                    }

                                    Spacer()

                                    Text("›")
                                        .font(.system(size: 20, weight: .light))
                                        .foregroundColor(opt.featured ? .lullAmber : .lullInk3)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 18)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(opt.featured
                                            ? LinearGradient(
                                                colors: [Color.lullAmber.opacity(0.10), Color.lullAmber.opacity(0.02)],
                                                startPoint: .top, endPoint: .bottom)
                                            : LinearGradient(
                                                colors: [Color.white.opacity(0.025), Color.white.opacity(0.025)],
                                                startPoint: .top, endPoint: .bottom))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .strokeBorder(
                                            opt.featured ? Color.lullAmber.opacity(0.4) : Color.lullLine,
                                            lineWidth: 1)
                                )
                                .shadow(color: opt.featured ? .lullAmberGlow.opacity(0.4) : .clear, radius: 14)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 20)

                    // Get-up protocol footer
                    MidSleepGetUpFooter(
                        isInSleepWindow: isInSleepWindow,
                        awakeMinutes: awakeMinutes,
                        pastThreshold: pastThreshold,
                        onStartGetUp: { showGetUpPrompt = true }
                    )
                    .padding(.horizontal, 22)
                    .padding(.bottom, 36)
                }
            }
        }
        .fullScreenCover(isPresented: $showBreathing) {
            NightlyBreathingView(isMidSleep: true).environmentObject(state)
        }
        .fullScreenCover(isPresented: $showBoringStory) { MidSleepBoringStoryView() }
        .fullScreenCover(isPresented: $showBodyScan)    { MidSleepBodyScanView() }
        .fullScreenCover(isPresented: $showGetUpPrompt) {
            GetUpPromptView().environmentObject(state)
        }
        .onAppear {
            currentDate = Date()
            hasSeenMidSleepMode = true
            if isInSleepWindow {
                sessionStart = Date()
                minuteTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
                    Task { @MainActor in
                        guard let start = self.sessionStart else { return }
                        self.awakeMinutes = Int(Date().timeIntervalSince(start) / 60)
                    }
                }
            }
        }
        .onDisappear {
            minuteTimer?.invalidate()
            minuteTimer = nil
        }
    }

    private var toolkitItems: [(primary: String, sub: String, featured: Bool)] {
        [
            ("4·7·8 breath", "In · hold · out", isInSleepWindow),
            ("Boring story",  "~8 min · audio",  false),
            ("Body scan",     "~5 min · guided",  false),
        ]
    }
}

// MARK: - Education Card

struct MidSleepEduCard: View {
    var isInSleepWindow: Bool

    // Cool moonlit palette — not in design token system, kept inline
    private let coolCard    = Color(hex: "#3c345a")
    private let coolBorder  = Color(hex: "#b4a0dc")
    private let coolGlow    = Color(hex: "#a0aadc")
    private let coolEyebrow = Color(hex: "#a89cc8")
    private let coolTitle   = Color(hex: "#cfc4ec")

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Corner glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [coolGlow.opacity(0.16), .clear],
                        center: .center, startRadius: 0, endRadius: 80)
                )
                .frame(width: 160, height: 160)
                .offset(x: 30, y: -40)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Text(isInSleepWindow
                         ? "How to use this"
                         : "Preview · use this when you wake up tonight")
                        .font(.mono(10))
                        .kerning(1.4)
                        .foregroundColor(coolEyebrow)
                        .fixedSize(horizontal: false, vertical: true)

                    if !isInSleepWindow {
                        Spacer()
                        Text("Practice")
                            .font(.mono(9))
                            .kerning(1.2)
                            .foregroundColor(coolTitle)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(coolBorder.opacity(0.10))
                                    .overlay(Capsule().strokeBorder(coolBorder.opacity(0.25), lineWidth: 1))
                            )
                    }
                }
                .padding(.bottom, 8)

                if isInSleepWindow {
                    (Text("You're up, mid-sleep.")
                        .italic()
                        .foregroundColor(coolTitle)
                    + Text(" Don't fight it.")
                        .foregroundColor(.lullInk1))
                    .font(.serif(20))
                    .lineSpacing(2)
                    .padding(.bottom, 8)

                    Text("Pick the gentlest technique your brain will accept. Eyes stay closed. No decisions, no scrolling. If you're still awake in 20 minutes, get out of bed — staying in bed awake teaches your brain that bed = thinking.")
                        .font(.system(size: 12.5))
                        .foregroundColor(.lullInk2)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("For 2am wake-ups.")
                        .font(.serifItalic(20))
                        .foregroundColor(coolTitle)
                        .padding(.bottom, 8)

                    Text("If you wake during the night and can't fall back asleep, open this screen and tap one technique. They're designed to work with eyes closed — no decisions, no light, no scroll. Tonight you can rehearse them so your hands know where to go.")
                        .font(.system(size: 12.5))
                        .foregroundColor(.lullInk2)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: isInSleepWindow
                            ? [coolCard.opacity(0.55), Color(hex: "#1c1820").opacity(0.30)]
                            : [coolCard.opacity(0.45), Color(hex: "#1c182a").opacity(0.30)],
                        startPoint: .top, endPoint: .bottom)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(coolBorder.opacity(0.18), lineWidth: 1)
                )
        )
        .clipped()
    }
}

// MARK: - Get-Up Footer

struct MidSleepGetUpFooter: View {
    var isInSleepWindow: Bool
    var awakeMinutes: Int
    var pastThreshold: Bool
    var onStartGetUp: () -> Void

    var body: some View {
        if !isInSleepWindow {
            // Awake window: dashed teaser
            awakeWindowTeaser
        } else {
            // Sleep window: live card
            sleepWindowCard
        }
    }

    // MARK: Awake window teaser
    private var awakeWindowTeaser: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("IF YOU'RE STILL AWAKE AFTER 20 MIN")
                .font(.mono(9.5))
                .kerning(1.4)
                .foregroundColor(.lullInk3)
            Text("Lull will surface a ")
                .font(.system(size: 12.5))
                .foregroundColor(.lullInk1)
            + Text("get-up protocol")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(.lullAmberSoft)
            + Text(" — a short reset in another room so your brain keeps associating bed with sleep, not frustration.")
                .font(.system(size: 12.5))
                .foregroundColor(.lullInk1)

            Button(action: {}) {
                Text("Why 20 minutes? · the science →")
                    .font(.system(size: 12))
                    .foregroundColor(.lullAmberSoft)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                        .foregroundColor(Color.lullLine)
                )
        )
    }

    // MARK: Sleep window card
    private var sleepWindowCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(pastThreshold ? Color.lullAmber : Color.lullInk3)
                        .frame(width: 6, height: 6)
                        .shadow(color: pastThreshold ? .lullAmberGlow : .clear, radius: 4)
                    Text("Still awake? · \(awakeMinutes) min")
                        .font(.mono(10))
                        .kerning(1.6)
                        .foregroundColor(pastThreshold ? .lullAmber : .lullInk3)
                }
                Spacer()
            }
            .padding(.bottom, 10)

            Text("Get out of bed.")
                .font(.serif(22))
                .foregroundColor(.lullInk0)
                .padding(.bottom, 6)

            Text("After 20 min awake, your brain starts associating bed with frustration. A short reset in another room — dim light, no screens, something boring — protects that association.")
                .font(.system(size: 12.5))
                .foregroundColor(.lullInk2)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 14)

            PrimaryCTA(title: "Start get-up protocol →") {
                onStartGetUp()
            }

            Button(action: {}) {
                Text("Why 20 minutes? · the science")
                    .font(.system(size: 12))
                    .foregroundColor(.lullInk3)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    pastThreshold
                    ? LinearGradient(
                        colors: [Color.lullAmber.opacity(0.14), Color.lullAmber.opacity(0.04)],
                        startPoint: .top, endPoint: .bottom)
                    : LinearGradient(
                        colors: [Color.white.opacity(0.025), Color.white.opacity(0.025)],
                        startPoint: .top, endPoint: .bottom)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            pastThreshold ? Color.lullAmber.opacity(0.45) : Color.lullLine,
                            lineWidth: 1)
                )
                .shadow(color: pastThreshold ? .lullAmberGlow.opacity(0.5) : .clear, radius: 14)
        )
        .animation(.easeInOut(duration: 0.25), value: pastThreshold)
    }
}

// MARK: - Boring Story

struct MidSleepBoringStoryView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var tts = TTSService()
    @State private var elapsedSeconds = 0
    @State private var clockTimer: Timer?
    @State private var glowPulse = false

    var body: some View {
        LullScreen(glow: false) {
            RadialGradient(colors: [Color.lullAmber.opacity(0.08), .clear],
                           center: UnitPoint(x: 0.5, y: 0.38), startRadius: 0, endRadius: 210)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("BORING STORY")
                        .font(.mono(10.5)).kerning(1.4).foregroundColor(.lullInk4)
                    Spacer()
                    Button(action: { finish() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14)).foregroundColor(.lullInk3)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 28).padding(.top, 20).padding(.bottom, 36)

                VStack(spacing: 14) {
                    Text("Eyes closed.")
                        .font(.serif(26)).foregroundColor(.lullInk2)
                    Text("Just listen.")
                        .font(.serifItalic(26)).foregroundColor(.lullAmber)
                }
                .multilineTextAlignment(.center)

                Spacer()

                Circle()
                    .fill(Color.lullAmber)
                    .frame(width: 14, height: 14)
                    .shadow(color: .lullAmber,    radius: glowPulse ? 28 : 10)
                    .shadow(color: .lullAmberGlow, radius: glowPulse ? 56 : 22)
                    .scaleEffect(glowPulse ? 1.3 : 1.0)
                    .animation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true), value: glowPulse)
                    .onAppear { glowPulse = true }

                Spacer()

                VStack(spacing: 12) {
                    Text("\(timeString(elapsedSeconds)) / ~8:00")
                        .font(.mono(11)).kerning(1.6).foregroundColor(.lullInk3)
                    GeometryReader { geo in
                        let pct = min(1, CGFloat(elapsedSeconds) / 480)
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.08))
                            Capsule().fill(Color.lullAmber.opacity(0.7)).frame(width: geo.size.width * pct)
                        }
                    }
                    .frame(height: 2)
                    .animation(.linear(duration: 1), value: elapsedSeconds)
                }
                .padding(.horizontal, 28)

                HStack(spacing: 22) {
                    circleButton(icon: tts.isPaused ? "play.fill" : "pause.fill", size: 18) { tts.togglePause() }
                    circleButton(icon: "xmark", size: 14) { finish() }
                }
                .padding(.top, 36).padding(.bottom, 52)
            }
        }
        .onAppear {
            let story = (0..<2).map { _ in BundledStories.all.randomElement() ?? "" }.joined(separator: "\n\n")
            tts.append(story); tts.flushRemaining()
            clockTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                Task { @MainActor in elapsedSeconds += 1 }
            }
        }
        .onDisappear { finish() }
    }

    private func finish() { tts.stop(); clockTimer?.invalidate(); dismiss() }
    private func timeString(_ s: Int) -> String { String(format: "%d:%02d", s / 60, s % 60) }
    private func circleButton(icon: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle().strokeBorder(Color.lullLine, lineWidth: 1)
                    .background(Circle().fill(Color.white.opacity(0.02)))
                    .frame(width: 56, height: 56)
                Image(systemName: icon).font(.system(size: size)).foregroundColor(.lullInk2)
            }
        }.buttonStyle(.plain)
    }
}

// MARK: - Body Scan

struct MidSleepBodyScanView: View {
    @Environment(\.dismiss) var dismiss
    @State private var currentStep = 0
    @State private var secondsLeft = 20
    @State private var timer: Timer?

    private let steps: [(area: String, instruction: String)] = [
        ("Feet & toes",    "Let them go heavy. Feel the weight sink into the mattress."),
        ("Calves & shins", "Release any held tension. Let your legs feel warm and still."),
        ("Thighs & hips",  "Soften the muscles. Allow the bed to fully support you."),
        ("Belly",          "With each breath out, let your belly fall. No effort needed."),
        ("Chest",          "Notice the gentle rise and fall. You don't need to control it."),
        ("Hands & arms",   "Uncurl your fingers. Let your arms rest heavy at your sides."),
        ("Shoulders",      "Drop them away from your ears. Feel the space open."),
        ("Face & jaw",     "Unclench your jaw. Let your eyes be soft behind your lids."),
    ]

    var body: some View {
        LullScreen(glow: false) {
            RadialGradient(colors: [Color.lullAmber.opacity(0.05), .clear],
                           center: .center, startRadius: 0, endRadius: 200)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("BODY SCAN")
                        .font(.mono(10.5)).kerning(1.4).foregroundColor(.lullInk4)
                    Spacer()
                    Text("\(currentStep + 1) / \(steps.count)")
                        .font(.mono(10.5)).kerning(1).foregroundColor(.lullInk4)
                }
                .padding(.horizontal, 28).padding(.top, 20).padding(.bottom, 48)

                if currentStep < steps.count {
                    let step = steps[currentStep]

                    VStack(spacing: 16) {
                        Kicker(text: "Focus here")
                        Text(step.area)
                            .font(.serif(32)).foregroundColor(.lullAmber)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 28)

                    Text(step.instruction)
                        .font(.system(size: 15))
                        .foregroundColor(.lullInk2)
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .frame(maxWidth: 290)
                        .padding(.top, 24).padding(.horizontal, 28)

                    Spacer()

                    ZStack {
                        Circle().stroke(Color.lullLine, lineWidth: 1).frame(width: 96, height: 96)
                        Circle()
                            .trim(from: 0, to: CGFloat(secondsLeft) / 20)
                            .stroke(Color.lullAmber.opacity(0.7), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .frame(width: 96, height: 96)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1), value: secondsLeft)
                        Text("\(secondsLeft)")
                            .font(.serif(32)).foregroundColor(.lullInk1)
                    }

                    Spacer()

                    Button(action: advance) {
                        Text(currentStep < steps.count - 1 ? "Next area →" : "Done · rest now")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color(hex: "#1a0d06"))
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .background(Capsule().fill(Color.lullAmber))
                            .shadow(color: .lullAmberGlow, radius: 12)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 22).padding(.bottom, 52)
                } else {
                    Spacer()
                    VStack(spacing: 16) {
                        Text("Scan complete.")
                            .font(.serif(28)).foregroundColor(.lullInk2)
                        Text("Let yourself drift.")
                            .font(.serifItalic(28)).foregroundColor(.lullAmber)
                    }
                    Spacer()
                    Button(action: { dismiss() }) {
                        Text("Close")
                            .font(.system(size: 14)).foregroundColor(.lullInk3)
                    }
                    .buttonStyle(.plain).padding(.bottom, 52)
                }
            }
        }
        .onAppear { startTimer() }
        .onDisappear { timer?.invalidate() }
    }

    private func startTimer() {
        secondsLeft = 20
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                if secondsLeft > 0 { secondsLeft -= 1 } else { advance() }
            }
        }
    }

    private func advance() {
        if currentStep < steps.count - 1 {
            currentStep += 1
            startTimer()
        } else {
            currentStep = steps.count
            timer?.invalidate()
        }
    }
}
