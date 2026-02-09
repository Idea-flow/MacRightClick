import Foundation

struct MessagePayload: Codable {
    var action: String
    var target: String?
    var targets: [String]
    var template: FileTemplate?
    var templateID: UUID?
    var templates: [FileTemplate]
    var copyPathsEnabled: Bool?
    var menuConfig: MenuConfig?
    var favoriteFolders: [FavoriteFolder]?
    var favoriteApps: [FavoriteApp]?
    var appBundleID: String?
    var level: String?
    var category: String?
    var message: String?
    var timestamp: TimeInterval?

    init(action: String,
         target: String? = nil,
         targets: [String] = [],
         template: FileTemplate? = nil,
         templateID: UUID? = nil,
         templates: [FileTemplate] = [],
         copyPathsEnabled: Bool? = nil,
         menuConfig: MenuConfig? = nil,
         favoriteFolders: [FavoriteFolder]? = nil,
         favoriteApps: [FavoriteApp]? = nil,
         appBundleID: String? = nil,
         level: String? = nil,
         category: String? = nil,
         message: String? = nil,
         timestamp: TimeInterval? = nil) {
        self.action = action
        self.target = target
        self.targets = targets
        self.template = template
        self.templateID = templateID
        self.templates = templates
        self.copyPathsEnabled = copyPathsEnabled
        self.menuConfig = menuConfig
        self.favoriteFolders = favoriteFolders
        self.favoriteApps = favoriteApps
        self.appBundleID = appBundleID
        self.level = level
        self.category = category
        self.message = message
        self.timestamp = timestamp
    }
}

final class DistributedMessenger {
    static let shared = DistributedMessenger()

    private let center = DistributedNotificationCenter.default()
    private var handlersFromExtension: [(MessagePayload) -> Void] = []
    private var handlersFromApp: [(MessagePayload) -> Void] = []
    private var observerFromExtension: NSObjectProtocol?
    private var observerFromApp: NSObjectProtocol?

    private init() {}

    func sendToApp(_ payload: MessagePayload) {
        post(name: Self.fromExtension, payload: payload)
    }

    func sendToExtension(_ payload: MessagePayload) {
        post(name: Self.fromApp, payload: payload)
    }

    func onFromExtension(_ handler: @escaping (MessagePayload) -> Void) {
        if observerFromExtension == nil {
            observerFromExtension = center.addObserver(
                forName: Self.fromExtension,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.handle(notification, handlers: self?.handlersFromExtension ?? [])
            }
        }
        handlersFromExtension.append(handler)
    }

    func onFromApp(_ handler: @escaping (MessagePayload) -> Void) {
        if observerFromApp == nil {
            observerFromApp = center.addObserver(
                forName: Self.fromApp,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.handle(notification, handlers: self?.handlersFromApp ?? [])
            }
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

    private func handle(_ notification: Notification, handlers: [(MessagePayload) -> Void]) {
        guard let string = notification.object as? String,
              let data = string.data(using: .utf8),
              let payload = try? JSONDecoder().decode(MessagePayload.self, from: data) else {
            return
        }
        handlers.forEach { $0(payload) }
    }

    private static let fromExtension = Notification.Name("MacRightClick.FromExtension")
    private static let fromApp = Notification.Name("MacRightClick.FromApp")
}
