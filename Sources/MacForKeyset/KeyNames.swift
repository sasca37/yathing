import CoreGraphics

enum KeyNames {
    static let names: [Int: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V", 11: "B", 12: "Q",
        13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5",
        24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I",
        35: "P", 36: "Return", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
        45: "N", 46: "M", 47: ".", 48: "Tab", 49: "Space", 50: "`", 51: "Delete", 53: "Esc",
        54: "Right ⌘", 55: "Left ⌘", 56: "Left ⇧", 57: "Caps Lock", 58: "Left ⌥", 59: "Left ⌃",
        60: "Right ⇧", 61: "Right ⌥", 62: "Right ⌃", 63: "fn",
        64: "F17", 79: "F18", 80: "F19", 90: "F20",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11", 105: "F13", 106: "F16",
        107: "F14", 109: "F10", 111: "F12", 113: "F15", 114: "Help", 115: "Home", 116: "Page Up",
        117: "Fwd Delete", 118: "F4", 119: "End", 120: "F2", 121: "Page Down", 122: "F1",
        123: "←", 124: "→", 125: "↓", 126: "↑",
    ]

    static func name(_ keyCode: Int) -> String {
        if keyCode == toggleInputSource { return "입력 소스 전환" }
        return names[keyCode] ?? "Key \(keyCode)"
    }

    static func modifierSymbols(_ flags: UInt64) -> String {
        let f = CGEventFlags(rawValue: flags)
        var s = ""
        if f.contains(.maskAlphaShift) { s += "⇪" }
        if f.contains(.maskControl) { s += "⌃" }
        if f.contains(.maskAlternate) { s += "⌥" }
        if f.contains(.maskShift) { s += "⇧" }
        if f.contains(.maskCommand) { s += "⌘" }
        if f.contains(.maskSecondaryFn) { s += "fn" }
        return s
    }
}
