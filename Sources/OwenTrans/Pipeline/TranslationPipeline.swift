import Foundation
import AppKit

/// 전체 흐름을 조율한다:
/// 오디오 입력 → Apple Speech(영어 STT) → Gemma/Stub 번역 → 노치 오버레이 표시.
@MainActor
final class TranslationPipeline {

    private(set) var isRunning = false

    private let audio = AudioInputManager()
    private let speech = SpeechRecognizerService()
    private var translator: Translator
    private let overlay: NotchOverlayController
    private let settings = AppSettings.shared

    /// 동일 문장 중복 번역 방지용.
    private var lastTranslatedSource = ""
    /// partial 결과 디바운스 타이머.
    private var debounceTask: Task<Void, Never>?

    var statusText: String {
        if isRunning {
            return speech.isAvailable ? "듣는 중 · \(translator.statusText)" : "음성 인식 불가"
        }
        return "정지됨 · \(translator.statusText)"
    }

    init(overlay: NotchOverlayController) {
        self.overlay = overlay
        self.translator = TranslatorFactory.make()

        audio.onBuffer = { [weak self] buffer, _ in
            self?.speech.append(buffer)
        }
        speech.onTranscript = { [weak self] text, isFinal in
            Task { @MainActor in self?.handleTranscript(text, isFinal: isFinal) }
        }
        speech.onError = { error in
            NSLog("[OwenTrans] STT 오류: \(error.localizedDescription)")
        }
    }

    // MARK: - 제어

    func toggle() {
        isRunning ? stop() : start()
    }

    func start() {
        guard !isRunning else { return }

        SpeechRecognizerService.requestAuthorization { [weak self] granted in
            guard let self else { return }
            guard granted else {
                self.overlay.show(original: "Speech permission denied",
                                  translation: "시스템 설정 > 개인정보 보호 > 음성 인식에서 권한을 허용하세요.")
                return
            }
            Task { @MainActor in
                await self.prepareTranslatorIfNeeded()
                do {
                    self.speech.start()
                    try self.audio.start(deviceUID: self.settings.selectedInputDeviceUID)
                    self.isRunning = true
                    self.overlay.show(original: "Listening…", translation: "듣는 중…")
                } catch {
                    NSLog("[OwenTrans] 오디오 시작 실패: \(error)")
                    self.overlay.show(original: "Audio error", translation: "오디오 입력을 시작할 수 없습니다.")
                }
            }
        }
    }

    func stop() {
        guard isRunning else { return }
        debounceTask?.cancel()
        audio.stop()
        speech.stop()
        isRunning = false
        overlay.hide()
    }

    /// 입력 장치가 바뀌었을 때, 실행 중이면 재시작.
    func reloadInputDeviceIfRunning() {
        guard isRunning else { return }
        stop()
        start()
    }

    /// 모델 변경 시 번역기 재생성.
    func reloadModel() {
        translator = TranslatorFactory.make()
        Task { await prepareTranslatorIfNeeded() }
    }

    private func prepareTranslatorIfNeeded() async {
        do {
            try await translator.prepare()
        } catch {
            NSLog("[OwenTrans] 번역기 준비 실패: \(error)")
        }
    }

    // MARK: - 인식 결과 처리

    private func handleTranscript(_ text: String, isFinal: Bool) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // 원문 즉시 표시(번역은 약간 지연될 수 있으므로).
        overlay.updateOriginal(trimmed)

        // 너무 잦은 번역 호출 방지: 최종 결과거나, 짧은 디바운스 후 번역.
        debounceTask?.cancel()
        let delay: UInt64 = isFinal ? 0 : 600_000_000 // 0.6s
        debounceTask = Task { [weak self] in
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
                if Task.isCancelled { return }
            }
            await self?.translate(trimmed)
        }
    }

    private func translate(_ english: String) async {
        guard english != lastTranslatedSource else { return }
        lastTranslatedSource = english
        do {
            let korean = try await translator.translate(english)
            guard !korean.isEmpty else { return }
            overlay.show(original: settings.showsOriginalText ? english : "",
                         translation: korean,
                         autoHideAfter: settings.overlayAutoHideSeconds)
        } catch {
            NSLog("[OwenTrans] 번역 실패: \(error)")
        }
    }
}
