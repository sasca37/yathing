import SwiftUI

@main
struct MacForKeysetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra { MenuContent() } label: { menuBarIcon }
        Window("설정", id: "settings") { SettingsView() }
            .windowResizability(.contentSize)
        Window("키 이벤트", id: "events") { EventLogView() }
    }

    /// 앱 번들의 MenuBarIcon(템플릿 이미지). 번들 없이 실행하면 시스템 키보드 아이콘을 쓴다.
    private var menuBarIcon: Image {
        guard let img = NSImage(named: "MenuBarIcon") else { return Image(systemName: "keyboard") }
        img.isTemplate = true
        return Image(nsImage: img)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Store.shared.bootstrap()
    }

    func applicationWillTerminate(_ notification: Notification) {
        HIDRemap.reset()
    }
}

private struct MenuContent: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var store = Store.shared

    var body: some View {
        Text(store.engineRunning ? "키 처리 동작 중" : "권한 필요 — 설정에서 확인")
        Divider()
        Button("설정…") { show("settings") }
        Button("키 이벤트 보기…") { show("events") }
        Toggle("윈도우 키보드 설정 (Alt↔Win)", isOn: $store.config.windowsKeyboard)
        Divider()
        Button("종료") { NSApp.terminate(nil) }
    }

    private func show(_ id: String) {
        openWindow(id: id)
        NSApp.activate(ignoringOtherApps: true)
    }
}
