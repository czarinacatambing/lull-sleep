import SwiftUI

struct MidSleepModeView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss

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
                                state.useBreathingInstead = true
                                state.nightlyStep = 3
                                state.showNightlyFlow = true
                                dismiss()
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
    }
}
