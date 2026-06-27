import AppKit

/// 상단 메뉴바(NSStatusItem)에 아이콘을 표시하고,
/// 클릭하면 번역 시작/중지 · 입력 장치 · 모델 선택 · 환경설정 · 앱 정보 · 종료 메뉴를 노출한다.
///
/// 모든 메뉴 글씨는 나눔스퀘어(FontProvider)로 표시한다.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {

    private let statusItem: NSStatusItem
    private let pipeline: TranslationPipeline
    private let onOpenPreferences: () -> Void
    private let onOpenAbout: () -> Void
    private let onQuit: () -> Void

    private let settings = AppSettings.shared

    init(pipeline: TranslationPipeline,
         onOpenPreferences: @escaping () -> Void,
         onOpenAbout: @escaping () -> Void,
         onQuit: @escaping () -> Void) {
        self.pipeline = pipeline
        self.onOpenPreferences = onOpenPreferences
        self.onOpenAbout = onOpenAbout
        self.onQuit = onQuit
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        configureButton()
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        let image = NSImage(systemSymbolName: "character.bubble",
                            accessibilityDescription: "OwenTrans")
        image?.isTemplate = true
        button.image = image
        button.toolTip = "OwenTrans — 실시간 영어→한글 번역"
    }

    // 메뉴를 열 때마다 현재 상태로 다시 구성한다.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        // 번역 시작/중지
        let toggle = NSMenuItem(title: "", action: #selector(toggleTranslation), keyEquivalent: "")
        toggle.target = self
        toggle.applyNanumTitle(pipeline.isRunning ? "번역 중지" : "번역 시작", weight: .bold)
        menu.addItem(toggle)

        // 상태 표시(읽기 전용)
        let status = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        status.isEnabled = false
        status.applyNanumTitle("상태: \(pipeline.statusText)", weight: .light)
        menu.addItem(status)

        menu.addItem(.separator())

        // 입력 장치 서브메뉴
        let deviceItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        deviceItem.applyNanumTitle("입력 장치")
        deviceItem.submenu = makeInputDeviceMenu()
        menu.addItem(deviceItem)

        // 모델 서브메뉴
        let modelItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        modelItem.applyNanumTitle("번역 모델")
        modelItem.submenu = makeModelMenu()
        menu.addItem(modelItem)

        menu.addItem(.separator())

        // 환경설정
        let prefs = NSMenuItem(title: "", action: #selector(openPreferences), keyEquivalent: ",")
        prefs.target = self
        prefs.applyNanumTitle("환경설정…")
        menu.addItem(prefs)

        // 앱 정보
        let about = NSMenuItem(title: "", action: #selector(openAbout), keyEquivalent: "")
        about.target = self
        about.applyNanumTitle("OwenTrans 정보")
        menu.addItem(about)

        menu.addItem(.separator())

        // 종료
        let quit = NSMenuItem(title: "", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        quit.applyNanumTitle("OwenTrans 종료")
        menu.addItem(quit)
    }

    private func makeInputDeviceMenu() -> NSMenu {
        let submenu = NSMenu()

        let systemDefault = NSMenuItem(title: "", action: #selector(selectDefaultDevice), keyEquivalent: "")
        systemDefault.target = self
        systemDefault.applyNanumTitle("시스템 기본 입력")
        systemDefault.state = (settings.selectedInputDeviceUID == nil) ? .on : .off
        submenu.addItem(systemDefault)

        let devices = AudioInputManager.availableInputDevices()
        if !devices.isEmpty { submenu.addItem(.separator()) }

        for device in devices {
            let item = NSMenuItem(title: "", action: #selector(selectDevice(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = device.uid
            item.applyNanumTitle(device.name)
            item.state = (settings.selectedInputDeviceUID == device.uid) ? .on : .off
            submenu.addItem(item)
        }
        return submenu
    }

    private func makeModelMenu() -> NSMenu {
        let submenu = NSMenu()
        for size in GemmaModelSize.allCases {
            let item = NSMenuItem(title: "", action: #selector(selectModel(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = size.rawValue
            item.applyNanumTitle(size.displayName)
            item.state = (settings.modelSize == size) ? .on : .off
            submenu.addItem(item)
        }
        return submenu
    }

    // MARK: - Actions

    @objc private func toggleTranslation() {
        pipeline.toggle()
    }

    @objc private func selectDefaultDevice() {
        settings.selectedInputDeviceUID = nil
        pipeline.reloadInputDeviceIfRunning()
    }

    @objc private func selectDevice(_ sender: NSMenuItem) {
        settings.selectedInputDeviceUID = sender.representedObject as? String
        pipeline.reloadInputDeviceIfRunning()
    }

    @objc private func selectModel(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let size = GemmaModelSize(rawValue: raw) else { return }
        settings.modelSize = size
        pipeline.reloadModel()
    }

    @objc private func openPreferences() { onOpenPreferences() }
    @objc private func openAbout() { onOpenAbout() }
    @objc private func quit() { onQuit() }
}
