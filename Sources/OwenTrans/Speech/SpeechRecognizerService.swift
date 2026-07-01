import Foundation
import Speech
import AVFoundation

/// Apple Speech 프레임워크 기반 영어(en-US) 실시간 음성 인식.
///
/// 의존성·다운로드 없이 OS 내장 엔진을 사용한다(가능하면 on-device).
/// 더 높은 정확도가 필요하면 동일한 인터페이스로 WhisperKit 구현으로 교체할 수 있다.
final class SpeechRecognizerService {

    /// 부분(partial) 또는 최종(final) 영어 인식 결과.
    var onTranscript: ((_ text: String, _ isFinal: Bool) -> Void)?
    var onError: ((Error) -> Void)?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    /// 현재 세션이 온디바이스 인식을 사용 중인지.
    private var usingOnDevice = false
    /// 온디바이스 인식 실패로 서버 인식에 폴백했는지(1회, 인스턴스 수명 동안 유지).
    private var didFallbackToServer = false

    /// 음성 인식 권한 요청.
    static func requestAuthorization(_ completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                completion(status == .authorized)
            }
        }
    }

    var isAvailable: Bool {
        recognizer?.isAvailable ?? false
    }

    func start() {
        stop()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // 가능한 기기에서는 온디바이스 인식 우선(프라이버시·지연시간).
        // 단, 온디바이스가 실패해 서버로 폴백한 뒤에는 다시 서버 인식을 사용한다.
        let onDevice = !didFallbackToServer && (recognizer?.supportsOnDeviceRecognition == true)
        request.requiresOnDeviceRecognition = onDevice
        usingOnDevice = onDevice
        self.request = request

        task = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let text = result.bestTranscription.formattedString
                self.onTranscript?(text, result.isFinal)
            }
            if let error {
                // 온디바이스 인식이 실패하면 1회에 한해 서버 인식으로 재시작한다.
                if self.usingOnDevice && !self.didFallbackToServer {
                    self.didFallbackToServer = true
                    NSLog("[OwenTrans] 온디바이스 인식 실패 → 서버 인식으로 폴백: \(error.localizedDescription)")
                    DispatchQueue.main.async { [weak self] in self?.start() }
                    return
                }
                self.onError?(error)
            }
        }
    }

    /// 오디오 버퍼 주입(AudioInputManager 콜백에서 호출).
    func append(_ buffer: AVAudioPCMBuffer) {
        request?.append(buffer)
    }

    func stop() {
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
    }
}
