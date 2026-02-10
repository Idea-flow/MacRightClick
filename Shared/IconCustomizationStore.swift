import AppKit
import Foundation

/// Persists and resolves user-selected icons using security-scoped bookmarks.
enum IconCustomizationStore {
    private static let dockBookmarkKey = "DockIconBookmark"
    private static let dockPathKey = "DockIconPath"
    private static let menuBookmarkKey = "MenuBarIconBookmark"
    private static let menuPathKey = "MenuBarIconPath"
    private static let menuTemplateKey = "MenuBarIconIsTemplate"

    static func dockIconPath(from defaults: UserDefaults = .appGroup) -> String? {
        defaults.string(forKey: dockPathKey)
    }

    static func menuBarIconPath(from defaults: UserDefaults = .appGroup) -> String? {
        defaults.string(forKey: menuPathKey)
    }

    static func menuBarIconIsTemplate(from defaults: UserDefaults = .appGroup) -> Bool {
        if defaults.object(forKey: menuTemplateKey) == nil {
            return true
        }
        return defaults.bool(forKey: menuTemplateKey)
    }

    static func setMenuBarIconIsTemplate(_ isTemplate: Bool, defaults: UserDefaults = .appGroup) {
        defaults.set(isTemplate, forKey: menuTemplateKey)
    }

    static func saveDockIcon(url: URL, defaults: UserDefaults = .appGroup) throws {
        try withSecurityScopedAccess(to: url) {
            let bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            defaults.set(bookmark, forKey: dockBookmarkKey)
            defaults.set(url.path, forKey: dockPathKey)
        }
    }

    static func saveMenuBarIcon(url: URL, isTemplate: Bool, defaults: UserDefaults = .appGroup) throws {
        try withSecurityScopedAccess(to: url) {
            let bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            defaults.set(bookmark, forKey: menuBookmarkKey)
            defaults.set(url.path, forKey: menuPathKey)
            defaults.set(isTemplate, forKey: menuTemplateKey)
        }
    }

    static func clearDockIcon(defaults: UserDefaults = .appGroup) {
        defaults.removeObject(forKey: dockBookmarkKey)
        defaults.removeObject(forKey: dockPathKey)
    }

    static func clearMenuBarIcon(defaults: UserDefaults = .appGroup) {
        defaults.removeObject(forKey: menuBookmarkKey)
        defaults.removeObject(forKey: menuPathKey)
    }

    static func resolveDockIconURL(from defaults: UserDefaults = .appGroup) -> URL? {
        resolveBookmarkURL(bookmarkKey: dockBookmarkKey, pathKey: dockPathKey, defaults: defaults)
    }

    static func resolveMenuBarIconURL(from defaults: UserDefaults = .appGroup) -> URL? {
        resolveBookmarkURL(bookmarkKey: menuBookmarkKey, pathKey: menuPathKey, defaults: defaults)
    }

    static func loadImage(from url: URL) -> NSImage? {
        withSecurityScopedAccess(to: url) {
            NSImage(contentsOf: url)
        }
    }

    static func withSecurityScopedAccess<T>(to url: URL, _ action: () throws -> T) rethrows -> T {
        let success = url.startAccessingSecurityScopedResource()
        if !success {
            AppLogger.log(.warning, "未获得安全范围访问权限: \(url.path)", category: "appearance")
        }
        defer {
            if success {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try action()
    }

    private static func resolveBookmarkURL(
        bookmarkKey: String,
        pathKey: String,
        defaults: UserDefaults
    ) -> URL? {
        guard let bookmark = defaults.data(forKey: bookmarkKey) else {
            return nil
        }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }
        if isStale, let refreshed = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
            defaults.set(refreshed, forKey: bookmarkKey)
            defaults.set(url.path, forKey: pathKey)
        }
        return url
    }
}
