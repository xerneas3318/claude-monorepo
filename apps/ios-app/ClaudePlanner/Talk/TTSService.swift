import AVFoundation
import Foundation

@MainActor
final class TTSService: ObservableObject {
    @Published private(set) var isSpeaking: Bool = false

    private let synth = AVSpeechSynthesizer()
    private let delegateBridge = DelegateBridge()

    init() {
        synth.delegate = delegateBridge
        delegateBridge.onStart  = { [weak self] in Task { @MainActor in self?.isSpeaking = true } }
        delegateBridge.onFinish = { [weak self] in Task { @MainActor in self?.isSpeaking = false } }
    }

    func speak(_ text: String) {
        let cleaned = stripMarkdown(text)
        guard !cleaned.isEmpty else { return }
        // Don't let new messages queue up — replace any in-flight utterance.
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true, options: [])
        let utt = AVSpeechUtterance(string: cleaned)
        utt.voice = AVSpeechSynthesisVoice(language: Locale.preferredLanguages.first ?? "en-US")
            ?? AVSpeechSynthesisVoice(language: "en-US")
        utt.rate = AVSpeechUtteranceDefaultSpeechRate
        synth.speak(utt)
    }

    func stop() {
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
    }

    // Strip markdown noise so TTS doesn't read out "asterisk asterisk bold asterisk asterisk".
    private func stripMarkdown(_ s: String) -> String {
        var t = s
        // links: [text](url) -> text
        t = t.replacingOccurrences(of: #"\[([^\]]+)\]\([^)]+\)"#, with: "$1", options: .regularExpression)
        // emphasis markers and inline code
        for marker in ["**", "__", "`"] {
            t = t.replacingOccurrences(of: marker, with: "")
        }
        // leading bullets and headings
        t = t.replacingOccurrences(of: #"^\s*[-*+]\s+"#, with: "", options: [.regularExpression])
        t = t.replacingOccurrences(of: #"^#+\s*"#, with: "", options: [.regularExpression])
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private final class DelegateBridge: NSObject, AVSpeechSynthesizerDelegate {
    var onStart: (() -> Void)?
    var onFinish: (() -> Void)?

    func speechSynthesizer(_ synth: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        onStart?()
    }
    func speechSynthesizer(_ synth: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onFinish?()
    }
    func speechSynthesizer(_ synth: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        onFinish?()
    }
}
