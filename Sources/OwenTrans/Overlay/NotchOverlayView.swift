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
                // 고정 가로 폭 안에서 줄바꿈, 세로는 최대 3줄.
                .lineLimit(3)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        // 상단은 화면 맨 위(노치/메뉴바)에 붙으므로, 텍스트가 가려지지 않도록 여백을 크게.
        .padding(.top, 40)
        .padding(.bottom, 18)
        // 환경설정에서 지정한 고정 가로 폭(동적 리사이즈 없음 → 눈 피로 감소).
        .frame(width: model.boxWidth)
        .background(
            NotchExtensionShape(cornerRadius: 26)
                .fill(.black.opacity(0.92))
                .overlay(
                    NotchExtensionShape(cornerRadius: 26)
                        .stroke(.white.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.45), radius: 18, y: 8)
        )
        // 세로 높이만 내용에 맞춰 변함(최대 3줄).
        .fixedSize(horizontal: false, vertical: true)
        .animation(.easeInOut(duration: 0.15), value: model.translation)
    }
}

/// 오버레이 레이아웃 공통 수치.
enum NotchOverlayMetrics {
    /// 가로 폭 슬라이더 범위.
    static let minWidth: CGFloat = 320
    static let maxWidth: CGFloat = 900
}

/// 노치가 아래로 확장된 듯한 모양: 상단은 평평(화면 최상단에 밀착),
/// 하단 두 모서리만 둥글게 처리한다.
struct NotchExtensionShape: Shape {
    var cornerRadius: CGFloat = 26

    func path(in rect: CGRect) -> Path {
        let r = min(cornerRadius, min(rect.width, rect.height) / 2)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX - r, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - r),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        p.closeSubpath()
        return p
    }
}

extension Font {
    /// 나눔스퀘어 SwiftUI 폰트.
    static func nanum(_ size: CGFloat, weight: FontProvider.Weight = .regular) -> Font {
        Font(FontProvider.nanum(size, weight: weight) as CTFont)
    }
}
