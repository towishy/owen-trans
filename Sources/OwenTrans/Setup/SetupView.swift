import SwiftUI

/// 의존성(Ollama·Gemma·BlackHole) 점검 및 자동 설치 마법사.
struct SetupView: View {
    @ObservedObject var manager: DependencyManager
    var onDone: () -> Void
    @State private var showAudioGuide = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("OwenTrans 설치 마법사")
                    .font(.nanum(18, weight: .extraBold))
                Text("실시간 번역에 필요한 구성 요소를 점검하고 자동으로 설치·구성합니다.")
                    .font(.nanum(12, weight: .light))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                ForEach(DependencyManager.Item.allCases) { item in
                    itemRow(item)
                    if item != DependencyManager.Item.allCases.last {
                        Divider()
                    }
                }
            }
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .underPageBackgroundColor).opacity(0.5))
            )

            // 설치 로그
            if !manager.log.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView {
                        Text(manager.log)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .id("logEnd")
                    }
                    .frame(height: 140)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(nsColor: .textBackgroundColor).opacity(0.5))
                    )
                    .onChange(of: manager.log) { _, _ in
                        proxy.scrollTo("logEnd", anchor: .bottom)
                    }
                }
            }

            HStack {
                Button { Task { await manager.checkAll() } } label: {
                    Text("다시 점검").font(.nanum(12))
                }
                .disabled(manager.isBusy)

                Spacer()

                Button { Task { await manager.setupAll() } } label: {
                    Text(manager.isBusy ? "설치 중…" : "부족한 항목 자동 설치")
                        .font(.nanum(13, weight: .bold))
                        .padding(.horizontal, 6)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(manager.isBusy || manager.allRequiredSatisfied)

                Button { onDone() } label: {
                    Text(manager.allRequiredSatisfied ? "시작하기" : "나중에")
                        .font(.nanum(13, weight: manager.allRequiredSatisfied ? .bold : .regular))
                        .padding(.horizontal, 6)
                }
                .disabled(manager.isBusy)
            }
        }
        .padding(24)
        .frame(width: 520)
        .task { await manager.checkAll() }
        .sheet(isPresented: $showAudioGuide) {
            SystemAudioGuideView { showAudioGuide = false }
        }
    }

    private func itemRow(_ item: DependencyManager.Item) -> some View {
        let state = manager.states[item] ?? .unknown
        return HStack(spacing: 12) {
            statusIcon(state)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.title).font(.nanum(13, weight: .bold))
                    if !item.isRequired {
                        Text("선택").font(.nanum(10))
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Capsule().fill(.secondary.opacity(0.18)))
                    }
                }
                Text(item.detail)
                    .font(.nanum(11, weight: .light))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if item == .virtualAudio {
                Button { showAudioGuide = true } label: {
                    Text("설정 가이드").font(.nanum(11))
                }
            }
            if state != .satisfied {
                Button { Task { await manager.install(item) } } label: {
                    Text(state == .working ? "진행 중…" : "설치").font(.nanum(11))
                }
                .disabled(manager.isBusy)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func statusIcon(_ state: DependencyManager.State) -> some View {
        switch state {
        case .satisfied:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .missing, .failed:
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
        case .working, .checking:
            ProgressView().scaleEffect(0.5)
        case .unknown:
            Image(systemName: "circle").foregroundStyle(.secondary)
        }
    }
}
