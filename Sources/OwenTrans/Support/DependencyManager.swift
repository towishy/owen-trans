import Foundation
import Combine
import AppKit

/// Ollama·Gemma 모델·가상 오디오 장치 등 외부 의존성을 점검하고,
/// 가능한 항목은 자동으로 설치·구성한다.
///
/// 완전 무인 설치가 불가능한 부분(Homebrew 최초 설치의 관리자 암호,
/// BlackHole 시스템 확장 승인)은 명령을 실행하되 사용자 승인이 필요함을 안내한다.
@MainActor
final class DependencyManager: ObservableObject {

    enum State: Equatable {
        case unknown
        case checking
        case satisfied
        case missing
        case working
        case failed(String)
    }

    /// 점검·설치 대상 항목.
    enum Item: String, CaseIterable, Identifiable {
        case homebrew
        case ollama
        case ollamaServe
        case gemmaModel
        case virtualAudio

        var id: String { rawValue }

        var title: String {
            switch self {
            case .homebrew:     return "Homebrew"
            case .ollama:       return "Ollama"
            case .ollamaServe:  return "Ollama 서버 실행"
            case .gemmaModel:   return "Gemma 모델"
            case .virtualAudio: return "시스템 오디오 캡처 장치"
            }
        }

        var detail: String {
            switch self {
            case .homebrew:     return "패키지 관리자 (Ollama·BlackHole 설치에 사용)"
            case .ollama:       return "로컬 LLM 실행 데몬"
            case .ollamaServe:  return "localhost:11434 번역 서버"
            case .gemmaModel:   return "영어→한글 번역 모델"
            case .virtualAudio: return "브라우저·YouTube 소리 캡처 (BlackHole, 선택)"
            }
        }

        /// 필수 항목인지(가상 오디오는 선택).
        var isRequired: Bool { self != .virtualAudio }
    }

    @Published private(set) var states: [Item: State] = [:]
    @Published private(set) var log: String = ""
    @Published private(set) var isBusy = false

    private let host = "http://127.0.0.1:11434"
    private let modelTag = AppSettings.shared.modelSize.ollamaTag

    /// 모든 필수 항목이 충족됐는지.
    var allRequiredSatisfied: Bool {
        Item.allCases.filter(\.isRequired).allSatisfy { states[$0] == .satisfied }
    }

    // MARK: - 점검

    func checkAll() async {
        for item in Item.allCases { states[item] = .checking }
        await refresh(.homebrew)
        await refresh(.ollama)
        await refresh(.ollamaServe)
        await refresh(.gemmaModel)
        await refresh(.virtualAudio)
    }

    private func refresh(_ item: Item) async {
        switch item {
        case .homebrew:
            states[item] = brewPath() != nil ? .satisfied : .missing
        case .ollama:
            states[item] = which("ollama") != nil ? .satisfied : .missing
        case .ollamaServe:
            states[item] = await isServeRunning() ? .satisfied : .missing
        case .gemmaModel:
            states[item] = await isModelInstalled() ? .satisfied : .missing
        case .virtualAudio:
            states[item] = AudioInputManager.hasVirtualLoopbackDevice() ? .satisfied : .missing
        }
    }

    // MARK: - 자동 설치/구성

    /// 부족한 모든 항목을 순서대로 자동 설치·구성한다.
    func setupAll() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }

        if states[.homebrew] != .satisfied { await install(.homebrew) }
        if states[.ollama] != .satisfied { await install(.ollama) }
        if states[.ollamaServe] != .satisfied { await install(.ollamaServe) }
        if states[.gemmaModel] != .satisfied { await install(.gemmaModel) }
        if states[.virtualAudio] != .satisfied { await install(.virtualAudio) }
    }

    /// 단일 항목 설치·구성.
    func install(_ item: Item) async {
        states[item] = .working
        switch item {
        case .homebrew:
            appendLog("Homebrew는 보안상 자동 설치가 제한됩니다. 터미널에서 아래를 실행하세요:")
            appendLog("  /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"")
            await refresh(.homebrew)
            if states[.homebrew] != .satisfied { states[.homebrew] = .failed("수동 설치 필요") }

        case .ollama:
            await run("brew install ollama", label: "Ollama 설치")
            await refresh(.ollama)

        case .ollamaServe:
            // 데몬을 백그라운드 서비스로 시작.
            await run("brew services start ollama", label: "Ollama 서버 시작")
            // 기동 대기(최대 ~10초).
            for _ in 0..<20 {
                if await isServeRunning() { break }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            await refresh(.ollamaServe)

        case .gemmaModel:
            appendLog("모델 다운로드는 수 분 걸릴 수 있습니다: \(modelTag)")
            await run("ollama pull \(modelTag)", label: "Gemma 모델 다운로드")
            await refresh(.gemmaModel)

        case .virtualAudio:
            appendLog("BlackHole은 CoreAudio 오디오 드라이버(HAL 플러그인)입니다.")
            appendLog("‘시스템 확장’ 목록에는 나오지 않으며, 설치되면 곧바로 오디오 장치로 표시됩니다.")
            appendLog("설치에는 관리자 권한(sudo)이 필요해 터미널에서 진행합니다 — 암호를 입력하세요.")
            // cask 설치는 sudo 가 필요하므로 대화형 터미널에서 실행.
            // 설치 후 자동으로 coreaudiod 를 재시작해 즉시 장치로 인식되게 한다.
            runInTerminal("brew install blackhole-2ch && sudo killall coreaudiod")
            appendLog("터미널 설치가 끝나면 ‘다시 점검’을 누르세요.")
            appendLog("그다음 Audio MIDI 설정에서 ‘다중 출력 장치’(스피커+BlackHole)를 만들어 시스템 출력으로 지정하세요.")
            // 다음 단계인 Audio MIDI 설정을 함께 연다.
            openAudioMIDISetup()
            await refresh(.virtualAudio)
        }
    }

    // MARK: - 점검 헬퍼

    private func isServeRunning() async -> Bool {
        await httpOK("\(host)/api/version")
    }

    private func isModelInstalled() async -> Bool {
        guard let data = await httpData("\(host)/api/tags"),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["models"] as? [[String: Any]] else {
            return false
        }
        let names = models.compactMap { $0["name"] as? String }
        let base = modelTag.split(separator: ":").first.map(String.init) ?? modelTag
        return names.contains { $0 == modelTag || $0.hasPrefix(base) }
    }

    private func httpOK(_ urlString: String) async -> Bool {
        guard let url = URL(string: urlString) else { return false }
        var req = URLRequest(url: url)
        req.timeoutInterval = 2
        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse else { return false }
        return (200..<300).contains(http.statusCode)
    }

    private func httpData(_ urlString: String) async -> Data? {
        guard let url = URL(string: urlString) else { return nil }
        var req = URLRequest(url: url)
        req.timeoutInterval = 3
        return try? await URLSession.shared.data(for: req).0
    }

    // MARK: - 셸 실행

    /// Homebrew 등 PATH 보강을 위해 로그인 셸로 명령을 실행하고 출력을 로그에 스트리밍한다.
    private func run(_ command: String, label: String) async {
        appendLog("$ \(command)")
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                // 로그인 셸(-l)로 brew PATH(/opt/homebrew/bin 등)를 확보.
                process.arguments = ["-lc", command]
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe
                pipe.fileHandleForReading.readabilityHandler = { handle in
                    let chunk = handle.availableData
                    guard !chunk.isEmpty, let text = String(data: chunk, encoding: .utf8) else { return }
                    Task { @MainActor in self.appendLog(text, raw: true) }
                }
                do {
                    try process.run()
                    process.waitUntilExit()
                    let code = process.terminationStatus
                    Task { @MainActor in
                        self.appendLog(code == 0 ? "✓ \(label) 완료" : "✗ \(label) 실패 (코드 \(code))")
                        continuation.resume()
                    }
                } catch {
                    Task { @MainActor in
                        self.appendLog("✗ \(label) 실행 오류: \(error.localizedDescription)")
                        continuation.resume()
                    }
                }
            }
        }
    }

    /// Audio MIDI 설정을 연다(다중 출력 장치 구성 안내).
    private func openAudioMIDISetup() {
        let url = URL(fileURLWithPath: "/System/Applications/Utilities/Audio MIDI Setup.app")
        if NSWorkspace.shared.open(url) {
            appendLog("‘Audio MIDI 설정’을 열었습니다. ‘+’ → 다중 출력 장치로 스피커+BlackHole 을 묶으세요.")
        }
    }

    /// 관리자 암호가 필요한 명령을 Terminal.app 에서 대화형으로 실행한다.
    private func runInTerminal(_ command: String) {
        let escaped = command.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = "tell application \"Terminal\"\nactivate\ndo script \"\(escaped)\"\nend tell"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try? process.run()
    }

    private func brewPath() -> String? {
        for path in ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"] where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        return which("brew")
    }

    private func which(_ tool: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", "command -v \(tool)"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (path?.isEmpty == false) ? path : nil
    }

    @MainActor
    private func appendLog(_ text: String, raw: Bool = false) {
        if raw {
            log += text
        } else {
            log += text + "\n"
        }
        // 로그가 과도하게 길어지면 앞부분을 잘라낸다.
        if log.count > 20_000 {
            log = String(log.suffix(16_000))
        }
    }
}
