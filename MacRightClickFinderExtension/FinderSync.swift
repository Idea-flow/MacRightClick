import Cocoa
import FinderSync
import CoreGraphics

final class FinderSync: FIFinderSync {
    private var templates: [FileTemplate] = []
    private var templateIDsByTag: [Int: UUID] = [:]
    private var menuConfig: MenuConfig = .default
    private var favoriteFolders: [FavoriteFolder] = []
    private var favoriteApps: [FavoriteApp] = []

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
            case "update-menu-config":
                if let config = payload.menuConfig {
                    self.menuConfig = config
                    AppLogger.log(.info, "菜单配置已更新", category: "finder")
                }
            case "update-favorites":
                if let folders = payload.favoriteFolders {
                    self.favoriteFolders = folders
                }
                if let apps = payload.favoriteApps {
                    self.favoriteApps = apps
                }
                AppLogger.log(.info, "常用列表已更新", category: "finder")
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

        AppLogger.log(.info, "右键菜单打开", category: "finder")

        let menu = NSMenu(title: "快捷操作")
        menu.autoenablesItems = false

        switch menuKind {
        case .contextualMenuForContainer: // 空白区域
            if menuConfig.container.newFileEnabled {
                addNewFileMenu(to: menu)
            }
            if menuConfig.container.copyPathEnabled {
                addCopyCurrentDirectoryPath(to: menu)
            }
            if menuConfig.container.openTerminalEnabled {
                addOpenTerminalMenu(to: menu)
            }
            if !favoriteFolders.isEmpty {
                addFavoriteFoldersMenu(to: menu)
            }
            if !favoriteApps.isEmpty {
                addFavoriteAppsMenu(to: menu)
            }
        case .contextualMenuForItems: // items
            if menuConfig.items.copyPathEnabled {
                addCopyPathMenu(to: menu)
            }
        default:
            break
        }
        return menu
    }

    @objc func createFile(_ sender: NSMenuItem) {
        guard let templateID = templateIDsByTag[sender.tag] else {
            AppLogger.log(.warning, "无法找到模板ID，tag: \(sender.tag)", category: "finder")
            return
        }

        let controller = FIFinderSyncController.default()
        let targetURL = controller.targetedURL() ?? controller.selectedItemURLs()?.first
        guard let targetURL else {
            return
        }

        let directoryURL = targetURL.hasDirectoryPath ? targetURL : targetURL.deletingLastPathComponent()
        DistributedMessenger.shared.sendToApp(
            MessagePayload(action: "create-file", target: directoryURL.path, templateID: templateID)
        )
        AppLogger.log(.info, "已点击菜单: \(sender.title)", category: "finder")
        AppLogger.log(.info, "发送创建请求: \(directoryURL.path) templateID: \(templateID)", category: "finder")
        AppLogger.log(.info, "已请求创建文件: \(directoryURL.path)", category: "finder")
    }
}

// MARK: - Menu Builders
private extension FinderSync {
    func addNewFileMenu(to menu: NSMenu) {
        guard !templates.isEmpty else {
            AppLogger.log(.warning, "未启用任何模板，菜单不显示", category: "finder")
            return
        }
        let parentItem = NSMenuItem(title: "新建文件", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "新建文件")
        submenu.autoenablesItems = false

        templateIDsByTag.removeAll(keepingCapacity: true)
        var tagCounter = 1
        for template in templates {
            let item = NSMenuItem(title: template.displayName, action: #selector(FinderSync.createFile(_:)), keyEquivalent: "")
            item.target = self
            item.isEnabled = true
            item.tag = tagCounter
            templateIDsByTag[tagCounter] = template.id
            tagCounter += 1
            submenu.addItem(item)
        }

        parentItem.submenu = submenu
        menu.addItem(parentItem)
    }

    func addCopyPathMenu(to menu: NSMenu) {
        // Only show one menu item. Click decides whether to copy selected items
        // or the current directory path, so there is no extra submenu.
        let item = NSMenuItem(title: "复制当前路径", action: #selector(copyCurrentPath(_:)), keyEquivalent: "")
        item.target = self
        item.isEnabled = true
        menu.addItem(item)
    }

    func addCopyCurrentDirectoryPath(to menu: NSMenu) {
        let item = NSMenuItem(title: "复制当前目录路径", action: #selector(copyCurrentDirectoryPath(_:)), keyEquivalent: "")
        item.target = self
        item.isEnabled = true
        menu.addItem(item)
    }

    func addOpenTerminalMenu(to menu: NSMenu) {
        let item = NSMenuItem(title: "进入终端", action: #selector(openTerminal(_:)), keyEquivalent: "")
        item.target = self
        item.isEnabled = true
        menu.addItem(item)
    }

    func addFavoriteFoldersMenu(to menu: NSMenu) {
        let parentItem = NSMenuItem(title: "常用目录", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "常用目录")
        submenu.autoenablesItems = false

        for folder in favoriteFolders {
            let item = NSMenuItem(title: folder.name, action: #selector(openFavoriteFolder(_:)), keyEquivalent: "")
            item.target = self
            item.toolTip = folder.path
            item.representedObject = folder
            submenu.addItem(item)
        }

        parentItem.submenu = submenu
        menu.addItem(parentItem)
    }

    func addFavoriteAppsMenu(to menu: NSMenu) {
        let parentItem = NSMenuItem(title: "常用 App", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "常用 App")
        submenu.autoenablesItems = false

        for app in favoriteApps {
            let item = NSMenuItem(title: app.name, action: #selector(openFavoriteApp(_:)), keyEquivalent: "")
            item.target = self
            item.toolTip = app.path
            item.representedObject = app
            submenu.addItem(item)
        }

        parentItem.submenu = submenu
        menu.addItem(parentItem)
    }
}

// MARK: - Copy Actions
private extension FinderSync {
    @objc func copyCurrentPath(_ sender: NSMenuItem) {
        // If there are selected items, copy their paths; otherwise copy the current directory.
        if let urls = FIFinderSyncController.default().selectedItemURLs(),
           !urls.isEmpty {
            let paths = urls.map { $0.path }
            writePathsToPasteboard(paths)
            AppLogger.log(.info, "已复制所选项路径: \(paths.joined(separator: ", "))", category: "finder")
            return
        }

        guard let url = FIFinderSyncController.default().targetedURL() else {
            return
        }
        let path = url.path
        writePathsToPasteboard([path])
        AppLogger.log(.info, "已复制当前目录路径: \(path)", category: "finder")
    }

    @objc func copyCurrentDirectoryPath(_ sender: NSMenuItem) {
        guard let url = FIFinderSyncController.default().targetedURL() else {
            return
        }
        let path = url.path
        writePathsToPasteboard([path])
        AppLogger.log(.info, "已复制当前目录路径: \(path)", category: "finder")
    }

    @objc func openTerminal(_ sender: NSMenuItem) {
        guard let url = FIFinderSyncController.default().targetedURL() else {
            return
        }
        DistributedMessenger.shared.sendToApp(
            MessagePayload(action: "open-terminal", target: url.path)
        )
        AppLogger.log(.info, "已请求打开终端: \(url.path)", category: "finder")
    }

    @objc func openFavoriteFolder(_ sender: NSMenuItem) {
        guard let folder = sender.representedObject as? FavoriteFolder else {
            return
        }
        DistributedMessenger.shared.sendToApp(
            MessagePayload(action: "open-favorite-folder", target: folder.path)
        )
        AppLogger.log(.info, "已请求打开目录: \(folder.path)", category: "finder")
    }

    @objc func openFavoriteApp(_ sender: NSMenuItem) {
        guard let app = sender.representedObject as? FavoriteApp else {
            return
        }
        DistributedMessenger.shared.sendToApp(
            MessagePayload(action: "open-favorite-app", target: app.path)
        )
        AppLogger.log(.info, "已请求打开 App: \(app.path)", category: "finder")
    }

    func writePathsToPasteboard(_ paths: [String]) {
        // Explicitly clear then set to avoid mixing with previous clipboard content.
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(paths.joined(separator: "\n"), forType: .string)
    }
}
