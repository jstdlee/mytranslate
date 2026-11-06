#if os(iOS)
import AVFoundation
import Observation

/// Reads the source or the result aloud. One voice at a time: starting one stops the other.
@MainActor
@Observable
public final class Speaker: NSObject, @preconcurrency AVSpeechSynthesizerDelegate {
    public enum Channel: String, Sendable {
        case source, result
    }

    /// Which text is being read right now, if any.
    public private(set) var current: Channel?

    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private var active: AVSpeechUtterance?

    public override init() {
        super.init()
        synthesizer.delegate = self
    }

    public func toggle(_ text: String, language: Language?, channel: Channel) {
        if current == channel {
            stop()
        } else {
            speak(text, language: language, channel: channel)
        }
    }

    public func speak(_ text: String, language: Language?, channel: Channel) {
        stop()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // .playback so the voice is heard with the ringer switch silenced.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        let utterance = AVSpeechUtterance(string: trimmed)
        if let language, let voice = AVSpeechSynthesisVoice(language: language.speechCode) {
            utterance.voice = voice
        }
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        active = utterance
        current = channel
        synthesizer.speak(utterance)
    }

    public func stop() {
        active = nil
        current = nil
        synthesizer.stopSpeaking(at: .immediate)
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        finish(utterance)
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        finish(utterance)
    }

    /// Ignores the callbacks of utterances that were already replaced.
    private func finish(_ utterance: AVSpeechUtterance) {
        guard utterance === active else { return }
        active = nil
        current = nil
    }
}
#endif
