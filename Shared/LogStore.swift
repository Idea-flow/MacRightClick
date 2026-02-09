import Foundation
import OSLog

enum LogLevel: String, Codable, CaseIterable {
    case info
    case warning
    case error

    var label: String {
        switch self {
        case .info:
            return "INFO"
        case .warning:
            return "WARN"
        case .error:
            return "ERROR"
        }
    }
}

struct LogEntry: Codable, Identifiable, Hashable {
    let id: UUID
    let date: Date
    let level: LogLevel
    let category: String
    let message: String

    init(level: LogLevel, category: String, message: String) {
        self.id = UUID()
        self.date = Date()
        self.level = level
        self.category = category
        self.message = message
    }

    init(id: UUID = UUID(), date: Date, level: LogLevel, category: String, message: String) {
        self.id = id
        self.date = date
        self.level = level
        self.category = category
        self.message = message
    }
}

enum AppLogger {
    static func log(_ level: LogLevel, _ message: String, category: String) {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MacRightClick", category: category)
        switch level {
        case .info:
            logger.info("\(message, privacy: .public)")
        case .warning:
            logger.warning("\(message, privacy: .public)")
        case .error:
            logger.error("\(message, privacy: .public)")
        }

        if AppRuntime.isExtension {
            DistributedNotificationCenter.default()
                .post(name: LogStore.distributedLogNotification, object: nil, userInfo: [
                    LogStore.userInfoLevelKey: level.rawValue,
                    LogStore.userInfoCategoryKey: category,
                    LogStore.userInfoMessageKey: message,
                    LogStore.userInfoTimestampKey: Date().timeIntervalSince1970
                ])
            return
        }

        LogStore.shared.append(LogEntry(level: level, category: category, message: message))
    }
}

enum AppRuntime {
    static let isExtension: Bool = {
        Bundle.main.bundleURL.pathExtension == "appex"
    }()
}

final class LogStore {
    static let shared = LogStore()
    static let didAppendNotification = Notification.Name("LogStoreDidAppend")
    static let distributedLogNotification = Notification.Name("MacRightClickDistributedLog")
    static let userInfoLevelKey = "level"
    static let userInfoCategoryKey = "category"
    static let userInfoMessageKey = "message"
    static let userInfoTimestampKey = "timestamp"

    private let queue = DispatchQueue(label: "LogStoreQueue")
    private let fileURL: URL
    private var distributedObserver: NSObjectProtocol?

    private init() {
        self.fileURL = Self.defaultLogFileURL()
        if !AppRuntime.isExtension {
            distributedObserver = DistributedNotificationCenter.default()
                .addObserver(
                    forName: Self.distributedLogNotification,
                    object: nil,
                    queue: .main
                ) { [weak self] notification in
                    self?.handleDistributedLog(notification.userInfo)
                }
        }
    }

    func append(_ entry: LogEntry) {
        queue.sync {
            do {
                try ensureDirectoryExists()
                if !FileManager.default.fileExists(atPath: fileURL.path) {
                    FileManager.default.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
                }

                let handle = try FileHandle(forWritingTo: fileURL)
                defer { try? handle.close() }
                try handle.seekToEnd()

                let data = try JSONEncoder().encode(entry)
                if var line = String(data: data, encoding: .utf8) {
                    line.append("\n")
                    if let lineData = line.data(using: .utf8) {
                        try handle.write(contentsOf: lineData)
                    }
                }
            } catch {
                // Avoid recursive logging on failure.
            }
        }
        NotificationCenter.default.post(name: Self.didAppendNotification, object: nil)
    }

    func fetchAll(limit: Int? = 500) -> [LogEntry] {
        queue.sync {
            guard let data = try? Data(contentsOf: fileURL),
                  let content = String(data: data, encoding: .utf8) else {
                return []
            }
            let lines = content.split(separator: "\n")
            var entries: [LogEntry] = []
            entries.reserveCapacity(lines.count)
            let decoder = JSONDecoder()
            for line in lines {
                guard let lineData = line.data(using: .utf8),
                      let entry = try? decoder.decode(LogEntry.self, from: lineData) else {
                    continue
                }
                entries.append(entry)
            }
            entries.reverse()
            if let limit, limit > 0, entries.count > limit {
                return Array(entries.prefix(limit))
            }
            return entries
        }
    }

    func clear() {
        queue.sync {
            try? FileManager.default.removeItem(at: fileURL)
        }
        NotificationCenter.default.post(name: Self.didAppendNotification, object: nil)
    }

    private func handleDistributedLog(_ userInfo: [AnyHashable: Any]?) {
        guard let userInfo,
              let levelRaw = userInfo[Self.userInfoLevelKey] as? String,
              let level = LogLevel(rawValue: levelRaw),
              let category = userInfo[Self.userInfoCategoryKey] as? String,
              let message = userInfo[Self.userInfoMessageKey] as? String else {
            return
        }

        let timestamp = (userInfo[Self.userInfoTimestampKey] as? TimeInterval) ?? Date().timeIntervalSince1970
        let date = Date(timeIntervalSince1970: timestamp)
        append(LogEntry(date: date, level: level, category: category, message: message))
    }

    private func ensureDirectoryExists() throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private static func defaultLogFileURL() -> URL {
        let fileManager = FileManager.default
        if let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.id) {
            return containerURL
                .appendingPathComponent("Logs", isDirectory: true)
                .appendingPathComponent("macrightclick.log.jsonl", isDirectory: false)
        }
        return fileManager.temporaryDirectory.appendingPathComponent("macrightclick.log.jsonl")
    }
}
