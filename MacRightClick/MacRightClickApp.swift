import SwiftUI

@main
struct MacRightClickApp: App {
    @AppStorage("ShowMenuBar", store: .appGroup) private var showMenuBar = true
    @AppStorage("ShowDockIcon", store: .appGroup) private var showDockIcon = true

    init() {
        _ = LogStore.shared
        setupExtensionCommunication()
        sendScopeUpdate()
        sendTemplatesUpdate()
        sendMenuSettingsUpdate()
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

    private func sendMenuSettingsUpdate() {
        let enabled = UserDefaults.appGroup.object(forKey: "CopyPathsMenuEnabled") as? Bool ?? true
        DistributedMessenger.shared.sendToExtension(MessagePayload(action: "update-menu-settings", copyPathsEnabled: enabled))
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
