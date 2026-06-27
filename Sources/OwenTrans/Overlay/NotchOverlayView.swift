import SwiftUI

/// 노치 오버레이의 SwiftUI 콘텐츠.
///
/// 어두운 캡슐 안에 영어 원문(작게, 흐리게)과 한글 번역(크게, 또렷하게)을 표시한다.
/// 모든 텍스트는 나눔스퀘어 폰트를 사용한다.
struct NotchOverlayView: View {
    @ObservedObject var model: OverlayModel
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if settings.showsOriginalText && !model.original.isEmpty {
                Text(model.original)
                    .font(.nanum(11, weight: .light))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            Text(model.translation.isEmpty ? " " : model.translation)
                .font(.nanum(17, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.black.opacity(0.82))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 16, y: 6)
        )
        .animation(.easeInOut(duration: 0.18), value: model.translation)
        .padding(6)
    }
}

extension Font {
    /// 나눔스퀘어 SwiftUI 폰트.
    static func nanum(_ size: CGFloat, weight: FontProvider.Weight = .regular) -> Font {
        Font(FontProvider.nanum(size, weight: weight) as CTFont)
    }
}
