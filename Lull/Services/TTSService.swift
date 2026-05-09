import AVFoundation

// Streams text to AVSpeechSynthesizer sentence-by-sentence as it arrives.
// Slow, low-pitched delivery optimized for sleep onset.
@MainActor
class TTSService: NSObject, ObservableObject {

    @Published var isSpeaking = false
    @Published var isPaused = false

    // Karen (AU) is a default iPhone voice — no download needed. Enhanced if available, compact fallback.
    static let calmingVoice: AVSpeechSynthesisVoice? = {
        let candidates = [
            "com.apple.voice.enhanced.en-AU.Karen",
            "com.apple.ttsbundle.Karen-premium",
            "com.apple.voice.compact.en-AU.Karen",
            "com.apple.ttsbundle.Karen-compact",
        ]
        return candidates.compactMap { AVSpeechSynthesisVoice(identifier: $0) }.first
            ?? AVSpeechSynthesisVoice(language: "en-AU")
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
            synthesizer.continueSpeaking()
            isPaused = false
        } else {
            synthesizer.pauseSpeaking(at: .word)
            isPaused = true
        }
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        buffer = ""
        isSpeaking = false
        isPaused = false
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
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate            = 0.25          // slow, deliberate — sleep pace
        utterance.pitchMultiplier = 0.80          // pull Karen's natural register down for bedtime
        utterance.postUtteranceDelay = 0.45       // natural pause between sentences
        utterance.voice = TTSService.calmingVoice
        synthesizer.speak(utterance)
        isSpeaking = true
    }
}

extension TTSService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if !synthesizer.isSpeaking { self.isSpeaking = false }
        }
    }
}
