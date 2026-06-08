import SwiftUI
import AVFoundation

// MARK: - Body Scan (guided audio)
//
// Mirrors NightlyBreathingView's cue-driven path, but a body scan is not
// breath-paced: regions land at irregular times, so the phase/orb are driven
// entirely by BodyScanCue.all (no synthetic cycle). One view serves both the
// nightly flow and Mid-Sleep mode (isMidSleep).

private enum AudioBodyScanPhase: Equatable {
    case intro, arrive, soften, release, rest, windDown

    var label: String {
        switch self {
        case .intro:    return "Settle in"
        case .arrive:   return "Notice this part"
        case .soften:   return "Soften"
        case .release:  return "Let it sink"
        case .rest:     return "Rest"
        case .windDown: return "Let go"
        }
    }
}

// Body areas in the order they are named in the narration, with the second they
// are first mentioned (from the Whisper transcription — see BodyScanCue / Docs).
// Decoupled from BodyScanCue.region so the area name persists through the brief
// "rest" beats until the next area is introduced.
private struct BodyScanArea {
    let name: String
    let start: Double

    static let all: [BodyScanArea] = [
        .init(name: "Feet & legs",      start:  71.0),
        .init(name: "Hips & belly",     start: 108.2),
        .init(name: "Back",             start: 138.2),
        .init(name: "Hands & arms",     start: 165.0),
        .init(name: "Shoulders & neck", start: 193.2),
        .init(name: "Face & head",      start: 215.0),
        .init(name: "Whole body",       start: 244.6),
    ]
    static let windDownStart: Double = 270.8
}

private struct BodyScanCue {
    let time: Double
    let phase: AudioBodyScanPhase
    let region: Int  // 0 = intro / between regions / wind-down

    // Derived from Whisper word-level transcription of body-scan.mp3 (289.3s).
    // See Docs/body-scan-script.md.
    static let all: [BodyScanCue] = [
        .init(time:   0.0, phase: .intro,    region: 0),
        // Region 1 — feet & legs
        .init(time:  71.0, phase: .arrive,   region: 1),
        .init(time:  80.1, phase: .soften,   region: 1),
        .init(time:  90.0, phase: .release,  region: 1),
        .init(time: 107.2, phase: .rest,     region: 0),
        // Region 2 — hips & belly
        .init(time: 108.2, phase: .arrive,   region: 2),
        .init(time: 118.0, phase: .soften,   region: 2),
        .init(time: 125.2, phase: .release,  region: 2),
        .init(time: 136.7, phase: .rest,     region: 0),
        // Region 3 — back
        .init(time: 138.2, phase: .arrive,   region: 3),
        .init(time: 149.5, phase: .soften,   region: 3),
        .init(time: 154.7, phase: .release,  region: 3),
        .init(time: 162.9, phase: .rest,     region: 0),
        // Region 4 — hands & arms
        .init(time: 165.0, phase: .arrive,   region: 4),
        .init(time: 171.7, phase: .soften,   region: 4),
        .init(time: 178.6, phase: .release,  region: 4),
        .init(time: 191.3, phase: .rest,     region: 0),
        // Region 5 — shoulders & neck
        .init(time: 193.2, phase: .arrive,   region: 5),
        .init(time: 198.9, phase: .soften,   region: 5),
        .init(time: 204.5, phase: .release,  region: 5),
        .init(time: 212.1, phase: .rest,     region: 0),
        // Region 6 — face & head
        .init(time: 215.0, phase: .arrive,   region: 6),
        .init(time: 219.7, phase: .soften,   region: 6),
        .init(time: 230.2, phase: .release,  region: 6),
        .init(time: 242.8, phase: .rest,     region: 0),
        // Whole-body release + wind-down
        .init(time: 244.6, phase: .release,  region: 0),
        .init(time: 270.8, phase: .windDown, region: 0),
    ]
}

struct NightlyBodyScanView: View {
    var isMidSleep: Bool = false
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss

    @State private var player: AVAudioPlayer?
    @State private var pollTimer: Timer?
    @State private var currentPhase: AudioBodyScanPhase = .intro
    @State private var elapsed: Double = 0
    @State private var totalDuration: Double = 289
    @State private var viewActive = false
    @State private var isAudioPlaying = false
    @State private var playbackRate: Float = 1.0

    private let playbackRates: [Float] = [0.75, 0.9, 1.0, 1.5]
    private var currentRateIndex: Int {
        playbackRates.enumerated().min(by: {
            abs($0.element - playbackRate) < abs($1.element - playbackRate)
        })?.offset ?? 2
    }
    private var canSlowDown: Bool { currentRateIndex > playbackRates.startIndex }
    private var canSpeedUp: Bool { currentRateIndex < playbackRates.index(before: playbackRates.endIndex) }

    private var progress: Double { min(1, elapsed / totalDuration) }
    private var timeRemainingString: String {
        let secs = max(0, Int(totalDuration - elapsed))
        let m = secs / 60; let s = secs % 60
        return m > 0 ? "\(m):\(String(format: "%02d", s))" : "0:\(String(format: "%02d", s))"
    }

    // Phase word shown above the area name (Soften / Let it sink / Rest …).
    private var kickerText: String {
        switch currentPhase {
        case .intro:    return "Body scan"
        case .windDown: return "Winding down"
        default:        return currentPhase.label
        }
    }

    private var inIntro: Bool { elapsed < BodyScanArea.all.first!.start }
    private var inWindDown: Bool { elapsed >= BodyScanArea.windDownStart }

    // Hero text: the current body area, or the intro / wind-down state.
    private var heroText: String {
        if inIntro { return "Settle in" }
        if inWindDown { return "Let go" }
        return currentArea?.name ?? "Body scan"
    }

    private var currentArea: BodyScanArea? {
        BodyScanArea.all.last(where: { $0.start <= elapsed })
    }

    // [start, end) window of the current area; end is the next area's start
    // (or wind-down for the final "Whole body" area, or the first area for the intro).
    private var currentAreaWindow: (start: Double, end: Double)? {
        if inWindDown { return nil }
        if inIntro { return (0, BodyScanArea.all.first!.start) }
        guard let area = currentArea,
              let idx = BodyScanArea.all.firstIndex(where: { $0.start == area.start }) else { return nil }
        let end = idx + 1 < BodyScanArea.all.count
            ? BodyScanArea.all[idx + 1].start
            : BodyScanArea.windDownStart
        return (area.start, end)
    }

    private var areaSecondsRemaining: Int {
        guard let w = currentAreaWindow else { return 0 }
        return max(0, Int(ceil(w.end - elapsed)))
    }

    // Fraction of the current area still to go (1 → 0), for the depleting ring.
    private var areaRingProgress: Double {
        guard let w = currentAreaWindow, w.end > w.start else { return 0 }
        return min(1, max(0, (w.end - elapsed) / (w.end - w.start)))
    }

    var body: some View {
        LullScreen(glow: false) {
            AmberGlow(x: 0.5, y: 0.4, radius: 260, opacity: 0.5)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer().frame(height: 16)
                if isMidSleep {
                    HStack {
                        Text("BODY SCAN")
                            .font(.mono(10.5))
                            .kerning(1.2)
                            .foregroundColor(.lullInk3)
                        Spacer()
                        MidSleepExitButton { complete() }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 14)
                } else {
                    NightlyStepHeader(step: state.nightlyStep + 1, total: state.nightlyStepTotal, label: "Body scan")
                }

                VStack(spacing: 12) {
                    Kicker(text: kickerText)
                    Text(heroText)
                        .font(.serif(30))
                        .foregroundColor(.lullAmber)
                        .animation(.easeInOut(duration: 0.4), value: heroText)
                }
                .padding(.horizontal, 28)
                .multilineTextAlignment(.center)
                .padding(.bottom, 36)

                Spacer()

                ZStack {
                    Circle()
                        .stroke(Color.lullLine, lineWidth: 1)
                        .frame(width: 200, height: 200)
                    Circle()
                        .trim(from: 0, to: areaRingProgress)
                        .stroke(Color.lullAmber.opacity(0.7),
                                style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 200, height: 200)
                        .rotationEffect(.degrees(-90))
                        .shadow(color: .lullAmberGlow.opacity(0.5), radius: 8)
                        .animation(.linear(duration: 0.1), value: areaRingProgress)
                    if inWindDown {
                        Ember(size: 8)
                    } else {
                        Text("\(areaSecondsRemaining)")
                            .font(.serif(44))
                            .foregroundColor(.lullInk1)
                            .contentTransition(.numericText())
                            .animation(.easeInOut(duration: 0.2), value: areaSecondsRemaining)
                    }
                }

                Spacer()

                VStack(spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.08))
                            Capsule()
                                .fill(Color.lullAmber.opacity(0.6))
                                .frame(width: geo.size.width * progress)
                        }
                    }
                    .frame(height: 2)
                    .animation(.linear(duration: 0.1), value: progress)

                    Text(timeRemainingString)
                        .font(.mono(11))
                        .kerning(1.4)
                        .foregroundColor(.lullInk4)
                }
                .padding(.horizontal, 28)
                .padding(.top, 8)

                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        controlButton(icon: isAudioPlaying ? "pause.fill" : "play.fill", size: 18) {
                            if isAudioPlaying { pause() } else { play() }
                        }

                        Spacer().frame(width: 18)

                        HStack(spacing: 8) {
                            controlButton(icon: "minus", size: 18, disabled: !canSlowDown) {
                                stepPlaybackRate(-1)
                            }
                            Text(rateText(playbackRate))
                                .font(.mono(11))
                                .kerning(1.2)
                                .foregroundColor(.lullInk3)
                                .frame(width: 38)
                            controlButton(icon: "plus", size: 18, disabled: !canSpeedUp) {
                                stepPlaybackRate(1)
                            }
                        }
                    }

                    GhostButton(title: "End early · I'm calm") {
                        complete()
                    }
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 22)
                .padding(.top, 24)
                .padding(.bottom, 36)
            }
        }
        .onAppear {
            viewActive = true
            startSession()
        }
        .onDisappear { stopSession() }
    }

    private func complete() {
        stopSession()
        if isMidSleep {
            dismiss()
        } else {
            state.recordCurrentStepAttempt(status: .completed)
            state.nightlyStep += 1
        }
    }

    private func rateText(_ rate: Float) -> String {
        switch rate {
        case 0.75: return ".75x"
        case 0.9: return ".9x"
        case 1.0: return "1x"
        case 1.5: return "1.5x"
        default: return "\(rate)x"
        }
    }

    private func controlButton(icon: String, size: CGFloat, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .strokeBorder(Color.lullLine, lineWidth: 1)
                    .background(Circle().fill(Color.white.opacity(0.02)))
                    .frame(width: 56, height: 56)
                Image(systemName: icon)
                    .font(.system(size: size))
                    .foregroundColor(.lullInk2)
            }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
    }

    private func startSession() {
        playbackRate = 1.0
        guard let url = Bundle.main.url(forResource: "body-scan", withExtension: "mp3") else {
            // No audio bundled — nothing meaningful to guide through; end gracefully.
            complete(); return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.enableRate = true
            player?.rate = playbackRate
            totalDuration = player?.duration ?? 289
            player?.play()
            isAudioPlaying = true
        } catch {
            complete(); return
        }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in poll() }
        }
    }

    private func stopSession() {
        viewActive = false
        isAudioPlaying = false
        pollTimer?.invalidate(); pollTimer = nil
        player?.stop(); player = nil
    }

    private func pause() {
        player?.pause()
        isAudioPlaying = false
    }

    private func play() {
        player?.enableRate = true
        player?.rate = playbackRate
        player?.play()
        isAudioPlaying = true
    }

    private func stepPlaybackRate(_ direction: Int) {
        let nextIndex = min(max(currentRateIndex + direction, playbackRates.startIndex), playbackRates.index(before: playbackRates.endIndex))
        playbackRate = playbackRates[nextIndex]
        player?.enableRate = true
        player?.rate = playbackRate
    }

    @MainActor
    private func poll() {
        guard let player else { return }
        let t = player.currentTime
        elapsed = t

        let newPhase = BodyScanCue.all.last(where: { $0.time <= t })?.phase ?? .intro
        if newPhase != currentPhase { currentPhase = newPhase }

        if !player.isPlaying && t >= max(0, totalDuration - 0.5) {
            complete()
        }
    }
}
