import Foundation
import Combine

/// 모델 선택지(번역 LLM).
enum GemmaModelSize: String, CaseIterable, Codable {
    case gemma4B = "gemma-3-4b"
    case gemma12B = "gemma-3-12b"
    case qwen7B = "qwen2.5-7b"
    case exaone8B = "exaone-3.5-7.8b"

    var displayName: String {
        switch self {
        case .gemma4B:  return "Gemma 3 · 4B (빠름·권장)"
        case .gemma12B: return "Gemma 3 · 12B (정확)"
        case .qwen7B:   return "Qwen 2.5 · 7B (한국어 강함)"
        case .exaone8B: return "EXAONE 3.5 · 7.8B (한국어 특화)"
        }
    }

    /// MLX(Hugging Face) 모델 저장소 ID. GemmaTranslator 에서 사용.
    /// (MLX 인프로세스 경로는 현재 비활성 — Ollama 경로 사용 시엔 참조되지 않음)
    var huggingFaceRepo: String {
        switch self {
        case .gemma4B:  return "mlx-community/gemma-3-4b-it-4bit"
        case .gemma12B: return "mlx-community/gemma-3-12b-it-4bit"
        case .qwen7B:   return "mlx-community/Qwen2.5-7B-Instruct-4bit"
        case .exaone8B: return "mlx-community/EXAONE-3.5-7.8B-Instruct-4bit"
        }
    }

    /// Ollama 모델 태그. OllamaTranslator 에서 사용.
    var ollamaTag: String {
        switch self {
        case .gemma4B:  return "gemma3:4b"
        case .gemma12B: return "gemma3:12b"
        case .qwen7B:   return "qwen2.5:7b"
        case .exaone8B: return "exaone3.5:7.8b"
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

    /// 노치 오버레이 가로 폭(고정). 동적 리사이즈 대신 이 값으로 고정한다.
    @Published var notchWidth: Double {
        didSet { defaults.set(notchWidth, forKey: Keys.notchWidth) }
    }

    /// 노치 오버레이 번역 글자 크기(pt).
    @Published var notchFontSize: Double {
        didSet { defaults.set(notchFontSize, forKey: Keys.notchFontSize) }
    }

    /// 번역 내용을 Markdown 문서로 자동 저장할지 여부.
    @Published var autoSaveMarkdown: Bool {
        didSet { defaults.set(autoSaveMarkdown, forKey: Keys.autoSave) }
    }

    /// 저장 폴더 경로. nil/빈 값이면 다운로드 폴더에 저장한다.
    @Published var saveFolderPath: String? {
        didSet { defaults.set(saveFolderPath, forKey: Keys.saveFolder) }
    }

    /// TTS 음성 식별자(nil 이면 시스템 기본 en-US).
    @Published var ttsVoiceIdentifier: String? {
        didSet { defaults.set(ttsVoiceIdentifier, forKey: Keys.ttsVoice) }
    }

    /// TTS 말하기 속도(0.0~1.0, 기본 0.5).
    @Published var ttsRate: Double {
        didSet { defaults.set(ttsRate, forKey: Keys.ttsRate) }
    }

    /// TTS 음높이/톤(0.5~2.0, 기본 1.0).
    @Published var ttsPitch: Double {
        didSet { defaults.set(ttsPitch, forKey: Keys.ttsPitch) }
    }

    /// 문맥 유지 번역(직전 문장을 프롬프트에 포함) 사용 여부.
    @Published var useContextTranslation: Bool {
        didSet { defaults.set(useContextTranslation, forKey: Keys.useContext) }
    }

    /// 용어집 텍스트. 한 줄에 "원문=번역" 형식.
    @Published var glossaryText: String {
        didSet { defaults.set(glossaryText, forKey: Keys.glossary) }
    }

    /// 전역 단축키: 번역 시작/정지 (keyCode, Carbon modifier 마스크).
    @Published var hotKeyTranslateCode: Int {
        didSet { defaults.set(hotKeyTranslateCode, forKey: Keys.hkTransCode) }
    }
    @Published var hotKeyTranslateMods: Int {
        didSet { defaults.set(hotKeyTranslateMods, forKey: Keys.hkTransMods) }
    }
    /// 전역 단축키: 번역 입력창 토글.
    @Published var hotKeyComposerCode: Int {
        didSet { defaults.set(hotKeyComposerCode, forKey: Keys.hkCompCode) }
    }
    @Published var hotKeyComposerMods: Int {
        didSet { defaults.set(hotKeyComposerMods, forKey: Keys.hkCompMods) }
    }

    /// 용어집을 (원문, 번역) 쌍으로 파싱.
    var glossaryPairs: [(String, String)] {
        glossaryText
            .split(separator: "\n")
            .compactMap { line in
                let parts = line.split(separator: "=", maxSplits: 1).map {
                    $0.trimmingCharacters(in: .whitespaces)
                }
                guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return nil }
                return (parts[0], parts[1])
            }
    }

    /// 실제 저장 위치(미지정 시 다운로드 폴더).
    var resolvedSaveFolderURL: URL {
        if let path = saveFolderPath, !path.isEmpty {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        let fm = FileManager.default
        return fm.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? fm.homeDirectoryForCurrentUser
    }

    private enum Keys {
        static let modelSize = "modelSize"
        static let inputDeviceUID = "inputDeviceUID"
        static let showsOriginal = "showsOriginalText"
        static let autoHide = "overlayAutoHideSeconds"
        static let notchWidth = "notchWidth"
        static let notchFontSize = "notchFontSize"
        static let autoSave = "autoSaveMarkdown"
        static let saveFolder = "saveFolderPath"
        static let ttsVoice = "ttsVoiceIdentifier"
        static let ttsRate = "ttsRate"
        static let ttsPitch = "ttsPitch"
        static let useContext = "useContextTranslation"
        static let glossary = "glossaryText"
        static let hkTransCode = "hotKeyTranslateCode"
        static let hkTransMods = "hotKeyTranslateMods"
        static let hkCompCode = "hotKeyComposerCode"
        static let hkCompMods = "hotKeyComposerMods"
    }

    private init() {
        let rawModel = defaults.string(forKey: Keys.modelSize) ?? GemmaModelSize.gemma4B.rawValue
        self.modelSize = GemmaModelSize(rawValue: rawModel) ?? .gemma4B
        self.selectedInputDeviceUID = defaults.string(forKey: Keys.inputDeviceUID)
        self.showsOriginalText = defaults.object(forKey: Keys.showsOriginal) as? Bool ?? true
        self.overlayAutoHideSeconds = defaults.object(forKey: Keys.autoHide) as? Double ?? 4.0
        self.notchWidth = defaults.object(forKey: Keys.notchWidth) as? Double ?? 480
        self.notchFontSize = defaults.object(forKey: Keys.notchFontSize) as? Double ?? 17
        self.autoSaveMarkdown = defaults.object(forKey: Keys.autoSave) as? Bool ?? true
        self.saveFolderPath = defaults.string(forKey: Keys.saveFolder)
        self.ttsVoiceIdentifier = defaults.string(forKey: Keys.ttsVoice)
        self.ttsRate = defaults.object(forKey: Keys.ttsRate) as? Double ?? 0.5
        self.ttsPitch = defaults.object(forKey: Keys.ttsPitch) as? Double ?? 1.0
        self.useContextTranslation = defaults.object(forKey: Keys.useContext) as? Bool ?? true
        self.glossaryText = defaults.string(forKey: Keys.glossary) ?? ""
        // 기본 단축키: ⌥⌘T(번역), ⌥⌘I(입력창). Carbon optionKey|cmdKey = 2304, T=0x11, I=0x22.
        self.hotKeyTranslateCode = defaults.object(forKey: Keys.hkTransCode) as? Int ?? 0x11
        self.hotKeyTranslateMods = defaults.object(forKey: Keys.hkTransMods) as? Int ?? 2304
        self.hotKeyComposerCode = defaults.object(forKey: Keys.hkCompCode) as? Int ?? 0x22
        self.hotKeyComposerMods = defaults.object(forKey: Keys.hkCompMods) as? Int ?? 2304
    }
}
