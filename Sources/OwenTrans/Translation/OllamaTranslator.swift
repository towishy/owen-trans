import Foundation

/// Ollama 로컬 서버를 통한 Gemma 영어→한글 번역기.
///
/// 전체 Xcode(MLX) 없이도 **실제 Gemma 로컬 번역**을 사용할 수 있는 경로다.
/// - 로컬 데몬: `http://localhost:11434` (ollama serve)
/// - 모델: `gemma4:e2b` / `gemma4:e4b` / `gemma4:12b`
///
/// 데몬이 없거나 모델이 없으면 사용자에게 안내 메시지를 반환한다.
final class OllamaTranslator: Translator {

    private let baseURL = URL(string: "http://localhost:11434")!
    private let session: URLSession
    private let pullSession: URLSession
    private var modelSize: GemmaModelSize
    private(set) var statusText: String

    /// 헬스체크(/api/version) 결과를 짧게 캐시해 발화마다 왕복하는 것을 막는다.
    private var reachableCache: (value: Bool, at: Date)?
    private let reachableTTL: TimeInterval = 3

    init(modelSize: GemmaModelSize) {
        self.modelSize = modelSize
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
        // 모델 다운로드는 수 분~수십 분 걸릴 수 있으므로 긴 타임아웃.
        let pullConfig = URLSessionConfiguration.default
        pullConfig.timeoutIntervalForRequest = 120
        pullConfig.timeoutIntervalForResource = 7200
        self.pullSession = URLSession(configuration: pullConfig)
        self.statusText = "Ollama · \(modelSize.ollamaTag) 확인 중"
    }

    func prepare() async throws {
        guard await isReachable() else {
            statusText = "Ollama 미실행 (brew services start ollama)"
            return
        }
        let installed = await installedModels()
        if installed.contains(where: { $0.hasPrefix(modelSize.ollamaTag) }) {
            statusText = "Ollama · \(modelSize.ollamaTag) 준비됨"
        } else {
            statusText = "모델 없음: ollama pull \(modelSize.ollamaTag)"
        }
    }

    /// 모델을 메모리에 미리 올려 첫 번역의 콜드스타트 지연을 줄인다.
    func warmUp() async {
        guard await isReachable() else { return }
        var request = URLRequest(url: baseURL.appendingPathComponent("api/generate"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "model": modelSize.ollamaTag,
            "prompt": "Hi",
            "stream": false,
            // 모델만 로드하고 토큰 생성은 최소화.
            "keep_alive": "30m",
            "options": ["num_predict": 1]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        _ = try? await session.data(for: request)
    }

    /// 필요한 모델이 없으면 /api/pull 로 다운로드한다(진행률 콜백).
    func ensureModelAvailable(onProgress: @escaping (String) -> Void) async -> Bool {
        guard await isReachable() else { return false }
        if await installedModels().contains(where: { $0.hasPrefix(modelSize.ollamaTag) }) {
            return true
        }
        onProgress("모델 다운로드 준비 중… (\(modelSize.ollamaTag))")
        return await pullModel(onProgress: onProgress)
    }

    /// /api/pull 스트리밍으로 모델을 내려받고 진행률을 보고한다.
    private func pullModel(onProgress: @escaping (String) -> Void) async -> Bool {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/pull"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["name": modelSize.ollamaTag, "stream": true]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (bytes, _) = try await pullSession.bytes(for: request)
            for try await line in bytes.lines {
                guard !line.isEmpty, let data = line.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    continue
                }
                if let error = json["error"] as? String {
                    onProgress("다운로드 오류: \(error)")
                    return false
                }
                let status = json["status"] as? String ?? ""
                if let total = json["total"] as? Double, let completed = json["completed"] as? Double, total > 0 {
                    let percent = Int(completed / total * 100)
                    let gb = total / 1_000_000_000
                    onProgress(String(format: "모델 다운로드 중… %d%% (%.1fGB)", percent, gb))
                } else if !status.isEmpty {
                    onProgress("모델 다운로드: \(status)")
                }
                if status == "success" {
                    statusText = "Ollama · \(modelSize.ollamaTag) 준비됨"
                    return true
                }
            }
            // 스트림이 끝났는데 success 가 없으면 설치 여부 재확인.
            return await installedModels().contains(where: { $0.hasPrefix(modelSize.ollamaTag) })
        } catch {
            onProgress("다운로드 실패: \(error.localizedDescription)")
            return false
        }
    }

    func translate(_ text: String, direction: TranslationDirection, context: [String]) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        guard await isReachable() else {
            return "〔Ollama 미실행〕 brew services start ollama"
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("api/generate"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": modelSize.ollamaTag,
            "prompt": Self.buildPrompt(for: trimmed, direction: direction, context: context),
            "stream": false,
            "options": ["temperature": 0.2]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 404 {
            return "〔모델 없음〕 ollama pull \(modelSize.ollamaTag)"
        }
        let decoded = try JSONDecoder().decode(OllamaGenerateResponse.self, from: data)
        return Self.cleanup(decoded.response)
    }

    /// 스트리밍 번역: NDJSON 응답을 줄 단위로 읽어 누적 텍스트를 콜백으로 전달한다.
    func translateStream(_ text: String,
                         direction: TranslationDirection,
                         context: [String],
                         onPartial: @escaping (String) -> Void) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        guard await isReachable(useCache: true) else {
            let message = "〔Ollama 미실행〕 brew services start ollama"
            onPartial(message)
            return message
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("api/generate"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "model": modelSize.ollamaTag,
            "prompt": Self.buildPrompt(for: trimmed, direction: direction, context: context),
            "stream": true,
            "options": ["temperature": 0.2]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await session.bytes(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 404 {
            let message = "〔모델 없음〕 ollama pull \(modelSize.ollamaTag)"
            onPartial(message)
            return message
        }
        // generate 응답이 온 시점엔 서버가 확실히 살아있으므로 캐시를 갱신한다.
        reachableCache = (true, Date())

        var accumulated = ""
        for try await line in bytes.lines {
            guard !line.isEmpty, let lineData = line.data(using: .utf8),
                  let chunk = try? JSONDecoder().decode(OllamaGenerateResponse.self, from: lineData) else {
                continue
            }
            if !chunk.response.isEmpty {
                accumulated += chunk.response
                let cleaned = Self.cleanup(accumulated)
                onPartial(cleaned)
            }
            if chunk.done == true { break }
        }
        return Self.cleanup(accumulated)
    }

    // MARK: - Helpers

    private func isReachable(useCache: Bool = false) async -> Bool {
        if useCache, let cache = reachableCache,
           Date().timeIntervalSince(cache.at) < reachableTTL {
            return cache.value
        }
        var request = URLRequest(url: baseURL.appendingPathComponent("api/version"))
        request.timeoutInterval = 2
        let ok: Bool
        if let (_, response) = try? await session.data(for: request),
           let http = response as? HTTPURLResponse {
            ok = http.statusCode == 200
        } else {
            ok = false
        }
        reachableCache = (ok, Date())
        return ok
    }

    private func installedModels() async -> [String] {
        let request = URLRequest(url: baseURL.appendingPathComponent("api/tags"))
        guard let (data, _) = try? await session.data(for: request),
              let decoded = try? JSONDecoder().decode(OllamaTagsResponse.self, from: data) else {
            return []
        }
        return decoded.models.map(\.name)
    }

    private static func buildPrompt(for text: String, direction: TranslationDirection, context: [String]) -> String {
        let glossary = glossaryInstruction(direction: direction)
        let contextBlock = contextInstruction(context, direction: direction)
        switch direction {
        case .enToKo:
            return """
            You are a professional English→Korean interpreter.
            Translate the following English speech into natural, fluent Korean.
            Output ONLY the Korean translation. No explanation, no quotes, no romanization.
            \(glossary)\(contextBlock)
            English: \(text)
            Korean:
            """
        case .koToEn:
            return """
            You are a professional Korean→English interpreter.
            Translate the following Korean text into natural, fluent English.
            Output ONLY the English translation. No explanation, no quotes.
            \(glossary)\(contextBlock)
            Korean: \(text)
            English:
            """
        }
    }

    /// 직전 문장들을 문맥으로 제공(대명사·맥락 정확도 향상).
    private static func contextInstruction(_ context: [String], direction: TranslationDirection) -> String {
        let recent = context.suffix(3).filter { !$0.isEmpty }
        guard !recent.isEmpty else { return "" }
        let label = direction == .enToKo ? "Previous English context (for reference only, do NOT translate)" :
                                           "Previous Korean context (for reference only, do NOT translate)"
        return "\(label):\n" + recent.map { "- \($0)" }.joined(separator: "\n") + "\n\n"
    }

    /// 용어집을 고정 번역 규칙으로 제공.
    private static func glossaryInstruction(direction: TranslationDirection) -> String {
        let pairs = AppSettings.shared.glossaryPairs
        guard !pairs.isEmpty else { return "" }
        let rules = pairs.map { "\($0.0) → \($0.1)" }.joined(separator: ", ")
        return "Always use these fixed translations: \(rules).\n"
    }

    private static func cleanup(_ text: String) -> String {
        // 스트리밍 중 매 청크마다 호출되므로, 접두어가 실제로 있을 때만 치환한다.
        var result = text
        if result.contains("Korean:") {
            result = result.replacingOccurrences(of: "Korean:", with: "")
        }
        if result.contains("English:") {
            result = result.replacingOccurrences(of: "English:", with: "")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct OllamaGenerateResponse: Decodable {
    let response: String
    let done: Bool?
}

private struct OllamaTagsResponse: Decodable {
    struct Model: Decodable { let name: String }
    let models: [Model]
}
