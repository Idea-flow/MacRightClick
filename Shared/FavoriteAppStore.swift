import Foundation

struct FavoriteApp: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var bundleIdentifier: String
    var path: String
    var isEnabled: Bool

    init(id: UUID = UUID(), name: String, bundleIdentifier: String, path: String, isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.path = path
        self.isEnabled = isEnabled
    }
}

enum FavoriteAppStore {
    private static let storageKey = "FavoriteApps"

    static func load(from defaults: UserDefaults = .appGroup) -> [FavoriteApp] {
        guard let data = defaults.data(forKey: storageKey) else {
            return []
        }
        return (try? JSONDecoder().decode([FavoriteApp].self, from: data)) ?? []
    }

    static func save(_ apps: [FavoriteApp], to defaults: UserDefaults = .appGroup) {
        if let data = try? JSONEncoder().encode(apps) {
            defaults.set(data, forKey: storageKey)
        }
    }
}
