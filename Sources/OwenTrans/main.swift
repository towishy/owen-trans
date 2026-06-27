import AppKit

// OwenTrans 진입점.
// 메뉴바(액세서리) 앱이므로 Dock 아이콘 없이 상단 표시줄에만 위치한다.

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
