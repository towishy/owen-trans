import Foundation

/// 번역 방향.
enum TranslationDirection {
    case enToKo  // 영어 → 한글 (듣기·노치 오버레이)
    case koToEn  // 한글 → 영어 (말하기·플로팅 입력창)
}

/// 번역기 추상화.
///
/// 기본 구현은 `StubTranslator`(의존성 없음, 데모용).
/// 전체 Xcode 환경에서는 `GemmaTranslator`(MLX 로컬 LLM)로 교체된다.
protocol Translator: AnyObject {
    /// 모델 로딩 등 준비 작업.
    func prepare() async throws

    /// 지정한 방향으로 텍스트를 번역.
    func translate(_ text: String, direction: TranslationDirection) async throws -> String

    /// 사람이 읽을 수 있는 상태(로딩됨/로딩 중/미로딩 등).
    var statusText: String { get }
}

extension Translator {
    /// 기존 호출 호환: 영어 → 한글.
    func translate(_ english: String) async throws -> String {
        try await translate(english, direction: .enToKo)
    }
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
