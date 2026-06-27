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

    /// 내용 크기에 맞춰 창 너비를 정하고 화면 최상단 중앙(노치)에 밀착 배치한다.
    /// 폰트는 줄이지 않고, 문장이 길면 박스가 옆으로 늘어난 뒤 줄바꿈한다.
    /// 문장이 짧아도 검정 박스 최소 너비를 노치만큼 확보한다.
    func repositionWindow() {
        guard let window, let hosting, let screen = NSScreen.main else { return }
        // 노치를 덮을 최소 박스 너비를 SwiftUI 쪽에 전달.
        model.minBoxWidth = max(NotchOverlayMetrics.minBoxWidth, notchCoveringWidth(for: screen))
        hosting.layoutSubtreeIfNeeded()
        let fitting = hosting.fittingSize
        let frame = screen.frame
        let maxWidth = min(NotchOverlayMetrics.maxBoxWidth, frame.width - 40)
        let width = min(fitting.width, maxWidth)
        let height = max(fitting.height, 60)
        let x = frame.midX - width / 2
        // 화면 물리적 최상단에 밀착(메뉴바/노치와 연결되는 느낌).
        let y = frame.maxY - height
        window.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }

    /// 노치를 완전히 덮을 만큼의 너비(노치 너비 + 좌우 여유).
    /// 노치가 없는 디스플레이면 0을 반환한다.
    private func notchCoveringWidth(for screen: NSScreen) -> CGFloat {
        guard let left = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea else {
            return 0
        }
        let notchWidth = right.minX - left.maxX
        guard notchWidth > 0 else { return 0 }
        return notchWidth + 96 // 좌우로 48px씩 더 덮어 노치를 확실히 가린다.
    }

    // MARK: - 표시 API

    func show(original: String, translation: String, autoHideAfter seconds: Double? = nil) {
        model.original = original
        model.translation = translation
        window?.orderFrontRegardless()
        // SwiftUI 레이아웃 갱신 후 내용 크기에 맞춰 재배치.
        DispatchQueue.main.async { [weak self] in self?.repositionWindow() }
        scheduleAutoHide(seconds)
    }

    func updateOriginal(_ text: String) {
        model.original = text
        window?.orderFrontRegardless()
        DispatchQueue.main.async { [weak self] in self?.repositionWindow() }
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
    /// 검정 박스의 최소 너비(노치를 덮기 위해 컨트롤러가 설정).
    @Published var minBoxWidth: CGFloat = NotchOverlayMetrics.minBoxWidth
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
