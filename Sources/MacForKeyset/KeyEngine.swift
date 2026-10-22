import Cocoa

final class KeyEngine {
    static let shared = KeyEngine()

    var config = Config.default
    /// (keyCode, flags, isModifier) → 입력을 소비했으면 true. 설정되어 있는 동안 모든 키 이벤트를 삼킨다.
    var capture: ((Int, UInt64, Bool) -> Bool)?

    var bypassRemaps = false
    private var tap: CFMachPort?
    private var swallowedKeyUps = Set<Int>()
    /// 윈도우 단축키로 바꿔 보낸 keyDown. keyUp도 같은 키로 바꿔야 앱에서 키가 눌린 채 남지 않는다.
    private var translatedKeyUps: [Int: (Int, CGEventFlags)] = [:]
    /// Alt+Tab 중: Alt를 누르고 있는 동안 ⌘를 대신 눌러 둔 상태 (맥 앱 전환기는 ⌘가 눌려 있어야 유지된다).
    private var altTabActive = false
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
            endAltTab()
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

        // Alt+Tab ("윈도우처럼" 모드): ⌘를 대신 눌러 맥 앱 전환기를 띄우고, Alt를 떼면 ⌘도 뗀다.
        // 그동안 들어오는 키(Tab, Shift, Esc, 방향키)는 ⌥ 대신 ⌘가 눌린 것으로 바꾼다.
        let altOnly = flags & hotkeyModifierMask & ~CGEventFlags.maskShift.rawValue == CGEventFlags.maskAlternate.rawValue
        if altTabActive {
            if isModifier && flags & CGEventFlags.maskAlternate.rawValue == 0 {
                endAltTab()
                log("Alt+Tab 끝")
                return pass
            }
            event.flags = event.flags.subtracting(.maskAlternate).union(.maskCommand)
            log("Alt+Tab")
            return pass
        }
        if isDown, !isModifier, keyCode == 48, altOnly, config.keyboardMode == .windowsAsWindows, !bypassRemaps {
            altTabActive = true
            post(55, down: true, flags: .maskCommand)
            post(48, down: true, flags: event.flags.subtracting(.maskAlternate).union(.maskCommand))
            log("Alt+Tab → 앱 전환")
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
                // AX 호출은 대상 앱이 멈추면 오래 걸리므로 탭 콜백 밖에서 실행한다 (탭 타임아웃 방지).
                if !isRepeat { DispatchQueue.main.async { WindowManager.apply(hk.action) } }
                return nil
            }

            // 윈도우 단축키 ("윈도우처럼" 모드). 사용자 매핑의 대상 키(예: F13)는 건드리지 않는다.
            if !isDown, let (key, mods) = translatedKeyUps.removeValue(forKey: keyCode) {
                Self.rewrite(event, keyCode: key, modifiers: mods)
                return pass
            }
            if isDown, config.keyboardMode == .windowsAsWindows, !bypassRemaps,
               !config.activeRemaps.contains(where: { $0.to == keyCode }),
               let out = WindowsShortcuts.match(keyCode: keyCode, flags: flags) {
                switch out {
                case .key(let key, let mods):
                    log("윈도우 단축키 → \(KeyNames.modifierSymbols(mods.rawValue))\(KeyNames.name(key))")
                    translatedKeyUps[keyCode] = (key, mods)
                    Self.rewrite(event, keyCode: key, modifiers: mods)
                    return pass
                case .action(let action):
                    log("윈도우 단축키")
                    swallowedKeyUps.insert(keyCode)
                    if !isRepeat { DispatchQueue.main.async(execute: action) }
                    return nil
                }
            }
        }

        // 키 매핑
        if !bypassRemaps, let r = config.activeRemaps.first(where: { $0.from == keyCode }) {
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

    /// 이벤트의 키와 modifier를 바꾼다. Caps Lock 상태는 유지하고, 방향키 등에 맞는 fn/numpad 플래그를 붙인다.
    private static func rewrite(_ event: CGEvent, keyCode: Int, modifiers: CGEventFlags) {
        var flags = modifiers.union(event.flags.intersection(.maskAlphaShift))
        if (123...126).contains(keyCode) { flags.formUnion([.maskNumericPad, .maskSecondaryFn]) }
        if [103, 115, 117, 119].contains(keyCode) { flags.insert(.maskSecondaryFn) }
        event.setIntegerValueField(.keyboardEventKeycode, value: Int64(keyCode))
        event.flags = flags
    }

    private func endAltTab() {
        guard altTabActive else { return }
        altTabActive = false
        post(55, down: false)
    }

    private func post(_ keyCode: Int, down: Bool, flags: CGEventFlags = []) {
        guard let e = CGEvent(keyboardEventSource: CGEventSource(stateID: .privateState),
                              virtualKey: CGKeyCode(keyCode), keyDown: down) else { return }
        if keyCode == 55 { e.type = .flagsChanged }
        e.flags = flags
        e.setIntegerValueField(.eventSourceUserData, value: marker)
        e.post(tap: .cghidEventTap)
    }
}
