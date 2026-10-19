import Foundation
import CoreGraphics

/// `Remap.to` 값으로 쓰면 키를 보내는 대신 입력 소스를 전환한다.
let toggleInputSource = -1

let hotkeyModifierMask: UInt64 = CGEventFlags([.maskCommand, .maskAlternate, .maskControl, .maskShift]).rawValue

struct Remap: Codable, Identifiable, Equatable {
    var from: Int
    var to: Int
    var id: Int { from }
}

enum WindowAction: String, Codable, CaseIterable {
    case left, right, top, bottom, maximize

    var title: String {
        switch self {
        case .left: return "왼쪽 절반"
        case .right: return "오른쪽 절반"
        case .top: return "위쪽 절반"
        case .bottom: return "아래쪽 절반"
        case .maximize: return "최대화"
        }
    }
}

struct Shortcut: Codable, Equatable {
    var keyCode: Int
    var modifiers: UInt64

    var display: String { KeyNames.modifierSymbols(modifiers) + KeyNames.name(keyCode) }
}

struct Hotkey: Codable, Identifiable, Equatable {
    var action: WindowAction
    var shortcut: Shortcut
    var id: String { action.rawValue }
}

struct Config: Codable, Equatable {
    var remaps: [Remap]
    var hotkeys: [Hotkey]

    static let `default`: Config = {
        let mods = CGEventFlags([.maskControl, .maskAlternate]).rawValue
        func hk(_ a: WindowAction, _ key: Int) -> Hotkey { Hotkey(action: a, shortcut: Shortcut(keyCode: key, modifiers: mods)) }
        return Config(
            remaps: [Remap(from: 54, to: 113)],  // Right ⌘ → F15
            hotkeys: [hk(.left, 123), hk(.right, 124), hk(.bottom, 125), hk(.top, 126), hk(.maximize, 36)]
        )
    }()

    static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MacForKeyset", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("config.json")
    }

    static func load() -> Config {
        guard let data = try? Data(contentsOf: fileURL), let cfg = try? JSONDecoder().decode(Config.self, from: data) else {
            return .default
        }
        return cfg
    }

    func save() {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(self) { try? data.write(to: Self.fileURL, options: .atomic) }
    }
}
