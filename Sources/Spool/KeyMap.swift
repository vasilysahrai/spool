import AppKit
import Carbon.HIToolbox

enum KeyMap {
    static let names: [UInt16: String] = [
        0x00: "A", 0x01: "S", 0x02: "D", 0x03: "F", 0x04: "H", 0x05: "G",
        0x06: "Z", 0x07: "X", 0x08: "C", 0x09: "V", 0x0B: "B", 0x0C: "Q",
        0x0D: "W", 0x0E: "E", 0x0F: "R", 0x10: "Y", 0x11: "T", 0x1F: "O",
        0x20: "U", 0x22: "I", 0x23: "P", 0x25: "L", 0x26: "J", 0x28: "K",
        0x2D: "N", 0x2E: "M",
        0x12: "1", 0x13: "2", 0x14: "3", 0x15: "4", 0x17: "5", 0x16: "6",
        0x1A: "7", 0x1C: "8", 0x19: "9", 0x1D: "0",
        0x18: "=", 0x1B: "-", 0x21: "[", 0x1E: "]", 0x27: "'", 0x29: ";",
        0x2A: "\\", 0x2B: ",", 0x2C: "/", 0x2F: ".", 0x32: "`",
        0x24: "RET", 0x30: "TAB", 0x31: "SPC", 0x33: "DEL", 0x35: "ESC",
        0x36: "RCMD", 0x37: "CMD", 0x38: "SHIFT", 0x39: "CAPS", 0x3A: "OPT",
        0x3B: "CTRL", 0x3C: "RSHIFT", 0x3D: "ROPT", 0x3E: "RCTRL", 0x3F: "FN",
        0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4", 0x60: "F5", 0x61: "F6",
        0x62: "F7", 0x64: "F8", 0x65: "F9", 0x6D: "F10", 0x67: "F11", 0x6F: "F12",
        0x69: "F13", 0x6B: "F14", 0x71: "F15", 0x6A: "F16", 0x40: "F17",
        0x4F: "F18", 0x50: "F19", 0x5A: "F20",
        0x7B: "←", 0x7C: "→", 0x7D: "↓", 0x7E: "↑",
        0x73: "HOME", 0x77: "END", 0x74: "PGUP", 0x79: "PGDN",
        0x75: "FWDDEL"
    ]

    static func name(for keyCode: UInt16) -> String {
        if let n = names[keyCode] { return n }
        return "k\(keyCode)"
    }

    static func mouseLabel(_ button: Int) -> String {
        button == 1 ? "RCLICK" : "LCLICK"
    }

    static func carbonModifiers(from f: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if f.contains(.command) { m |= UInt32(cmdKey) }
        if f.contains(.option)  { m |= UInt32(optionKey) }
        if f.contains(.control) { m |= UInt32(controlKey) }
        if f.contains(.shift)   { m |= UInt32(shiftKey) }
        return m
    }

    static func label(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> String {
        var p = ""
        if modifiers.contains(.control) { p += "⌃" }
        if modifiers.contains(.option)  { p += "⌥" }
        if modifiers.contains(.shift)   { p += "⇧" }
        if modifiers.contains(.command) { p += "⌘" }
        p += name(for: keyCode)
        return p
    }
}
