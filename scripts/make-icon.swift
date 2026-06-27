#!/usr/bin/env swift
import AppKit

// OwenTrans 앱 아이콘 생성기.
// "O"(Owen) 링 + 음성 파형을 인디고→에메랄드 그라데이션 라운드 스퀘어 위에 그린다.
// 1024px PNG 렌더 → iconset → iconutil 로 AppIcon.icns 생성.

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let ctx = NSGraphicsContext.current!.cgContext

    // 배경 라운드 스퀘어(macOS superellipse 느낌의 둥근 사각형) + 그라데이션.
    let inset = size * 0.06
    let rect = CGRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
    let radius = rect.width * 0.225
    let bgPath = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()
    let colors = [NSColor(red: 0.31, green: 0.27, blue: 0.90, alpha: 1).cgColor,  // #4F46E5 indigo
                  NSColor(red: 0.06, green: 0.72, blue: 0.51, alpha: 1).cgColor]  // #10B981 emerald
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: colors as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient,
                           start: CGPoint(x: rect.minX, y: rect.maxY),
                           end: CGPoint(x: rect.maxX, y: rect.minY),
                           options: [])
    ctx.restoreGState()

    // 흰색 "O" 링.
    let ringLine = size * 0.075
    let ringInset = size * 0.27
    let ringRect = CGRect(x: ringInset, y: ringInset,
                          width: size - 2 * ringInset, height: size - 2 * ringInset)
    ctx.setStrokeColor(NSColor.white.cgColor)
    ctx.setLineWidth(ringLine)
    ctx.strokeEllipse(in: ringRect)

    // 링 안쪽 중앙의 음성 파형 막대 4개(흰색).
    let centerY = size / 2
    let barWidth = size * 0.045
    let gap = size * 0.045
    let halfHeights: [CGFloat] = [0.07, 0.13, 0.09, 0.15].map { $0 * size }
    let count = halfHeights.count
    let totalWidth = CGFloat(count) * barWidth + CGFloat(count - 1) * gap
    var x = size / 2 - totalWidth / 2
    ctx.setFillColor(NSColor.white.cgColor)
    for half in halfHeights {
        let bar = CGRect(x: x, y: centerY - half, width: barWidth, height: half * 2)
        let p = CGPath(roundedRect: bar, cornerWidth: barWidth / 2, cornerHeight: barWidth / 2, transform: nil)
        ctx.addPath(p)
        ctx.fillPath()
        x += barWidth + gap
    }

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, size: Int, to url: URL) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                              isPlanar: false, colorSpaceName: .deviceRGB,
                              bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    drawIcon(size: CGFloat(size)).draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: url)
}

let fm = FileManager.default
let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let iconset = outDir.appendingPathComponent("AppIcon.iconset")
try? fm.removeItem(at: iconset)
try! fm.createDirectory(at: iconset, withIntermediateDirectories: true)

// iconset 표준 사이즈.
let specs: [(name: String, px: Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]
for spec in specs {
    writePNG(NSImage(), size: spec.px, to: iconset.appendingPathComponent(spec.name))
}

// iconutil 로 .icns 생성.
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path,
                     "-o", outDir.appendingPathComponent("AppIcon.icns").path]
try! process.run()
process.waitUntilExit()
try? fm.removeItem(at: iconset)
print("✓ AppIcon.icns 생성: \(outDir.appendingPathComponent("AppIcon.icns").path)")
