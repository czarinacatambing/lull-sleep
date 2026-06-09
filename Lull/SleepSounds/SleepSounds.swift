import SwiftUI
@preconcurrency import AVFoundation
import MediaPlayer

enum SoundId: String, Codable, CaseIterable, Identifiable {
    case heavyRain = "heavy-rain"
    case ambient
    case greenNoise = "green-noise"
    case minSolf = "min-solf"
    case solf
    case birds
    case lake

    var id: String { rawValue }

    var name: String {
        switch self {
        case .heavyRain: return "Heavy Rain"
        case .ambient: return "Ambient"
        case .greenNoise: return "Green Noise"
        case .minSolf: return "Minimal Solfeggio"
        case .solf: return "Solfeggio"
        case .birds: return "Distant Birds"
        case .lake: return "Calm Lake"
        }
    }

    var hint: String {
        switch self {
        case .heavyRain: return "Drumming, full coverage"
        case .ambient: return "Soft pads, evolving"
        case .greenNoise: return "Mid-band, less hiss"
        case .minSolf: return "396 Hz · sparse tones"
        case .solf: return "396 / 528 Hz blend"
        case .birds: return "Pre-dawn, faint chorus"
        case .lake: return "Lapping water, reeds"
        }
    }

    var symbol: String {
        switch self {
        case .heavyRain: return "cloud.rain"
        case .ambient: return "waveform.path"
        case .greenNoise: return "waveform"
        case .minSolf: return "circle.dotted"
        case .solf: return "circle.grid.cross"
        case .birds: return "bird"
        case .lake: return "water.waves"
        }
    }
}

struct SleepSoundStepConfig: Codable, Equatable {
    var soundId: SoundId?
    var durationMinutes: Int?
    var infinite: Bool
    var fadeOut: Bool

    static let fresh = SleepSoundStepConfig(
        soundId: nil,
        durationMinutes: 60,
        infinite: false,
        fadeOut: true
    )

    var durationSummary: String {
        guard !infinite else { return "∞ until I wake" }
        return Self.durationText(minutes: durationMinutes ?? 60)
    }

    static func durationText(minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h) hr" : "\(h) hr \(m)m"
    }

    static func accessibilityDurationText(minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) minutes" }
        let h = minutes / 60
        let m = minutes % 60
        let hourText = h == 1 ? "1 hour" : "\(h) hours"
        return m == 0 ? hourText : "\(hourText) \(m) minutes"
    }
}

private enum SleepSoundPalette {
    static let bg = Color.black
    static let bgDeep = Color.black
    static let card = Color.white.opacity(0.045)
    static let cardHi = Color.white.opacity(0.07)
    static let line = Color.lullLine
    static let lineHi = Color.lullLineStrong
    static let text = Color(red: 245 / 255, green: 232 / 255, blue: 210 / 255).opacity(0.96)
    static let textDim = Color(red: 245 / 255, green: 232 / 255, blue: 210 / 255).opacity(0.55)
    static let textFaint = Color(red: 245 / 255, green: 232 / 255, blue: 210 / 255).opacity(0.35)
    static let accent = Color(hex: "#E8B87A")
    static let accentDeep = Color(hex: "#C99356")
    static let accentSoft = Color(hex: "#E8B87A").opacity(0.14)
    static let accentGlow = Color(hex: "#E8B87A").opacity(0.55)
}

@MainActor
final class SleepSoundsAudioStore: NSObject, ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var currentConfig: SleepSoundStepConfig?
    @Published private(set) var sampledSoundId: SoundId?
    @Published private(set) var remainingSeconds: Int?
    @Published private(set) var lastPlaybackError: String?

    private var player: AVAudioPlayer?
    private var samplePlayer: AVAudioPlayer?
    private var playbackTimer: Timer?
    private var crossfadeTimer: Timer?
    private var endDate: Date?
    private var pausedRemainingSeconds: Int?
    private var lastPlayerTime: TimeInterval = 0
    private var lastPlayerAdvanceCheck = Date()
    private var remoteTargetsInstalled = false
    private var observerTokens: [NSObjectProtocol] = []

    override init() {
        super.init()
        installAudioObservers()
        installRemoteCommands()
    }

    deinit {
        for token in observerTokens {
            NotificationCenter.default.removeObserver(token)
        }
    }

    func play(config: SleepSoundStepConfig) {
        guard let soundId = config.soundId else { return }
        stopSample()

        guard prepareAudioSession() else { return }

        guard let url = soundURL(for: soundId) else {
            reportPlaybackError("Missing bundled audio for \(soundId.rawValue).m4a")
            return
        }

        let audio: AVAudioPlayer
        do {
            audio = try AVAudioPlayer(contentsOf: url)
        } catch {
            reportPlaybackError("Could not load \(soundId.rawValue).m4a: \(error.localizedDescription)")
            return
        }
        audio.numberOfLoops = -1
        audio.delegate = self
        audio.currentTime = 0
        let shouldCrossfade = player != nil && currentConfig?.soundId != soundId
        audio.volume = shouldCrossfade ? 0 : 1
        audio.prepareToPlay()
        guard audio.play() else {
            reportPlaybackError("AVAudioPlayer refused to play \(soundId.rawValue).m4a")
            return
        }

        let previousPlayer = player
        player = audio
        currentConfig = config
        isPlaying = true
        lastPlaybackError = nil
        pausedRemainingSeconds = nil
        resetPlayerAdvanceTracking(audio)
        endDate = config.infinite ? nil : Date().addingTimeInterval(TimeInterval((config.durationMinutes ?? 60) * 60))
        updateRemaining()
        startPlaybackTimer()
        updateNowPlaying()
        if shouldCrossfade, let previousPlayer {
            crossfade(from: previousPlayer, to: audio)
        } else {
            previousPlayer?.stop()
        }
    }

    func pause() {
        updateRemaining()
        pausedRemainingSeconds = remainingSeconds
        player?.pause()
        isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
        MPNowPlayingInfoCenter.default().playbackState = .paused
    }

    func resume() {
        guard let player else { return }
        guard prepareAudioSession() else { return }
        guard player.play() else {
            reportPlaybackError("AVAudioPlayer refused to resume")
            return
        }
        if let seconds = pausedRemainingSeconds {
            endDate = Date().addingTimeInterval(TimeInterval(seconds))
            pausedRemainingSeconds = nil
        }
        isPlaying = true
        startPlaybackTimer()
        MPNowPlayingInfoCenter.default().playbackState = .playing
    }

    func stop(fadeOut: Bool = false) {
        if fadeOut {
            fadeOutAndStop(duration: 90)
            return
        }
        player?.stop()
        player = nil
        crossfadeTimer?.invalidate()
        crossfadeTimer = nil
        isPlaying = false
        currentConfig = nil
        remainingSeconds = nil
        endDate = nil
        pausedRemainingSeconds = nil
        lastPlayerTime = 0
        lastPlayerAdvanceCheck = Date()
        playbackTimer?.invalidate()
        playbackTimer = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func toggleSample(for soundId: SoundId) {
        if sampledSoundId == soundId {
            stopSample()
            return
        }
        stopSample()
        guard prepareAudioSession() else { return }
        guard let url = soundURL(for: soundId) else {
            reportPlaybackError("Missing bundled audio for \(soundId.rawValue).m4a")
            return
        }

        let preview: AVAudioPlayer
        do {
            preview = try AVAudioPlayer(contentsOf: url)
        } catch {
            reportPlaybackError("Could not load preview \(soundId.rawValue).m4a: \(error.localizedDescription)")
            return
        }
        preview.numberOfLoops = 0
        preview.delegate = self
        preview.volume = 1
        preview.prepareToPlay()
        guard preview.play() else {
            reportPlaybackError("AVAudioPlayer refused to preview \(soundId.rawValue).m4a")
            return
        }
        samplePlayer = preview
        sampledSoundId = soundId
        lastPlaybackError = nil
    }

    func stopSample() {
        samplePlayer?.stop()
        samplePlayer = nil
        sampledSoundId = nil
    }

    private func soundURL(for soundId: SoundId) -> URL? {
        Bundle.main.url(forResource: soundId.rawValue, withExtension: "m4a", subdirectory: "sleep")
            ?? Bundle.main.url(forResource: soundId.rawValue, withExtension: "m4a")
    }

    private func prepareAudioSession() -> Bool {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
            return true
        } catch {
            reportPlaybackError("Audio session failed: \(error.localizedDescription)")
            return false
        }
    }

    private func reportPlaybackError(_ message: String) {
        lastPlaybackError = message
        #if DEBUG
        print("[SleepSounds] \(message)")
        #endif
    }

    private func crossfade(from oldPlayer: AVAudioPlayer, to newPlayer: AVAudioPlayer) {
        crossfadeTimer?.invalidate()
        let duration: TimeInterval = 0.6
        let startedAt = Date()
        let oldVolume = oldPlayer.volume
        crossfadeTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self, weak oldPlayer, weak newPlayer] timer in
            Task { @MainActor in
                guard let self, let oldPlayer, let newPlayer else {
                    timer.invalidate()
                    return
                }
                let progress = min(1, Date().timeIntervalSince(startedAt) / duration)
                oldPlayer.volume = oldVolume * Float(1 - progress)
                newPlayer.volume = Float(progress)
                if progress >= 1 {
                    oldPlayer.stop()
                    newPlayer.volume = 1
                    timer.invalidate()
                    self.crossfadeTimer = nil
                }
            }
        }
    }

    private func startPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        guard isPlaying else { return }
        if shouldRefreshAudioSession() {
            _ = prepareAudioSession()
        }
        updateRemaining()
        guard let endDate else { return }
        let remaining = endDate.timeIntervalSinceNow
        if remaining <= 0 {
            stop()
            return
        }
        if player?.isPlaying != true {
            recoverUnexpectedPlayerStop(remaining: remaining)
            return
        }
        if playerAppearsStalled() {
            reportPlaybackError("Player time stalled while timer was active; recovering")
            recoverUnexpectedPlayerStop(remaining: remaining)
            return
        }
        if currentConfig?.fadeOut == true, remaining <= 90 {
            player?.volume = max(0, Float(remaining / 90))
        }
    }

    private func shouldRefreshAudioSession() -> Bool {
        Date().timeIntervalSince(lastPlayerAdvanceCheck) >= 1
    }

    private func resetPlayerAdvanceTracking(_ player: AVAudioPlayer?) {
        lastPlayerTime = player?.currentTime ?? 0
        lastPlayerAdvanceCheck = Date()
    }

    private func playerAppearsStalled() -> Bool {
        guard let player, player.isPlaying else { return false }
        let now = Date()
        guard now.timeIntervalSince(lastPlayerAdvanceCheck) >= 1.5 else { return false }
        defer {
            lastPlayerTime = player.currentTime
            lastPlayerAdvanceCheck = now
        }
        return abs(player.currentTime - lastPlayerTime) < 0.05
    }

    private func recoverUnexpectedPlayerStop(remaining: TimeInterval) {
        guard let config = currentConfig, let soundId = config.soundId else {
            stop()
            return
        }
        guard remaining > 0 else {
            stop()
            return
        }
        guard prepareAudioSession() else { return }
        guard let url = soundURL(for: soundId) else {
            reportPlaybackError("Missing bundled audio for \(soundId.rawValue).m4a")
            return
        }

        let recoveredPlayer: AVAudioPlayer
        do {
            recoveredPlayer = try AVAudioPlayer(contentsOf: url)
        } catch {
            reportPlaybackError("Could not recover \(soundId.rawValue).m4a: \(error.localizedDescription)")
            return
        }

        recoveredPlayer.numberOfLoops = -1
        recoveredPlayer.delegate = self
        recoveredPlayer.currentTime = 0
        recoveredPlayer.volume = config.fadeOut && remaining <= 90 ? max(0, Float(remaining / 90)) : 1
        recoveredPlayer.prepareToPlay()
        guard recoveredPlayer.play() else {
            reportPlaybackError("AVAudioPlayer refused to recover \(soundId.rawValue).m4a")
            return
        }

        player?.stop()
        player = recoveredPlayer
        isPlaying = true
        lastPlaybackError = nil
        resetPlayerAdvanceTracking(recoveredPlayer)
        updateNowPlaying()
        #if DEBUG
        print("[SleepSounds] Recovered unexpected stop for \(soundId.rawValue)")
        #endif
    }

    private func updateRemaining() {
        guard let endDate else {
            remainingSeconds = nil
            return
        }
        remainingSeconds = max(0, Int(ceil(endDate.timeIntervalSinceNow)))
    }

    private func fadeOutAndStop(duration: TimeInterval) {
        guard let player else {
            stop()
            return
        }
        let startVolume = player.volume
        let start = Date()
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else { return }
                let progress = min(1, Date().timeIntervalSince(start) / duration)
                player.volume = startVolume * Float(1 - progress)
                if progress >= 1 {
                    timer.invalidate()
                    self.stop()
                }
            }
        }
    }

    private func updateNowPlaying() {
        guard let config = currentConfig, let soundId = config.soundId else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: soundId.name,
            MPMediaItemPropertyArtist: "Lull Sleep Sounds",
            MPNowPlayingInfoPropertyPlaybackRate: 1.0
        ]
        if let remainingSeconds {
            info[MPMediaItemPropertyPlaybackDuration] = remainingSeconds
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = .playing
    }

    private func installAudioObservers() {
        let center = NotificationCenter.default
        observerTokens.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            Task { @MainActor in self?.handleInterruption(note) }
        })
        observerTokens.append(center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            Task { @MainActor in self?.handleRouteChange(note) }
        })
    }

    private func installRemoteCommands() {
        guard !remoteTargetsInstalled else { return }
        let commands = MPRemoteCommandCenter.shared()
        commands.playCommand.isEnabled = true
        commands.pauseCommand.isEnabled = true
        commands.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.resume() }
            return .success
        }
        commands.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        remoteTargetsInstalled = true
    }

    private func handleInterruption(_ note: Notification) {
        guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        if type == .began {
            pause()
        } else if type == .ended, let player, currentConfig != nil {
            try? AVAudioSession.sharedInstance().setActive(true)
            player.play()
            isPlaying = true
            startPlaybackTimer()
            updateNowPlaying()
        }
    }

    private func handleRouteChange(_ note: Notification) {
        guard let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: raw),
              reason == .oldDeviceUnavailable else { return }
        pause()
    }
}

extension SleepSoundsAudioStore: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            if self.samplePlayer === player {
                self.stopSample()
                return
            }

            guard self.player === player else { return }
            self.updateRemaining()
            if self.isPlaying, let seconds = self.remainingSeconds, seconds > 0 {
                self.recoverUnexpectedPlayerStop(remaining: TimeInterval(seconds))
            } else {
                self.stop()
            }
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            let message = error?.localizedDescription ?? "Unknown decode error"
            if self.samplePlayer === player {
                self.stopSample()
                self.reportPlaybackError("Preview decode error: \(message)")
                return
            }

            guard self.player === player else { return }
            self.reportPlaybackError("Playback decode error: \(message)")
            self.updateRemaining()
            if self.isPlaying, let seconds = self.remainingSeconds, seconds > 0 {
                self.recoverUnexpectedPlayerStop(remaining: TimeInterval(seconds))
            } else {
                self.stop()
            }
        }
    }
}

struct SleepSoundsStep: View {
    enum Mode {
        case editStep
        case standalone
    }

    var initial: SleepSoundStepConfig = .fresh
    var mode: Mode
    var onSave: ((SleepSoundStepConfig) -> Void)?
    var onDismiss: (() -> Void)?

    @EnvironmentObject private var audioStore: SleepSoundsAudioStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var config: SleepSoundStepConfig
    @State private var customMinutes: Double
    @State private var showCustom: Bool

    init(
        initial: SleepSoundStepConfig = .fresh,
        mode: Mode,
        onSave: ((SleepSoundStepConfig) -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.initial = initial
        self.mode = mode
        self.onSave = onSave
        self.onDismiss = onDismiss
        _config = State(initialValue: initial)
        let minutes = initial.durationMinutes ?? 60
        _customMinutes = State(initialValue: Double(minutes))
        _showCustom = State(initialValue: ![15, 30, 60, 120].contains(minutes) && !initial.infinite)
    }

    private var isCurrentSoundPlaying: Bool {
        audioStore.isPlaying && audioStore.currentConfig?.soundId == config.soundId
    }

    private var ctaTitle: String {
        guard config.soundId != nil else { return "Pick a sound" }
        return "Save"
    }

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 700
            let bottomPadding = max(proxy.safeAreaInsets.bottom + 18, mode == .editStep ? 104 : 28)

            ZStack {
            SleepSoundPalette.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                header(compact: compact)

                VStack(alignment: .leading, spacing: compact ? 6 : 8) {
                    Text("SLEEP SOUNDS")
                        .font(.system(size: 11.5, weight: .medium))
                        .tracking(0.92)
                        .foregroundColor(SleepSoundPalette.accent)
                    Text("Sound to drift off to")
                        .font(.serif(compact ? 22 : 24))
                        .foregroundColor(SleepSoundPalette.text)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, compact ? 6 : 14)
                .padding(.bottom, compact ? 8 : 14)

                soundList(compact: compact)
                    .padding(.horizontal, 16)

                if config.soundId != nil {
                    timerCard(compact: compact)
                        .padding(.horizontal, 16)
                        .padding(.top, compact ? 8 : 14)
                        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                } else {
                    Text("Tap a sound to set how long it plays.")
                        .font(.system(size: 13))
                        .foregroundColor(SleepSoundPalette.textFaint)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 24)
                        .padding(.top, compact ? 10 : 20)
                }

                Spacer(minLength: compact ? 4 : 14)

                Button(action: primaryAction) {
                    HStack(spacing: 8) {
                        Image(systemName: ctaIcon)
                            .font(.system(size: 15, weight: .semibold))
                        Text(ctaTitle)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(config.soundId == nil ? SleepSoundPalette.textFaint : SleepSoundPalette.bgDeep)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        Capsule()
                            .fill(config.soundId == nil ? Color.white.opacity(0.05) : SleepSoundPalette.accent)
                    )
                }
                .buttonStyle(.plain)
                .disabled(config.soundId == nil)
                .padding(.horizontal, 16)
                .padding(.bottom, bottomPadding)
                .accessibilityHint(config.soundId == nil ? "Select a sound first" : "")
            }
        }
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: reduceMotion ? 0.18 : 0.32), value: config.soundId != nil)
        .onDisappear {
            audioStore.stopSample()
        }
    }

    private func header(compact: Bool) -> some View {
        HStack {
            Text(mode == .editStep ? "EDIT STEP" : "SLEEP SOUNDS")
                .font(.system(size: 13, weight: .medium))
                .tracking(0.52)
                .foregroundColor(SleepSoundPalette.textFaint)

            Spacer()

            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(SleepSoundPalette.textDim)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.05))
                            .overlay(Circle().strokeBorder(SleepSoundPalette.line, lineWidth: 1))
                    )
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 16)
        .padding(.top, compact ? 40 : 52)
        .padding(.bottom, compact ? 4 : 8)
    }

    private func soundList(compact: Bool) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(SoundId.allCases.enumerated()), id: \.element) { index, sound in
                SoundRow(
                    sound: sound,
                    selected: config.soundId == sound,
                    sampling: audioStore.sampledSoundId == sound,
                    compact: compact,
                    isLast: index == SoundId.allCases.count - 1,
                    onSelect: { config.soundId = sound },
                    onSample: { audioStore.toggleSample(for: sound) }
                )
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(SleepSoundPalette.card)
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(SleepSoundPalette.line, lineWidth: 1))
        )
    }

    private func timerCard(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Play for")
                    .font(.system(size: compact ? 12.5 : 13, weight: .medium))
                    .foregroundColor(SleepSoundPalette.textDim)
                Spacer()
                Text(config.infinite ? "∞ until I wake" : config.durationSummary)
                    .font(.serif(compact ? 18 : 20))
                    .foregroundColor(SleepSoundPalette.accent)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    durationChip(label: "15m", minutes: 15)
                    durationChip(label: "30m", minutes: 30)
                    durationChip(label: "1h", minutes: 60)
                    durationChip(label: "2h", minutes: 120)
                }
                HStack(spacing: 6) {
                    infiniteChip
                    customChip
                }
            }

            if showCustom && !config.infinite {
                customSlider
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
            }

            if config.infinite {
                Text("Play until I wake")
                    .font(.serif(22))
                    .foregroundColor(SleepSoundPalette.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Toggle(isOn: $config.fadeOut) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Fade out at the end")
                        .font(.system(size: compact ? 13 : 13.5, weight: .medium))
                        .foregroundColor(SleepSoundPalette.text)
                    Text("Last 90 seconds taper to silence.")
                        .font(.system(size: compact ? 11.5 : 12.5))
                        .foregroundColor(SleepSoundPalette.textDim)
                }
            }
            .tint(SleepSoundPalette.accent)
        }
        .padding(compact ? 12 : 16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(SleepSoundPalette.card)
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(SleepSoundPalette.line, lineWidth: 1))
        )
    }

    private func durationChip(label: String, minutes: Int) -> some View {
        let selected = !config.infinite && config.durationMinutes == minutes && !showCustom
        return Button(label) {
            config.infinite = false
            config.durationMinutes = minutes
            customMinutes = Double(minutes)
            showCustom = false
        }
        .font(.system(size: 13.5, weight: .medium))
        .foregroundColor(selected ? SleepSoundPalette.accent : SleepSoundPalette.textDim)
        .frame(minWidth: 44, minHeight: 34)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(selected ? SleepSoundPalette.accentSoft : Color.clear)
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(selected ? SleepSoundPalette.accentDeep : SleepSoundPalette.lineHi, lineWidth: 1))
        )
        .buttonStyle(.plain)
        .accessibilityLabel("\(label), button, \(selected ? "selected" : "not selected")")
    }

    private var infiniteChip: some View {
        Button("∞ Until I wake") {
            config.infinite = true
            config.durationMinutes = nil
            showCustom = false
        }
        .font(.system(size: 13.5, weight: .medium))
        .foregroundColor(config.infinite ? SleepSoundPalette.accent : SleepSoundPalette.textDim)
        .frame(minHeight: 34)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(config.infinite ? SleepSoundPalette.accentSoft : Color.clear)
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(config.infinite ? SleepSoundPalette.accentDeep : SleepSoundPalette.lineHi, lineWidth: 1))
        )
        .buttonStyle(.plain)
        .accessibilityLabel("Until I wake, button, \(config.infinite ? "selected" : "not selected")")
    }

    private var customChip: some View {
        Button("Custom…") {
            config.infinite = false
            let minutes = Int((customMinutes / 5).rounded() * 5)
            config.durationMinutes = minutes
            showCustom = true
        }
        .font(.system(size: 13.5, weight: .medium))
        .foregroundColor(showCustom ? SleepSoundPalette.accent : SleepSoundPalette.textDim)
        .frame(minWidth: 74, minHeight: 34)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(showCustom ? SleepSoundPalette.accentSoft : Color.clear)
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(showCustom ? SleepSoundPalette.accentDeep : SleepSoundPalette.lineHi, lineWidth: 1))
        )
        .buttonStyle(.plain)
        .accessibilityLabel("Custom, button, \(showCustom ? "selected" : "not selected")")
    }

    private var customSlider: some View {
        VStack(spacing: 8) {
            Slider(
                value: Binding(
                    get: { customMinutes },
                    set: { newValue in
                        let snapped = (newValue / 5).rounded() * 5
                        customMinutes = snapped
                        config.durationMinutes = Int(snapped)
                    }
                ),
                in: 5...480,
                step: 5
            )
            .tint(SleepSoundPalette.accent)
            .accessibilityValue(SleepSoundStepConfig.accessibilityDurationText(minutes: Int(customMinutes)))

            HStack {
                ForEach(["0", "1h", "2h", "4h", "6h", "8h"], id: \.self) { tick in
                    Text(tick)
                        .font(.system(size: 10))
                        .foregroundColor(SleepSoundPalette.textFaint)
                    if tick != "8h" { Spacer() }
                }
            }
        }
    }

    private var ctaIcon: String {
        return "checkmark"
    }

    private func primaryAction() {
        if mode == .editStep {
            onSave?(config)
            dismiss()
            return
        }
        onSave?(config)
        audioStore.play(config: config)
        dismiss()
    }

    private func close() {
        onDismiss?()
        dismiss()
    }

    private func toggleMainPlayback() {
        if isCurrentSoundPlaying {
            audioStore.pause()
        } else if audioStore.currentConfig?.soundId == config.soundId, !audioStore.isPlaying {
            audioStore.resume()
        } else {
            audioStore.play(config: config)
        }
    }
}

private struct SoundRow: View {
    var sound: SoundId
    var selected: Bool
    var sampling: Bool
    var compact: Bool
    var isLast: Bool
    var onSelect: () -> Void
    var onSample: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(selected ? SleepSoundPalette.accentSoft : Color.white.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(selected ? SleepSoundPalette.accent.opacity(0.35) : SleepSoundPalette.line, lineWidth: 1))
                    Image(systemName: sound.symbol)
                        .font(.system(size: compact ? 14 : 16, weight: .regular))
                        .foregroundColor(selected ? SleepSoundPalette.accent : SleepSoundPalette.textDim)
                }
                .frame(width: compact ? 30 : 34, height: compact ? 30 : 34)

                HStack(spacing: 8) {
                    Text(sound.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(SleepSoundPalette.text)
                        .lineLimit(1)
                    SampleWave(active: sampling)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: onSample) {
                    ZStack {
                        Circle()
                            .fill(sampling ? SleepSoundPalette.accent : Color.white.opacity(0.06))
                            .overlay(Circle().strokeBorder(sampling ? SleepSoundPalette.accentDeep : SleepSoundPalette.line, lineWidth: 1))
                            .frame(width: 30, height: 30)
                        Image(systemName: sampling ? "pause.fill" : "play.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(sampling ? SleepSoundPalette.bgDeep : SleepSoundPalette.textDim)
                    }
                    .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(sound.name) preview")
                    .accessibilityHint("Plays a short preview")

                RadioDot(selected: selected)
            }
            .frame(height: compact ? 34 : 43)
            .padding(.leading, 14)
            .padding(.trailing, 10)
            .background(selected ? SleepSoundPalette.accentSoft : Color.clear)
            .overlay(alignment: .bottom) {
                if !isLast {
                    Rectangle()
                        .fill(SleepSoundPalette.line)
                        .frame(height: 1)
                        .padding(.leading, 64)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(sound.name), sample available, \(selected ? "selected" : "not selected")")
    }
}

private struct RadioDot: View {
    var selected: Bool

    var body: some View {
        Circle()
            .strokeBorder(selected ? SleepSoundPalette.accent : SleepSoundPalette.lineHi, lineWidth: 1.5)
            .background(
                Circle()
                    .fill(selected ? SleepSoundPalette.accentSoft : Color.clear)
                    .overlay {
                        if selected {
                            Circle()
                                .fill(SleepSoundPalette.accent)
                                .frame(width: 10, height: 10)
                        }
                    }
            )
            .frame(width: 22, height: 22)
    }
}

private struct SampleWave: View {
    var active: Bool
    @State private var phase = false
    private let bars: [CGFloat] = [3, 6, 4, 7, 5, 8, 4, 6, 3]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(bars.enumerated()), id: \.offset) { index, height in
                RoundedRectangle(cornerRadius: 1)
                    .fill(SleepSoundPalette.accent)
                    .frame(width: 2, height: active && phase ? height + CGFloat(index % 3) * 2 : height)
                    .animation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true).delay(Double(index) * 0.04), value: phase)
            }
        }
        .frame(width: 34, height: 14)
        .opacity(active ? 1 : 0)
        .onAppear { phase = active }
        .onChange(of: active) { _, newValue in phase = newValue }
    }
}

struct SleepSoundsMiniPlayer: View {
    @EnvironmentObject private var audioStore: SleepSoundsAudioStore
    var onOpen: () -> Void

    var body: some View {
        if let config = audioStore.currentConfig, let soundId = config.soundId, audioStore.isPlaying {
            HStack(spacing: 12) {
                Button(action: onOpen) {
                    HStack(spacing: 12) {
                        Image(systemName: soundId.symbol)
                            .font(.system(size: 15))
                            .foregroundColor(SleepSoundPalette.accent)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(SleepSoundPalette.accentSoft))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(soundId.name)
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundColor(SleepSoundPalette.text)
                            Text(config.infinite ? "Until I wake" : remainingText)
                                .font(.system(size: 11.5))
                                .foregroundColor(SleepSoundPalette.textDim)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(soundId.name), playing")

                Button(action: { audioStore.pause() }) {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.black)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(SleepSoundPalette.accent))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Pause sleep sound")

                Button(action: { audioStore.stop() }) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(SleepSoundPalette.text)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.white.opacity(0.06)))
                        .overlay(Circle().strokeBorder(SleepSoundPalette.lineHi, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Stop sleep sound")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(height: SleepSoundsMiniPlayerLayout.height)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(SleepSoundPalette.bgDeep.opacity(0.96))
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(SleepSoundPalette.lineHi, lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.45), radius: 18, y: 8)
            )
        }
    }

    private var remainingText: String {
        guard let seconds = audioStore.remainingSeconds else { return "Playing" }
        let minutes = max(1, Int(ceil(Double(seconds) / 60)))
        return "\(SleepSoundStepConfig.durationText(minutes: minutes)) left"
    }
}

enum SleepSoundsMiniPlayerLayout {
    static let height: CGFloat = 58
    static let reservedHeight: CGFloat = height + 12
    static let bottomAboveTabBar: CGFloat = 72
}

struct SleepSoundsToolCard: View {
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(SleepSoundPalette.accentSoft)
                    Image(systemName: "water.waves")
                        .font(.system(size: 17))
                        .foregroundColor(SleepSoundPalette.accent)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Kicker(text: "Sleep sounds", color: .lullAmberSoft)
                    Text("Rain, green noise, lake water")
                        .font(.system(size: 13))
                        .foregroundColor(.lullInk2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.lullInk3)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.025))
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.lullLine, lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }
}

struct NightlySleepSoundsView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var audioStore: SleepSoundsAudioStore
    @State private var activeConfig = SleepSoundStepConfig.fresh
    @State private var activePanel: NightlySoundPanel?
    @State private var didStartPlayback = false
    @State private var startPlaybackTask: Task<Void, Never>?

    private var configuredStep: RoutineStep? {
        state.coreRoutine.first { $0.label == R.sleepSounds }
    }

    private var config: SleepSoundStepConfig {
        configuredStep?.sleepSoundConfig ?? .fresh
    }

    private var sound: SoundId {
        activeConfig.soundId ?? config.soundId ?? .heavyRain
    }

    private var isPaused: Bool {
        audioStore.currentConfig?.soundId == sound && !audioStore.isPlaying
    }

    var body: some View {
        LullScreen(glow: false) {
            ZStack {
                Color.black.ignoresSafeArea()
                RadialGradient(
                    colors: [sound.auraColor.opacity(0.18), .clear],
                    center: .center,
                    startRadius: 20,
                    endRadius: 320
                )
                .ignoresSafeArea()

                GeometryReader { proxy in
                    let compact = proxy.size.height < 740
                    let orbSize: CGFloat = compact ? 176 : 230
                    let titleSize: CGFloat = compact ? 26 : 30
                    let timerSize: CGFloat = activeConfig.infinite ? (compact ? 40 : 46) : (compact ? 30 : 34)

                    VStack(spacing: 0) {
                        Spacer().frame(height: 16)
                        NightlyStepHeader(
                            step: state.nightlyStep + 1,
                            total: state.nightlyStepTotal,
                            label: "Sounds",
                            time: state.scheduledTime(for: R.sleepSounds)
                        )

                        VStack(spacing: 10) {
                            Group {
                                Text("Drifting off to ")
                                    .foregroundColor(SleepSoundPalette.text)
                                + Text(sound.name)
                                    .foregroundColor(SleepSoundPalette.accent)
                                    .italic()
                            }
                            .font(.serif(titleSize))
                            .multilineTextAlignment(.center)

                            Text(activeConfig.fadeOut ? "Sound continues through the next steps. Fades out at the end." : "Sound continues through the next steps.")
                                .font(.system(size: 13.5))
                                .foregroundColor(SleepSoundPalette.textDim)
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                                .frame(maxWidth: 292)
                        }
                        .padding(.horizontal, 28)

                        Spacer(minLength: compact ? 10 : 18)

                        NightlySoundOrb(sound: sound, paused: isPaused)
                            .frame(width: orbSize, height: orbSize)

                        Text(timerLabel)
                            .font(.serif(timerSize))
                            .foregroundColor(isPaused ? SleepSoundPalette.textDim : SleepSoundPalette.text)
                            .monospacedDigit()
                            .padding(.top, compact ? 10 : 16)

                        HStack(spacing: 12) {
                            NightlySoundControl(icon: isPaused ? "play.fill" : "pause.fill", label: isPaused ? "Resume" : "Pause") {
                                if isPaused {
                                    audioStore.resume()
                                } else {
                                    audioStore.pause()
                                }
                            }
                            NightlySoundControl(icon: "music.note.list", label: "Switch") {
                                activePanel = .switchSound
                            }
                            NightlySoundControl(icon: "timer", label: "Timer") {
                                activePanel = .timer
                            }
                        }
                        .padding(.top, compact ? 12 : 18)

                        Spacer()

                        VStack(spacing: 14) {
                            PrimaryCTA(title: "Continue") {
                                advance(status: .completed)
                            }

                            Button("Skip this step") {
                                audioStore.stop()
                                advance(status: .skipped)
                            }
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(SleepSoundPalette.textDim)
                        }
                        .padding(.horizontal, 22)
                        .padding(.bottom, compact ? 24 : 36)
                    }
                }
            }
        }
        .onAppear {
            guard !didStartPlayback else { return }
            didStartPlayback = true
            let preparedConfig = playableConfig(config)
            activeConfig = preparedConfig
            startPlaybackTask?.cancel()
            startPlaybackTask = Task {
                try? await Task.sleep(nanoseconds: 1_100_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    audioStore.play(config: preparedConfig)
                }
            }
        }
        .onDisappear {
            startPlaybackTask?.cancel()
            startPlaybackTask = nil
        }
        .sheet(item: $activePanel) { panel in
            switch panel {
            case .switchSound:
                NightlySoundSwitchSheet(current: sound) { newSound in
                    startPlaybackTask?.cancel()
                    var updated = activeConfig
                    updated.soundId = newSound
                    activeConfig = updated
                    activePanel = nil
                    startPlaybackTask = Task {
                        try? await Task.sleep(nanoseconds: 350_000_000)
                        guard !Task.isCancelled else { return }
                        await MainActor.run {
                            audioStore.play(config: updated)
                        }
                    }
                }
            case .timer:
                NightlySoundTimerSheet(config: activeConfig) { updated in
                    startPlaybackTask?.cancel()
                    activeConfig = updated
                    activePanel = nil
                    startPlaybackTask = Task {
                        try? await Task.sleep(nanoseconds: 250_000_000)
                        guard !Task.isCancelled else { return }
                        await MainActor.run {
                            audioStore.play(config: updated)
                        }
                    }
                }
            }
        }
    }

    private var timerLabel: String {
        if isPaused { return "paused" }
        if activeConfig.infinite { return "∞" }
        guard let seconds = audioStore.remainingSeconds else {
            return SleepSoundStepConfig.durationText(minutes: activeConfig.durationMinutes ?? 60)
        }
        if seconds >= 3600 {
            return String(format: "%d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
        }
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private func playableConfig(_ base: SleepSoundStepConfig) -> SleepSoundStepConfig {
        var next = base
        if next.soundId == nil { next.soundId = .heavyRain }
        if !next.infinite && next.durationMinutes == nil { next.durationMinutes = 60 }
        return next
    }

    private func advance(status: StepStatus) {
        let listenedSeconds: Int? = {
            guard !activeConfig.infinite else { return nil }
            let configured = (activeConfig.durationMinutes ?? 60) * 60
            let remaining = audioStore.remainingSeconds ?? configured
            return max(0, configured - remaining)
        }()
        state.recordSleepSoundAttempt(status: status, config: activeConfig, listenedSeconds: listenedSeconds)
        state.nightlyStep += 1
    }
}

private enum NightlySoundPanel: Identifiable {
    case switchSound
    case timer

    var id: String {
        switch self {
        case .switchSound: return "switch"
        case .timer: return "timer"
        }
    }
}

private struct NightlySoundOrb: View {
    var sound: SoundId
    var paused: Bool
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [sound.auraColor.opacity(paused ? 0.10 : 0.32), .clear],
                        center: .center,
                        startRadius: 8,
                        endRadius: pulse && !paused ? 120 : 88
                    )
                )
                .scaleEffect(pulse && !paused ? 1.08 : 0.92)

            Circle()
                .stroke(sound.auraColor.opacity(paused ? 0.16 : 0.42), lineWidth: 1.2)
                .frame(width: pulse && !paused ? 176 : 150, height: pulse && !paused ? 176 : 150)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [sound.auraColor.opacity(paused ? 0.42 : 0.95), sound.auraColor.opacity(paused ? 0.14 : 0.36)],
                        center: .topLeading,
                        startRadius: 8,
                        endRadius: 72
                    )
                )
                .frame(width: 118, height: 118)
                .shadow(color: sound.auraColor.opacity(paused ? 0.16 : 0.65), radius: pulse && !paused ? 42 : 24)
                .overlay {
                    Image(systemName: paused ? "pause.fill" : sound.symbol)
                        .font(.system(size: paused ? 28 : 34, weight: .regular))
                        .foregroundColor(Color.black.opacity(0.72))
                }
        }
        .opacity(paused ? 0.4 : 1)
        .animation(paused ? nil : .easeInOut(duration: 5.2).repeatForever(autoreverses: true), value: pulse)
        .onAppear { pulse = true }
        .onChange(of: paused) { _, newValue in
            pulse = !newValue
        }
    }
}

private struct NightlySoundControl: View {
    var icon: String
    var label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white.opacity(0.055)))
                    .overlay(Circle().strokeBorder(SleepSoundPalette.lineHi, lineWidth: 1))
                Text(label)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(SleepSoundPalette.textDim)
            }
            .foregroundColor(SleepSoundPalette.text)
        }
        .buttonStyle(.plain)
    }
}

private struct NightlySoundSwitchSheet: View {
    var current: SoundId
    var onPick: (SoundId) -> Void
    @State private var pickedSound: SoundId?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Switch sound")
                .font(.serif(26))
                .foregroundColor(SleepSoundPalette.text)
                .padding(.horizontal, 22)
                .padding(.top, 22)

            VStack(spacing: 0) {
                ForEach(Array(SoundId.allCases.enumerated()), id: \.element) { index, sound in
                    Button {
                        guard pickedSound == nil else { return }
                        pickedSound = sound
                        onPick(sound)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: sound.symbol)
                                .font(.system(size: 16))
                                .foregroundColor(isSelected(sound) ? SleepSoundPalette.accent : SleepSoundPalette.textDim)
                                .frame(width: 34, height: 34)
                                .background(RoundedRectangle(cornerRadius: 12).fill(isSelected(sound) ? SleepSoundPalette.accentSoft : Color.white.opacity(0.04)))

                            Text(sound.name)
                                .font(.system(size: 15.5, weight: .medium))
                                .foregroundColor(SleepSoundPalette.text)

                            Spacer()

                            if isSelected(sound) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(SleepSoundPalette.accent)
                            }
                        }
                        .padding(.horizontal, 18)
                        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
                        .contentShape(Rectangle())
                        .background(isSelected(sound) ? SleepSoundPalette.accentSoft : Color.clear)
                    }
                    .buttonStyle(.plain)
                    .disabled(pickedSound != nil)

                    if index != SoundId.allCases.count - 1 {
                        Divider().background(SleepSoundPalette.line).padding(.leading, 66)
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 18).fill(SleepSoundPalette.card))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(SleepSoundPalette.line, lineWidth: 1))
            .padding(.horizontal, 16)

            Spacer()
        }
        .presentationDetents([.height(506), .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.black)
    }

    private func isSelected(_ sound: SoundId) -> Bool {
        (pickedSound ?? current) == sound
    }
}

private struct NightlySoundTimerSheet: View {
    @State private var draft: SleepSoundStepConfig
    var onUpdate: (SleepSoundStepConfig) -> Void

    init(config: SleepSoundStepConfig, onUpdate: @escaping (SleepSoundStepConfig) -> Void) {
        _draft = State(initialValue: config)
        self.onUpdate = onUpdate
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Update timer")
                .font(.serif(26))
                .foregroundColor(SleepSoundPalette.text)
                .padding(.horizontal, 22)
                .padding(.top, 22)

            VStack(alignment: .leading, spacing: 12) {
                Text(draft.infinite ? "∞ until I wake" : SleepSoundStepConfig.durationText(minutes: draft.durationMinutes ?? 60))
                    .font(.serif(30))
                    .foregroundColor(SleepSoundPalette.accent)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 86), spacing: 8)], spacing: 8) {
                    timerPreset(label: "15m", minutes: 15)
                    timerPreset(label: "30m", minutes: 30)
                    timerPreset(label: "1h", minutes: 60)
                    timerPreset(label: "90m", minutes: 90)
                    timerPreset(label: "2h", minutes: 120)
                    timerInfinitePreset
                }
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 18).fill(SleepSoundPalette.card))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(SleepSoundPalette.line, lineWidth: 1))
            .padding(.horizontal, 16)

            Spacer()

            PrimaryCTA(title: "Update timer") {
                onUpdate(draft)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 34)
        }
        .presentationDetents([.height(360), .medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.black)
    }

    private func timerPreset(label: String, minutes: Int) -> some View {
        let selected = !draft.infinite && draft.durationMinutes == minutes
        return Button(label) {
            draft.infinite = false
            draft.durationMinutes = minutes
        }
        .font(.system(size: 14, weight: .medium))
        .foregroundColor(selected ? Color.black : SleepSoundPalette.text)
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .background(
            Capsule()
                .fill(selected ? SleepSoundPalette.accent : Color.white.opacity(0.04))
                .overlay(Capsule().strokeBorder(selected ? SleepSoundPalette.accentDeep : SleepSoundPalette.lineHi, lineWidth: 1))
        )
        .buttonStyle(.plain)
    }

    private var timerInfinitePreset: some View {
        let selected = draft.infinite
        return Button("∞") {
            draft.infinite = true
            draft.durationMinutes = nil
        }
        .font(.system(size: 18, weight: .medium))
        .foregroundColor(selected ? Color.black : SleepSoundPalette.text)
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .background(
            Capsule()
                .fill(selected ? SleepSoundPalette.accent : Color.white.opacity(0.04))
                .overlay(Capsule().strokeBorder(selected ? SleepSoundPalette.accentDeep : SleepSoundPalette.lineHi, lineWidth: 1))
        )
        .buttonStyle(.plain)
    }
}

private extension SoundId {
    var auraColor: Color {
        switch self {
        case .heavyRain: return Color(hex: "#7BA7D9")
        case .ambient: return Color(hex: "#A98AE6")
        case .greenNoise: return Color(hex: "#86A978")
        case .minSolf, .solf: return SleepSoundPalette.accent
        case .birds: return Color(hex: "#E8A889")
        case .lake: return Color(hex: "#5DBDB5")
        }
    }
}
