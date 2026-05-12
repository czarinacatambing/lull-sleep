import SwiftUI

struct SleepHistoryLegendView: View {
    @Environment(\.dismiss) var dismiss
    @State private var todayPulse = false

    var body: some View {
        ZStack {
            Color.lullBg.ignoresSafeArea()

            // Subtle warm glow behind title
            Ellipse()
                .fill(Color.lullAmber.opacity(0.06))
                .frame(width: 320, height: 200)
                .blur(radius: 50)
                .offset(y: -180)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Sheet handle
                RoundedRectangle(cornerRadius: 99)
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 36, height: 4)
                    .padding(.top, 14)
                    .padding(.bottom, 32)

                // Title block
                VStack(spacing: 8) {
                    Text("Understanding Your\nSleep History")
                        .font(.serif(26))
                        .foregroundColor(.lullInk0)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)

                    Text("These dots track your consistency, not perfection.")
                        .font(.system(size: 13.5))
                        .foregroundColor(.lullInk3)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .frame(maxWidth: 260)
                }
                .padding(.bottom, 36)

                // Legend card
                VStack(spacing: 0) {
                    LegendRow(
                        dot: { ratedDot },
                        label: "Routine done",
                        description: "You completed your wind-down and logged a sleep score."
                    )
                    legendDivider
                    LegendRow(
                        dot: { skippedDot },
                        label: "Night skipped",
                        description: "No routine started and no score logged for this night."
                    )
                    legendDivider
                    LegendRow(
                        dot: { unratedDot },
                        label: "Awaiting rating",
                        description: "You followed your routine but haven't logged your morning score yet."
                    )
                    legendDivider
                    LegendRow(
                        dot: { inProgressDot },
                        label: "Tonight",
                        description: "Your routine is in progress. Rate your sleep tomorrow morning."
                    )
                }
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.white.opacity(0.025))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .strokeBorder(Color.lullLine, lineWidth: 1)
                        )
                )
                .padding(.horizontal, 22)

                Spacer()

                // Got it
                Button { dismiss() } label: {
                    Text("Got it")
                        .font(.mono(13))
                        .kerning(1.2)
                        .foregroundColor(.lullAmber)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.lullAmber.opacity(0.10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(Color.lullAmber.opacity(0.25), lineWidth: 1)
                                )
                        )
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 40)
                .padding(.top, 32)
            }
        }
        .onAppear { todayPulse = true }
    }

    // MARK: - Dot replicas (match ProgressDotsCard exactly)

    private var ratedDot: some View {
        Circle()
            .fill(Color.lullAmber)
            .frame(width: 22, height: 22)
    }

    private var skippedDot: some View {
        Circle()
            .fill(Color.white.opacity(0.10))
            .frame(width: 22, height: 22)
    }

    private var unratedDot: some View {
        Image(systemName: "circle.lefthalf.filled")
            .resizable()
            .scaledToFit()
            .foregroundColor(.lullInk3)
            .frame(width: 20, height: 20)
    }

    private var inProgressDot: some View {
        ZStack {
            Circle()
                .strokeBorder(Color.lullAmber, lineWidth: 1.5)
                .frame(width: 22, height: 22)
                .shadow(color: .lullAmberGlow, radius: todayPulse ? 8 : 4)
                .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: todayPulse)
            Circle()
                .fill(Color.lullAmber.opacity(0.65))
                .frame(width: 10, height: 10)
        }
    }

    private var legendDivider: some View {
        Divider()
            .background(Color.lullLine)
            .padding(.horizontal, 20)
    }
}

// MARK: - Legend Row

private struct LegendRow<Dot: View>: View {
    let dot: () -> Dot
    let label: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            dot()
                .frame(width: 28)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.lullInk1)
                Text(description)
                    .font(.system(size: 12.5))
                    .foregroundColor(.lullInk3)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
    }
}
