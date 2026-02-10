import SwiftUI
import AppKit

@main
struct MacRightClickApp: App {
    @AppStorage("ShowMenuBar", store: .appGroup) private var showMenuBar = true
    @AppStorage("ShowDockIcon", store: .appGroup) private var showDockIcon = true
    @State private var iconManager = AppIconManager.shared

    init() {
        _ = LogStore.shared
        setupExtensionCommunication()
        sendScopeUpdate()
        sendTemplatesUpdate()
        sendMenuConfigUpdate()
        sendFavoritesUpdate()
        sendAppRunning()
        DispatchQueue.main.async {
            DockVisibility.apply(showDockIcon: UserDefaults.appGroup.object(forKey: "ShowDockIcon") as? Bool ?? true)
            AppIconManager.shared.applyStoredIcons()
        }
        AppLogger.log(.info, "App 启动", category: "app")

        // Ensure quit notification is sent when the app terminates.
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            AppLogger.log(.info, "发送主程序退出通知", category: "app")
            DistributedMessenger.shared.sendToExtension(MessagePayload(action: "app-quit"))
        }
    }

    var body: some Scene {
        WindowGroup("右键助手", id: "main") {
            ContentView()
                .environment(iconManager)
        }
        Settings {
            SettingsView()
                .environment(iconManager)
        }
        MenuBarExtra(isInserted: $showMenuBar) {
            MenuBarContentView()
        } label: {
            iconManager.menuBarLabel()
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
            if payload.action == "move-items" {
                let target = payload.target ?? ""
                let items = payload.targets
                AppLogger.log(.info, "请求移动: \(items.joined(separator: ", ")) -> \(target)", category: "app")
                Task {
                    await moveItems(targetDirectory: target, itemPaths: items)
                }
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

    private func sendAppRunning() {
        AppLogger.log(.info, "发送主程序启动通知", category: "app")
        DistributedMessenger.shared.sendToExtension(MessagePayload(action: "app-running"))
    }

    private func sendAppQuit() {
        AppLogger.log(.info, "发送主程序退出通知", category: "app")
        DistributedMessenger.shared.sendToExtension(MessagePayload(action: "app-quit"))
    }

    private func openFolder(at path: String) {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            AppLogger.log(.warning, "打开目录失败：路径为空", category: "app")
            return
        }
        let url = URL(fileURLWithPath: trimmedPath, isDirectory: true)
        guard FileManager.default.fileExists(atPath: url.path) else {
            AppLogger.log(.error, "打开目录失败：路径不存在 \(url.path)", category: "app")
            return
        }

        Task {
            guard let scopeURL = await ensureAuthorizedScope(for: url) else {
                AppLogger.log(.warning, "打开目录失败：未授权 \(url.path)", category: "authorization")
                return
            }
            do {
                try AuthorizedFolderStore.withSecurityScopedAccess(to: scopeURL) {
                    NSWorkspace.shared.open(url)
                }
                AppLogger.log(.info, "打开目录成功: \(url.path)", category: "app")
            } catch {
                AppLogger.log(.error, "打开目录失败: \(url.path) \(error.localizedDescription)", category: "app")
            }
        }
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
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            AppLogger.log(.warning, "打开终端失败：路径为空", category: "app")
            return
        }
        AppLogger.log(.info, "准备打开终端: \(trimmedPath)", category: "app")
        let directoryURL = URL(fileURLWithPath: trimmedPath, isDirectory: true)
        guard FileManager.default.fileExists(atPath: directoryURL.path) else {
            AppLogger.log(.error, "打开终端失败：路径不存在 \(directoryURL.path)", category: "app")
            return
        }

        Task {
            guard let scopeURL = await ensureAuthorizedScope(for: directoryURL, mode: .guide) else {
                AppLogger.log(.warning, "打开终端失败：目录未授权 \(directoryURL.path)", category: "authorization")
                return
            }
            do {
                try AuthorizedFolderStore.withSecurityScopedAccess(to: scopeURL) {
                    openTerminalWithWorkspace(directoryURL: directoryURL)
                }
            } catch {
                AppLogger.log(.error, "打开终端失败: \(directoryURL.path) \(error.localizedDescription)", category: "app")
            }
        }
    }

    private func openTerminalWithWorkspace(directoryURL: URL) {
        if let terminalURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") {
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open([directoryURL], withApplicationAt: terminalURL, configuration: config) { _, error in
                if let error {
                    AppLogger.log(.error, "打开终端失败: \(directoryURL.path) \(error.localizedDescription)", category: "app")
                    AppLogger.log(.error, "Terminal URL: \(terminalURL.path)", category: "app")
                } else {
                    AppLogger.log(.info, "已请求打开终端: \(directoryURL.path)", category: "app")
                }
            }
            return
        }

        // 备用方案：/usr/bin/open
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Terminal", directoryURL.path]
        do {
            try process.run()
            AppLogger.log(.info, "已请求打开终端(备用): \(directoryURL.path)", category: "app")
        } catch {
            AppLogger.log(.error, "打开终端失败(备用): \(directoryURL.path) \(error.localizedDescription)", category: "app")
            AppLogger.log(.error, "备用命令: /usr/bin/open -a Terminal \(directoryURL.path)", category: "app")
        }
    }

    private func moveItems(targetDirectory: String, itemPaths: [String]) async {
        let trimmedTarget = targetDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTarget.isEmpty else {
            AppLogger.log(.warning, "移动失败：目标目录为空", category: "move")
            return
        }
        guard itemPaths.isEmpty == false else {
            AppLogger.log(.warning, "移动失败：未提供任何条目", category: "move")
            return
        }

        let targetURL = URL(fileURLWithPath: trimmedTarget, isDirectory: true)
        guard let targetScopeURL = await ensureAuthorizedScope(for: targetURL) else {
            AppLogger.log(.warning, "移动失败：目标目录未授权 \(targetURL.path)", category: "move")
            return
        }

        let fileManager = FileManager.default
        var successCount = 0
        var failureCount = 0

        for path in itemPaths {
            let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedPath.isEmpty { continue }
            let sourceURL = URL(fileURLWithPath: trimmedPath)
            let sourceDir = sourceURL.deletingLastPathComponent()
            guard let sourceScopeURL = await ensureAuthorizedScope(for: sourceDir) else {
                AppLogger.log(.warning, "移动失败：源目录未授权 \(sourceDir.path)", category: "move")
                failureCount += 1
                continue
            }

            do {
                let destinationURL = targetURL.appendingPathComponent(sourceURL.lastPathComponent)
                try AuthorizedFolderStore.withSecurityScopedAccess(to: targetScopeURL) {
                    try AuthorizedFolderStore.withSecurityScopedAccess(to: sourceScopeURL) {
                        if fileManager.fileExists(atPath: destinationURL.path) {
                            throw NSError(domain: "MoveItems", code: 1, userInfo: [NSLocalizedDescriptionKey: "目标已存在: \(destinationURL.lastPathComponent)"])
                        }
                        try fileManager.copyItem(at: sourceURL, to: destinationURL)
                        try fileManager.removeItem(at: sourceURL)
                    }
                }
                successCount += 1
                AppLogger.log(.info, "移动成功: \(sourceURL.path) -> \(destinationURL.path)", category: "move")
            } catch {
                failureCount += 1
                AppLogger.log(.error, "移动失败: \(sourceURL.path) \(error.localizedDescription)", category: "move")
            }
        }

        AppLogger.log(.info, "移动完成：成功 \(successCount) 个，失败 \(failureCount) 个", category: "move")
    }

    private enum AuthorizationPromptMode {
        case panel
        case guide
    }

    @MainActor
    private func openAuthorizedFoldersPage() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
        NotificationCenter.default.post(name: AppNotifications.openAuthorizedFolders, object: nil)
    }

    private func ensureAuthorizedScope(for directoryURL: URL, mode: AuthorizationPromptMode = .panel) async -> URL? {
        if let scope = AuthorizedFolderStore.nearestAuthorizedURL(for: directoryURL) {
            return scope
        }

        if mode == .guide {
            await MainActor.run {
                openAuthorizedFoldersPage()
            }
            return nil
        }

        // 未授权时允许弹窗一次，引导用户选择目录并保存安全书签。
        let selectedURL = await MainActor.run { () -> URL? in
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.allowsMultipleSelection = false
            panel.prompt = "授权"
            panel.message = "需要授权访问该目录以完成移动操作。请选择对应目录或其父目录。"
            panel.directoryURL = directoryURL
            return panel.runModal() == .OK ? panel.url : nil
        }

        guard let url = selectedURL else {
            return nil
        }

        do {
            let folder = try AuthorizedFolderStore.addFolder(url: url)
            AppLogger.log(.info, "已新增授权目录: \(folder.path)", category: "authorization")
            // 同步授权范围给 Finder 扩展
            sendScopeUpdate()
            return URL(fileURLWithPath: folder.path, isDirectory: true)
        } catch {
            AppLogger.log(.error, "授权失败: \(url.path) \(error.localizedDescription)", category: "authorization")
            return nil
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
