import SwiftUI

struct MorningCheckInView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    @StateObject private var playback = AudioPlaybackService()
    @State private var currentDate = Date()

    // Reward state — set in handleLog() so confetti/headline match the just-logged numbers.
    @State private var showReward = false
    @State private var rewardScore: Int = 0
    @State private var rewardYesterday: Int? = nil
    @State private var rewardBaseline: Int = 0
    @State private var rewardVariable: String? = nil
    @State private var rewardNight: Int = 0

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE · h:mm a"; return f
    }()

    var body: some View {
        ZStack {
            if showReward {
                MorningRewardView(
                    score: rewardScore,
                    yesterday: rewardYesterday,
                    baseline: rewardBaseline,
                    variable: rewardVariable,
                    night: rewardNight,
                    totalNights: 5,
                    allowRerate: Calendar.current.component(.hour, from: Date()) < 12,
                    onRerate: { withAnimation(.easeInOut(duration: 0.25)) { showReward = false } },
                    onDismiss: { dismiss() },
                    onNote: { dismiss() }
                )
                .transition(.opacity)
            } else {
                checkInContent
            }
        }
    }

    private var checkInContent: some View {
        LullScreen(glow: false) {
            AmberGlow(x: 0.5, y: -0.05, radius: 250, opacity: 0.65)
                .ignoresSafeArea()

            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer().frame(height: 16)

                        HStack {
                            BrandMark()
                            Spacer()
                            Text(MorningCheckInView.dateFmt.string(from: currentDate))
                                .font(.mono(10.5))
                                .kerning(1.4)
                                .foregroundColor(.lullInk3)
                        }
                        .padding(.horizontal, Lull.horizontalPad)
                        .padding(.bottom, 8)
                        .onAppear { currentDate = Date() }

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

                        HoursSleptStepper(hours: $state.morningHoursSlept)
                            .padding(.top, 36)

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

                        if let entry = state.lastNightEntry,
                           let fileURL = entry.brainDumpFileURL,
                           let duration = entry.brainDumpDurationSec, duration > 0 {
                            BrainDumpPlayerCard(fileURL: fileURL, playback: playback)
                                .padding(.horizontal, 22)
                                .padding(.top, 12)
                        }

                        VStack(spacing: 0) {
                            PrimaryCTA(title: "Log this morning", disabled: state.morningScore == 0) {
                                handleLog()
                            }
                            .opacity(state.morningScore == 0 ? 0.45 : 1)
                            GhostButton(title: "Add a note · woke at 4am") {}
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 24)
                        .padding(.bottom, 36)
                    }
                    .frame(minHeight: geo.size.height)
                }
            }
        }
    }

    private func handleLog() {
        // Capture "yesterday's" score BEFORE logging — it's the most recent rated entry
        // before this one. (state.logMorningScore will either update an existing unrated
        // entry from last night, or create a new one — either way the previous rated
        // entry stays as-is.)
        let yesterdayScore: Int? = state.sleepLogs
            .filter { $0.score > 0 }
            .sorted { $0.date > $1.date }
            .first?.score

        let scoreToLog = AppState.clampedSleepScore(state.morningScore)
        let baseline = state.baselineScore

        playback.stop()
        state.logMorningScore()

        if state.justTriggeredNightFivePaywall {
            dismiss()
            return
        }

        // Read the experiment status AFTER logging so the "Tonight's experiment" card
        // reflects whatever variable advanceExperiment lined up next.
        let status = state.experimentStatus

        rewardScore = scoreToLog
        rewardYesterday = yesterdayScore
        rewardBaseline = baseline
        rewardVariable = status?.variable
        rewardNight = status?.night ?? 0

        withAnimation(.easeInOut(duration: 0.35)) { showReward = true }
    }
}

private struct BrainDumpPlayerCard: View {
    let fileURL: URL
    @ObservedObject var playback: AudioPlaybackService

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Kicker(text: "Brain dump · last night")

            HStack(spacing: 12) {
                Button {
                    if playback.isPlaying { playback.pause() } else { playback.play() }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.lullAmber)
                            .frame(width: 44, height: 44)
                        Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.lullBgDeep)
                            .offset(x: playback.isPlaying ? 0 : 1)
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.lullLine)
                                .frame(height: 3)
                            Capsule()
                                .fill(Color.lullAmber)
                                .frame(width: geo.size.width * playback.progress, height: 3)
                        }
                    }
                    .frame(height: 3)

                    HStack {
                        Text(playback.elapsed.lullTimeString)
                        Spacer()
                        Text(playback.duration.lullTimeString)
                    }
                    .font(.mono(10))
                    .foregroundColor(.lullInk3)
                }
            }
        }
        .padding(16)
        .lullCard(radius: 18)
        .onAppear { playback.load(url: fileURL) }
    }
}
