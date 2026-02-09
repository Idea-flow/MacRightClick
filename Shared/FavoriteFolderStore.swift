import Foundation

struct FavoriteFolder: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var path: String
    var isEnabled: Bool

    init(id: UUID = UUID(), name: String, path: String, isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.path = path
        self.isEnabled = isEnabled
    }
}

enum FavoriteFolderStore {
    private static let storageKey = "FavoriteFolders"

    static func load(from defaults: UserDefaults = .appGroup) -> [FavoriteFolder] {
        guard let data = defaults.data(forKey: storageKey) else {
            return []
        }
        return (try? JSONDecoder().decode([FavoriteFolder].self, from: data)) ?? []
    }

    static func save(_ folders: [FavoriteFolder], to defaults: UserDefaults = .appGroup) {
        if let data = try? JSONEncoder().encode(folders) {
            defaults.set(data, forKey: storageKey)
        }
    }
}
