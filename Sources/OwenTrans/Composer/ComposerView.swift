import SwiftUI

/// 플로팅 입력창 UI: 검은 라운드 박스 + 한글 입력 + 영어 결과 + 복사/음성/닫기 아이콘.
struct ComposerView: View {
    @ObservedObject var model: ComposerModel
    var onClose: () -> Void
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 헤더(드래그 영역 겸용) + 닫기
            HStack(spacing: 6) {
                Image(systemName: "character.bubble.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.7))
                Text("한글 → 영어")
                    .font(.nanum(11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                iconButton("xmark") { onClose() }
            }

            // 한글 입력
            ZStack(alignment: .topLeading) {
                if model.input.isEmpty {
                    Text("여기에 한글을 입력하세요 (⌘↵ 번역)")
                        .font(.nanum(13))
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 6)
                }
                TextEditor(text: $model.input)
                    .font(.nanum(13))
                    .foregroundStyle(.white)
                    .scrollContentBackground(.hidden)
                    .frame(height: 56)
                    .focused($inputFocused)
                    .onSubmit { model.translate() }
            }
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.10), lineWidth: 1))

            // 번역 버튼 행
            HStack {
                if !model.statusMessage.isEmpty {
                    Text(model.statusMessage)
                        .font(.nanum(11, weight: .light))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Button { model.translate() } label: {
                    HStack(spacing: 4) {
                        if model.isTranslating { ProgressView().scaleEffect(0.5).frame(width: 12, height: 12) }
                        Text("영어로 번역").font(.nanum(12, weight: .bold))
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(model.isTranslating)
            }

            // 영어 결과 + 복사/음성
            HStack(alignment: .top, spacing: 8) {
                Text(model.output.isEmpty ? "영어 번역 결과가 여기에 표시됩니다." : model.output)
                    .font(.nanum(14, weight: model.output.isEmpty ? .light : .bold))
                    .foregroundStyle(model.output.isEmpty ? .white.opacity(0.35) : .white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                VStack(spacing: 6) {
                    iconButton("doc.on.doc") { model.copyOutput() }
                        .disabled(model.output.isEmpty)
                    iconButton("speaker.wave.2.fill") { model.speakOutput() }
                        .disabled(model.output.isEmpty)
                }
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.06)))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.black.opacity(0.88))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 1))
                .shadow(color: .black.opacity(0.45), radius: 18, y: 8)
        )
        .frame(width: 420)
        .onAppear { inputFocused = true }
    }

    private func iconButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 26, height: 26)
                .background(RoundedRectangle(cornerRadius: 7).fill(.white.opacity(0.10)))
        }
        .buttonStyle(.plain)
    }
}
