import Foundation
import Combine

/// Ollama 모델 설치 상태 확인 및 다운로드 관리(환경설정 UI 용).
@MainActor
final class OllamaModelManager: ObservableObject {
    static let shared = OllamaModelManager()

    private let baseURL = URL(string: "http://localhost:11434")!
    private let session: URLSession

    /// 설치된 모델 태그 목록.
    @Published private(set) var installedTags: [String] = []
    /// 다운로드 진행 메시지(모델별).
    @Published private(set) var progress: [GemmaModelSize: String] = [:]
    /// 다운로드 진행률 0.0~1.0(진행바용).
    @Published private(set) var progressFraction: [GemmaModelSize: Double] = [:]
    /// 현재 다운로드 중인 모델.
    @Published private(set) var downloading: Set<GemmaModelSize> = []
    /// Ollama 서버 실행 여부.
    @Published private(set) var reachable = false
    /// brew services 서버 제어(시작/중지/재시작) 진행 중.
    @Published private(set) var serviceBusy = false
    /// 마지막 서버 제어 결과 메시지.
    @Published private(set) var serviceMessage: String?

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 7200
        self.session = URLSession(configuration: config)
    }

    /// 설치 목록·서버 상태 갱신.
    func refresh() async {
        reachable = await isReachable()
        guard reachable else { installedTags = []; return }
        let request = URLRequest(url: baseURL.appendingPathComponent("api/tags"))
        if let (data, _) = try? await session.data(for: request),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let models = json["models"] as? [[String: Any]] {
            installedTags = models.compactMap { $0["name"] as? String }
        }
    }

    func isInstalled(_ size: GemmaModelSize) -> Bool {
        installedTags.contains { $0.hasPrefix(size.ollamaTag) }
    }

    /// 모델을 /api/pull 로 다운로드(진행률 표시).
    func download(_ size: GemmaModelSize) async {
        guard !downloading.contains(size) else { return }
        guard await isReachable() else {
            progress[size] = "Ollama 미실행 — 설치 마법사에서 서버를 시작하세요"
            return
        }
        downloading.insert(size)
        progress[size] = "다운로드 준비 중…"
        progressFraction[size] = 0
        defer {
            downloading.remove(size)
            progressFraction[size] = nil
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("api/pull"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["name": size.ollamaTag, "stream": true]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (bytes, _) = try await session.bytes(for: request)
            for try await line in bytes.lines {
                guard !line.isEmpty, let data = line.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    continue
                }
                if let error = json["error"] as? String {
                    progress[size] = "오류: \(error)"
                    return
                }
                let status = json["status"] as? String ?? ""
                if let total = json["total"] as? Double, let completed = json["completed"] as? Double, total > 0 {
                    let fraction = completed / total
                    progressFraction[size] = fraction
                    let gb = total / 1_000_000_000
                    progress[size] = String(format: "%d%% (%.1fGB)", Int(fraction * 100), gb)
                } else if !status.isEmpty {
                    progress[size] = status
                }
                if status == "success" {
                    progress[size] = nil
                    await refresh()
                    return
                }
            }
            progress[size] = nil
            await refresh()
        } catch {
            progress[size] = "다운로드 실패: \(error.localizedDescription)"
        }
    }

    // MARK: - 서버 제어 (brew services)

    /// Ollama 서버 시작(brew services start ollama).
    func startService() async { await controlService("start", expectRunning: true) }
    /// Ollama 서버 중지(brew services stop ollama).
    func stopService() async { await controlService("stop", expectRunning: false) }
    /// Ollama 서버 재시작(brew services restart ollama).
    func restartService() async { await controlService("restart", expectRunning: true) }

    /// `brew services <action> ollama` 을 실행하고 상태를 갱신한다.
    private func controlService(_ action: String, expectRunning: Bool) async {
        guard !serviceBusy else { return }
        serviceBusy = true
        serviceMessage = nil
        defer { serviceBusy = false }

        let (code, output) = await runShell("brew services \(action) ollama")
        if code != 0 {
            let detail = output.isEmpty ? "brew services \(action) ollama (코드 \(code))" : output
            serviceMessage = "실패: \(detail)"
            await refresh()
            return
        }

        // 상태 반영 대기(기동 또는 종료까지 최대 ~10초).
        for _ in 0..<20 {
            if await isReachable() == expectRunning { break }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        await refresh()
        if expectRunning {
            serviceMessage = reachable ? "Ollama 서버 실행 중" : "서버가 시작되지 않았습니다 — Homebrew·Ollama 설치를 확인하세요."
        } else {
            serviceMessage = reachable ? "서버가 아직 응답합니다 — 잠시 후 다시 확인하세요." : "Ollama 서버 중지됨"
        }
    }

    /// 로그인 셸(-l)로 명령을 실행해 brew PATH를 확보한다. (종료코드, 출력) 반환.
    private func runShell(_ command: String) async -> (Int32, String) {
        await withCheckedContinuation { (continuation: CheckedContinuation<(Int32, String), Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-lc", command]
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe
                do {
                    try process.run()
                    // 파이프 deadlock 방지: EOF까지 읽은 뒤 종료 대기.
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    let text = String(data: data, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    continuation.resume(returning: (process.terminationStatus, text))
                } catch {
                    continuation.resume(returning: (-1, error.localizedDescription))
                }
            }
        }
    }

    private func isReachable() async -> Bool {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/version"))
        request.timeoutInterval = 2
        guard let (_, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse else { return false }
        return http.statusCode == 200
    }
}
