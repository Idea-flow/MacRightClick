import SwiftUI
import AppKit

@main
struct MacRightClickApp: App {
    @AppStorage("ShowMenuBar", store: .appGroup) private var showMenuBar = true
    @AppStorage("ShowDockIcon", store: .appGroup) private var showDockIcon = true

    init() {
        _ = LogStore.shared
        setupExtensionCommunication()
        sendScopeUpdate()
        sendTemplatesUpdate()
        sendMenuConfigUpdate()
        sendFavoritesUpdate()
        DispatchQueue.main.async {
            DockVisibility.apply(showDockIcon: UserDefaults.appGroup.object(forKey: "ShowDockIcon") as? Bool ?? true)
        }
        AppLogger.log(.info, "App 启动", category: "app")
    }

    var body: some Scene {
        WindowGroup("右键助手", id: "main") {
            ContentView()
        }
        Settings {
            SettingsView()
        }
        MenuBarExtra("右键助手", image: "MenuBarIcon", isInserted: $showMenuBar) {
            MenuBarContentView()
        }
    }

    private func setupExtensionCommunication() {
        DistributedMessenger.shared.onFromExtension { payload in
            if payload.action == "log" {
                // LogStore already consumes log payloads; skip app-level warnings.
                return
            }

            if payload.action == "open-terminal", let target = payload.target {
                openTerminal(at: target)
                return
            }
            if payload.action == "open-favorite-folder", let target = payload.target {
                AppLogger.log(.info, "请求打开目录: \(target)", category: "app")
                openFolder(at: target)
                return
            }
            if payload.action == "open-favorite-app" {
                AppLogger.log(.info, "请求打开 App: path=\(payload.target ?? ""), bundleID=\(payload.appBundleID ?? "")", category: "app")
                openApp(at: payload.target ?? "", bundleID: payload.appBundleID)
                return
            }

            AppLogger.log(.info, "收到消息: \(payload.action)", category: "app")
            guard payload.action == "create-file",
                  let target = payload.target,
                  let templateID = payload.templateID else {
                AppLogger.log(.warning, "消息缺少必要字段: \(payload)", category: "app")
                return
            }

            let enabled = TemplateStore.enabledTemplates()
            guard let template = enabled.first(where: { $0.id == templateID }) else {
                AppLogger.log(.warning, "未找到模板: \(templateID)", category: "app")
                return
            }

            let directoryURL = URL(fileURLWithPath: target)
            guard let scopeURL = AuthorizedFolderStore.nearestAuthorizedURL(for: directoryURL) else {
                AppLogger.log(.warning, "目录未授权: \(directoryURL.path)", category: "authorization")
                return
            }

            Task.detached(priority: .userInitiated) {
                do {
                    let fileURL = try AuthorizedFolderStore.withSecurityScopedAccess(to: scopeURL) {
                        try FileCreator.createFile(template: template, in: directoryURL)
                    }
                    AppLogger.log(.info, "创建文件成功: \(fileURL.path)", category: "app")
                } catch {
                    AppLogger.log(.error, "创建文件失败: \(directoryURL.path) \(error.localizedDescription)", category: "app")
                }
            }
        }
    }

    private func sendScopeUpdate() {
        let paths = AuthorizedFolderStore.authorizedPaths()
        DistributedMessenger.shared.sendToExtension(MessagePayload(action: "update-scope", targets: paths))
    }

    private func sendTemplatesUpdate() {
        let enabled = TemplateStore.enabledTemplates()
        DistributedMessenger.shared.sendToExtension(MessagePayload(action: "update-templates", templates: enabled))
    }

    private func sendMenuConfigUpdate() {
        let config = MenuConfigStore.load()
        DistributedMessenger.shared.sendToExtension(MessagePayload(action: "update-menu-config", menuConfig: config))
    }

    private func sendFavoritesUpdate() {
        var folders = FavoriteFolderStore.load()
        let folderBefore = folders.count
        folders.removeAll { $0.path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if folders.count != folderBefore {
            AppLogger.log(.warning, "常用目录存在空路径，已清理 \(folderBefore - folders.count) 个", category: "app")
            FavoriteFolderStore.save(folders)
        }

        var apps = FavoriteAppStore.load()
        var repaired = 0
        var removed = 0
        apps = apps.compactMap { app in
            if app.path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier) {
                    var fixed = app
                    fixed.path = url.path
                    repaired += 1
                    return fixed
                }
                removed += 1
                return nil
            }
            return app
        }
        if repaired > 0 || removed > 0 {
            AppLogger.log(.warning, "常用 App 路径修复: 修复 \(repaired) 个, 移除 \(removed) 个", category: "app")
            FavoriteAppStore.save(apps)
        }

        let enabledFolders = folders.filter { $0.isEnabled }
        let enabledApps = apps.filter { $0.isEnabled }
        DistributedMessenger.shared.sendToExtension(
            MessagePayload(action: "update-favorites", favoriteFolders: enabledFolders, favoriteApps: enabledApps)
        )
    }

    private func openFolder(at path: String) {
        guard !path.isEmpty else {
            AppLogger.log(.warning, "打开目录失败：路径为空", category: "app")
            return
        }
        let url = URL(fileURLWithPath: path, isDirectory: true)
        guard FileManager.default.fileExists(atPath: url.path) else {
            AppLogger.log(.error, "打开目录失败：路径不存在 \(url.path)", category: "app")
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func openApp(at path: String, bundleID: String?) {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBundleID = (bundleID ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let configuration = NSWorkspace.OpenConfiguration()

        // 1) Prefer bundleIdentifier to locate the real app bundle path.
        if !trimmedBundleID.isEmpty {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: trimmedBundleID) {
                AppLogger.log(.info, "通过 bundleID 找到 App: \(trimmedBundleID) -> \(url.path)", category: "app")
                NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
                    if let error {
                        AppLogger.log(.error, "打开 App 失败: \(url.path) \(error.localizedDescription)", category: "app")
                    } else {
                        AppLogger.log(.info, "打开 App 成功: \(url.path)", category: "app")
                    }
                }
                return
            } else {
                AppLogger.log(.warning, "通过 bundleID 未找到 App: \(trimmedBundleID)", category: "app")
            }
        }

        // 2) Fallback to raw path if bundleID lookup failed or absent.
        guard !trimmedPath.isEmpty else {
            AppLogger.log(.warning, "打开 App 失败：路径为空且 bundleID 无效", category: "app")
            return
        }
        let url = URL(fileURLWithPath: trimmedPath, isDirectory: false)
        guard FileManager.default.fileExists(atPath: url.path) else {
            AppLogger.log(.error, "打开 App 失败：路径不存在 \(url.path)", category: "app")
            return
        }
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            if let error {
                AppLogger.log(.error, "打开 App 失败: \(url.path) \(error.localizedDescription)", category: "app")
            } else {
                AppLogger.log(.info, "打开 App 成功: \(url.path)", category: "app")
            }
        }
    }

    private func openTerminal(at path: String) {
        let process = Process()
        process.launchPath = "/usr/bin/open"
        process.arguments = ["-a", "Terminal", path]
        do {
            try process.run()
        } catch {
            AppLogger.log(.error, "打开终端失败: \(path) \(error.localizedDescription)", category: "app")
        }
    }
}

private struct MenuBarContentView: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("打开主程序") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        Divider()
        Button("退出") {
            NSApp.terminate(nil)
        }
    }
}
