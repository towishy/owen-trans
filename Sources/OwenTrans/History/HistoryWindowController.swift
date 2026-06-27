import AppKit
import SwiftUI

/// 번역 기록 열람 창.
@MainActor
final class HistoryWindowController: NSWindowController {

    init() {
        let hosting = NSHostingController(rootView: HistoryView())
        let window = NSWindow(contentViewController: hosting)
        window.title = "OwenTrans 번역 기록"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 720, height: 480))
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
