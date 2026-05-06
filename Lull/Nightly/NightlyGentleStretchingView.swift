import SwiftUI

struct NightlyGentleStretchingView: View {
    @EnvironmentObject var state: AppState
    @State private var currentStep = 0
    @State private var secondsLeft = 60
    @State private var timer: Timer?

    private let stretches: [(name: String, instruction: String, duration: Int)] = [
        ("Legs up the wall",     "Lie on your back, legs resting vertically against the wall. Let gravity drain the tension from your legs.", 90),
        ("Neck rolls",           "Slowly roll your head in a full circle, ear to shoulder, chin to chest, ear to shoulder. Reverse.", 60),
        ("Seated forward fold",  "Sit upright, extend your legs, and gently reach toward your feet. Let your spine soften with each exhale.", 90),
    ]

    private var totalSeconds: Int { stretches.reduce(0) { $0 + $1.duration } }

    var body: some View {
        LullScreen(glow: false) {
            AmberGlow(x: 0.5, y: 0.4, radius: 230, opacity: 0.4)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 16)
                NightlyStepHeader(
                    step: state.nightlyStep + 1,
                    total: state.nightlyStepTotal,
                    label: "Stretching"
                )

                if currentStep < stretches.count {
                    let stretch = stretches[currentStep]

                    VStack(spacing: 12) {
                        Kicker(text: "\(currentStep + 1) of \(stretches.count)")
                        Text(stretch.name)
                            .font(.serif(28))
                            .foregroundColor(.lullAmber)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 28)

                    Text(stretch.instruction)
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
                        Circle().stroke(Color.lullLine, lineWidth: 1).frame(width: 110, height: 110)
                        Circle()
                            .trim(from: 0, to: CGFloat(secondsLeft) / CGFloat(stretch.duration))
                            .stroke(Color.lullAmber.opacity(0.7),
                                    style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .frame(width: 110, height: 110)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1), value: secondsLeft)
                        VStack(spacing: 2) {
                            Text("\(secondsLeft)")
                                .font(.serif(36))
                                .foregroundColor(.lullInk1)
                            Text("SEC")
                                .font(.mono(9))
                                .kerning(1.4)
                                .foregroundColor(.lullInk3)
                        }
                    }

                    Spacer()

                    VStack(spacing: 0) {
                        PrimaryCTA(title: currentStep < stretches.count - 1 ? "Next stretch →" : "Done") {
                            advance()
                        }
                        GhostButton(title: "Skip all") { state.nightlyStep += 1 }
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 36)

                } else {
                    // Completion
                    Spacer()
                    VStack(spacing: 16) {
                        Kicker(text: "All done")
                        Text("Body released.")
                            .font(.serif(28))
                            .foregroundColor(.lullInk0)
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
        secondsLeft = stretches[currentStep].duration
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                if secondsLeft > 0 { secondsLeft -= 1 } else { advance() }
            }
        }
    }

    private func advance() {
        if currentStep < stretches.count - 1 {
            currentStep += 1
            startTimer()
        } else {
            timer?.invalidate()
            currentStep = stretches.count // show completion screen
        }
    }
}
