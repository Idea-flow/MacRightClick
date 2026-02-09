import Foundation

struct MessagePayload: Codable {
    var action: String
    var target: String?
    var targets: [String]
    var template: FileTemplate?
    var templates: [FileTemplate]

    init(action: String, target: String? = nil, targets: [String] = [], template: FileTemplate? = nil, templates: [FileTemplate] = []) {
        self.action = action
        self.target = target
        self.targets = targets
        self.template = template
        self.templates = templates
    }
}

final class DistributedMessenger {
    static let shared = DistributedMessenger()

    private let center = DistributedNotificationCenter.default()
    private var handlersFromExtension: [(MessagePayload) -> Void] = []
    private var handlersFromApp: [(MessagePayload) -> Void] = []

    private init() {}

    func sendToApp(_ payload: MessagePayload) {
        post(name: Self.fromExtension, payload: payload)
    }

    func sendToExtension(_ payload: MessagePayload) {
        post(name: Self.fromApp, payload: payload)
    }

    func onFromExtension(_ handler: @escaping (MessagePayload) -> Void) {
        if handlersFromExtension.isEmpty {
            center.addObserver(self, selector: #selector(receivedFromExtension(_:)), name: Self.fromExtension, object: nil)
        }
        handlersFromExtension.append(handler)
    }

    func onFromApp(_ handler: @escaping (MessagePayload) -> Void) {
        if handlersFromApp.isEmpty {
            center.addObserver(self, selector: #selector(receivedFromApp(_:)), name: Self.fromApp, object: nil)
        }
        handlersFromApp.append(handler)
    }

    private func post(name: Notification.Name, payload: MessagePayload) {
        guard let data = try? JSONEncoder().encode(payload),
              let string = String(data: data, encoding: .utf8) else {
            return
        }
        center.postNotificationName(name, object: string, userInfo: nil, deliverImmediately: true)
    }

    @objc private func receivedFromExtension(_ notification: Notification) {
        guard let string = notification.object as? String,
              let data = string.data(using: .utf8),
              let payload = try? JSONDecoder().decode(MessagePayload.self, from: data) else {
            return
        }
        handlersFromExtension.forEach { $0(payload) }
    }

    @objc private func receivedFromApp(_ notification: Notification) {
        guard let string = notification.object as? String,
              let data = string.data(using: .utf8),
              let payload = try? JSONDecoder().decode(MessagePayload.self, from: data) else {
            return
        }
        handlersFromApp.forEach { $0(payload) }
    }

    private static let fromExtension = Notification.Name("MacRightClick.FromExtension")
    private static let fromApp = Notification.Name("MacRightClick.FromApp")
}
