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

enum KeyboardMode: String, Codable, CaseIterable {
    /// 아무것도 바꾸지 않는다.
    case mac
    /// 윈도우 키보드를 맥 배열로: Alt 자리 → ⌘, Win 자리 → ⌥.
    case windowsAsMac
    /// 윈도우 키보드를 윈도우 단축키로: Ctrl → ⌘, Win → ⌃, 그리고 WindowsShortcuts 변환.
    case windowsAsWindows

    var title: String {
        switch self {
        case .mac: return "맥 키보드"
        case .windowsAsMac: return "윈도우 키보드 · 맥처럼"
        case .windowsAsWindows: return "윈도우 키보드 · 윈도우처럼"
        }
    }

    var example: String {
        switch self {
        case .mac: return "키를 바꾸지 않아요"
        case .windowsAsMac: return "Alt 자리를 ⌘로 써요 (Alt+C로 복사)"
        case .windowsAsWindows: return "윈도우 단축키를 그대로 써요 (Ctrl+C로 복사)"
        }
    }
}

struct Config: Codable, Equatable {
    var remaps: [Remap]
    var hotkeys: [Hotkey]
    var keyboardMode = KeyboardMode.mac

    /// 실제로 적용할 매핑. 윈도우 키보드 모드에선 오른쪽 Alt(한/영 키)가 우측 ⌘ 매핑을 따른다.
    var activeRemaps: [Remap] {
        guard keyboardMode != .mac, !remaps.contains(where: { $0.from == 61 }) else { return remaps }
        return remaps + [Remap(from: 61, to: remaps.first { $0.from == 54 }?.to ?? 113)]
    }

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

extension Config {
    private enum LegacyKeys: String, CodingKey { case windowsKeyboard }

    /// 예전 설정 파일에는 keyboardMode가 없다. windowsKeyboard(Bool)가 켜져 있었으면 "맥처럼"으로 옮긴다.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        remaps = try c.decode([Remap].self, forKey: .remaps)
        hotkeys = try c.decode([Hotkey].self, forKey: .hotkeys)
        if let mode = try c.decodeIfPresent(KeyboardMode.self, forKey: .keyboardMode) {
            keyboardMode = mode
        } else {
            let legacy = try decoder.container(keyedBy: LegacyKeys.self)
            keyboardMode = try legacy.decodeIfPresent(Bool.self, forKey: .windowsKeyboard) == true ? .windowsAsMac : .mac
        }
    }
}
