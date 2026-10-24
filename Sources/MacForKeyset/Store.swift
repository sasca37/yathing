import Cocoa
import ApplicationServices
import ServiceManagement

final class Store: ObservableObject {
    static let shared = Store()

    @Published var config: Config {
        didSet {
            config.save()
            KeyEngine.shared.config = config
            if !rawMode { HIDRemap.apply(config) }
        }
    }
    @Published var engineRunning = false
    @Published var accessibilityGranted = false
    @Published var capturing = false
    @Published var inputMonitoringGranted = false
    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled
    @Published var launchAtLoginError: String?
    /// 이벤트 뷰어용: 매핑을 모두 풀고 물리 키 값을 그대로 본다.
    @Published var rawMode = false {
        didSet {
            KeyEngine.shared.bypassRemaps = rawMode
            if rawMode { HIDRemap.reset() } else { HIDRemap.apply(config) }
        }
    }

    private init() {
        config = Config.load()
        KeyEngine.shared.config = config
    }

    /// 권한을 요청하고, 권한이 생길 때까지 2초마다 이벤트 탭 생성을 재시도한다.
    func bootstrap() {
        HIDRemap.apply(config)
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        _ = CGRequestListenEventAccess()
        refresh()
        if !ready { SetupWindow.show() }
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.refresh() }
    }

    /// 입력 모니터링 확인 API는 엔진이 이미 동작 중이어도 false를 줄 수 있어서, 엔진이 실제로 도는지를 기준으로 한다.
    private var ready: Bool { accessibilityGranted && engineRunning }

    private func refresh() {
        accessibilityGranted = AXIsProcessTrusted()
        inputMonitoringGranted = CGPreflightListenEventAccess()
        engineRunning = KeyEngine.shared.start()
        if ready { SetupWindow.close() }
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    // MARK: capture

    func capture(_ accept: @escaping (Int, UInt64, Bool) -> Bool) {
        capturing = true
        KeyEngine.shared.capture = { [weak self] key, flags, isMod in
            guard accept(key, flags, isMod) else { return false }
            self?.capturing = false
            return true
        }
    }

    func cancelCapture() {
        KeyEngine.shared.capture = nil
        capturing = false
    }

    // MARK: edits

    func setRemap(from: Int, to: Int) {
        if let i = config.remaps.firstIndex(where: { $0.from == from }) {
            config.remaps[i].to = to
        } else {
            config.remaps.append(Remap(from: from, to: to))
        }
    }

    func removeRemap(from: Int) { config.remaps.removeAll { $0.from == from } }

    func setHotkey(_ action: WindowAction, _ shortcut: Shortcut) {
        config.hotkeys.removeAll { $0.action == action || $0.shortcut == shortcut }
        config.hotkeys.append(Hotkey(action: action, shortcut: shortcut))
    }

    func clearHotkey(_ action: WindowAction) { config.hotkeys.removeAll { $0.action == action } }
}
