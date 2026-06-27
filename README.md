# OwenTrans

macOS 상단 메뉴바에 상주하는 **실시간 영어 → 한글 음성 번역기**입니다.
선택한 마이크(내장/외장)로 들어오는 영어 음성을 인식해, 로컬 LLM(Gemma)으로 한글 번역하고
화면 상단 **노치(Dynamic Island 유사) 오버레이**에 실시간 표시합니다.

> [!NOTE]
> macOS에는 iPhone의 Dynamic Island가 없습니다. 이 앱은 MacBook의 카메라 **노치 주변**
> (노치가 없으면 메뉴바 바로 아래 중앙)에 떠 있는 캡슐 오버레이로 동일한 경험을 제공합니다.

## 동작 파이프라인

```
마이크(선택 입력) → Apple Speech(영어 STT) → 영어 텍스트 → Gemma/MLX(EN→KO) → 노치 오버레이
```

- **STT(영어 음성→텍스트)**: Apple Speech 프레임워크(OS 내장, 가능 시 온디바이스). 의존성·다운로드 없음.
- **번역(영어→한글)**: 로컬 **Gemma 3 (4B / 12B)**. 두 가지 백엔드 지원
  - **Ollama**(기본·Xcode 불필요): 로컬 `ollama serve` 데몬으로 즉시 동작.
  - **MLX**(in-app·전체 Xcode 필요): 앱 안에서 직접 모델 로딩.
- **표시**: 노치 오버레이 + 나눔스퀘어 폰트.
- **UI**: 상단 메뉴바 아이콘 → `번역 시작/중지`, `입력 장치`, `번역 모델`, `환경설정`, `OwenTrans 정보`, `종료`.

## 요구 사항

| 항목 | 내용 |
|---|---|
| 칩 | Apple Silicon (arm64) |
| OS | macOS 14+ |
| 기본 빌드 | Swift 6 / Command Line Tools (의존성 0) |
| 실제 번역(권장) | **Ollama** + `gemma3:4b`/`gemma3:12b` (Xcode 불필요) |
| in-app 번역(선택) | **전체 Xcode** 필요 (MLX Metal 커널 컴파일) |

## 빠른 시작 (Xcode 불필요 · 실제 Gemma 번역)

```bash
# 1) Ollama 설치 + 모델 다운로드 (실제 Gemma 번역 백엔드)
brew install ollama
brew services start ollama
ollama pull gemma3:4b        # 12B 를 쓰려면: ollama pull gemma3:12b

# 2) .app 번들 조립 + ad-hoc 서명 (마이크/음성 권한이 동작하려면 .app 번들 필요)
chmod +x scripts/build-app.sh
./scripts/build-app.sh --run
```

처음 실행 시 **마이크**와 **음성 인식** 권한을 허용하세요.
메뉴바의 말풍선 아이콘 → `번역 시작`을 누르면 노치에 인식/번역 결과가 표시됩니다.

> Ollama 데몬이 꺼져 있거나 모델이 없으면 노치에 안내 메시지가 표시됩니다.

## 시스템 오디오 캡처 (브라우저·YouTube 영상 번역)

이 앱은 **입력 장치(마이크)** 의 소리를 인식합니다. 브라우저/YouTube 소리는 **출력(스피커)** 으로
나가므로, 시스템 출력을 다시 입력으로 되돌려주는 **가상 오디오 장치**가 필요합니다.

```bash
# 1) BlackHole(무료 가상 오디오 장치) 설치
brew install blackhole-2ch
```

2. **Audio MIDI 설정**(`/System/Applications/Utilities/Audio MIDI Setup.app`)에서
   **다중 출력 장치**(Multi-Output Device)를 만들어 `스피커 + BlackHole`을 함께 체크 →
   소리도 들으면서 BlackHole로 복사됩니다.
3. 시스템 **출력**을 방금 만든 다중 출력 장치로 변경.
4. OwenTrans **환경설정 → 음성 입력 장치**에서 **BlackHole 2ch**(‘시스템 오디오’ 표시) 선택.
5. `번역 시작` → 브라우저에서 영어 영상 재생 → 노치에 한글 번역 표시.

> 환경설정의 **시스템 오디오 캡처** 섹션에서 설치 명령 복사 · BlackHole 다운로드 ·
> Audio MIDI 설정 열기를 바로 실행할 수 있습니다. 헤드폰만 쓰면 마이크가 소리를 못 줍는 점에
> 유의하세요(가상 장치 경로를 권장).

## in-app MLX 번역 활성화 (전체 Xcode · 선택)

Ollama 데몬 없이 앱이 직접 모델을 로딩하게 하려면 MLX 경로를 사용합니다.

1. App Store 또는 developer.apple.com에서 **Xcode**를 설치하고 활성화:
   ```bash
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   ```
2. `Package.swift`에서 MLX 의존성과 `MLXLLM`·`MLXLMCommon` product 주석을 해제.
3. 빌드하면 `#if canImport(MLXLLM)` 분기가 활성화되어 `GemmaTranslator`가 사용됩니다.
4. 첫 실행 시 선택한 모델(4B/12B)을 Hugging Face에서 내려받아 로컬 캐시에 저장 후
   이후에는 앱 안에서 직접 로딩합니다.

기본 모델 저장소(`Sources/OwenTrans/Support/AppSettings.swift`):
- 4B: `mlx-community/gemma-3-4b-it-4bit`
- 12B: `mlx-community/gemma-3-12b-it-4bit`

## 폰트 (나눔스퀘어)

모든 메뉴·UI 텍스트는 **나눔스퀘어**를 사용합니다.
- 시스템에 설치되어 있으면 그대로 사용.
- 없으면 `Sources/OwenTrans/Resources/Fonts/`에 넣은 `.ttf`/`.otf`를 런타임 등록.
- 둘 다 없으면 시스템 폰트로 폴백.
- 다운로드: https://hangeul.naver.com/font

## 프로젝트 구조

```
Sources/OwenTrans/
├── main.swift                     # 진입점(액세서리 앱)
├── AppDelegate.swift              # 구성 요소 조립
├── Support/
│   ├── AppSettings.swift          # 설정(UserDefaults)
│   └── FontProvider.swift         # 나눔스퀘어 폰트 공급
├── MenuBar/
│   └── StatusItemController.swift # 메뉴바 아이콘 + 메뉴
├── Audio/
│   └── AudioInputManager.swift    # 입력 장치 열거/선택 + 캡처
├── Speech/
│   └── SpeechRecognizerService.swift  # 영어 STT(Apple Speech)
├── Translation/
│   ├── Translator.swift           # 번역기 추상화 + 팩토리
│   ├── OllamaTranslator.swift     # 로컬 Gemma (Ollama, 기본)
│   ├── StubTranslator.swift       # 데모/폴백
│   └── GemmaTranslator.swift      # Gemma/MLX in-app (Xcode 필요)
├── Pipeline/
│   └── TranslationPipeline.swift  # 전체 흐름 조율
├── Overlay/
│   ├── NotchOverlayController.swift   # 노치 창 관리
│   └── NotchOverlayView.swift         # 노치 SwiftUI 뷰
└── Preferences/
    ├── PreferencesWindowController.swift
    ├── PreferencesView.swift
    └── AboutWindowController.swift
```

## 라이선스

TBD.
