import SwiftUI

struct NightlyGratitudeJournalView: View {
    @EnvironmentObject var state: AppState
    @State private var notes: String = ""
    @State private var secondsLeft: Int = 60
    @State private var timer: Timer?
    @State private var isDone = false

    private let prompts = [
        "Something that went okay today.",
        "Someone who helped you, even a little.",
        "One small thing you're looking forward to.",
    ]

    var body: some View {
        LullScreen(glow: false) {
            AmberGlow(x: 0.5, y: 0.3, radius: 220, opacity: 0.45)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 16)
                NightlyStepHeader(
                    step: state.nightlyStep + 1,
                    total: state.nightlyStepTotal,
                    label: "Gratitude"
                )

                VStack(spacing: 12) {
                    Kicker(text: "Quick · 1 min")
                    (Text("Three things that ")
                        .foregroundColor(.lullInk0)
                    + Text("went okay.")
                        .foregroundColor(.lullAmber))
                    .font(.serif(26))
                    .multilineTextAlignment(.center)

                    Text("Doesn't have to be big. Just real.")
                        .font(.system(size: 13.5))
                        .foregroundColor(.lullInk2)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .padding(.horizontal, 28)

                Spacer()

                // Prompt cards
                VStack(spacing: 10) {
                    ForEach(Array(prompts.enumerated()), id: \.offset) { i, prompt in
                        HStack(spacing: 14) {
                            Text("\(i + 1)")
                                .font(.mono(11))
                                .foregroundColor(.lullAmber)
                                .frame(width: 20)
                            Text(prompt)
                                .font(.system(size: 14))
                                .foregroundColor(.lullInk1)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.025)))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.lullLine, lineWidth: 1))
                    }
                }
                .padding(.horizontal, 22)

                // Optional text note
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.03))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.lullLine, lineWidth: 1))
                    if notes.isEmpty {
                        Text("Jot a word or two if it helps…")
                            .font(.system(size: 13))
                            .foregroundColor(.lullInk4)
                            .padding(14)
                    }
                    TextEditor(text: $notes)
                        .font(.system(size: 13))
                        .foregroundColor(.lullInk1)
                        .scrollContentBackground(.hidden)
                        .background(.clear)
                        .padding(10)
                }
                .frame(height: 72)
                .padding(.horizontal, 22)
                .padding(.top, 14)

                Spacer()

                // Timer ring
                ZStack {
                    Circle().stroke(Color.lullLine, lineWidth: 1).frame(width: 64, height: 64)
                    Circle()
                        .trim(from: 0, to: CGFloat(secondsLeft) / 60)
                        .stroke(Color.lullAmber.opacity(0.7), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 64, height: 64)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: secondsLeft)
                    Text("\(secondsLeft)")
                        .font(.serif(20))
                        .foregroundColor(.lullInk2)
                }
                .padding(.bottom, 12)

                VStack(spacing: 0) {
                    PrimaryCTA(title: isDone ? "Continue →" : "Done") {
                        advance()
                    }
                    GhostButton(title: "Skip") { state.nightlyStep += 1 }
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 36)
            }
        }
        .onAppear { startTimer() }
        .onDisappear { timer?.invalidate() }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                if secondsLeft > 0 {
                    secondsLeft -= 1
                } else {
                    timer?.invalidate()
                    isDone = true
                }
            }
        }
    }

    private func advance() {
        timer?.invalidate()
        state.nightlyStep += 1
    }
}
