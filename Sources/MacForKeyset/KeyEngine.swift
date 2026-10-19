import Cocoa

final class KeyEngine {
    static let shared = KeyEngine()

    var config = Config.default
    /// (keyCode, flags, isModifier) → 입력을 소비했으면 true. 설정되어 있는 동안 모든 키 이벤트를 삼킨다.
    var capture: ((Int, UInt64, Bool) -> Bool)?

    var bypassRemaps = false
    private var tap: CFMachPort?
    private var swallowedKeyUps = Set<Int>()
    private let marker: Int64 = 0x4B455953

    /// flagsChanged 이벤트에서 키별 눌림 여부를 판단하는 device-dependent 마스크.
    private static let deviceMasks: [Int: UInt64] = [
        59: 0x1, 56: 0x2, 60: 0x4, 55: 0x8, 54: 0x10, 58: 0x20, 61: 0x40, 62: 0x2000, 63: 0x800000,
    ]

    var isRunning: Bool { tap != nil }

    @discardableResult
    func start() -> Bool {
        if tap != nil { return true }
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            Unmanaged<KeyEngine>.fromOpaque(refcon!).takeUnretainedValue().handle(type, event)
        }
        guard let t = CGEvent.tapCreate(
            tap: .cghidEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: CGEventMask(mask), callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        tap = t
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, t, 0), .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
        return true
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return pass
        }

        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags.rawValue
        let isModifier = type == .flagsChanged
        let isDown = type == .keyDown
            || (isModifier && flags & (Self.deviceMasks[keyCode] ?? CGEventFlags.maskAlphaShift.rawValue) != 0)
        let isRepeat = type == .keyDown && event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        let kind = isModifier ? (isDown ? "mod ↓" : "mod ↑") : (isDown ? "key ↓" : "key ↑")

        func log(_ note: String = "") {
            guard EventLog.shared.active else { return }
            EventLog.shared.add(LogEntry(kind: kind, keyCode: keyCode, isDown: isDown,
                                         flags: KeyNames.modifierSymbols(flags), chars: isModifier ? "" : Self.chars(of: event), note: note))
        }

        if event.getIntegerValueField(.eventSourceUserData) == marker {
            log("합성 이벤트")
            return pass
        }

        if let capture {
            if isDown && !isRepeat, capture(keyCode, flags, isModifier) { self.capture = nil }
            return nil
        }

        // 창 분할 단축키
        if !isModifier {
            if !isDown, swallowedKeyUps.remove(keyCode) != nil { return nil }
            if isDown, let hk = config.hotkeys.first(where: {
                $0.shortcut.keyCode == keyCode && $0.shortcut.modifiers == flags & hotkeyModifierMask
            }) {
                swallowedKeyUps.insert(keyCode)
                log("창 분할: \(hk.action.title)")
                if !isRepeat { WindowManager.apply(hk.action) }
                return nil
            }
        }

        // 키 매핑
        if !bypassRemaps, let r = config.remaps.first(where: { $0.from == keyCode }) {
            log("매핑 → \(KeyNames.name(r.to))")
            if r.to == toggleInputSource {
                if isDown && !isRepeat { InputSource.toggle() }
            } else if isModifier {
                post(r.to, down: isDown)
            } else {
                event.setIntegerValueField(.keyboardEventKeycode, value: Int64(r.to))
                return pass
            }
            return nil
        }

        log()
        return pass
    }

    private static func chars(of event: CGEvent) -> String {
        var len = 0
        var buf = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &len, unicodeString: &buf)
        return String(utf16CodeUnits: buf, count: len).filter { !$0.isNewline && !($0.asciiValue.map { $0 < 32 || $0 == 127 } ?? false) }
    }

    private func post(_ keyCode: Int, down: Bool) {
        guard let e = CGEvent(keyboardEventSource: CGEventSource(stateID: .privateState),
                              virtualKey: CGKeyCode(keyCode), keyDown: down) else { return }
        e.flags = []
        e.setIntegerValueField(.eventSourceUserData, value: marker)
        e.post(tap: .cghidEventTap)
    }
}
