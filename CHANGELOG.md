# Changelog

모든 주요 변경 사항을 이 파일에 기록합니다.

## v0.1.16
- MLX(인프로세스 Gemma) 로컬 번역 경로 활성화 — Ollama 없이 앱 프로세스 안에서 직접 번역
- MLXLLM/MLXLMCommon 저장소 이전 대응: mlx-swift-examples → mlx-swift-lm
- 신규 loadContainer API 대응: MLXHuggingFace 매크로(#hubDownloader / #huggingFaceTokenizerLoader)로 기본 다운로더·토크나이저 주입
- 의존성 추가: mlx-swift-lm, swift-huggingface(HuggingFace), swift-transformers(Tokenizers)

## v0.1.15
- 환경설정 번역 모델에 모델별 다운로드 버튼 + 설치 상태 + 진행바 추가
- OllamaModelManager: /api/tags 설치 확인, /api/pull 스트리밍 다운로드·진행률

## v0.1.14
- 번역 모델 선택 확장: Qwen 2.5 · 7B, EXAONE 3.5 · 7.8B (한국어 특화) 추가
- 번역 캐시(LRU 200개): 동일 문장 즉시 표시
- 번역 실패 시 1회 자동 재시도(일시적 네트워크 오류 대비)
- 노치 글자 크기 슬라이더(12~26pt) + 실시간 미리보기
- 번역 기록 뷰어 검색(파일명·본문 내용)

## v0.1.13
- 노치 라운드 모서리 사각 잔상 제거(창/SwiftUI 그림자 정리)

## v0.1.12
- 모델 없을 때 자동 다운로드(ollama pull) + 진행률 노치 표시

## v0.1.11
- 노치 가로 폭 고정 슬라이더 + 실시간 미리보기, 세로 최대 3줄

## v0.1.10
- 번역 기록 뷰어, 메뉴바 아이콘 실행 상태 색상, 업데이트 확인

## v0.1.9
- 문맥 유지 번역 + 용어집, 단축키 커스터마이즈, 플로팅 입력창 위치 기억

## v0.1.8
- 스트리밍 번역, 모델 워밍업, 전역 단축키(⌥⌘T/⌥⌘I), 앱 아이콘, /Applications 설치 옵션

## v0.1.7
- 로그인 시 자동 실행(SMAppService), 첫 실행 온보딩 마법사

## v0.1.6
- 회의용 플로팅 입력창(한→영) + 클립보드 복사·음성 출력, TTS 음성 선택

## v0.1.5
- 시스템 오디오 설정 그림 가이드, BlackHole 안내 정정

## v0.1.4
- 실행 시 의존성 자동 점검 + 설치 마법사

## v0.1.3
- 시스템 오디오 캡처(브라우저·YouTube) 지원: 가상 오디오 장치 감지 + 가이드

## v0.1.2
- 메뉴바 트레이 아이콘(OWEN 형상화)

## v0.1.1
- 노치 오버레이 개선, 일시정지/종료, Markdown 저장, 번역 취소 버그 수정

## v0.1.0
- 최초 릴리스: 실시간 영어→한글 음성 번역, Ollama Gemma 백엔드, 나눔스퀘어 폰트
