import SwiftUI

/// 권한이 부족할 때 자동으로 뜨는 첫 실행 안내 창. 권한이 모두 갖춰지면 스스로 닫힌다.
enum SetupWindow {
    private static var window: NSWindow?

    static let accessibilityURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
    static let inputMonitoringURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!

    static func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
        } else {
            let w = NSWindow(contentViewController: NSHostingController(rootView: SetupView()))
            w.title = "yathing 시작하기"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            w.makeKeyAndOrderFront(nil)
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    static func close() {
        window?.close()
        window = nil
    }
}

private struct SetupView: View {
    @ObservedObject private var store = Store.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("키보드를 바꾸려면 권한 두 가지가 필요해요")
                .font(.headline)
            Text("각 버튼을 눌러 열린 화면에서 yathing을 켜 주세요. 켜면 여기 표시가 자동으로 바뀝니다.")
                .foregroundStyle(.secondary)

            step("손쉬운 사용", "키 입력을 바꾸고 창을 옮기기 위해", store.accessibilityGranted, SetupWindow.accessibilityURL)
            step("입력 모니터링", "어떤 키를 눌렀는지 알기 위해", store.inputMonitoringGranted || store.engineRunning, SetupWindow.inputMonitoringURL)

            Text(store.engineRunning ? "준비됐어요. 이제 쓸 수 있어요." : "모두 켰는데도 반영되지 않으면 메뉴바 아이콘에서 종료한 뒤 다시 실행해 주세요.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 440)
    }

    private func step(_ title: String, _ reason: String, _ granted: Bool, _ url: URL) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(granted ? .green : .secondary)
                .font(.title3)
            VStack(alignment: .leading) {
                Text(title)
                Text(reason).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if !granted { Button("설정 열기") { NSWorkspace.shared.open(url) } }
        }
    }
}
