import SwiftUI

// Guides the user through 5 muscle groups, 20 seconds each.
// Tense then release (a step-based timer view, distinct from the audio-guided body scan).
struct NightlyProgressiveMuscleRelaxationView: View {
    @EnvironmentObject var state: AppState
    @State private var currentStep = 0
    @State private var secondsLeft = 20
    @State private var timer: Timer?

    private let groups: [(area: String, instruction: String)] = [
        ("Feet & calves",    "Curl your toes and tense your calves. Hold the squeeze… then release completely. Feel the warmth."),
        ("Thighs & hips",    "Tighten your thigh muscles and press your legs together. Hold… then let them go heavy."),
        ("Belly & back",     "Draw your belly in and tense your lower back. Hold… then soften with your next exhale."),
        ("Hands & arms",     "Make fists and tighten your forearms and biceps. Hold… then uncurl your fingers and let your arms sink."),
        ("Shoulders & face", "Raise your shoulders to your ears and scrunch your face. Hold everything tight… then drop it all at once."),
    ]

    var body: some View {
        LullScreen(glow: false) {
            AmberGlow(x: 0.5, y: 0.35, radius: 230, opacity: 0.4)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 16)
                NightlyStepHeader(
                    step: state.nightlyStep + 1,
                    total: state.nightlyStepTotal,
                    label: "PMR"
                )

                if currentStep < groups.count {
                    let group = groups[currentStep]

                    VStack(spacing: 12) {
                        Kicker(text: "\(currentStep + 1) of \(groups.count)")
                        Text(group.area)
                            .font(.serif(30))
                            .foregroundColor(.lullAmber)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 28)

                    Text(group.instruction)
                        .font(.system(size: 14))
                        .foregroundColor(.lullInk2)
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .frame(maxWidth: 300)
                        .padding(.horizontal, 28)
                        .padding(.top, 16)

                    Spacer()

                    // Countdown ring
                    ZStack {
                        Circle().stroke(Color.lullLine, lineWidth: 1).frame(width: 96, height: 96)
                        Circle()
                            .trim(from: 0, to: CGFloat(secondsLeft) / 20)
                            .stroke(Color.lullAmber.opacity(0.7),
                                    style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .frame(width: 96, height: 96)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1), value: secondsLeft)
                        Text("\(secondsLeft)")
                            .font(.serif(32))
                            .foregroundColor(.lullInk1)
                    }

                    Spacer()

                    VStack(spacing: 0) {
                        PrimaryCTA(title: currentStep < groups.count - 1 ? "Next area →" : "Done") {
                            advance()
                        }
                        GhostButton(title: "Skip") { state.nightlyStep += 1 }
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 36)

                } else {
                    // Completion
                    Spacer()
                    VStack(spacing: 16) {
                        Kicker(text: "Complete")
                        Text("Body released.")
                            .font(.serif(28))
                            .foregroundColor(.lullInk2)
                        Text("Let yourself drift.")
                            .font(.serifItalic(28))
                            .foregroundColor(.lullAmber)
                    }
                    .multilineTextAlignment(.center)
                    Spacer()
                    PrimaryCTA(title: "Continue") { state.nightlyStep += 1 }
                        .padding(.horizontal, 22)
                        .padding(.bottom, 36)
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
        if currentStep < groups.count - 1 {
            currentStep += 1
            startTimer()
        } else {
            timer?.invalidate()
            currentStep = groups.count // show completion
        }
    }
}
