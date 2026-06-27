import Foundation
import Combine

/// 모델 크기 선택지.
enum GemmaModelSize: String, CaseIterable, Codable {
    case gemma4B = "gemma-3-4b"
    case gemma12B = "gemma-3-12b"

    var displayName: String {
        switch self {
        case .gemma4B:  return "Gemma 3 · 4B (빠름)"
        case .gemma12B: return "Gemma 3 · 12B (정확)"
        }
    }

    /// MLX(Hugging Face) 모델 저장소 ID. GemmaTranslator 에서 사용.
    var huggingFaceRepo: String {
        switch self {
        case .gemma4B:  return "mlx-community/gemma-3-4b-it-4bit"
        case .gemma12B: return "mlx-community/gemma-3-12b-it-4bit"
        }
    }

    /// Ollama 모델 태그. OllamaTranslator 에서 사용.
    var ollamaTag: String {
        switch self {
        case .gemma4B:  return "gemma3:4b"
        case .gemma12B: return "gemma3:12b"
        }
    }
}

/// 앱 전역 설정. UserDefaults 영속화.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    @Published var modelSize: GemmaModelSize {
        didSet { defaults.set(modelSize.rawValue, forKey: Keys.modelSize) }
    }

    /// 선택한 오디오 입력 장치의 고유 ID(nil 이면 시스템 기본 입력).
    @Published var selectedInputDeviceUID: String? {
        didSet { defaults.set(selectedInputDeviceUID, forKey: Keys.inputDeviceUID) }
    }

    /// 노치 오버레이에 원문(영어)도 함께 표시할지 여부.
    @Published var showsOriginalText: Bool {
        didSet { defaults.set(showsOriginalText, forKey: Keys.showsOriginal) }
    }

    /// 오버레이 자동 숨김까지 대기 시간(초).
    @Published var overlayAutoHideSeconds: Double {
        didSet { defaults.set(overlayAutoHideSeconds, forKey: Keys.autoHide) }
    }

    private enum Keys {
        static let modelSize = "modelSize"
        static let inputDeviceUID = "inputDeviceUID"
        static let showsOriginal = "showsOriginalText"
        static let autoHide = "overlayAutoHideSeconds"
    }

    private init() {
        let rawModel = defaults.string(forKey: Keys.modelSize) ?? GemmaModelSize.gemma4B.rawValue
        self.modelSize = GemmaModelSize(rawValue: rawModel) ?? .gemma4B
        self.selectedInputDeviceUID = defaults.string(forKey: Keys.inputDeviceUID)
        self.showsOriginalText = defaults.object(forKey: Keys.showsOriginal) as? Bool ?? true
        self.overlayAutoHideSeconds = defaults.object(forKey: Keys.autoHide) as? Double ?? 4.0
    }
}
