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
- **번역(영어→한글)**: 로컬 **Gemma 4 (E2B / E4B / 12B)**. 두 가지 백엔드 지원
  - **Ollama**(기본·Xcode 불필요): 로컬 `ollama serve` 데몬으로 즉시 동작.
- **표시**: 노치 오버레이 + 나눔스퀘어 폰트.
- **UI**: 상단 메뉴바 아이콘 → `번역 시작/중지`, `입력 장치`, `번역 모델`, `환경설정`, `OwenTrans 정보`, `종료`.

## 요구 사항

| 항목 | 내용 |
|---|---|
| 칩 | Apple Silicon (arm64) |
| OS | macOS 14+ |
| 기본 빌드 | Swift 6 / Command Line Tools (의존성 0) |
| 실제 번역(권장) | **Ollama** + `gemma4:e4b` (기본) · `gemma4:e2b` · `gemma4:12b` |


## 빠른 시작 (실제 Gemma 번역)

처음 실행 시 **마이크**와 **음성 인식** 권한을 허용하세요.
메뉴바의 말풍선 아이콘 → `번역 시작`을 누르면 노치에 인식/번역 결과가 표시됩니다.

> Ollama 데몬이 꺼져 있거나 모델이 없으면 노치에 안내 메시지가 표시됩니다.

### 전역 단축키

앱이 백그라운드(메뉴바)에 있어도 동작합니다.

| 단축키 | 동작 |
|---|---|
| `⌥⌘T` | 번역 시작 / 정지 |
| `⌥⌘I` | 번역 입력창(한→영) 열기 / 닫기 |


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
