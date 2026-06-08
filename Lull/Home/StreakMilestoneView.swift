import SwiftUI

struct StreakMilestoneView: View {
    let milestone: StreakMilestonePresentation
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.lullBg.ignoresSafeArea()
            AmberGlow(x: 0.5, y: 0.15, radius: 360, opacity: 0.9)
                .ignoresSafeArea()

            if milestone.showsConfetti {
                Confetti(variant: .big)
                    .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                Spacer(minLength: 56)

                Kicker(text: "Milestone", color: .lullAmberSoft)
                    .padding(.bottom, 12)

                (Text("\(milestone.day)")
                    .font(.serif(78))
                    .foregroundColor(.lullInk0)
                 + Text(" nights")
                    .font(.serifItalic(30))
                    .foregroundColor(.lullAmber))
                .multilineTextAlignment(.center)
                .padding(.bottom, 10)

                Text("You kept showing up for your bedtime habits.")
                    .font(.system(size: 15))
                    .foregroundColor(.lullInk2)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 270)
                    .padding(.bottom, 28)

                VStack(spacing: 10) {
                    statRow(
                        title: milestone.headlineLabel,
                        value: "\(milestone.headlineRate)%",
                        subtitle: "bedtime habits completed"
                    )

                    if let secondaryRate = milestone.secondaryRate,
                       let secondaryLabel = milestone.secondaryLabel {
                        statRow(
                            title: secondaryLabel,
                            value: "\(secondaryRate)%",
                            subtitle: "completion rate"
                        )
                    }

                    if let average = milestone.averageSleepScore {
                        statRow(
                            title: "AVG SLEEP SCORE",
                            value: String(format: "%.1f", average),
                            subtitle: "during this milestone window"
                        )
                    }
                }
                .padding(.horizontal, 22)

                Spacer(minLength: 34)

                PrimaryCTA(title: "Back to Today", action: onDismiss)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 34)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func statRow(title: String, value: String, subtitle: String) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.mono(9.5))
                    .kerning(1.4)
                    .foregroundColor(.lullAmberSoft)
                Text(subtitle)
                    .font(.system(size: 12.5))
                    .foregroundColor(.lullInk3)
            }
            Spacer()
            Text(value)
                .font(.serif(28))
                .foregroundColor(.lullInk0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .lullCard(radius: 16, accent: true)
    }
}
