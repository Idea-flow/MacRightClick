import Foundation

struct AuthorizedFolder: Codable, Identifiable, Hashable {
    let id: UUID
    let bookmark: Data
    let path: String

    init(id: UUID = UUID(), bookmark: Data, path: String) {
        self.id = id
        self.bookmark = bookmark
        self.path = path
    }
}

enum AuthorizedFolderStore {
    private static let storageKey = "AuthorizedFolders"

    static func loadFolders(from defaults: UserDefaults = .appGroup) -> [AuthorizedFolder] {
        guard let data = defaults.data(forKey: storageKey) else {
            return []
        }
        do {
            return try JSONDecoder().decode([AuthorizedFolder].self, from: data)
        } catch {
            return []
        }
    }

    static func authorizedPaths(from defaults: UserDefaults = .appGroup) -> [String] {
        loadFolders(from: defaults).map { $0.path }
    }

    static func saveFolders(_ folders: [AuthorizedFolder], to defaults: UserDefaults = .appGroup) {
        do {
            let data = try JSONEncoder().encode(folders)
            defaults.set(data, forKey: storageKey)
        } catch {
            defaults.removeObject(forKey: storageKey)
        }
    }

    static func addFolder(url: URL, to defaults: UserDefaults = .appGroup) throws -> AuthorizedFolder {
        let bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        let folder = AuthorizedFolder(bookmark: bookmark, path: url.path)
        var folders = loadFolders(from: defaults)
        if !folders.contains(where: { $0.path == folder.path }) {
            folders.append(folder)
            saveFolders(folders, to: defaults)
        }
        return folder
    }

    static func removeFolder(id: UUID, from defaults: UserDefaults = .appGroup) {
        var folders = loadFolders(from: defaults)
        folders.removeAll { $0.id == id }
        saveFolders(folders, to: defaults)
    }

    static func resolveFolderURLs(from folders: [AuthorizedFolder]) -> [URL] {
        var result: [URL] = []
        result.reserveCapacity(folders.count)

        for folder in folders {
            var isStale = false
            guard let url = try? URL(
                resolvingBookmarkData: folder.bookmark,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) else {
                continue
            }
            result.append(url)
        }
        return result
    }

    static func isAuthorized(_ directoryURL: URL, from defaults: UserDefaults = .appGroup) -> Bool {
        let urls = resolveFolderURLs(from: loadFolders(from: defaults))
        guard !urls.isEmpty else {
            return false
        }
        let target = directoryURL.standardizedFileURL.path
        return urls.contains { target.hasPrefix($0.standardizedFileURL.path) }
    }

    static func nearestAuthorizedURL(for directoryURL: URL, from defaults: UserDefaults = .appGroup) -> URL? {
        let urls = resolveFolderURLs(from: loadFolders(from: defaults))
        guard !urls.isEmpty else {
            return nil
        }
        let target = directoryURL.standardizedFileURL.path
        let sorted = urls.sorted { $0.standardizedFileURL.path.count > $1.standardizedFileURL.path.count }
        return sorted.first { target.hasPrefix($0.standardizedFileURL.path) }
    }

    static func withSecurityScopedAccess<T>(to url: URL, _ action: () throws -> T) rethrows -> T {
        let success = url.startAccessingSecurityScopedResource()
        defer {
            if success {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try action()
    }
}
