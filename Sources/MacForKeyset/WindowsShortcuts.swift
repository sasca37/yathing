import Cocoa

/// "윈도우처럼" 모드에서 윈도우 단축키를 맥 동작으로 바꾼다.
/// hidutil이 이미 Ctrl → ⌘, Win → ⌃로 바꾼 뒤의 키를 기준으로 규칙을 적는다.
/// Alt+Tab은 ⌘를 누른 상태를 유지해야 해서 KeyEngine에서 따로 처리한다.
enum WindowsShortcuts {
    enum Output {
        /// 이 키(keyCode)와 modifier로 바꿔서 보낸다.
        case key(Int, CGEventFlags)
        /// 키 입력을 삼키고 이 동작을 실행한다.
        case action(() -> Void)
    }

    struct Rule {
        let keyCode: Int
        let modifiers: CGEventFlags
        let output: Output
        /// Shift를 같이 누르면 출력에도 Shift를 붙인다 (선택하며 이동).
        var keepsShift = false
        /// 설정 창 안내용: 윈도우에서 누르는 키와 하는 일.
        let keys: String
        let meaning: String
    }

    private static let cmd = CGEventFlags.maskCommand, opt = CGEventFlags.maskAlternate
    private static let ctrl = CGEventFlags.maskControl, shift = CGEventFlags.maskShift

    static let rules: [Rule] = [
        Rule(keyCode: 115, modifiers: [], output: .key(123, cmd), keepsShift: true, keys: "Home", meaning: "줄 맨 앞으로"),
        Rule(keyCode: 119, modifiers: [], output: .key(124, cmd), keepsShift: true, keys: "End", meaning: "줄 맨 뒤로"),
        Rule(keyCode: 115, modifiers: cmd, output: .key(126, cmd), keepsShift: true, keys: "Ctrl+Home", meaning: "문서 맨 앞으로"),
        Rule(keyCode: 119, modifiers: cmd, output: .key(125, cmd), keepsShift: true, keys: "Ctrl+End", meaning: "문서 맨 뒤로"),
        Rule(keyCode: 123, modifiers: cmd, output: .key(123, opt), keepsShift: true, keys: "Ctrl+←", meaning: "이전 단어로"),
        Rule(keyCode: 124, modifiers: cmd, output: .key(124, opt), keepsShift: true, keys: "Ctrl+→", meaning: "다음 단어로"),
        Rule(keyCode: 48, modifiers: cmd, output: .key(48, ctrl), keepsShift: true, keys: "Ctrl+Tab", meaning: "다음 탭 (Shift: 이전 탭)"),
        Rule(keyCode: 51, modifiers: cmd, output: .key(51, opt), keys: "Ctrl+Backspace", meaning: "앞 단어 지우기"),
        Rule(keyCode: 117, modifiers: cmd, output: .key(117, opt), keys: "Ctrl+Delete", meaning: "뒤 단어 지우기"),
        Rule(keyCode: 118, modifiers: opt, output: .key(13, cmd), keys: "Alt+F4", meaning: "창 닫기"),
        Rule(keyCode: 105, modifiers: [], output: .key(21, [cmd, shift]), keys: "Print Screen", meaning: "화면 캡처 (영역 선택)"),
        Rule(keyCode: 53, modifiers: [cmd, shift], output: .key(53, [cmd, opt]), keys: "Ctrl+Shift+Esc", meaning: "앱 강제 종료 창"),
        Rule(keyCode: 14, modifiers: ctrl, output: .action(openFinder), keys: "Win+E", meaning: "Finder 열기"),
        Rule(keyCode: 2, modifiers: ctrl, output: .key(103, []), keys: "Win+D", meaning: "바탕화면 보기"),
        Rule(keyCode: 37, modifiers: ctrl, output: .key(12, [ctrl, cmd]), keys: "Win+L", meaning: "화면 잠금"),
        Rule(keyCode: 123, modifiers: ctrl, output: .action { WindowManager.apply(.left) }, keys: "Win+←", meaning: "창을 왼쪽 절반으로"),
        Rule(keyCode: 124, modifiers: ctrl, output: .action { WindowManager.apply(.right) }, keys: "Win+→", meaning: "창을 오른쪽 절반으로"),
        Rule(keyCode: 126, modifiers: ctrl, output: .action { WindowManager.apply(.maximize) }, keys: "Win+↑", meaning: "창 최대화"),
    ]

    /// 설정 창 안내 표. 규칙 외에 Ctrl→⌘ 교환으로 생기는 기본 동작도 앞에 보여 준다.
    static let guide: [(keys: String, meaning: String)] =
        [("Ctrl+C / V / X", "복사 / 붙여넣기 / 잘라내기"), ("Ctrl+Z / A / S / F", "되돌리기 / 전체 선택 / 저장 / 찾기"),
         ("Alt+Tab", "앱 전환 (Alt를 떼면 선택, Shift: 반대로)")]
        + rules.map { ($0.keys, $0.meaning) }
        + [("한/영", "한영 전환")]

    /// keyCode와 현재 flags(hidutil 교환 후)에 맞는 규칙을 찾는다.
    static func match(keyCode: Int, flags: UInt64) -> Output? {
        let mods = CGEventFlags(rawValue: flags & hotkeyModifierMask)
        guard let rule = rules.first(where: {
            $0.keyCode == keyCode && (mods == $0.modifiers || ($0.keepsShift && mods == $0.modifiers.union(shift)))
        }) else { return nil }
        guard case .key(let key, var outMods) = rule.output else { return rule.output }
        if rule.keepsShift && mods.contains(shift) { outMods.insert(shift) }
        return .key(key, outMods)
    }

    private static func openFinder() {
        NSWorkspace.shared.open(URL(fileURLWithPath: NSHomeDirectory()))
    }
}
