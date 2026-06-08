import AVFoundation

// Streams text to AVSpeechSynthesizer sentence-by-sentence as it arrives.
// Slow, low-pitched delivery optimized for sleep onset.
@MainActor
class TTSService: NSObject, ObservableObject {

    @Published var isSpeaking = false
    @Published var isPaused = false

    // Gordon (AU) is the deepest voice Apple offers; Daniel (GB) is a deep British fallback;
    // Evan (US) is the deepest US male. Each tries enhanced then compact quality.
    static let calmingVoice: AVSpeechSynthesisVoice? = {
        let candidates = [
            "com.apple.voice.enhanced.en-AU.Gordon",
            "com.apple.ttsbundle.Gordon-premium",
            "com.apple.voice.compact.en-AU.Gordon",
            "com.apple.ttsbundle.Gordon-compact",
            "com.apple.voice.enhanced.en-GB.Daniel",
            "com.apple.ttsbundle.Daniel-premium",
            "com.apple.voice.compact.en-GB.Daniel",
            "com.apple.ttsbundle.Daniel-compact",
            "com.apple.voice.enhanced.en-US.Evan",
            "com.apple.voice.compact.en-US.Aaron",
        ]
        return candidates.compactMap { AVSpeechSynthesisVoice(identifier: $0) }.first
            ?? AVSpeechSynthesisVoice(language: "en-US")
    }()

    private let synthesizer = AVSpeechSynthesizer()
    private var buffer = ""

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // Feed incremental text chunks from the streaming API response.
    func append(_ text: String) {
        buffer += text
        flushSentences()
    }

    // Call when the stream is fully done to speak any trailing fragment.
    func flushRemaining() {
        let tail = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tail.isEmpty else { return }
        speak(tail)
        buffer = ""
    }

    func togglePause() {
        if synthesizer.isPaused {
            guard activateAudioSession() else { return }
            if synthesizer.continueSpeaking() {
                isPaused = false
                isSpeaking = true
            }
        } else if synthesizer.isSpeaking {
            if synthesizer.pauseSpeaking(at: .word) {
                isPaused = true
            }
        }
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        buffer = ""
        isSpeaking = false
        isPaused = false
        deactivateAudioSession()
    }

    // MARK: - Private

    private func flushSentences() {
        // Speak each complete sentence as it arrives so TTS starts within the first sentence.
        // Pattern: any text ending in . ! ? optionally followed by closing quote or space.
        while true {
            guard let range = buffer.range(of: #"[.!?][\"'\u{201D}]?(?:\s|$)"#,
                                           options: .regularExpression) else { break }
            let sentence = String(buffer[..<range.upperBound]).trimmingCharacters(in: .whitespaces)
            buffer = String(buffer[range.upperBound...])
            if !sentence.isEmpty { speak(sentence) }
        }
    }

    private func speak(_ text: String) {
        guard activateAudioSession() else {
            isSpeaking = false
            isPaused = false
            return
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate            = 0.30          // slow, deliberate — sleep pace
        utterance.pitchMultiplier = 0.85          // slightly lower than default
        utterance.postUtteranceDelay = 0.45       // natural pause between sentences
        utterance.voice = TTSService.calmingVoice
        synthesizer.speak(utterance)
        isSpeaking = true
    }

    private func activateAudioSession() -> Bool {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [])
            try session.setActive(true)
            return true
        } catch {
            return false
        }
    }

    private func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

extension TTSService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = true
            self.isPaused = false
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if !synthesizer.isSpeaking {
                self.isSpeaking = false
                self.isPaused = false
                self.deactivateAudioSession()
            }
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if !synthesizer.isSpeaking {
                self.isSpeaking = false
                self.isPaused = false
                self.deactivateAudioSession()
            }
        }
    }
}
