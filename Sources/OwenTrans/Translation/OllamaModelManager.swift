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

    private func isReachable() async -> Bool {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/version"))
        request.timeoutInterval = 2
        guard let (_, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse else { return false }
        return http.statusCode == 200
    }
}
