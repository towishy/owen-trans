import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItemController: StatusItemController!
    private var overlay: NotchOverlayController!
    private var pipeline: TranslationPipeline!
    private var composer: ComposerPanelController!
    private var preferencesWindow: PreferencesWindowController?
    private var aboutWindow: AboutWindowController?
    private var setupWindow: SetupWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 나눔스퀘어 동봉 폰트 등록.
        FontProvider.registerBundledFonts()

        // 노치 오버레이.
        overlay = NotchOverlayController()

        // 번역 파이프라인(오디오 → STT → Gemma → 오버레이).
        pipeline = TranslationPipeline(overlay: overlay)

        // 회의용 플로팅 입력창(한글 → 영어 + 복사/음성).
        composer = ComposerPanelController(translator: TranslatorFactory.make())

        // 메뉴바 상태 항목.
        statusItemController = StatusItemController(
            pipeline: pipeline,
            onOpenPreferences: { [weak self] in self?.openPreferences() },
            onToggleComposer: { [weak self] in self?.composer.toggle() },
            onOpenSetup: { [weak self] in self?.openSetup(auto: false) },
            onOpenAbout: { [weak self] in self?.openAbout() },
            onQuit: { NSApp.terminate(nil) }
        )

        // 실행 시 의존성 점검 — 필수 항목이 부족하면 설치 마법사 자동 표시.
        Task { await self.checkDependenciesOnLaunch() }
    }

    private func checkDependenciesOnLaunch() async {
        let key = "hasShownSetupWizard"
        let firstRun = !UserDefaults.standard.bool(forKey: key)
        let manager = DependencyManager()
        await manager.checkAll()
        // 첫 실행 때는 항상, 이후에는 필수 항목이 부족할 때만 마법사를 띄운다.
        if firstRun || !manager.allRequiredSatisfied {
            UserDefaults.standard.set(true, forKey: key)
            openSetup(auto: true)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        pipeline?.stop()
    }

    private func openPreferences() {
        if preferencesWindow == nil {
            preferencesWindow = PreferencesWindowController(pipeline: pipeline)
        }
        NSApp.activate(ignoringOtherApps: true)
        preferencesWindow?.showWindow(nil)
        preferencesWindow?.window?.makeKeyAndOrderFront(nil)
    }

    private func openSetup(auto: Bool = false) {
        if setupWindow == nil {
            setupWindow = SetupWindowController(onDone: { [weak self] in
                self?.setupWindow = nil
            })
        }
        NSApp.activate(ignoringOtherApps: true)
        setupWindow?.showWindow(nil)
        setupWindow?.window?.makeKeyAndOrderFront(nil)
    }

    private func openAbout() {
        if aboutWindow == nil {
            aboutWindow = AboutWindowController()
        }
        NSApp.activate(ignoringOtherApps: true)
        aboutWindow?.showWindow(nil)
        aboutWindow?.window?.makeKeyAndOrderFront(nil)
    }
}
