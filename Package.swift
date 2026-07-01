// swift-tools-version: 6.0
import PackageDescription

// OwenTrans — macOS 메뉴바 실시간 영어→한글 음성 번역기
//
// 기본 빌드(의존성 0): 메뉴바 + 노치 오버레이 + 오디오 캡처 + Apple Speech(영어 STT) + Stub 번역기.
//   → Command Line Tools만으로 `swift build` / `scripts/build-app.sh` 로 실행 가능.
//
// Gemma(MLX) 로컬 번역을 켜려면(전체 Xcode 필요):
//   1) 아래 dependencies 의 MLX 라인 주석 해제
//   2) executableTarget 의 dependencies 에 MLXLLM 추가
//   3) Sources/OwenTrans/Translation/GemmaTranslator.swift 의 `#if canImport(MLXLLM)` 경로가 활성화됨

let package = Package(
    name: "OwenTrans",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "OwenTrans", targets: ["OwenTrans"])
    ],
    dependencies: [
        // Gemma 로컬 LLM(MLX) — 전체 Xcode 설치 후 주석 해제
        // .package(url: "https://github.com/ml-explore/mlx-swift-examples.git", branch: "main"),

        // (선택) Whisper STT 로 교체하려면 주석 해제
        // .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0"),
    ],
    targets: [
        .executableTarget(
            name: "OwenTrans",
            dependencies: [
                // Gemma(MLX) 활성화 시 주석 해제
                // .product(name: "MLXLLM", package: "mlx-swift-examples"),
                // .product(name: "MLXLMCommon", package: "mlx-swift-examples"),

                // Whisper 사용 시 주석 해제
                // .product(name: "WhisperKit", package: "WhisperKit"),
            ],
            path: "Sources/OwenTrans",
            resources: [
                // 디렉터리 구조를 보존하기 위해 copy 사용(런타임 폰트 등록에 필요).
                .copy("Resources/Fonts")
            ],
            swiftSettings: [
                // 스캐폴드 단계에서는 Swift 5 동시성 모드로 완화(점진적 마이그레이션)
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
