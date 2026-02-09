import Cocoa
import FinderSync
import CoreGraphics

final class FinderSync: FIFinderSync {
    private var templates: [FileTemplate] = []

    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = []
        DistributedMessenger.shared.onFromApp { payload in
            switch payload.action {
            case "update-scope":
                let urls = payload.targets.map { URL(fileURLWithPath: $0) }
                FIFinderSyncController.default().directoryURLs = Set(urls)
                AppLogger.log(.info, "已更新授权目录: \(payload.targets.joined(separator: ", "))", category: "finder")
            case "update-templates":
                self.templates = payload.templates
                AppLogger.log(.info, "已更新模板列表: \(payload.templates.count) 个", category: "finder")
            default:
                break
            }
        }
        AppLogger.log(.info, "Finder 扩展启动", category: "finder")
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForContainer || menuKind == .contextualMenuForItems else {
            return nil
        }

        guard !templates.isEmpty else {
            AppLogger.log(.warning, "未启用任何模板，菜单不显示", category: "finder")
            return nil
        }
        AppLogger.log(.info, "右键菜单打开", category: "finder")

        let menu = NSMenu(title: "新建文件")
        let parentItem = NSMenuItem(title: "新建文件", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "新建文件")

        for template in templates {
            let item = NSMenuItem(title: template.displayName, action: #selector(createFile(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = template
            submenu.addItem(item)
        }

        parentItem.submenu = submenu
        menu.addItem(parentItem)
        return menu
    }

    @objc private func createFile(_ sender: NSMenuItem) {
        guard let template = sender.representedObject as? FileTemplate else {
            return
        }

        let controller = FIFinderSyncController.default()
        let targetURL = controller.targetedURL() ?? controller.selectedItemURLs()?.first
        guard let targetURL else {
            return
        }

        let directoryURL = targetURL.hasDirectoryPath ? targetURL : targetURL.deletingLastPathComponent()
        DistributedMessenger.shared.sendToApp(
            MessagePayload(action: "create-file", target: directoryURL.path, template: template)
        )
        AppLogger.log(.info, "已请求创建文件: \(directoryURL.path)", category: "finder")
    }
}
