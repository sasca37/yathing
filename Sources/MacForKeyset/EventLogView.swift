import SwiftUI

struct EventLogView: View {
    @ObservedObject private var log = EventLog.shared
    @ObservedObject private var store = Store.shared

    private static let timeFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("눌린 키").foregroundStyle(.secondary)
                if log.pressed.isEmpty {
                    Text("—").foregroundStyle(.secondary)
                } else {
                    ForEach(log.pressed, id: \.self) { code in
                        Text("\(KeyNames.name(code)) (\(code))")
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(.tint.opacity(0.25), in: Capsule())
                    }
                }
                Spacer()
            }
            .padding(8)
            Divider()
            if !store.accessibilityGranted || !store.inputMonitoringGranted {
                Text("⚠️ 손쉬운 사용 / 입력 모니터링 권한이 필요합니다. 설정 창에서 확인하세요.")
                    .foregroundStyle(.red).padding(8)
                Divider()
            }
            HStack {
                Toggle("일시정지", isOn: $log.paused)
                Toggle("원본 키 보기 (매핑 해제)", isOn: $store.rawMode)
                Spacer()
                Button("전체 복사") { copy(log.entries.map(\.tsv).joined(separator: "\n")) }
                Button("지우기") { log.clear() }
            }
            .padding(8)
            Divider()
            header
            List(log.entries) { e in
                HStack(spacing: 12) {
                    Text(Self.timeFormat.string(from: e.time)).foregroundStyle(.secondary).frame(width: 100, alignment: .leading)
                    Text(e.kind).frame(width: 50, alignment: .leading)
                    Text("\(e.keyCode)").frame(width: 36, alignment: .trailing)
                    Text(e.hex).frame(width: 44, alignment: .leading)
                    Text(KeyNames.name(e.keyCode)).frame(width: 90, alignment: .leading)
                    Text(e.chars).frame(width: 40, alignment: .leading)
                    Text(e.flags).frame(width: 60, alignment: .leading)
                    Text(e.note).foregroundStyle(.orange)
                }
                .font(.system(.body, design: .monospaced))
                .contextMenu { Button("복사") { copy(e.tsv) } }
            }
        }
        .frame(minWidth: 760, minHeight: 420)
        .onAppear { log.active = true }
        .onDisappear {
            log.active = false
            store.rawMode = false
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("시간").frame(width: 100, alignment: .leading)
            Text("종류").frame(width: 50, alignment: .leading)
            Text("코드").frame(width: 36, alignment: .trailing)
            Text("HEX").frame(width: 44, alignment: .leading)
            Text("키").frame(width: 90, alignment: .leading)
            Text("문자").frame(width: 40, alignment: .leading)
            Text("modifier").frame(width: 60, alignment: .leading)
            Text("비고")
            Spacer()
        }
        .font(.caption).foregroundStyle(.secondary)
        .padding(.horizontal, 20).padding(.vertical, 4)
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
