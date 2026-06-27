import AppKit
import SwiftUI
import Combine

/// 노치(Dynamic Island 유사) 오버레이를 관리하는 컨트롤러.
///
/// 메뉴바 바로 아래, 화면 상단 중앙(노치 위치)에 떠 있는 캡슐 창에
/// 영어 원문과 한글 번역을 실시간으로 표시한다.
@MainActor
final class NotchOverlayController {

    private let model = OverlayModel()
    private var window: NotchOverlayWindow?
    private var hosting: NSHostingView<NotchOverlayView>?
    private var hideWorkItem: DispatchWorkItem?
    private let settings = AppSettings.shared

    init() {
        buildWindow()
    }

    private func buildWindow() {
        let hosting = NSHostingView(rootView: NotchOverlayView(model: model))
        self.hosting = hosting
        let window = NotchOverlayWindow(contentView: hosting)
        self.window = window
        repositionWindow()
    }

    /// 환경설정에서 지정한 고정 가로 폭으로 창을 배치한다.
    /// 가로는 고정(동적 리사이즈 없음), 세로 높이만 내용(최대 3줄)에 맞춰 변한다.
    func repositionWindow() {
        guard let window, let hosting, let screen = NSScreen.main else { return }
        let frame = screen.frame
        // 고정 가로 폭(화면 폭을 넘지 않게 클램프).
        let width = min(max(CGFloat(settings.notchWidth), NotchOverlayMetrics.minWidth), frame.width - 24)
        model.boxWidth = width
        hosting.layoutSubtreeIfNeeded()
        let fitting = hosting.fittingSize
        let height = max(fitting.height, 60)
        let x = frame.midX - width / 2
        // 화면 물리적 최상단에 밀착(메뉴바/노치와 연결되는 느낌).
        let y = frame.maxY - height
        window.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }

    // MARK: - 표시 API

    func show(original: String, translation: String, autoHideAfter seconds: Double? = nil) {
        model.original = original
        model.translation = translation
        window?.orderFrontRegardless()
        // SwiftUI 레이아웃 갱신 후 높이만 재배치.
        DispatchQueue.main.async { [weak self] in self?.repositionWindow() }
        scheduleAutoHide(seconds)
    }

    func updateOriginal(_ text: String) {
        model.original = text
        window?.orderFrontRegardless()
        DispatchQueue.main.async { [weak self] in self?.repositionWindow() }
    }

    /// 환경설정에서 가로 폭 조절 시 실제 노치를 미리보기로 표시한다.
    func previewWidth() {
        let sampleOriginal = "Preview of the notch overlay width and wrapping."
        let sampleTranslation = "노치 오버레이 가로 폭 미리보기입니다. 이 길이로 줄바꿈과 박스 크기를 확인하세요. 세로는 최대 3줄까지 표시됩니다."
        show(original: settings.showsOriginalText ? sampleOriginal : "",
             translation: sampleTranslation,
             autoHideAfter: 2.5)
    }

    func hide() {
        hideWorkItem?.cancel()
        window?.orderOut(nil)
    }

    private func scheduleAutoHide(_ seconds: Double?) {
        hideWorkItem?.cancel()
        guard let seconds, seconds > 0 else { return }
        let item = DispatchWorkItem { [weak self] in self?.window?.orderOut(nil) }
        hideWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
    }
}

/// 오버레이 표시 데이터.
final class OverlayModel: ObservableObject {
    @Published var original: String = ""
    @Published var translation: String = ""
    /// 검정 박스의 고정 가로 폭(환경설정에서 지정).
    @Published var boxWidth: CGFloat = 480
}

/// 클릭을 통과시키고, 모든 창 위에 떠 있는 보더리스 패널.
final class NotchOverlayWindow: NSPanel {

    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 96),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.contentView = contentView
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.ignoresMouseEvents = true            // 클릭 통과
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.isFloatingPanel = true
        self.hidesOnDeactivate = false
        // ⚠️ 레벨은 반드시 isFloatingPanel 설정 "뒤"에 지정한다.
        //    isFloatingPanel=true 가 레벨을 .floating(3)으로 되돌리기 때문.
        //    시스템 메뉴바(레벨 24)보다 높게 띄워 메뉴바 위를 덮으며 확장된 것처럼 보이게 한다.
        self.level = .popUpMenu
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
