import AppKit
import CoreText

/// 앱 전역에서 사용하는 폰트 공급자.
///
/// 한글 글씨체는 **나눔스퀘어(NanumSquare)** 로 통일한다.
/// - 시스템에 설치되어 있으면 그대로 사용한다.
/// - 없으면 `Resources/Fonts/` 에 동봉한 ttf/otf 를 런타임에 등록해 사용한다.
/// - 그래도 없으면 시스템 폰트로 안전하게 폴백한다.
enum FontProvider {

    /// 나눔스퀘어 굵기별 PostScript / 패밀리 후보 이름.
    enum Weight {
        case light, regular, bold, extraBold

        /// 우선순위 순서의 폰트 이름 후보.
        var candidates: [String] {
            switch self {
            case .light:     return ["NanumSquareOTF_acL", "NanumSquareL", "NanumSquareOTFL", "NanumSquare Light", "NanumSquare"]
            case .regular:   return ["NanumSquareOTF_acR", "NanumSquareR", "NanumSquareOTFR", "NanumSquare", "NanumSquare Regular"]
            case .bold:      return ["NanumSquareOTF_acB", "NanumSquareB", "NanumSquareOTFB", "NanumSquare Bold", "NanumSquare"]
            case .extraBold: return ["NanumSquareOTF_acEB", "NanumSquareEB", "NanumSquareOTFEB", "NanumSquareExtraBold", "NanumSquare"]
            }
        }

        var systemWeight: NSFont.Weight {
            switch self {
            case .light:     return .light
            case .regular:   return .regular
            case .bold:      return .bold
            case .extraBold: return .heavy
            }
        }
    }

    private static var didRegisterBundledFonts = false

    /// 앱 시작 시 1회 호출 — 동봉 폰트를 런타임 등록한다.
    static func registerBundledFonts() {
        guard !didRegisterBundledFonts else { return }
        didRegisterBundledFonts = true

        guard let fontsURL = Bundle.module.url(forResource: "Fonts", withExtension: nil) else {
            return
        }
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: fontsURL,
                                                      includingPropertiesForKeys: nil) else {
            return
        }
        for url in items where ["ttf", "otf"].contains(url.pathExtension.lowercased()) {
            var error: Unmanaged<CFError>?
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
            // 이미 등록되어 있어도 무시한다.
        }
    }

    /// 나눔스퀘어 폰트를 반환한다. 없으면 동일 크기 시스템 폰트로 폴백.
    static func nanum(_ size: CGFloat, weight: Weight = .regular) -> NSFont {
        registerBundledFonts()
        for name in weight.candidates {
            if let font = NSFont(name: name, size: size) {
                return font
            }
        }
        return NSFont.systemFont(ofSize: size, weight: weight.systemWeight)
    }

    /// 메뉴 항목 기본 폰트.
    static var menu: NSFont { nanum(13, weight: .regular) }
}

extension NSMenuItem {
    /// 나눔스퀘어 폰트를 적용한 메뉴 항목 제목.
    func applyNanumTitle(_ title: String, weight: FontProvider.Weight = .regular) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: FontProvider.nanum(13, weight: weight)
        ]
        self.attributedTitle = NSAttributedString(string: title, attributes: attrs)
    }
}
