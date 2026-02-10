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

        init(newFileEnabled: Bool = true,
             copyPathEnabled: Bool = true,
             openTerminalEnabled: Bool = true,
             favoriteFoldersEnabled: Bool = true,
             favoriteAppsEnabled: Bool = true) {
            self.newFileEnabled = newFileEnabled
            self.copyPathEnabled = copyPathEnabled
            self.openTerminalEnabled = openTerminalEnabled
            self.favoriteFoldersEnabled = favoriteFoldersEnabled
            self.favoriteAppsEnabled = favoriteAppsEnabled
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            newFileEnabled = try container.decodeIfPresent(Bool.self, forKey: .newFileEnabled) ?? true
            copyPathEnabled = try container.decodeIfPresent(Bool.self, forKey: .copyPathEnabled) ?? true
            openTerminalEnabled = try container.decodeIfPresent(Bool.self, forKey: .openTerminalEnabled) ?? true
            favoriteFoldersEnabled = try container.decodeIfPresent(Bool.self, forKey: .favoriteFoldersEnabled) ?? true
            favoriteAppsEnabled = try container.decodeIfPresent(Bool.self, forKey: .favoriteAppsEnabled) ?? true
        }
    }

    struct Items: Codable, Equatable {
        var copyPathEnabled: Bool
        var moveToEnabled: Bool

        init(copyPathEnabled: Bool = true, moveToEnabled: Bool = true) {
            self.copyPathEnabled = copyPathEnabled
            self.moveToEnabled = moveToEnabled
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            copyPathEnabled = try container.decodeIfPresent(Bool.self, forKey: .copyPathEnabled) ?? true
            moveToEnabled = try container.decodeIfPresent(Bool.self, forKey: .moveToEnabled) ?? true
        }
    }

    var container: Container
    var items: Items
    var showIcons: Bool

    static let `default` = MenuConfig(
        container: .init(
            newFileEnabled: true,
            copyPathEnabled: true,
            openTerminalEnabled: true,
            favoriteFoldersEnabled: true,
            favoriteAppsEnabled: true
        ),
        items: .init(copyPathEnabled: true, moveToEnabled: true),
        showIcons: true
    )

    init(container: Container, items: Items, showIcons: Bool = true) {
        self.container = container
        self.items = items
        self.showIcons = showIcons
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.container = try container.decodeIfPresent(Container.self, forKey: .container) ?? .init()
        self.items = try container.decodeIfPresent(Items.self, forKey: .items) ?? .init()
        self.showIcons = try container.decodeIfPresent(Bool.self, forKey: .showIcons) ?? true
    }
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
