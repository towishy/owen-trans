import SwiftUI

/// 환경설정 화면. 모든 라벨은 나눔스퀘어 폰트.
struct PreferencesView: View {
    let pipeline: TranslationPipeline
    @ObservedObject private var settings = AppSettings.shared
    @State private var devices: [AudioInputManager.Device] = []

    var body: some View {
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
                    Text(device.name).font(.nanum(13)).tag(String?.some(device.uid))
                }
            }
            .labelsHidden()
            .onChange(of: settings.selectedInputDeviceUID) { _, _ in
                pipeline.reloadInputDeviceIfRunning()
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

            Spacer()
        }
        .padding(24)
        .frame(width: 460, height: 380, alignment: .topLeading)
        .onAppear { devices = AudioInputManager.availableInputDevices() }
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
