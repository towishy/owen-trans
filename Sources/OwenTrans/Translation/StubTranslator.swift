import Foundation

/// MLX/Gemma 가 빌드되지 않은 환경(Command Line Tools 전용)에서 동작하는 데모용 번역기.
///
/// 실제 번역 대신 입력 영어 앞에 마커를 붙여 파이프라인이 끝까지 도는지 확인할 수 있게 한다.
/// 전체 Xcode + MLX 활성화 시 `GemmaTranslator` 가 자동으로 사용된다(TranslatorFactory).
final class StubTranslator: Translator {

    private(set) var statusText = "데모 번역기(Gemma 미로딩)"

    func prepare() async throws {
        statusText = "데모 번역기 준비됨"
    }

    func translate(_ english: String) async throws -> String {
        let trimmed = english.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return "〔번역 미연결〕 \(trimmed)"
    }
}
