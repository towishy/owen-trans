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
                // 폰트를 줄이지 않는다: 짧으면 박스가 좁아지고,
                // 길면 maxWidth 까지 옆으로 늘어난 뒤 줄바꿈한다.
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(alignment: .leading)
        // 한 줄 최대 너비(이보다 길면 줄바꿈). 창 너비는 컨트롤러가 내용에 맞게 조절.
        .frame(maxWidth: NotchOverlayMetrics.maxContentWidth, alignment: .leading)
        .padding(.horizontal, 22)
        // 상단은 화면 맨 위(노치/메뉴바)에 붙으므로, 텍스트가 가려지지 않도록 여백을 크게.
        .padding(.top, 40)
        .padding(.bottom, 18)
        // 노치를 덮도록 검정 박스 자체에 최소 너비를 강제(짧은 문장도 노치만큼 넓게).
        .frame(minWidth: model.minBoxWidth, alignment: .center)
        .background(
            NotchExtensionShape(cornerRadius: 26)
                .fill(.black.opacity(0.92))
                .overlay(
                    NotchExtensionShape(cornerRadius: 26)
                        .stroke(.white.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.45), radius: 18, y: 8)
        )
        .fixedSize()
        .animation(.easeInOut(duration: 0.18), value: model.translation)
    }
}

/// 오버레이 레이아웃 공통 수치.
enum NotchOverlayMetrics {
    /// 한 줄 텍스트 최대 너비(이보다 길면 줄바꿈).
    static let maxContentWidth: CGFloat = 560
    /// 박스 최소 너비.
    static let minBoxWidth: CGFloat = 300
    /// 박스 최대 너비(메뉴바 좌우 메뉴 글자를 가리지 않도록 제한).
    static let maxBoxWidth: CGFloat = 640
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
