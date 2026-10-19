import Carbon.HIToolbox

enum InputSource {
    /// 활성화된 키보드 입력 소스 중 다음 것으로 전환한다 (보통 ABC ↔ 한글).
    static func toggle() {
        let filter = [
            kTISPropertyInputSourceIsSelectCapable: true,
            kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource!,
        ] as CFDictionary
        guard let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource],
              list.count > 1 else { return }
        let current = id(TISCopyCurrentKeyboardInputSource().takeRetainedValue())
        let index = list.firstIndex { id($0) == current } ?? -1
        TISSelectInputSource(list[(index + 1) % list.count])
    }

    private static func id(_ src: TISInputSource) -> String {
        guard let p = TISGetInputSourceProperty(src, kTISPropertyInputSourceID) else { return "" }
        return Unmanaged<CFString>.fromOpaque(p).takeUnretainedValue() as String
    }
}
