import AVFoundation

/// 영어 음성 출력(TTS) 공용 헬퍼.
enum TextToSpeech {

    /// 영어 음성 목록(언어·이름 순 정렬).
    static func englishVoices() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
            .sorted { ($0.language + $0.name) < ($1.language + $1.name) }
    }

    /// 음성의 성별 라벨.
    static func genderLabel(_ voice: AVSpeechSynthesisVoice) -> String {
        switch voice.gender {
        case .male:   return "남성"
        case .female: return "여성"
        default:      return "기본"
        }
    }

    /// 사람이 읽기 좋은 표시 이름: "Samantha · 여성 · en-US".
    static func displayName(_ voice: AVSpeechSynthesisVoice) -> String {
        "\(voice.name) · \(genderLabel(voice)) · \(voice.language)"
    }
}

/// 앱 전역에서 공유하는 음성 재생기(미리 듣기·플로팅 입력창 공용).
final class SpeechPlayer {
    static let shared = SpeechPlayer()
    private let synthesizer = AVSpeechSynthesizer()

    private init() {}

    /// 설정값(음성/속도/톤)으로 영어 텍스트를 읽는다.
    func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        stop()

        let settings = AppSettings.shared
        let utterance = AVSpeechUtterance(string: trimmed)
        if let id = settings.ttsVoiceIdentifier, let voice = AVSpeechSynthesisVoice(identifier: id) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        utterance.rate = Float(settings.ttsRate)
        utterance.pitchMultiplier = Float(settings.ttsPitch)
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
}
