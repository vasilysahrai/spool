import Foundation

enum MacroEventKind: String, Codable {
    case keyDown
    case keyUp
    case mouseDown
    case mouseUp
}

struct MacroEvent: Codable, Identifiable {
    var id: UUID = UUID()
    var kind: MacroEventKind
    var time: TimeInterval
    var keyCode: UInt16?
    var modifiers: UInt64?
    var x: Double?
    var y: Double?

    private enum CodingKeys: String, CodingKey {
        case kind, time, keyCode, modifiers, x, y
    }
}

struct Macro: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var events: [MacroEvent]
    var duration: TimeInterval
    var createdAt: Date

    static func == (lhs: Macro, rhs: Macro) -> Bool {
        lhs.id == rhs.id
    }
}

struct HotkeyDef: Codable, Equatable, Hashable {
    var keyCode: UInt32
    var modifiers: UInt32
    var label: String
}

struct HotkeyConfig: Codable, Equatable {
    var record: HotkeyDef?
    var pause: HotkeyDef?
    var stop: HotkeyDef?
    var play: HotkeyDef?

    static let `default` = HotkeyConfig(
        record: HotkeyDef(keyCode: 0x61, modifiers: 0, label: "F6"),
        pause:  HotkeyDef(keyCode: 0x62, modifiers: 0, label: "F7"),
        stop:   HotkeyDef(keyCode: 0x64, modifiers: 0, label: "F8"),
        play:   HotkeyDef(keyCode: 0x65, modifiers: 0, label: "F9")
    )
}
