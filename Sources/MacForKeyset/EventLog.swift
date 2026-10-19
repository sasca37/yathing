import Foundation

struct LogEntry: Identifiable {
    let id = UUID()
    let time = Date()
    let kind: String
    let keyCode: Int
    let isDown: Bool
    let flags: String
    let chars: String
    let note: String

    var hex: String { String(format: "0x%02X", keyCode) }
    var tsv: String { [kind, "\(keyCode)", hex, KeyNames.name(keyCode), chars, flags, note].joined(separator: "\t") }
}

final class EventLog: ObservableObject {
    static let shared = EventLog()
    @Published var entries: [LogEntry] = []
    /// 지금 눌려 있는 키 (keyCode).
    @Published var pressed: [Int] = []
    @Published var paused = false
    /// 이벤트 창이 열려 있을 때만 기록한다 (키 입력을 불필요하게 보관하지 않기 위해).
    var active = false

    func add(_ e: LogEntry) {
        guard !paused else { return }
        if e.isDown {
            if !pressed.contains(e.keyCode) { pressed.append(e.keyCode) }
        } else {
            pressed.removeAll { $0 == e.keyCode }
        }
        entries.insert(e, at: 0)
        if entries.count > 300 { entries.removeLast(entries.count - 300) }
    }

    func clear() {
        entries.removeAll()
        pressed.removeAll()
    }
}
