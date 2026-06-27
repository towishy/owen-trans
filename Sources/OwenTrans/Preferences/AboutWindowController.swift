import AppKit
import SwiftUI

/// 앱 정보 창.
@MainActor
final class AboutWindowController: NSWindowController {

    init() {
        let hosting = NSHostingController(rootView: AboutView())
        let window = NSWindow(contentViewController: hosting)
        window.title = "OwenTrans 정보"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 360, height: 260))
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

private struct AboutView: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "character.bubble")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            Text("OwenTrans")
                .font(.nanum(22, weight: .extraBold))
            Text("실시간 영어 → 한글 음성 번역기")
                .font(.nanum(13))
                .foregroundStyle(.secondary)
            Text("버전 \(version)")
                .font(.nanum(12, weight: .light))
                .foregroundStyle(.secondary)
            Divider().padding(.horizontal, 40)
            Text("로컬 Gemma LLM · Apple Speech · 노치 오버레이")
                .font(.nanum(11, weight: .light))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(width: 360, height: 260)
    }
}
