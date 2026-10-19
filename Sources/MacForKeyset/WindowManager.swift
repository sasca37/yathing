import Cocoa
import ApplicationServices

enum WindowManager {
    static func apply(_ action: WindowAction) {
        guard let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != getpid() else { return }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &ref) == .success,
              let ref else { return }
        let window = ref as! AXUIElement
        guard let frame = frame(of: window) else { return }

        // AX 좌표는 주 화면 좌상단 기준, NSScreen은 좌하단 기준.
        let primaryH = NSScreen.screens[0].frame.height
        let cocoa = CGRect(x: frame.minX, y: primaryH - frame.maxY, width: frame.width, height: frame.height)
        func overlap(_ s: NSScreen) -> CGFloat {
            let r = s.frame.intersection(cocoa)
            return r.isNull ? 0 : r.width * r.height
        }
        guard let screen = NSScreen.screens.max(by: { overlap($0) < overlap($1) }) else { return }
        let v = screen.visibleFrame

        let target: CGRect
        switch action {
        case .left: target = CGRect(x: v.minX, y: v.minY, width: v.width / 2, height: v.height)
        case .right: target = CGRect(x: v.midX, y: v.minY, width: v.width / 2, height: v.height)
        case .top: target = CGRect(x: v.minX, y: v.midY, width: v.width, height: v.height / 2)
        case .bottom: target = CGRect(x: v.minX, y: v.minY, width: v.width, height: v.height / 2)
        case .maximize: target = v
        }
        set(window, origin: CGPoint(x: target.minX, y: primaryH - target.maxY), size: target.size)
    }

    private static func frame(of window: AXUIElement) -> CGRect? {
        var posRef: CFTypeRef?, sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let posRef, let sizeRef else { return nil }
        var p = CGPoint.zero, s = CGSize.zero
        AXValueGetValue(posRef as! AXValue, .cgPoint, &p)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &s)
        return CGRect(origin: p, size: s)
    }

    private static func set(_ window: AXUIElement, origin: CGPoint, size: CGSize) {
        var o = origin, s = size
        // 크기 → 위치 → 크기 순서: 화면 경계에서 앱이 크기를 clamp 하는 경우를 보정한다.
        if let sv = AXValueCreate(.cgSize, &s) { AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sv) }
        if let pv = AXValueCreate(.cgPoint, &o) { AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pv) }
        if let sv = AXValueCreate(.cgSize, &s) { AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sv) }
    }
}
