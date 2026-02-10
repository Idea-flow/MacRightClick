import AppKit
import Observation
import SwiftUI

/// Manages loading, applying, and previewing custom dock/menu bar icons.
@MainActor
@Observable
final class AppIconManager {
    static let shared = AppIconManager()

    private var defaultDockIcon: NSImage?

    private(set) var dockIconImage: NSImage?
    private(set) var dockIconPath: String?
    private(set) var menuBarIconImage: NSImage?
    private(set) var menuBarIconPath: String?
    var menuBarIconIsTemplate: Bool = true

    init() {
        loadFromDefaults()
    }

    func applyStoredIcons() {
        loadFromDefaults()
        applyDockIcon()
    }

    func setDockIcon(from url: URL) {
        AppLogger.log(.info, "选择 Dock 图标: \(url.path)", category: "appearance")
        logFileDiagnostics(for: url, label: "Dock")
        do {
            try IconCustomizationStore.saveDockIcon(url: url)
            dockIconPath = url.path
            dockIconImage = IconCustomizationStore.loadImage(from: url)
            if dockIconImage == nil {
                AppLogger.log(.warning, "Dock 图标读取失败: \(url.path)", category: "appearance")
            }
            applyDockIcon()
        } catch {
            AppLogger.log(.error, "保存 Dock 图标失败: \(error.localizedDescription)", category: "appearance")
        }
    }

    func clearDockIcon() {
        IconCustomizationStore.clearDockIcon()
        dockIconImage = nil
        dockIconPath = nil
        applyDockIcon()
    }

    func setMenuBarIcon(from url: URL) {
        AppLogger.log(.info, "选择菜单栏图标: \(url.path)", category: "appearance")
        logFileDiagnostics(for: url, label: "MenuBar")
        do {
            try IconCustomizationStore.saveMenuBarIcon(url: url, isTemplate: menuBarIconIsTemplate)
            menuBarIconPath = url.path
            menuBarIconImage = IconCustomizationStore.loadImage(from: url)
            menuBarIconImage?.isTemplate = menuBarIconIsTemplate
            if menuBarIconImage == nil {
                AppLogger.log(.warning, "菜单栏图标读取失败，已回退默认: \(url.path)", category: "appearance")
                IconCustomizationStore.clearMenuBarIcon()
                menuBarIconPath = nil
            }
        } catch {
            AppLogger.log(.error, "保存菜单栏图标失败: \(error.localizedDescription)", category: "appearance")
        }
    }

    func clearMenuBarIcon() {
        IconCustomizationStore.clearMenuBarIcon()
        menuBarIconImage = nil
        menuBarIconPath = nil
    }

    func setMenuBarTemplate(_ isTemplate: Bool) {
        menuBarIconIsTemplate = isTemplate
        IconCustomizationStore.setMenuBarIconIsTemplate(isTemplate)
        menuBarIconImage?.isTemplate = isTemplate
    }

    func dockPreviewImage() -> NSImage? {
        dockIconImage ?? ensureDefaultDockIcon()
    }

    func menuBarPreviewImage() -> NSImage? {
        menuBarIconImage ?? NSImage(named: "MenuBarIcon")
    }

    func menuBarLabel() -> some View {
        Label {
            Text("右键助手")
        } icon: {
            menuBarIconView()
        }
    }

    private func loadFromDefaults() {
        dockIconPath = IconCustomizationStore.dockIconPath()
        menuBarIconPath = IconCustomizationStore.menuBarIconPath()
        menuBarIconIsTemplate = IconCustomizationStore.menuBarIconIsTemplate()

        if let dockURL = IconCustomizationStore.resolveDockIconURL() {
            dockIconImage = IconCustomizationStore.loadImage(from: dockURL)
        } else {
            dockIconImage = nil
        }

        if let menuURL = IconCustomizationStore.resolveMenuBarIconURL() {
            menuBarIconImage = IconCustomizationStore.loadImage(from: menuURL)
            menuBarIconImage?.isTemplate = menuBarIconIsTemplate
        } else {
            menuBarIconImage = nil
        }
    }

    private func applyDockIcon() {
        let fallback = ensureDefaultDockIcon()
        NSApp.applicationIconImage = dockIconImage ?? fallback
    }

    private func ensureDefaultDockIcon() -> NSImage? {
        if defaultDockIcon == nil {
            defaultDockIcon = NSApp.applicationIconImage
        }
        return defaultDockIcon
    }

    private func logFileDiagnostics(for url: URL, label: String) {
        IconCustomizationStore.withSecurityScopedAccess(to: url) {
            let fm = FileManager.default
            let path = url.path
            let exists = fm.fileExists(atPath: path)
            let readable = fm.isReadableFile(atPath: path)
            let size = (try? fm.attributesOfItem(atPath: path)[.size] as? NSNumber)?.intValue ?? -1
            AppLogger.log(.info, "\(label) 图标文件状态: exists=\(exists), readable=\(readable), size=\(size), path=\(path)", category: "appearance")
        }
    }

    @ViewBuilder
    private func menuBarIconView() -> some View {
        let size: CGFloat = 18
        if let image = menuBarIconImage {
            Image(nsImage: image)
                .resizable()
                .renderingMode(menuBarIconIsTemplate ? .template : .original)
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image("MenuBarIcon")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: size, height: size)
        }
    }
}
