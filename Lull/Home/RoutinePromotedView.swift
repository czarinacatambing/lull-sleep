import SwiftUI

// Big celebration — full-screen modal that fires the first time the user opens
// the app after an experimental variable graduates into their core routine.
// Confetti is full-bleed and falls past the viewport.
struct RoutinePromotedView: View {
    let promotion: PendingPromotion
    let onDismiss: () -> Void

    private var liftString: String {
        let lift = promotion.averageLift
        if lift >= 0 {
            return "+\(String(format: "%.1f", lift))"
        }
        return String(format: "%.1f", lift)
    }

    var body: some View {
        ZStack {
            LullScreen(glow: false) {
                AmberGlow(x: 0.5, y: 0.40, radius: 380, opacity: 1.0)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer().frame(height: 16)

                    // Header
                    HStack {
                        BrandMark()
                        Spacer()
                        Button(action: onDismiss) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.lullInk3)
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, Lull.horizontalPad)
                    .padding(.bottom, 8)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            Spacer().frame(height: 40)

                            Kicker(text: "Promoted to your routine", color: .lullAmberSoft)
                                .padding(.bottom, 26)

                            // Hero medallion
                            medallion

                            // Headline
                            headline
                                .padding(.top, 26)
                                .padding(.horizontal, 28)

                            // Body
                            bodyText
                                .padding(.top, 14)
                                .padding(.horizontal, 28)
                                .frame(maxWidth: 320)

                            // Evidence card
                            evidenceCard
                                .padding(.horizontal, 22)
                                .padding(.top, 34)
                        }
                    }

                    // CTAs
                    VStack(spacing: 0) {
                        PrimaryCTA(title: "Lock it in", action: onDismiss)
                            .shadow(color: .lullAmberGlow, radius: 18)
                        GhostButton(title: "Keep testing for another week", action: onDismiss)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 24)
                    .padding(.bottom, 36)
                }
            }

            // Full-bleed confetti layered above the screen
            Confetti(variant: .big)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    // MARK: - Medallion

    private var medallion: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.lullAmber, Color(hex: "#a66a2a")],
                        center: .center,
                        startRadius: 0,
                        endRadius: 44
                    )
                )
                .frame(width: 88, height: 88)
                .shadow(color: .lullAmberGlow, radius: 40)
                .overlay(
                    Circle()
                        .strokeBorder(Color.lullAmber.opacity(0.12), lineWidth: 8)
                )

            Text("★")
                .font(.serif(44))
                .foregroundColor(Color(hex: "#1a0d06"))
        }
    }

    // MARK: - Headline / body

    private var headline: some View {
        (Text(promotion.variable).font(.serifItalic(30)).foregroundColor(.lullAmber)
            + Text("\nearned its place.").font(.serif(30)).foregroundColor(.lullInk0))
            .multilineTextAlignment(.center)
            .lineSpacing(3)
    }

    private var bodyText: some View {
        (Text("\(promotion.nights) test nights. Average lift ")
            .foregroundColor(.lullInk2)
            + Text(liftString).foregroundColor(.lullInk0)
            + Text(" on your sleep score. It's now part of your core routine.")
                .foregroundColor(.lullInk2))
            .font(.system(size: 13.5))
            .lineSpacing(4)
            .multilineTextAlignment(.center)
    }

    // MARK: - Evidence card

    private var evidenceCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Kicker(text: "Evidence · last \(promotion.nights) nights", color: .lullAmberSoft)
                Spacer()
                Text("\(liftString) AVG")
                    .font(.mono(10))
                    .kerning(1.2)
                    .foregroundColor(.lullAmber)
            }

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(promotion.sparkline.enumerated()), id: \.offset) { _, bar in
                    sparkColumn(bar: bar)
                }
            }
            .frame(height: 56)
            .padding(.top, 14)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(LinearGradient(
                    colors: [Color.lullAmber.opacity(0.12), Color.lullAmber.opacity(0.02)],
                    startPoint: .top, endPoint: .bottom))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(Color.lullAmber.opacity(0.32), lineWidth: 1)
                )
        )
    }

    private func sparkColumn(bar: PendingPromotion.SparkBar) -> some View {
        let ratio = bar.score > 0 ? CGFloat(bar.score) / 5.0 : 0
        let barHeight: CGFloat = max(ratio * 44, bar.score > 0 ? 4 : 0)
        return VStack(spacing: 4) {
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    bar.onExperiment
                    ? AnyShapeStyle(LinearGradient(
                        colors: [Color.lullAmber, Color(hex: "#a66a2a")],
                        startPoint: .top, endPoint: .bottom))
                    : AnyShapeStyle(Color.white.opacity(0.10))
                )
                .frame(height: barHeight)
                .shadow(color: bar.onExperiment ? Color.lullAmberGlow : .clear, radius: 10)
                .frame(maxWidth: .infinity)
            Text(bar.score > 0 ? "\(bar.score)" : "·")
                .font(.mono(9))
                .foregroundColor(.lullInk4)
        }
    }
}
