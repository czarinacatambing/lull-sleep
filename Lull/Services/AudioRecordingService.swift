import AVFoundation

@MainActor
class AudioRecordingService: NSObject, ObservableObject {

    enum Permission { case unknown, granted, denied }
    enum RecordingState { case idle, recording, done }

    @Published var permission: Permission = .unknown
    @Published var recordingState: RecordingState = .idle
    @Published var duration: TimeInterval = 0

    private var recorder: AVAudioRecorder?
    private var timer: Timer?

    private var fileURL: URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("lull_braindump_\(UUID().uuidString).m4a")
    }

    static func braindumpURL(for date: Date) -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("brain_dumps", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let day = ISO8601DateFormatter().string(from: date).prefix(10)
        return dir.appendingPathComponent("braindump_\(day).m4a")
    }

    // MARK: - Permission

    func checkPermission() async {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            permission = .granted
        case .denied:
            permission = .denied
        case .undetermined:
            let granted = await AVAudioApplication.requestRecordPermission()
            permission = granted ? .granted : .denied
        @unknown default:
            break
        }
    }

    // MARK: - Recording

    func start() {
        guard permission == .granted else { return }

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.record, mode: .default, options: [])
        try? session.setActive(true)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        ]

        guard let rec = try? AVAudioRecorder(url: fileURL, settings: settings) else { return }
        rec.delegate = self
        rec.record()
        recorder = rec
        recordingState = .recording
        duration = 0

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.duration += 1 }
        }
    }

    func stopAndDiscard() {
        let url = recorder?.url
        recorder?.stop()
        timer?.invalidate()
        timer = nil
        recorder = nil
        recordingState = .done

        if let url { try? FileManager.default.removeItem(at: url) }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func stopAndSave(date: Date) -> URL? {
        guard let tempURL = recorder?.url else {
            stopAndDiscard()
            return nil
        }
        recorder?.stop()
        timer?.invalidate()
        timer = nil
        recorder = nil
        recordingState = .done

        let dest = AudioRecordingService.braindumpURL(for: date)
        try? FileManager.default.removeItem(at: dest)
        do {
            try FileManager.default.moveItem(at: tempURL, to: dest)
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            return nil
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return dest
    }

    func pause() {
        recorder?.pause()
    }

    func resume() {
        recorder?.record()
    }
}

extension AudioRecordingService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in self.recordingState = .idle }
    }
}
