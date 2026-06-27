import AppKit
import SwiftUI

/// 의존성 설치 마법사 창.
@MainActor
final class SetupWindowController: NSWindowController {

    let manager = DependencyManager()

    init(onDone: @escaping () -> Void) {
        let window = NSWindow(contentRect: .zero,
                              styleMask: [.titled, .closable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.title = "OwenTrans 설치 마법사"
        window.isReleasedWhenClosed = false
        super.init(window: window)

        let view = SetupView(manager: manager, onDone: { [weak window] in
            onDone()
            window?.close()
        })
        let hosting = NSHostingController(rootView: view)
        window.contentViewController = hosting
        window.setContentSize(NSSize(width: 520, height: 560))
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
