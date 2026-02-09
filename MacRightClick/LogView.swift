import SwiftUI
import Observation
import AppKit

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
                .contextMenu {
                    Button("复制本条") {
                        copyToPasteboard([entry])
                    }
                }
        }
        .navigationTitle("日志")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("清除", action: model.clear)
            }
            ToolbarItem(placement: .primaryAction) {
                Button("导出") { exportLogs() }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("复制全部") { copyToPasteboard(model.entries) }
            }
        }
        .task {
            model.reload()
        }
        .onReceive(NotificationCenter.default.publisher(for: LogStore.didAppendNotification)) { _ in
            model.reload()
        }
    }

    private func exportLogs() {
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["txt", "md"]
        panel.nameFieldStringValue = "macrightclick-logs.txt"
        panel.title = "导出日志"
        panel.prompt = "导出"
        if panel.runModal() == .OK, let url = panel.url {
            let isMarkdown = url.pathExtension.lowercased() == "md"
            let content = formattedLogs(markdown: isMarkdown, entries: model.entries)
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                AppLogger.log(.error, "导出日志失败: \(error.localizedDescription)", category: "log")
            }
        }
    }

    private func copyToPasteboard(_ entries: [LogEntry]) {
        let content = formattedLogs(markdown: false, entries: entries)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
    }

    private func formattedLogs(markdown: Bool, entries: [LogEntry]) -> String {
        let formatter = LogView.dateFormatter
        if markdown {
            return entries.map { entry in
                let time = formatter.string(from: entry.date)
                return "- `\(time)` **\(entry.level.label)** _\(entry.category)_: \(entry.message)"
            }.joined(separator: "\n")
        }
        return entries.map { entry in
            let time = formatter.string(from: entry.date)
            return "\(time) [\(entry.level.label)] \(entry.category) - \(entry.message)"
        }.joined(separator: "\n")
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
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
                .textSelection(.enabled)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(entry.level.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(levelColor)
                        .textSelection(.enabled)
                    Text(entry.category)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Text(entry.message)
                    .font(.body)
                    .textSelection(.enabled)
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
