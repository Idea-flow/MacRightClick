import SwiftUI

@main
struct MacRightClickApp: App {
    init() {
        _ = LogStore.shared
        setupExtensionCommunication()
        sendScopeUpdate()
        sendTemplatesUpdate()
        AppLogger.log(.info, "App 启动", category: "app")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private func setupExtensionCommunication() {
        DistributedMessenger.shared.onFromExtension { payload in
            guard payload.action == "create-file",
                  let target = payload.target,
                  let template = payload.template else {
                return
            }

            let directoryURL = URL(fileURLWithPath: target)
            guard AuthorizedFolderStore.isAuthorized(directoryURL) else {
                AppLogger.log(.warning, "目录未授权: \(directoryURL.path)", category: "authorization")
                return
            }

            do {
                let fileURL = try AuthorizedFolderStore.withSecurityScopedAccess(to: directoryURL) {
                    try FileCreator.createFile(template: template, in: directoryURL)
                }
                AppLogger.log(.info, "创建文件成功: \(fileURL.path)", category: "app")
            } catch {
                AppLogger.log(.error, "创建文件失败: \(directoryURL.path) \(error.localizedDescription)", category: "app")
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
}
