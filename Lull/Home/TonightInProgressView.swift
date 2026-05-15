import SwiftUI

// Standalone "first night / tonight in progress" welcome sheet.
//
// Presented when the user taps the today-empty dot in the routine grid.
// Unlike SleepLogDetailView, this does NOT require an entry — it's purely
// informational. No data persists when it's shown or dismissed.
struct TonightInProgressView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss

    // True if no rated entries exist yet (i.e. this is the user's first night).
    private var isFirstNight: Bool {
        state.sleepLogs.allSatisfy { $0.score == 0 }
    }

    private static let dayFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEEE · MMM d"; return f
    }()

    var body: some View {
        LullScreen(glow: false) {
            AmberGlow(x: 0.5, y: -0.05, radius: 240, opacity: 0.55)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    BrandMark()
                    Spacer()
                    Text(Self.dayFmt.string(from: Date()).uppercased())
                        .font(.mono(10.5))
                        .kerning(1.4)
                        .foregroundColor(.lullInk3)
                }
                .padding(.horizontal, Lull.horizontalPad)
                .padding(.top, 16)
                .padding(.bottom, 8)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Title block
                        VStack(alignment: .leading, spacing: 10) {
                            Kicker(text: "Tonight in progress")

                            Text(isFirstNight
                                 ? "This is your first night with Lull! 🌙"
                                 : "Tonight's routine is in progress 🌙")
                                .font(.serif(28))
                                .foregroundColor(.lullInk0)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineSpacing(3)

                            Text(isFirstNight
                                 ? "No sleep score logged yet. Finish your routine tonight and rate your sleep tomorrow morning — your first dot with sleep score will appear."
                                 : "No sleep score logged yet. Rate your sleep tomorrow morning and this dot will fill in.")
                                .font(.system(size: 13.5))
                                .foregroundColor(.lullInk2)
                                .lineSpacing(4)
                                .padding(.top, 4)
                        }
                        .padding(.horizontal, 28)
                        .padding(.top, 28)

                        // Disabled, dimmed score selector — visually parks the
                        // rating slot so users know where it'll appear later.
                        SleepScoreSelector(score: .constant(0), disabled: true)
                            .opacity(0.35)
                            .padding(.top, 40)

                        // Variable label — what's being tested tonight.
                        HStack(spacing: 8) {
                            Text("VARIABLE TESTED")
                                .font(.mono(9.5))
                                .kerning(1.4)
                                .foregroundColor(.lullInk4)
                            Text(state.tonightVariable)
                                .font(.mono(9.5))
                                .kerning(1)
                                .foregroundColor(.lullAmberSoft)
                        }
                        .padding(.horizontal, 28)
                        .padding(.top, 24)
                    }
                }

                // Single dismiss button (no rating to log).
                GhostButton(title: "Got it") { dismiss() }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 22)
                    .padding(.top, 16)
                    .padding(.bottom, 36)
            }
        }
    }
}
