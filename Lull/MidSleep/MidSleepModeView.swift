import SwiftUI

struct MidSleepModeView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    @State private var showBoringStory = false
    @State private var showBodyScan = false

    private let toolkit: [(primary: String, sub: String, featured: Bool)] = [
        ("4·7·8 breath",  "IN · HOLD · OUT",  true),
        ("Boring story",  "~8 MIN · AUDIO",   false),
        ("Body scan",     "~5 MIN · GUIDED",  false),
    ]

    var body: some View {
        LullScreen(glow: false) {
            // Very subtle amber wash
            RadialGradient(
                colors: [Color.lullAmber.opacity(0.06), .clear],
                center: .center, startRadius: 0, endRadius: 190)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 16)

                // Status bar row
                HStack {
                    Text("MID-SLEEP MODE")
                        .font(.mono(10.5))
                        .kerning(1.4)
                        .foregroundColor(.lullInk4)
                    Spacer()
                    Ember(size: 5)
                    Text("03:14")
                        .font(.mono(10.5))
                        .kerning(1)
                        .foregroundColor(.lullInk4)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 36)

                VStack(spacing: 14) {
                    Text("You're awake.")
                        .font(.serif(28))
                        .foregroundColor(.lullInk2)
                    Text("That's okay.")
                        .font(.serifItalic(28))
                        .foregroundColor(.lullAmber)
                }
                .multilineTextAlignment(.center)

                Text("One tap. No decisions. Pick the gentlest thing your brain will accept.")
                    .font(.system(size: 13.5))
                    .foregroundColor(.lullInk3)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 270)
                    .padding(.top, 14)

                // Toolkit
                VStack(spacing: 12) {
                    ForEach(toolkit, id: \.primary) { opt in
                        Button(action: {
                            if opt.primary == "4·7·8 breath" {
                                let idx = state.nightlyFlowSteps.firstIndex(of: .fourSevenEightBreathing) ?? 0
                                state.nightlyStep = idx
                                state.showNightlyFlow = true
                                dismiss()
                            } else if opt.primary == "Boring story" {
                                showBoringStory = true
                            } else if opt.primary == "Body scan" {
                                showBodyScan = true
                            }
                        }) {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(opt.featured
                                            ? AnyShapeStyle(RadialGradient(colors: [.lullAmber, .lullAmberDeep],
                                                                            center: .center, startRadius: 0, endRadius: 26))
                                            : AnyShapeStyle(Color.white.opacity(0.04)))
                                        .overlay(Circle().strokeBorder(opt.featured ? Color.clear : Color.lullLine, lineWidth: 1))
                                        .frame(width: 52, height: 52)
                                        .shadow(color: opt.featured ? .lullAmberGlow : .clear, radius: 10)

                                    if opt.featured {
                                        Circle()
                                            .fill(Color(hex: "#1a0d06"))
                                            .frame(width: 12, height: 12)
                                    } else {
                                        Ember(size: 6)
                                    }
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(opt.primary)
                                        .font(.serif(19))
                                        .foregroundColor(opt.featured ? .lullInk0 : .lullInk1)
                                    Text(opt.sub)
                                        .font(.mono(10.5))
                                        .kerning(1)
                                        .foregroundColor(.lullInk3)
                                }
                                Spacer()
                                Text("›")
                                    .font(.system(size: 22, weight: .light))
                                    .foregroundColor(opt.featured ? .lullAmber : .lullInk3)
                            }
                            .padding(24)
                            .background(
                                RoundedRectangle(cornerRadius: 22)
                                    .fill(opt.featured
                                        ? LinearGradient(colors: [Color.lullAmber.opacity(0.10), Color.lullAmber.opacity(0.02)],
                                                         startPoint: .top, endPoint: .bottom)
                                        : LinearGradient(colors: [Color.white.opacity(0.025), Color.white.opacity(0.025)],
                                                         startPoint: .top, endPoint: .bottom))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 22)
                                    .strokeBorder(opt.featured ? Color.lullAmber.opacity(0.4) : Color.lullLine, lineWidth: 1)
                            )
                            .shadow(color: opt.featured ? Color.lullAmberGlow.opacity(0.4) : .clear, radius: 14)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 44)

                Spacer()

                // Get-up protocol link
                VStack(spacing: 8) {
                    Text("STILL AWAKE IN 20 MIN?")
                        .font(.mono(10))
                        .kerning(1.4)
                        .foregroundColor(.lullInk4)
                    Button(action: { state.showMidSleepMode = false }) {
                        Text("Try the get-up protocol →")
                            .font(.system(size: 14))
                            .foregroundColor(.lullInk2)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 40)
            }
        }
        .fullScreenCover(isPresented: $showBoringStory) { MidSleepBoringStoryView() }
        .fullScreenCover(isPresented: $showBodyScan)    { MidSleepBodyScanView() }
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
