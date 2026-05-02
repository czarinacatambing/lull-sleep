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

                // 5 score circles — growing size
                VStack(spacing: 14) {
                    HStack(alignment: .center, spacing: 0) {
                        ForEach(1...5, id: \.self) { n in
                            let selected = state.morningScore == n
                            let baseSize: CGFloat = 36 + CGFloat(n) * 6  // 42, 48, 54, 60, 66

                            Button(action: { state.morningScore = n }) {
                                ZStack {
                                    Circle()
                                        .fill(selected
                                            ? AnyShapeStyle(RadialGradient(colors: [.lullAmber, .lullAmberDeep],
                                                                            center: .center, startRadius: 0, endRadius: baseSize / 2))
                                            : AnyShapeStyle(Color.clear))
                                        .overlay(
                                            Circle().strokeBorder(
                                                selected ? Color.clear : Color.white.opacity(0.12 + Double(n) * 0.04),
                                                lineWidth: 1.2)
                                        )
                                        .frame(width: baseSize, height: baseSize)
                                        .shadow(color: selected ? .lullAmberGlow : .clear, radius: 11)
                                        .shadow(color: selected ? Color.lullAmber.opacity(0.10) : .clear, radius: 0)

                                    if selected {
                                        Text("\(n)")
                                            .font(.serif(22))
                                            .foregroundColor(Color(hex: "#1a0d06"))
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 28)

                    HStack {
                        Text("WRECKED")
                            .font(.mono(9.5))
                            .kerning(1.4)
                            .foregroundColor(.lullInk4)
                        Spacer()
                        Text("FANTASTIC")
                            .font(.mono(9.5))
                            .kerning(1.4)
                            .foregroundColor(.lullInk4)
                    }
                    .padding(.horizontal, 32)
                }
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
                    PrimaryCTA(title: "Log this morning") {
                        state.logMorningScore()
                        dismiss()
                    }
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
