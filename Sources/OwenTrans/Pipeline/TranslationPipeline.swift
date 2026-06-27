import Foundation
import AppKit

/// 전체 흐름을 조율한다:
/// 오디오 입력 → Apple Speech(영어 STT) → Gemma/Stub 번역 → 노치 오버레이 표시.
@MainActor
final class TranslationPipeline {

    /// 세션이 시작되어 있는지(종료 전).
    private(set) var isRunning = false {
        didSet { onStateChange?() }
    }
    /// 일시정지 상태인지.
    private(set) var isPaused = false {
        didSet { onStateChange?() }
    }

    /// 실행/일시정지 상태가 바뀔 때 호출(메뉴바 아이콘 갱신 등).
    var onStateChange: (() -> Void)?

    private let audio = AudioInputManager()
    private let speech = SpeechRecognizerService()
    private var translator: Translator
    private let overlay: NotchOverlayController
    private let logger = TranscriptLogger()
    private let settings = AppSettings.shared

    /// 동일 문장 중복 번역 방지용.
    private var lastTranslatedSource = ""
    /// 가장 최근 인식 텍스트(번역 대기열).
    private var latestTranscript = ""
    /// 현재 번역 네트워크 호출이 진행 중인지.
    private var isTranslating = false
    /// partial 결과 디바운스 타이머(대기만 취소, 네트워크 호출은 취소하지 않음).
    private var debounceTask: Task<Void, Never>?
    /// 문맥 유지 번역용 직전 원문(영어) 히스토리.
    private var contextHistory: [String] = []

    var statusText: String {
        if isRunning {
            if isPaused { return "일시정지됨 · \(translator.statusText)" }
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
        speech.onError = { [weak self] error in
            NSLog("[OwenTrans] STT 오류: \(error.localizedDescription)")
            Task { @MainActor in
                guard let self, self.isRunning, !self.isPaused else { return }
                let message = Self.friendlyMessage(for: error)
                self.overlay.show(original: "STT error", translation: message)
            }
        }
    }

    /// STT 오류를 사용자가 조치할 수 있는 한국어 안내로 변환.
    private static func friendlyMessage(for error: Error) -> String {
        let text = error.localizedDescription.lowercased()
        if text.contains("dictation") || text.contains("siri") {
            return "받아쓰기를 켜주세요: 시스템 설정 > 키보드 > 받아쓰기 ON (영어 포함)"
        }
        if text.contains("no speech") {
            return "음성이 감지되지 않았습니다. 마이크 입력을 확인하세요."
        }
        return "인식 오류: \(error.localizedDescription)"
    }

    // MARK: - 제어

    func toggle() {
        isRunning ? stop() : start()
    }

    /// 일시정지/재개 토글.
    func togglePause() {
        guard isRunning else { return }
        isPaused ? resume() : pause()
    }

    func start() {
        guard !isRunning else { return }

        // 번역 시작을 누른 즉시 노치를 덮는 박스를 띄운다(권한/모델 준비 동안에도 표시).
        overlay.show(original: "", translation: "듣는 중…")

        SpeechRecognizerService.requestAuthorization { [weak self] granted in
            guard let self else { return }
            guard granted else {
                self.overlay.show(original: "Speech permission denied",
                                  translation: "시스템 설정 > 개인정보 보호 > 음성 인식에서 권한을 허용하세요.")
                return
            }
            // 마이크 권한도 명시적으로 요청(미요청 시 무음 입력 → 인식 0건).
            AudioInputManager.requestMicrophoneAccess { [weak self] micGranted in
                guard let self else { return }
                guard micGranted else {
                    self.overlay.show(original: "Microphone denied",
                                      translation: "시스템 설정 > 개인정보 보호 > 마이크에서 권한을 허용하세요.")
                    return
                }
                Task { @MainActor in
                    await self.prepareTranslatorIfNeeded()

                    // Markdown 기록 세션 시작.
                    if self.settings.autoSaveMarkdown {
                        self.logger.startSession(folder: self.settings.resolvedSaveFolderURL,
                                                 modelName: self.settings.modelSize.displayName)
                    }

                    do {
                        self.speech.start()
                        try self.audio.start(deviceUID: self.settings.selectedInputDeviceUID)
                        self.isRunning = true
                        self.isPaused = false
                        self.overlay.show(original: "Listening…", translation: "듣는 중…")
                    } catch {
                        NSLog("[OwenTrans] 오디오 시작 실패: \(error)")
                        self.overlay.show(original: "Audio error", translation: "오디오 입력을 시작할 수 없습니다.")
                    }
                }
            }
        }
    }

    /// 일시정지: 입력/인식을 멈추되 세션과 기록은 유지한다.
    func pause() {
        guard isRunning, !isPaused else { return }
        debounceTask?.cancel()
        audio.stop()
        speech.stop()
        isPaused = true
        overlay.show(original: "", translation: "⏸ 일시정지")
    }

    /// 재개: 입력/인식을 다시 시작한다.
    func resume() {
        guard isRunning, isPaused else { return }
        speech.start()
        do {
            try audio.start(deviceUID: settings.selectedInputDeviceUID)
            isPaused = false
            overlay.show(original: "Listening…", translation: "듣는 중…")
        } catch {
            NSLog("[OwenTrans] 재개 실패: \(error)")
            overlay.show(original: "Audio error", translation: "오디오 입력을 재개할 수 없습니다.")
        }
    }

    /// 번역 종료: 세션을 끝내고 기록 파일을 마무리한다.
    func stop() {
        guard isRunning else { return }
        debounceTask?.cancel()
        audio.stop()
        speech.stop()
        isRunning = false
        isPaused = false
        lastTranslatedSource = ""
        latestTranscript = ""
        contextHistory.removeAll()
        logger.endSession()
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
            // 첫 번역 콜드스타트 지연 제거를 위해 모델을 미리 메모리에 올린다.
            await translator.warmUp()
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
        latestTranscript = trimmed

        // 디바운스: 대기 구간만 취소 가능. 대기가 끝나면 번역을 "시작"만 한다.
        // 실제 네트워크 호출은 별도의 취소되지 않는 Task 에서 실행한다.
        debounceTask?.cancel()
        let delay: UInt64 = isFinal ? 0 : 600_000_000 // 0.6s
        debounceTask = Task { [weak self] in
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
                if Task.isCancelled { return }
            }
            await MainActor.run { self?.startTranslationIfIdle() }
        }
    }

    /// 진행 중인 번역이 없을 때만 최신 텍스트 번역을 시작한다.
    /// 번역 중 새 텍스트가 들어오면 완료 후 자동으로 한 번 더 처리한다.
    private func startTranslationIfIdle() {
        guard isRunning, !isPaused, !isTranslating else { return }
        let text = latestTranscript
        guard !text.isEmpty, text != lastTranslatedSource else { return }

        isTranslating = true
        lastTranslatedSource = text

        // 디바운스 Task 와 무관한 독립 Task — 새 partial 이 와도 취소되지 않는다.
        Task { @MainActor in
            defer {
                self.isTranslating = false
                // 번역 도중 더 최신 텍스트가 도착했다면 이어서 처리.
                if self.latestTranscript != text {
                    self.startTranslationIfIdle()
                }
            }
            do {
                let contextArg = settings.useContextTranslation ? contextHistory : []
                let korean = try await self.translator.translateStream(text, direction: .enToKo, context: contextArg) { partial in
                    // 단어 단위로 노치 오버레이를 실시간 갱신(지연 체감 ↓). 반드시 메인에서.
                    guard !partial.isEmpty else { return }
                    Task { @MainActor in
                        guard self.isRunning, !self.isPaused else { return }
                        self.overlay.show(original: self.settings.showsOriginalText ? text : "",
                                          translation: partial,
                                          autoHideAfter: nil)
                    }
                }
                guard !korean.isEmpty else { return }
                // 최종 결과로 자동 숨김 타이머를 시작하고 기록을 저장한다.
                self.overlay.show(original: self.settings.showsOriginalText ? text : "",
                                  translation: korean,
                                  autoHideAfter: self.settings.overlayAutoHideSeconds)
                // 문맥 히스토리 갱신(최근 3개 유지).
                self.contextHistory.append(text)
                if self.contextHistory.count > 3 {
                    self.contextHistory.removeFirst(self.contextHistory.count - 3)
                }
                if self.settings.autoSaveMarkdown {
                    self.logger.append(original: text, korean: korean)
                }
            } catch {
                NSLog("[OwenTrans] 번역 실패: \(error)")
            }
        }
    }
}
