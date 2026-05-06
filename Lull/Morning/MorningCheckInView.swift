import SwiftUI

struct MorningCheckInView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        LullScreen(glow: false) {
            AmberGlow(x: 0.5, y: -0.05, radius: 250, opacity: 0.65)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 16)

                HStack {
                    BrandMark()
                    Spacer()
                    Text("WED · 6:42 AM")
                        .font(.mono(10.5))
                        .kerning(1.4)
                        .foregroundColor(.lullInk3)
                }
                .padding(.horizontal, Lull.horizontalPad)
                .padding(.bottom, 8)

                VStack(alignment: .leading, spacing: 12) {
                    Kicker(text: "Morning check-in")
                    Group {
                        Text("How does this morning ")
                            .foregroundColor(.lullInk0)
                        + Text("feel?")
                            .foregroundColor(.lullAmber)
                    }
                    .font(.serif(30))

                    Text("One tap. We'll use this to nudge tonight's variable.")
                        .font(.system(size: 13.5))
                        .foregroundColor(.lullInk2)
                        .lineSpacing(3)
                }
                .padding(.horizontal, 28)
                .padding(.top, 28)

                Spacer()

                SleepScoreSelector(score: $state.morningScore)
                    .padding(.top, 50)

                Spacer()

                // Experiment insight card
                if let status = state.experimentStatus {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Kicker(text: "What we're learning", color: .lullAmberSoft)
                            Spacer()
                            Text("Night \(status.night) of 5")
                                .font(.mono(9.5))
                                .kerning(1)
                                .foregroundColor(.lullInk4)
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(status.variable)
                                .font(.system(size: 13))
                                .foregroundColor(.lullAmber)
                            Text("·")
                                .font(.system(size: 13))
                                .foregroundColor(.lullInk3)
                            Text(status.insightLine)
                                .font(.system(size: 13))
                                .foregroundColor(.lullInk1)
                        }
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)

                        if status.decision == .promote {
                            Text("↑ Adding to core routine")
                                .font(.mono(10)).kerning(0.8)
                                .foregroundColor(.lullAmber)
                                .padding(.top, 2)
                        } else if status.decision == .drop, let next = status.nextCandidate {
                            Text("Next up: \(next)")
                                .font(.mono(10)).kerning(0.8)
                                .foregroundColor(.lullInk3)
                                .padding(.top, 2)
                        }
                    }
                    .padding(16)
                    .lullCard(radius: 18)
                    .padding(.horizontal, 22)
                }

                VStack(spacing: 0) {
                    PrimaryCTA(title: "Log this morning", disabled: state.morningScore == 0) {
                        state.logMorningScore()
                        dismiss()
                    }
                    .opacity(state.morningScore == 0 ? 0.45 : 1)
                    GhostButton(title: "Add a note · woke at 4am") {}
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 22)
                .padding(.top, 24)
                .padding(.bottom, 36)
            }
        }
    }
}
