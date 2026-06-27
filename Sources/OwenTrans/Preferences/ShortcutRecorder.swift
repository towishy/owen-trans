import SwiftUI
import AppKit

/// 클릭하면 다음 키 입력을 받아 단축키로 기록하는 컨트롤.
struct ShortcutRecorder: View {
    let title: String
    @Binding var keyCode: Int
    @Binding var modifiers: Int
    var onChange: () -> Void

    @State private var recording = false

    var body: some View {
        HStack {
            Text(title).font(.nanum(13)).frame(width: 110, alignment: .leading)
            RecorderField(keyCode: $keyCode, modifiers: $modifiers, recording: $recording, onChange: onChange)
                .frame(height: 24)
                .frame(maxWidth: .infinity)
        }
    }
}

private struct RecorderField: NSViewRepresentable {
    @Binding var keyCode: Int
    @Binding var modifiers: Int
    @Binding var recording: Bool
    var onChange: () -> Void

    func makeNSView(context: Context) -> RecorderNSView {
        let view = RecorderNSView()
        view.onCapture = { code, mods in
            keyCode = code
            modifiers = mods
            onChange()
        }
        return view
    }

    func updateNSView(_ nsView: RecorderNSView, context: Context) {
        nsView.keyCode = keyCode
        nsView.modifiers = modifiers
        nsView.needsDisplay = true
    }
}

/// 키 입력을 캡처하는 NSView.
final class RecorderNSView: NSView {
    var keyCode = 0
    var modifiers = 0
    var onCapture: ((Int, Int) -> Void)?
    private var recording = false

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let bg = NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6)
        (recording ? NSColor.controlAccentColor.withAlphaComponent(0.18)
                   : NSColor.textBackgroundColor.withAlphaComponent(0.6)).setFill()
        bg.fill()
        NSColor.separatorColor.setStroke()
        bg.lineWidth = 1
        bg.stroke()

        let text = recording ? "키를 누르세요…" : HotKeyFormatter.string(keyCode: keyCode, modifiers: modifiers)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: recording ? NSColor.controlAccentColor : NSColor.labelColor
        ]
        let size = text.size(withAttributes: attrs)
        text.draw(at: NSPoint(x: (bounds.width - size.width) / 2,
                              y: (bounds.height - size.height) / 2), withAttributes: attrs)
    }

    override func mouseDown(with event: NSEvent) {
        recording = true
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        guard recording else { super.keyDown(with: event); return }
        let mods = HotKeyFormatter.carbonModifiers(from: event.modifierFlags)
        let code = Int(event.keyCode)
        if HotKeyFormatter.isValid(keyCode: code, modifiers: mods) {
            keyCode = code
            modifiers = mods
            onCapture?(code, mods)
        }
        recording = false
        needsDisplay = true
    }

    override func resignFirstResponder() -> Bool {
        recording = false
        needsDisplay = true
        return true
    }
}
