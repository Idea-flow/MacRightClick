import SwiftUI
import Observation

@MainActor
@Observable
final class LogViewModel {
    var entries: [LogEntry] = []

    func reload() {
        entries = LogStore.shared.fetchAll()
    }

    func clear() {
        LogStore.shared.clear()
        entries = []
    }
}

struct LogView: View {
    @State private var model = LogViewModel()

    var body: some View {
        List(model.entries) { entry in
            LogRow(entry: entry)
        }
        .navigationTitle("日志")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("清除", action: model.clear)
            }
        }
        .task {
            model.reload()
        }
        .onReceive(NotificationCenter.default.publisher(for: LogStore.didAppendNotification)) { _ in
            model.reload()
        }
    }
}

private struct LogRow: View {
    let entry: LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(Self.dateFormatter.string(from: entry.date))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 160, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(entry.level.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(levelColor)
                    Text(entry.category)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(entry.message)
                    .font(.body)
            }
        }
        .padding(.vertical, 4)
    }

    private var levelColor: Color {
        switch entry.level {
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}
