import SwiftUI

struct SettingsView: View {
    @ObservedObject private var store = Store.shared
    @State private var addingRemap = false
    @State private var recordingAction: WindowAction?

    var body: some View {
        Form {
            Section("권한") {
                LabeledContent("손쉬운 사용", value: store.accessibilityGranted ? "허용됨" : "필요")
                LabeledContent("입력 모니터링", value: store.inputMonitoringGranted ? "허용됨" : "필요")
                LabeledContent("키 처리 엔진", value: store.engineRunning ? "동작 중" : "중지 (입력 모니터링 권한 확인)")
                Button("시스템 설정 열기") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")!)
                }
            }

            Section("일반") {
                Toggle("로그인 시 자동 실행", isOn: Binding(get: { store.launchAtLogin }, set: { store.setLaunchAtLogin($0) }))
                if let err = store.launchAtLoginError { Text(err).font(.caption).foregroundStyle(.red) }
            }

            Section("키보드 모드") {
                Picker("", selection: $store.config.keyboardMode) {
                    ForEach(KeyboardMode.allCases, id: \.self) { mode in
                        VStack(alignment: .leading) {
                            Text(mode.title)
                            Text(mode.example).font(.caption).foregroundStyle(.secondary)
                        }
                        .tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
                if store.config.keyboardMode == .windowsAsWindows {
                    DisclosureGroup("이렇게 동작해요") {
                        Grid(alignment: .leading, verticalSpacing: 4) {
                            ForEach(WindowsShortcuts.guide, id: \.keys) { row in
                                GridRow {
                                    Text(row.keys).font(.system(.body, design: .monospaced))
                                    Text(row.meaning).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                if store.config.keyboardMode != .mac {
                    Text("연결된 모든 키보드(내장 키보드 포함)에 적용돼요. 맥 키보드를 쓸 때는 '맥 키보드'로 바꾸세요.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("키 매핑") {
                ForEach(store.config.remaps) { r in
                    HStack {
                        Text("\(KeyNames.name(r.from))  →")
                        Picker("", selection: Binding(get: { r.to }, set: { store.setRemap(from: r.from, to: $0) })) {
                            ForEach(targetChoices(including: r.to), id: \.self) { Text(KeyNames.name($0)).tag($0) }
                        }
                        .labelsHidden()
                        .fixedSize()
                        Spacer()
                        Button("삭제", role: .destructive) { store.removeRemap(from: r.from) }
                    }
                }
                if addingRemap {
                    HStack {
                        Text("바꿀 키를 누르세요…")
                        Spacer()
                        Button("취소") { cancelRemap() }
                    }
                } else {
                    Button("매핑 추가") { beginRemap() }
                }
                Text("추가하면 F15로 설정됩니다. 변환될 키는 목록에서 고르세요 (F13–F20, 입력 소스 전환).").font(.caption).foregroundStyle(.secondary)
            }

            Section("창 분할 단축키") {
                ForEach(WindowAction.allCases, id: \.self) { action in
                    let hk = store.config.hotkeys.first { $0.action == action }
                    HStack {
                        Text(action.title)
                        Spacer()
                        if recordingAction == action {
                            Text("단축키를 누르세요…").foregroundStyle(.secondary)
                            Button("취소") { recordingAction = nil; store.cancelCapture() }
                        } else {
                            Text(hk?.shortcut.display ?? "없음").foregroundStyle(.secondary)
                            Button("변경") { record(action) }
                            if hk != nil { Button("해제") { store.clearHotkey(action) } }
                        }
                    }
                }
                Text("⌘⌥⌃⇧ 중 하나 이상과 함께 지정해야 합니다.").font(.caption).foregroundStyle(.secondary)
            }

            Section("한/영 전환") {
                Text("""
                    기본값은 우측 ⌘ → F15 입니다. 시스템 설정 → 키보드 → 키보드 단축키 → 입력 소스 → \
                    '이전 입력 소스 선택'을 F15로 지정하세요 (단축키 입력란에서 우측 ⌘를 누르면 F15가 입력됩니다). F15가 먹지 않으면 매핑 대상을 '입력 소스 전환'으로 바꾸면 \
                    앱이 직접 전환합니다.
                    """).font(.caption)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 680)
        // 입력 대기 중에 창을 닫으면 이벤트 탭이 모든 키를 계속 삼키므로 대기를 풀어 준다.
        .onDisappear {
            store.cancelCapture()
            addingRemap = false
            recordingAction = nil
        }
    }

    // MARK: remap flow

    private static let defaultTarget = 113  // F15
    private static let functionKeys = [105, 107, 113, 106, 64, 79, 80, 90]  // F13–F20

    private func targetChoices(including current: Int) -> [Int] {
        let base = Self.functionKeys + [toggleInputSource]
        return base.contains(current) ? base : base + [current]
    }

    private func beginRemap() {
        addingRemap = true
        store.capture { key, _, _ in
            DispatchQueue.main.async {
                store.setRemap(from: key, to: Self.defaultTarget)
                addingRemap = false
            }
            return true
        }
    }

    private func cancelRemap() {
        store.cancelCapture()
        addingRemap = false
    }

    private func record(_ action: WindowAction) {
        recordingAction = action
        store.capture { key, flags, isMod in
            let mods = flags & hotkeyModifierMask
            guard !isMod, mods != 0 else { return false }
            DispatchQueue.main.async {
                store.setHotkey(action, Shortcut(keyCode: key, modifiers: mods))
                recordingAction = nil
            }
            return true
        }
    }
}
