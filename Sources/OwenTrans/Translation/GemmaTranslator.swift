import Foundation

// Gemma 로컬 LLM(MLX) 기반 영어→한글 번역기.
//
// 이 파일은 MLX(mlx-swift-examples) 가 의존성에 추가된 전체 Xcode 환경에서만 컴파일된다.
// 활성화 방법:
//   1) Package.swift 의 MLX 의존성 / MLXLLM·MLXLMCommon product 주석 해제
//   2) 전체 Xcode 설치(Metal 툴체인 필요)
//   3) 빌드 시 `#if canImport(MLXLLM)` 분기가 자동 활성화
//
// 최초 실행 시 선택한 모델(4B/12B)을 Hugging Face 에서 내려받아 로컬 캐시에 저장하고
// 이후에는 앱 안에서 직접 로딩한다.

#if canImport(MLXLLM)
import MLXLLM
import MLXLMCommon

final class GemmaTranslator: Translator {

    private let modelSize: GemmaModelSize
    private var container: ModelContainer?
    private(set) var statusText: String

    init(modelSize: GemmaModelSize) {
        self.modelSize = modelSize
        self.statusText = "\(modelSize.displayName) 미로딩"
    }

    func prepare() async throws {
        statusText = "\(modelSize.displayName) 로딩 중…"
        let configuration = ModelConfiguration(id: modelSize.huggingFaceRepo)
        container = try await LLMModelFactory.shared.loadContainer(configuration: configuration)
        statusText = "\(modelSize.displayName) 로딩 완료"
    }

    func translate(_ text: String, direction: TranslationDirection, context: [String]) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        if container == nil {
            try await prepare()
        }
        guard let container else { return "" }

        let prompt = Self.buildPrompt(for: trimmed, direction: direction, context: context)

        let result = try await container.perform { context in
            let input = try await context.processor.prepare(input: .init(prompt: prompt))
            var output = ""
            let stream = try MLXLMCommon.generate(
                input: input,
                parameters: GenerateParameters(temperature: 0.2),
                context: context
            )
            for await item in stream {
                if let chunk = item.chunk {
                    output += chunk
                }
            }
            return output
        }
        return Self.cleanup(result)
    }

    private static func buildPrompt(for text: String, direction: TranslationDirection, context: [String]) -> String {
        let contextBlock: String = {
            let recent = context.suffix(3).filter { !$0.isEmpty }
            guard !recent.isEmpty else { return "" }
            return "Previous context (reference only):\n" + recent.map { "- \($0)" }.joined(separator: "\n") + "\n\n"
        }()
        switch direction {
        case .enToKo:
            return """
            You are a professional English→Korean interpreter.
            Translate the following English speech into natural, fluent Korean.
            Output ONLY the Korean translation, with no explanation or quotes.
            \(contextBlock)
            English: \(text)
            Korean:
            """
        case .koToEn:
            return """
            You are a professional Korean→English interpreter.
            Translate the following Korean text into natural, fluent English.
            Output ONLY the English translation, with no explanation or quotes.
            \(contextBlock)
            Korean: \(text)
            English:
            """
        }
    }

    private static func cleanup(_ text: String) -> String {
        text
            .replacingOccurrences(of: "Korean:", with: "")
            .replacingOccurrences(of: "English:", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
#endif
