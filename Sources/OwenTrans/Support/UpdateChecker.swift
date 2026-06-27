import AppKit

/// GitHub 릴리스를 조회해 새 버전이 있는지 확인한다.
enum UpdateChecker {

    private static let repo = "towishy/owen-trans"

    /// 현재 앱 버전(CFBundleShortVersionString).
    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    /// 최신 릴리스를 확인하고 결과를 알림으로 표시한다.
    /// - userInitiated: 사용자가 직접 눌렀으면 "최신입니다" 알림도 표시.
    @MainActor
    static func check(userInitiated: Bool) {
        Task {
            guard let latest = await fetchLatest() else {
                if userInitiated { showAlert(title: "업데이트 확인 실패",
                                             message: "릴리스 정보를 가져오지 못했습니다. 네트워크를 확인하세요.") }
                return
            }
            let latestVersion = latest.tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            if isNewer(latestVersion, than: currentVersion) {
                showUpdateAlert(version: latestVersion, url: latest.url)
            } else if userInitiated {
                showAlert(title: "최신 버전입니다",
                          message: "현재 \(currentVersion) 이 최신 버전입니다.")
            }
        }
    }

    private static func fetchLatest() async -> (tag: String, url: String)? {
        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else { return nil }
        var req = URLRequest(url: url)
        req.timeoutInterval = 8
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String else {
            return nil
        }
        let htmlURL = json["html_url"] as? String ?? "https://github.com/\(repo)/releases/latest"
        return (tag, htmlURL)
    }

    /// "0.1.10" > "0.1.9" 같은 시맨틱 비교.
    private static func isNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        let n = max(pa.count, pb.count)
        for i in 0..<n {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    @MainActor
    private static func showUpdateAlert(version: String, url: String) {
        let alert = NSAlert()
        alert.messageText = "새 버전 \(version) 이 있습니다"
        alert.informativeText = "현재 버전: \(currentVersion)\n릴리스 페이지에서 내려받으세요."
        alert.addButton(withTitle: "릴리스 열기")
        alert.addButton(withTitle: "나중에")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn, let link = URL(string: url) {
            NSWorkspace.shared.open(link)
        }
    }

    @MainActor
    private static func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "확인")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
