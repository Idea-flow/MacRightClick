import Foundation

// Menu configuration shared by app and Finder extension.
// The extension only receives this config via DistributedMessenger to avoid
// touching App Group storage and triggering privacy prompts.

struct MenuConfig: Codable, Equatable {
    struct Container: Codable, Equatable {
        var newFileEnabled: Bool
        var copyPathEnabled: Bool
        var openTerminalEnabled: Bool
        var favoriteFoldersEnabled: Bool
        var favoriteAppsEnabled: Bool
    }

    struct Items: Codable, Equatable {
        var copyPathEnabled: Bool
        var moveToEnabled: Bool
    }

    var container: Container
    var items: Items

    static let `default` = MenuConfig(
        container: .init(
            newFileEnabled: true,
            copyPathEnabled: true,
            openTerminalEnabled: true,
            favoriteFoldersEnabled: true,
            favoriteAppsEnabled: true
        ),
        items: .init(copyPathEnabled: true, moveToEnabled: true)
    )
}

enum MenuConfigStore {
    private static let storageKey = "MenuConfig"

    static func load(from defaults: UserDefaults = .appGroup) -> MenuConfig {
        guard let data = defaults.data(forKey: storageKey) else {
            return .default
        }
        return (try? JSONDecoder().decode(MenuConfig.self, from: data)) ?? .default
    }

    static func save(_ config: MenuConfig, to defaults: UserDefaults = .appGroup) {
        if let data = try? JSONEncoder().encode(config) {
            defaults.set(data, forKey: storageKey)
        }
    }
}
