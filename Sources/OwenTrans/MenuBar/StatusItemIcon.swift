import AppKit

/// 메뉴바 상태 아이콘을 코드로 그린다.
///
/// 디자인: "O"(Owen) 링 안에 음성 파형(waveform) 막대 4개.
/// 실시간 음성 번역 앱의 정체성을 한 글자로 형상화한다.
/// 모든 픽셀을 검정으로 그리고 `isTemplate = true` 로 설정해
/// 메뉴바의 라이트/다크 및 강조 색상에 자동으로 맞춰진다.
enum StatusItemIcon {

    /// 기본(대기) 아이콘: 링 + 파형 막대.
    static func make(size: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            drawRing(in: ctx, size: size)
            drawWaveform(in: ctx, size: size)
            return true
        }
        image.isTemplate = true
        return image
    }

    // MARK: - 구성 요소

    private static func drawRing(in ctx: CGContext, size: CGFloat) {
        let lineWidth = size * 0.11
        let inset = lineWidth / 2 + size * 0.07
        let rect = CGRect(x: inset, y: inset,
                          width: size - 2 * inset,
                          height: size - 2 * inset)
        ctx.setLineWidth(lineWidth)
        ctx.setStrokeColor(NSColor.black.cgColor)
        ctx.strokeEllipse(in: rect)
    }

    /// 링 안쪽 중앙에 음성 파형(높이가 다른 막대 4개)을 그린다.
    private static func drawWaveform(in ctx: CGContext, size: CGFloat) {
        let centerY = size / 2
        let barWidth = size * 0.085
        let gap = size * 0.085
        // 막대별 절반 높이(중심 기준 위아래) — 파형처럼 변주.
        let halfHeights: [CGFloat] = [0.12, 0.24, 0.17, 0.28].map { $0 * size }
        let count = halfHeights.count
        let totalWidth = CGFloat(count) * barWidth + CGFloat(count - 1) * gap
        var x = size / 2 - totalWidth / 2

        ctx.setFillColor(NSColor.black.cgColor)
        for half in halfHeights {
            let bar = CGRect(x: x, y: centerY - half,
                             width: barWidth, height: half * 2)
            let path = CGPath(roundedRect: bar,
                              cornerWidth: barWidth / 2,
                              cornerHeight: barWidth / 2,
                              transform: nil)
            ctx.addPath(path)
            ctx.fillPath()
            x += barWidth + gap
        }
    }
}
