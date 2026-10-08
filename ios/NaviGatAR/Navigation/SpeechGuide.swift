import AVFoundation
import UIKit

/// Spoken turn-by-turn guidance. When VoiceOver is running the text is sent
/// as a VoiceOver announcement instead, so the two voices don't overlap.
final class SpeechGuide {
    var enabled = true
    private let synthesizer = AVSpeechSynthesizer()
    private var sessionActive = false

    func say(_ text: String) {
        guard enabled, !text.isEmpty else { return }
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .announcement, argument: text)
            return
        }
        activateAudioSession()
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .word) }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        if sessionActive {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            sessionActive = false
        }
    }

    private func activateAudioSession() {
        guard !sessionActive else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
        try? session.setActive(true)
        sessionActive = true
    }
}
