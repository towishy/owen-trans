import Foundation

/// Ollama 로컬 서버를 통한 Gemma 영어→한글 번역기.
///
/// 전체 Xcode(MLX) 없이도 **실제 Gemma 로컬 번역**을 사용할 수 있는 경로다.
/// - 로컬 데몬: `http://localhost:11434` (ollama serve)
/// - 모델: `gemma3:4b` / `gemma3:12b`
///
/// 데몬이 없거나 모델이 없으면 사용자에게 안내 메시지를 반환한다.
final class OllamaTranslator: Translator {

    private let baseURL = URL(string: "http://localhost:11434")!
    private let session: URLSession
    private var modelSize: GemmaModelSize
    private(set) var statusText: String

    init(modelSize: GemmaModelSize) {
        self.modelSize = modelSize
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
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

    func translate(_ english: String) async throws -> String {
        let trimmed = english.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        guard await isReachable() else {
            return "〔Ollama 미실행〕 brew services start ollama"
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("api/generate"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": modelSize.ollamaTag,
            "prompt": Self.buildPrompt(for: trimmed),
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

    // MARK: - Helpers

    private func isReachable() async -> Bool {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/version"))
        request.timeoutInterval = 2
        guard let (_, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse else {
            return false
        }
        return http.statusCode == 200
    }

    private func installedModels() async -> [String] {
        let request = URLRequest(url: baseURL.appendingPathComponent("api/tags"))
        guard let (data, _) = try? await session.data(for: request),
              let decoded = try? JSONDecoder().decode(OllamaTagsResponse.self, from: data) else {
            return []
        }
        return decoded.models.map(\.name)
    }

    private static func buildPrompt(for english: String) -> String {
        """
        You are a professional English→Korean interpreter.
        Translate the following English speech into natural, fluent Korean.
        Output ONLY the Korean translation. No explanation, no quotes, no romanization.

        English: \(english)
        Korean:
        """
    }

    private static func cleanup(_ text: String) -> String {
        text
            .replacingOccurrences(of: "Korean:", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct OllamaGenerateResponse: Decodable {
    let response: String
}

private struct OllamaTagsResponse: Decodable {
    struct Model: Decodable { let name: String }
    let models: [Model]
}
