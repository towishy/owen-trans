import AppKit
import SwiftUI

/// 환경설정 창.
@MainActor
final class PreferencesWindowController: NSWindowController {

    init(pipeline: TranslationPipeline) {
        let view = PreferencesView(pipeline: pipeline)
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "OwenTrans 환경설정"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 460, height: 620))
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
