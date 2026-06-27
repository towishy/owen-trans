import SwiftUI
import AppKit

/// 환경설정 화면. 모든 라벨은 나눔스퀘어 폰트.
struct PreferencesView: View {
    let pipeline: TranslationPipeline
    @ObservedObject private var settings = AppSettings.shared
    @State private var devices: [AudioInputManager.Device] = []
    @State private var hasVirtualDevice = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
            sectionHeader("번역 모델")
            Picker("", selection: $settings.modelSize) {
                ForEach(GemmaModelSize.allCases, id: \.self) { size in
                    Text(size.displayName).font(.nanum(13)).tag(size)
                }
            }
            .labelsHidden()
            .pickerStyle(.radioGroup)
            .onChange(of: settings.modelSize) { _, _ in pipeline.reloadModel() }

            Divider()

            sectionHeader("음성 입력 장치")
            Picker("", selection: deviceBinding) {
                Text("시스템 기본 입력").font(.nanum(13)).tag(String?.none)
                ForEach(devices, id: \.uid) { device in
                    Text(device.isVirtualLoopback ? "\(device.name) · 시스템 오디오" : device.name)
                        .font(.nanum(13))
                        .tag(String?.some(device.uid))
                }
            }
            .labelsHidden()
            .onChange(of: settings.selectedInputDeviceUID) { _, _ in
                pipeline.reloadInputDeviceIfRunning()
            }

            Divider()

            sectionHeader("시스템 오디오 캡처 (브라우저·YouTube)")
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: hasVirtualDevice ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(hasVirtualDevice ? .green : .orange)
                    Text(hasVirtualDevice
                         ? "가상 오디오 장치 감지됨 — 위 목록에서 ‘시스템 오디오’ 장치를 선택하세요."
                         : "브라우저 소리를 번역하려면 BlackHole 같은 가상 오디오 장치가 필요합니다.")
                        .font(.nanum(12))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("① BlackHole 설치 → ② Audio MIDI 설정에서 ‘다중 출력 장치’(스피커+BlackHole) 생성 → ③ 출력을 다중 출력으로, 위 입력 장치를 BlackHole 로 선택")
                    .font(.nanum(11, weight: .light))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Button { copyInstallCommand() } label: {
                        Text("설치 명령 복사").font(.nanum(12))
                    }
                    Button { openBlackHoleDownload() } label: {
                        Text("BlackHole 다운로드").font(.nanum(12))
                    }
                    Button { openAudioMIDISetup() } label: {
                        Text("Audio MIDI 설정 열기").font(.nanum(12))
                    }
                }
            }

            Divider()

            sectionHeader("표시 옵션")
            Toggle(isOn: $settings.showsOriginalText) {
                Text("노치에 영어 원문도 함께 표시").font(.nanum(13))
            }

            HStack {
                Text("자동 숨김").font(.nanum(13))
                Slider(value: $settings.overlayAutoHideSeconds, in: 0...10, step: 0.5)
                Text(settings.overlayAutoHideSeconds == 0
                     ? "안 함"
                     : String(format: "%.1f초", settings.overlayAutoHideSeconds))
                    .font(.nanum(12, weight: .light))
                    .frame(width: 48, alignment: .trailing)
            }

            Divider()

            sectionHeader("번역 기록 저장")
            Toggle(isOn: $settings.autoSaveMarkdown) {
                Text("번역 내용을 Markdown 문서로 저장").font(.nanum(13))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("저장 폴더")
                    .font(.nanum(12, weight: .light))
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Text(settings.resolvedSaveFolderURL.path)
                        .font(.nanum(12))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color(nsColor: .textBackgroundColor).opacity(0.6))
                        )
                    Button { chooseSaveFolder() } label: {
                        Text("폴더 선택…").font(.nanum(12))
                    }
                    Button { openSaveFolder() } label: {
                        Text("열기").font(.nanum(12))
                    }
                    if settings.saveFolderPath?.isEmpty == false {
                        Button { settings.saveFolderPath = nil } label: {
                            Text("기본값").font(.nanum(12))
                        }
                    }
                }
            }
            .disabled(!settings.autoSaveMarkdown)
            .opacity(settings.autoSaveMarkdown ? 1 : 0.5)

            Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(width: 460, height: 620)
        .onAppear {
            devices = AudioInputManager.availableInputDevices()
            hasVirtualDevice = devices.contains { $0.isVirtualLoopback }
        }
    }

    private func copyInstallCommand() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString("brew install blackhole-2ch", forType: .string)
    }

    private func openBlackHoleDownload() {
        if let url = URL(string: "https://existential.audio/blackhole/") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openAudioMIDISetup() {
        let url = URL(fileURLWithPath: "/System/Applications/Utilities/Audio MIDI Setup.app")
        NSWorkspace.shared.open(url)
    }

    private func chooseSaveFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "선택"
        panel.message = "번역 기록을 저장할 폴더를 선택하세요"
        panel.directoryURL = settings.resolvedSaveFolderURL
        if panel.runModal() == .OK, let url = panel.url {
            settings.saveFolderPath = url.path
        }
    }

    private func openSaveFolder() {
        NSWorkspace.shared.open(settings.resolvedSaveFolderURL)
    }

    private var deviceBinding: Binding<String?> {
        Binding(
            get: { settings.selectedInputDeviceUID },
            set: { settings.selectedInputDeviceUID = $0 }
        )
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.nanum(14, weight: .extraBold))
            .foregroundStyle(.secondary)
    }
}
