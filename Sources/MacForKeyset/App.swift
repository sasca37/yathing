import SwiftUI

@main
struct MacForKeysetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra("Mac For Keyset", systemImage: "keyboard") { MenuContent() }
        Window("설정", id: "settings") { SettingsView() }
            .windowResizability(.contentSize)
        Window("키 이벤트", id: "events") { EventLogView() }
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
        Divider()
        Button("종료") { NSApp.terminate(nil) }
    }

    private func show(_ id: String) {
        openWindow(id: id)
        NSApp.activate(ignoringOtherApps: true)
    }
}
