import AppKit
import SwiftUI
import AVFoundation

/// 회의용 플로팅 입력창(한글 → 영어 역번역).
///
/// 노치 오버레이가 ‘듣기(영어→한글)’를 담당한다면, 이 창은 ‘말하기(한글→영어)’를 담당한다.
/// 한글을 입력하면 영어로 번역해 보여주고, 클립보드 복사·음성 출력(TTS)을 제공한다.
/// 창은 마우스로 드래그해 자유롭게 이동할 수 있다.
@MainActor
final class ComposerPanelController {

    private let model = ComposerModel()
    private var panel: ComposerPanel?

    init(translator: Translator) {
        model.translator = translator
        buildPanel()
    }

    private func buildPanel() {
        let hosting = NSHostingView(rootView: ComposerView(model: model, onClose: { [weak self] in
            self?.hide()
        }))
        let panel = ComposerPanel(contentView: hosting)
        // 창 위치·크기를 다음 실행까지 기억한다.
        panel.setFrameAutosaveName("OwenTransComposerPanel")
        self.panel = panel
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    func toggle() { isVisible ? hide() : show() }

    func show() {
        guard let panel else { return }
        if panel.frame.origin == .zero { panel.center() }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        model.stopSpeaking()
        panel?.orderOut(nil)
    }
}

/// 입력창 상태 + 역번역/TTS 로직.
@MainActor
final class ComposerModel: ObservableObject {
    @Published var input: String = ""
    @Published var output: String = ""
    @Published var isTranslating = false
    @Published var statusMessage = ""

    var translator: Translator?

    /// 한글 입력을 영어로 번역.
    func translate() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let translator else { return }
        guard !isTranslating else { return }
        isTranslating = true
        statusMessage = "번역 중…"
        Task { @MainActor in
            defer { isTranslating = false }
            do {
                let english = try await translator.translate(text, direction: .koToEn)
                output = english
                statusMessage = english.isEmpty ? "번역 결과 없음" : ""
            } catch {
                statusMessage = "번역 실패: \(error.localizedDescription)"
            }
        }
    }

    /// 영어 결과를 클립보드에 복사.
    func copyOutput() {
        guard !output.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(output, forType: .string)
        statusMessage = "복사됨"
    }

    /// 영어 결과를 음성으로 출력(TTS).
    func speakOutput() {
        guard !output.isEmpty else { return }
        SpeechPlayer.shared.speak(output)
    }

    func stopSpeaking() {
        SpeechPlayer.shared.stop()
    }
}

/// 드래그로 이동 가능한, 키 입력을 받는 보더리스 패널.
final class ComposerPanel: NSPanel {

    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 240),
            styleMask: [.borderless, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.contentView = contentView
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.level = .floating
        self.isMovableByWindowBackground = true   // 배경 드래그로 이동
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.hidesOnDeactivate = false
        self.isFloatingPanel = true
    }

    // 텍스트 입력을 받으려면 키 윈도우가 될 수 있어야 한다.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
