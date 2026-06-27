import Foundation

/// 영어 → 한글 번역기 추상화.
///
/// 기본 구현은 `StubTranslator`(의존성 없음, 데모용).
/// 전체 Xcode 환경에서는 `GemmaTranslator`(MLX 로컬 LLM)로 교체된다.
protocol Translator: AnyObject {
    /// 모델 로딩 등 준비 작업.
    func prepare() async throws

    /// 영어 텍스트를 한글로 번역.
    func translate(_ english: String) async throws -> String

    /// 사람이 읽을 수 있는 상태(로딩됨/로딩 중/미로딩 등).
    var statusText: String { get }
}

/// 어떤 번역기를 쓸지 결정한다.
///
/// 우선순위:
/// 1. MLX(in-app Gemma) — 전체 Xcode 빌드 시
/// 2. Ollama(로컬 Gemma 데몬) — Xcode 없이도 실제 번역 가능
/// 3. Stub — 데모/폴백
enum TranslatorFactory {
    @MainActor
    static func make() -> Translator {
        #if canImport(MLXLLM)
        return GemmaTranslator(modelSize: AppSettings.shared.modelSize)
        #else
        return OllamaTranslator(modelSize: AppSettings.shared.modelSize)
        #endif
    }
}
