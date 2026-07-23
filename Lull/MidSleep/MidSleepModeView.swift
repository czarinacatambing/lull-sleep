import SwiftUI

struct MidSleepModeView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject private var sleepSoundsAudio: SleepSoundsAudioStore
    @Environment(\.dismiss) private var dismiss
    var onExit: (() -> Void)?

    @State private var showBreathing = false
    @State private var showBoringStory = false
    @State private var showSleepSounds = false

    private let options: [MidSleepWindDownOption] = [
        MidSleepWindDownOption(
            kind: .breathing,
            title: "4·7·8 breath",
            subtitle: "In · hold · out",
            icon: "lungs"
        ),
        MidSleepWindDownOption(
            kind: .boringStory,
            title: "Boring story",
            subtitle: "Random · audio",
            icon: "book"
        ),
        MidSleepWindDownOption(
            kind: .sleepSounds,
            title: "Sleep sounds",
            subtitle: "Rain · noise · water",
            icon: "cloud.rain"
        )
    ]

    var body: some View {
        ZStack {
            Color.lullBgDeep.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 54)

                Text("Let's wind down")
                    .font(.serif(30))
                    .foregroundColor(.lullInk0)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 28)

                VStack(spacing: 12) {
                    ForEach(options) { option in
                        Button(action: { open(option) }) {
                            MidSleepWindDownRow(option: option)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 22)

                Spacer()
            }
        }
        .foregroundColor(.lullInk1)
        .preferredColorScheme(.dark)
        .contentShape(Rectangle())
        .highPriorityGesture(exitSwipeGesture)
        .fullScreenCover(isPresented: $showBreathing) {
            NightlyBreathingView(isMidSleep: true).environmentObject(state)
        }
        .fullScreenCover(isPresented: $showBoringStory) {
            MidSleepBoringStoryView()
        }
        .fullScreenCover(isPresented: $showSleepSounds) {
            NightlySleepSoundsView(isMidSleep: true)
                .environmentObject(state)
                .environmentObject(sleepSoundsAudio)
        }
        .accessibilityAction(named: "Close") {
            exit()
        }
    }

    private var exitSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 18)
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                guard dy > 80, dy > abs(dx) else { return }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                exit()
            }
    }

    private func open(_ option: MidSleepWindDownOption) {
        switch option.kind {
        case .breathing:
            showBreathing = true
        case .boringStory:
            guard state.canUseContentLibrary else {
                state.presentUpgradePaywall()
                return
            }
            showBoringStory = true
        case .sleepSounds:
            guard state.canUseSleepSounds else {
                state.presentUpgradePaywall()
                return
            }
            showSleepSounds = true
        }
    }

    private func exit() {
        if let onExit {
            onExit()
        } else {
            dismiss()
        }
    }
}

private struct MidSleepWindDownOption: Identifiable {
    enum Kind {
        case breathing
        case boringStory
        case sleepSounds
    }

    let id = UUID()
    let kind: Kind
    let title: String
    let subtitle: String
    let icon: String
}

private struct MidSleepWindDownRow: View {
    let option: MidSleepWindDownOption

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.04))
                Circle()
                    .strokeBorder(Color.lullLine.opacity(0.55), lineWidth: 1)
                Image(systemName: option.icon)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(.lullInk2)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(option.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.lullInk0)
                Text(option.subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.lullInk3)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.lullInk3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: "#2a2119").opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.lullLine.opacity(0.45), lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}

struct MidSleepExitButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.035))
                    .overlay(Circle().strokeBorder(Color.lullLine, lineWidth: 1))
                    .frame(width: 36, height: 36)
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.lullInk3)
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }
}

struct MidSleepBoringStoryView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var playback = AudioPlaybackService()
    @State private var glowPulse = false
    @State private var hasFinished = false
    @State private var activeStory: BoringStoryId?

    private var elapsedSeconds: Int { Int(playback.elapsed.rounded(.down)) }
    private var durationSeconds: Int {
        playback.duration > 0 ? Int(playback.duration.rounded(.up)) : 1200
    }

    var body: some View {
        LullScreen(glow: false) {
            RadialGradient(colors: [Color.lullAmber.opacity(0.08), .clear],
                           center: UnitPoint(x: 0.5, y: 0.38), startRadius: 0, endRadius: 210)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("Boring story")
                        .font(.system(size: 12, weight: .semibold, design: .default))
                        .foregroundColor(.lullInk4)
                    Spacer()
                    MidSleepExitButton(action: finish)
                }
                .padding(.horizontal, 28).padding(.top, 16).padding(.bottom, 32)

                VStack(spacing: 14) {
                    Text("Eyes closed.")
                        .font(.system(size: 26, weight: .regular)).foregroundColor(.lullInk2)
                    Text("Just listen.")
                        .font(.system(size: 26, weight: .regular).italic()).foregroundColor(.lullAmber)
                    if let activeStory {
                        Text(activeStory.title)
                            .font(.system(size: 11, weight: .medium, design: .default))
                            .foregroundColor(.lullInk4)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, 28)
                    }
                }
                .multilineTextAlignment(.center)

                Spacer()

                Circle()
                    .fill(Color.lullAmber)
                    .frame(width: 14, height: 14)
                    .shadow(color: .lullAmber,    radius: glowPulse ? 28 : 10)
                    .shadow(color: .lullAmberGlow, radius: glowPulse ? 56 : 22)
                    .scaleEffect(glowPulse ? 1.3 : 1.0)
                    .animation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true), value: glowPulse)
                    .onAppear { glowPulse = true }

                Spacer()

                VStack(spacing: 12) {
                    Text("\(timeString(elapsedSeconds)) / \(timeString(durationSeconds))")
                        .font(.mono(11)).kerning(1.6).foregroundColor(.lullInk3)
                    GeometryReader { geo in
                        let pct = min(1, CGFloat(elapsedSeconds) / CGFloat(max(1, durationSeconds)))
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.08))
                            Capsule().fill(Color.lullAmber.opacity(0.7)).frame(width: geo.size.width * pct)
                        }
                    }
                    .frame(height: 2)
                    .animation(.linear(duration: 1), value: elapsedSeconds)
                }
                .padding(.horizontal, 28)

                HStack(spacing: 12) {
                    circleButton(icon: playback.isPlaying ? "pause.fill" : "play.fill", size: 18) {
                        if playback.isPlaying { playback.pause() }
                        else { playback.play() }
                    }

                    circleButton(icon: "shuffle", size: 17) {
                        shuffleStory()
                    }
                    .accessibilityLabel("Shuffle story")

                    Spacer().frame(width: 6)

                    HStack(spacing: 8) {
                        circleButton(icon: "minus", size: 18, disabled: !playback.canSlowDown) {
                            playback.speedDown()
                        }
                        Text(rateText(playback.playbackRate))
                            .font(.mono(11))
                            .kerning(1.2)
                            .foregroundColor(.lullInk3)
                            .frame(width: 38)
                        circleButton(icon: "plus", size: 18, disabled: !playback.canSpeedUp) {
                            playback.speedUp()
                        }
                    }
                }
                .padding(.top, 36).padding(.bottom, 52)
            }
        }
        .onAppear { startStory() }
        .onDisappear { finish() }
    }

    private func startStory() {
        guard !hasFinished, let asset = BoringStoryAudioLibrary.randomStoryAsset() else { return }
        loadStory(asset)
    }

    private func shuffleStory() {
        guard !hasFinished, let asset = BoringStoryAudioLibrary.randomStoryAsset(excluding: activeStory) else { return }
        loadStory(asset)
    }

    private func loadStory(_ asset: BoringStoryAudioAsset) {
        activeStory = asset.story
        playback.load(url: asset.url)
        playback.onFinish = { finish() }
        playback.play()
    }

    private func cleanupStory() {
        playback.onFinish = nil
        playback.stop()
    }

    private func finish() {
        guard !hasFinished else { return }
        hasFinished = true
        cleanupStory()
        dismiss()
    }

    private func timeString(_ s: Int) -> String { String(format: "%d:%02d", s / 60, s % 60) }
    private func rateText(_ rate: Float) -> String {
        switch rate {
        case 0.75: return ".75x"
        case 0.9: return ".9x"
        case 1.0: return "1x"
        case 1.5: return "1.5x"
        default: return "\(rate)x"
        }
    }
    private func circleButton(icon: String, size: CGFloat, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle().strokeBorder(Color.lullLine, lineWidth: 1)
                    .background(Circle().fill(Color.white.opacity(0.02)))
                    .frame(width: 56, height: 56)
                Image(systemName: icon).font(.system(size: size)).foregroundColor(.lullInk2)
            }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
    }
}
