import AVFoundation

@MainActor
class AudioPlaybackService: NSObject, ObservableObject {

    @Published var isPlaying = false
    @Published var progress: Double = 0   // 0.0 – 1.0
    @Published var elapsed: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playbackRate: Float = 1.0

    private var player: AVAudioPlayer?
    private var timer: Timer?
    var onFinish: (() -> Void)?

    private let playbackRates: [Float] = [0.75, 0.9, 1.0, 1.5]

    var canSlowDown: Bool { currentRateIndex > playbackRates.startIndex }
    var canSpeedUp: Bool { currentRateIndex < playbackRates.index(before: playbackRates.endIndex) }

    func load(url: URL) {
        stop()
        guard let p = try? AVAudioPlayer(contentsOf: url) else { return }
        p.delegate = self
        p.enableRate = true
        p.rate = playbackRate
        p.prepareToPlay()
        player = p
        duration = p.duration
        elapsed = 0
        progress = 0
    }

    func play() {
        guard let player else { return }
        guard !isPlaying else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [])
        try? session.setActive(true)
        player.enableRate = true
        player.rate = playbackRate
        player.play()
        isPlaying = true
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        timer?.invalidate()
        timer = nil
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        timer?.invalidate()
        timer = nil
        elapsed = 0
        progress = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func speedDown() {
        setRate(playbackRates[max(playbackRates.startIndex, currentRateIndex - 1)])
    }

    func speedUp() {
        setRate(playbackRates[min(playbackRates.index(before: playbackRates.endIndex), currentRateIndex + 1)])
    }

    private func setRate(_ rate: Float) {
        playbackRate = nearestPlaybackRate(to: rate)
        player?.enableRate = true
        player?.rate = playbackRate
    }

    private var currentRateIndex: Int {
        playbackRates.enumerated().min(by: {
            abs($0.element - playbackRate) < abs($1.element - playbackRate)
        })?.offset ?? 2
    }

    private func nearestPlaybackRate(to rate: Float) -> Float {
        playbackRates.min(by: { abs($0 - rate) < abs($1 - rate) }) ?? 1.0
    }

    private func tick() {
        guard let player else { return }
        elapsed = player.currentTime
        progress = duration > 0 ? elapsed / duration : 0
    }
}

extension AudioPlaybackService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.elapsed = self.duration
            self.progress = 1.0
            self.timer?.invalidate()
            self.timer = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            self.onFinish?()
        }
    }
}
