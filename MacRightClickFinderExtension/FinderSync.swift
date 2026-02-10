import Cocoa
import FinderSync
import CoreGraphics
import UniformTypeIdentifiers

final class FinderSync: FIFinderSync {
    private var templates: [FileTemplate] = []
    private var templateIDsByTag: [Int: UUID] = [:]
    private var favoriteFolderByTag: [Int: FavoriteFolder] = [:]
    private var favoriteAppByTag: [Int: FavoriteApp] = [:]
    private var moveTargetByTag: [Int: FavoriteFolder] = [:]
    private var menuConfig: MenuConfig = .default
    private var favoriteFolders: [FavoriteFolder] = []
    private var favoriteApps: [FavoriteApp] = []
    private var isHostAppOpen = false

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
                    let emptyCount = folders.filter { $0.path.isEmpty }.count
                    AppLogger.log(.info, "常用目录已更新: \(folders.count) 个（空路径: \(emptyCount)）", category: "finder")
                }
                if let apps = payload.favoriteApps {
                    self.favoriteApps = apps
                    let emptyCount = apps.filter { $0.path.isEmpty }.count
                    AppLogger.log(.info, "常用 App 已更新: \(apps.count) 个（空路径: \(emptyCount)）", category: "finder")
                }
            case "app-running":
                self.isHostAppOpen = true
//                AppLogger.log(.info, "主程序已启动，扩展恢复可用", category: "finder")
            case "app-quit":
                self.isHostAppOpen = false
//                AppLogger.log(.info, "主程序已退出，扩展禁用菜单", category: "finder")
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

        // 主程序不在线时，不提供任何菜单项。
        guard isHostAppOpen else {
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
            if menuConfig.container.favoriteFoldersEnabled, !favoriteFolders.isEmpty {
                addFavoriteFoldersMenu(to: menu)
            }
            if menuConfig.container.favoriteAppsEnabled, !favoriteApps.isEmpty {
                addFavoriteAppsMenu(to: menu)
            }
        case .contextualMenuForItems: // items
            if menuConfig.items.copyPathEnabled {
                addCopyPathMenu(to: menu)
            }
            if menuConfig.items.moveToEnabled, !favoriteFolders.isEmpty {
                addMoveToMenu(to: menu)
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
    /// 一级菜单图标：使用调色板渲染（双色/轻渐变），更贴近系统菜单的层级质感。
    func applyPrimaryIcon(symbol: String, to item: NSMenuItem) {
        guard menuConfig.showIcons else { return }
        guard let base = NSImage(systemSymbolName: symbol, accessibilityDescription: symbol) else { return }
        if #available(macOS 13.0, *),
           let configured = base.withSymbolConfiguration(
            .init(paletteColors: [NSColor.controlAccentColor, NSColor.secondaryLabelColor])
           ) {
            configured.isTemplate = false
            item.image = configured
            return
        }
        // 回退：模板单色，由系统菜单自动着色
        base.isTemplate = true
        base.size = NSSize(width: 16, height: 16)
        item.image = base
    }

    /// 二级菜单图标：保持系统模板灰阶，避免视觉干扰。
    func applySecondaryIcon(symbol: String, to item: NSMenuItem) {
        guard menuConfig.showIcons else { return }
        guard let base = NSImage(systemSymbolName: symbol, accessibilityDescription: symbol) else { return }
        base.isTemplate = true
        base.size = NSSize(width: 16, height: 16)
        item.image = base
    }

    /// 设置“常用 App”菜单图标，优先使用应用自身图标（彩色）。
    /// 当应用路径无效时回退为通用 App 图标。
    func applyAppIcon(path: String, to item: NSMenuItem) {
        guard menuConfig.showIcons else { return } // 用户关闭图标时不渲染
        guard FileManager.default.fileExists(atPath: path) else { // 路径无效时回退
            applySecondaryIcon(symbol: "app", to: item)
            return
        }
        let image = NSWorkspace.shared.icon(forFile: path) // 系统读取应用图标
        image.size = NSSize(width: 16, height: 16) // 统一尺寸
        image.isTemplate = false // 保持原色
        item.image = image
    }

    /// 设置“新建文件”子菜单图标，与主程序模板列表保持一致。
    /// 使用 UTType 获取系统文件类型图标；无法识别则回退为扩展名图标。
    func applyFileTypeIcon(for template: FileTemplate, to item: NSMenuItem) {
        guard menuConfig.showIcons else { return } // 用户关闭图标时不渲染
        let ext = template.kind.iconFileExtension // 统一扩展名来源
        if let utType = UTType(filenameExtension: ext) { // 优先走 UTType
            item.image = NSWorkspace.shared.icon(forFileType: utType.identifier)
        } else {
            item.image = NSWorkspace.shared.icon(forFileType: ext) // 回退：直接用扩展名
        }
        item.image?.size = NSSize(width: 16, height: 16) // 统一尺寸
    }


    func addNewFileMenu(to menu: NSMenu) {
        guard !templates.isEmpty else {
            AppLogger.log(.warning, "未启用任何模板，菜单不显示", category: "finder")
            return
        }
        let parentItem = NSMenuItem(title: "新建文件", action: nil, keyEquivalent: "")
        applyPrimaryIcon(symbol: "doc.badge.plus", to: parentItem) // 一级菜单图标
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
            applyFileTypeIcon(for: template, to: item) // 子菜单使用文件类型图标
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
        applyPrimaryIcon(symbol: "doc.on.doc", to: item)
        menu.addItem(item)
    }

    func addCopyCurrentDirectoryPath(to menu: NSMenu) {
        let item = NSMenuItem(title: "复制当前目录路径", action: #selector(copyCurrentDirectoryPath(_:)), keyEquivalent: "")
        item.target = self
        item.isEnabled = true
        applyPrimaryIcon(symbol: "folder", to: item)
        menu.addItem(item)
    }

    func addOpenTerminalMenu(to menu: NSMenu) {
        let item = NSMenuItem(title: "进入终端", action: #selector(openTerminal(_:)), keyEquivalent: "")
        item.target = self
        item.isEnabled = true
        applyPrimaryIcon(symbol: "terminal", to: item)
        menu.addItem(item)
    }

    func addFavoriteFoldersMenu(to menu: NSMenu) {
        let parentItem = NSMenuItem(title: "常用目录", action: nil, keyEquivalent: "")
        applyPrimaryIcon(symbol: "folder", to: parentItem)
        let submenu = NSMenu(title: "常用目录")
        submenu.autoenablesItems = false

        favoriteFolderByTag.removeAll(keepingCapacity: true)
        var tagCounter = 1
        for folder in favoriteFolders {
            guard !folder.path.isEmpty else {
                AppLogger.log(.warning, "常用目录路径为空，已跳过：\(folder.name)", category: "finder")
                continue
            }
            let item = NSMenuItem(title: folder.name, action: #selector(openFavoriteFolder(_:)), keyEquivalent: "")
            item.target = self
            item.toolTip = folder.path
            item.tag = tagCounter
            favoriteFolderByTag[tagCounter] = folder
            tagCounter += 1
            applySecondaryIcon(symbol: "folder", to: item)
            submenu.addItem(item)
        }

        parentItem.submenu = submenu
        menu.addItem(parentItem)
    }

    func addFavoriteAppsMenu(to menu: NSMenu) {
        let parentItem = NSMenuItem(title: "常用 App", action: nil, keyEquivalent: "")
        applyPrimaryIcon(symbol: "app", to: parentItem)
        let submenu = NSMenu(title: "常用 App")
        submenu.autoenablesItems = false

        favoriteAppByTag.removeAll(keepingCapacity: true)
        var tagCounter = 1
        for app in favoriteApps {
            guard !app.path.isEmpty else {
                AppLogger.log(.warning, "常用 App 路径为空，已跳过：\(app.name)", category: "finder")
                continue
            }
            let item = NSMenuItem(title: app.name, action: #selector(openFavoriteApp(_:)), keyEquivalent: "")
            item.target = self
            item.toolTip = app.path
            item.tag = tagCounter
            favoriteAppByTag[tagCounter] = app
            tagCounter += 1
            applyAppIcon(path: app.path, to: item)
            submenu.addItem(item)
        }

        parentItem.submenu = submenu
        menu.addItem(parentItem)
    }

    func addMoveToMenu(to menu: NSMenu) {
        let parentItem = NSMenuItem(title: "移动到", action: nil, keyEquivalent: "")
        applyPrimaryIcon(symbol: "folder.badge.arrow.down", to: parentItem)
        let submenu = NSMenu(title: "移动到")
        submenu.autoenablesItems = false

        moveTargetByTag.removeAll(keepingCapacity: true)
        var tagCounter = 1
        for folder in favoriteFolders {
            guard !folder.path.isEmpty else {
                continue
            }
            let item = NSMenuItem(title: folder.name, action: #selector(moveSelectedItems(_:)), keyEquivalent: "")
            item.target = self
            item.toolTip = folder.path
            item.tag = tagCounter
            moveTargetByTag[tagCounter] = folder
            tagCounter += 1
            applySecondaryIcon(symbol: "folder", to: item)
            submenu.addItem(item)
        }

        if submenu.items.isEmpty == false {
            parentItem.submenu = submenu
            menu.addItem(parentItem)
        }
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
        guard let folder = favoriteFolderByTag[sender.tag] else {
            AppLogger.log(.warning, "打开目录失败：未找到对应条目（menuTitle: \(sender.title), tag: \(sender.tag)）", category: "finder")
            return
        }
        DistributedMessenger.shared.sendToApp(
            MessagePayload(action: "open-favorite-folder", target: folder.path)
        )
        AppLogger.log(.info, "已请求打开目录: \(folder.path)", category: "finder")
    }

    @objc func openFavoriteApp(_ sender: NSMenuItem) {
        guard let app = favoriteAppByTag[sender.tag] else {
            AppLogger.log(.warning, "打开 App 失败：未找到对应条目（menuTitle: \(sender.title), tag: \(sender.tag)）", category: "finder")
            return
        }
        DistributedMessenger.shared.sendToApp(
            MessagePayload(action: "open-favorite-app", target: app.path, appBundleID: app.bundleIdentifier)
        )
        AppLogger.log(.info, "已请求打开 App: path=\(app.path), bundleID=\(app.bundleIdentifier)", category: "finder")
    }

    @objc func moveSelectedItems(_ sender: NSMenuItem) {
        guard let targetFolder = moveTargetByTag[sender.tag] else {
            AppLogger.log(.warning, "移动失败：未找到目标目录（menuTitle: \(sender.title), tag: \(sender.tag)）", category: "finder")
            return
        }
        guard let urls = FIFinderSyncController.default().selectedItemURLs(),
              urls.isEmpty == false else {
            AppLogger.log(.warning, "移动失败：未选中任何条目", category: "finder")
            return
        }
        let paths = urls.map { $0.path }
        DistributedMessenger.shared.sendToApp(
            MessagePayload(action: "move-items", target: targetFolder.path, targets: paths)
        )
        AppLogger.log(.info, "已请求移动: \(paths.joined(separator: ", ")) -> \(targetFolder.path)", category: "finder")
    }

    func writePathsToPasteboard(_ paths: [String]) {
        // Explicitly clear then set to avoid mixing with previous clipboard content.
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(paths.joined(separator: "\n"), forType: .string)
    }
}
