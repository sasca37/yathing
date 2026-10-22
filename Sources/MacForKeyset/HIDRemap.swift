import Foundation

/// modifier 키 → F13–F20 매핑은 이벤트 탭으로는 시스템 modifier 상태를 못 지우므로
/// HID 드라이버 단계(hidutil)에서 적용한다. 재부팅하면 사라지므로 앱 실행 시마다 다시 적용한다.
enum HIDRemap {
    private static let modifierUsage: [Int: UInt64] = [
        59: 0xE0, 56: 0xE1, 58: 0xE2, 55: 0xE3, 62: 0xE4, 60: 0xE5, 61: 0xE6, 54: 0xE7, 57: 0x39,
    ]
    private static let fKeyUsage: [Int: UInt64] = [
        105: 0x68, 107: 0x69, 113: 0x6A, 106: 0x6B, 64: 0x6C, 79: 0x6D, 80: 0x6E, 90: 0x6F,
    ]
    private static var applied = false

    static func apply(_ config: Config) {
        let page: UInt64 = 0x7_0000_0000
        var pairs = config.activeRemaps.compactMap { r -> (UInt64, UInt64)? in
            guard let src = modifierUsage[r.from], let dst = fKeyUsage[r.to] else { return nil }
            return (src, dst)
        }
        if config.windowsKeyboard {
            // 윈도우 키보드: Alt 자리(Left ⌥) → ⌘, Win 자리(Left ⌘) → ⌥. 사용자 매핑이 있는 키는 건드리지 않는다.
            let used = Set(pairs.map { $0.0 })
            pairs += [(0xE2, 0xE3), (0xE3, 0xE2)].filter { !used.contains($0.0) }
        }
        let entries = pairs.map {
            ["HIDKeyboardModifierMappingSrc": page | $0.0, "HIDKeyboardModifierMappingDst": page | $0.1]
        }
        if entries.isEmpty && !applied { return }
        applied = true
        guard let json = try? JSONSerialization.data(withJSONObject: ["UserKeyMapping": entries]),
              let arg = String(data: json, encoding: .utf8) else { return }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        p.arguments = ["property", "--set", arg]
        p.standardOutput = FileHandle.nullDevice
        try? p.run()
        p.waitUntilExit()
    }

    static func reset() { if applied { apply(Config(remaps: [], hotkeys: [])) } }
}
