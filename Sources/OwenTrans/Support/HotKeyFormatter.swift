import AppKit
import Carbon.HIToolbox

/// 단축키 표시·변환 유틸리티.
enum HotKeyFormatter {

    /// Carbon modifier 마스크 + keyCode → "⌥⌘T" 형태 문자열.
    static func string(keyCode: Int, modifiers: Int) -> String {
        var result = ""
        if modifiers & controlKey != 0 { result += "⌃" }
        if modifiers & optionKey != 0 { result += "⌥" }
        if modifiers & shiftKey != 0 { result += "⇧" }
        if modifiers & cmdKey != 0 { result += "⌘" }
        result += keyName(keyCode)
        return result
    }

    /// AppKit modifier flags → Carbon 마스크.
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> Int {
        var mods = 0
        if flags.contains(.control) { mods |= controlKey }
        if flags.contains(.option) { mods |= optionKey }
        if flags.contains(.shift) { mods |= shiftKey }
        if flags.contains(.command) { mods |= cmdKey }
        return mods
    }

    /// 단축키로 사용할 수 있는 조합인지(수정자 1개 이상 + 일반 키).
    static func isValid(keyCode: Int, modifiers: Int) -> Bool {
        let hasModifier = modifiers & (controlKey | optionKey | shiftKey | cmdKey) != 0
        return hasModifier && keyCode >= 0
    }

    static func keyName(_ keyCode: Int) -> String {
        if let special = specialKeys[keyCode] { return special }
        // 문자 키 매핑.
        let map: [Int: String] = [
            0x00: "A", 0x0B: "B", 0x08: "C", 0x02: "D", 0x0E: "E", 0x03: "F",
            0x05: "G", 0x04: "H", 0x22: "I", 0x26: "J", 0x28: "K", 0x25: "L",
            0x2E: "M", 0x2D: "N", 0x1F: "O", 0x23: "P", 0x0C: "Q", 0x0F: "R",
            0x01: "S", 0x11: "T", 0x20: "U", 0x09: "V", 0x0D: "W", 0x07: "X",
            0x10: "Y", 0x06: "Z",
            0x1D: "0", 0x12: "1", 0x13: "2", 0x14: "3", 0x15: "4", 0x17: "5",
            0x16: "6", 0x1A: "7", 0x1C: "8", 0x19: "9",
        ]
        return map[keyCode] ?? "Key\(keyCode)"
    }

    private static let specialKeys: [Int: String] = [
        0x31: "Space", 0x24: "↩", 0x30: "⇥", 0x33: "⌫", 0x35: "⎋",
        0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4", 0x60: "F5", 0x61: "F6",
    ]
}
