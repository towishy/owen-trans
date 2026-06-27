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
    private var hideWorkItem: DispatchWorkItem?

    init() {
        buildWindow()
    }

    private func buildWindow() {
        let hosting = NSHostingView(rootView: NotchOverlayView(model: model))
        let window = NotchOverlayWindow(contentView: hosting)
        self.window = window
        repositionWindow()
    }

    /// 화면 상단 중앙(노치 영역)에 창을 배치한다.
    func repositionWindow() {
        guard let window, let screen = NSScreen.main else { return }
        let size = NSSize(width: 520, height: 96)
        let visible = screen.frame
        let x = visible.midX - size.width / 2
        // 메뉴바 높이를 고려해 화면 최상단 바로 아래.
        let y = visible.maxY - size.height - 4
        window.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }

    // MARK: - 표시 API

    func show(original: String, translation: String, autoHideAfter seconds: Double? = nil) {
        repositionWindow()
        model.original = original
        model.translation = translation
        window?.orderFrontRegardless()
        scheduleAutoHide(seconds)
    }

    func updateOriginal(_ text: String) {
        model.original = text
        window?.orderFrontRegardless()
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
        self.level = .statusBar
        self.ignoresMouseEvents = true            // 클릭 통과
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.isFloatingPanel = true
        self.hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
