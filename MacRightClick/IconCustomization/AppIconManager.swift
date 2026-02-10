import AppKit
import Observation
import SwiftUI

/// Manages loading, applying, and previewing custom dock/menu bar icons.
@MainActor
@Observable
final class AppIconManager {
    static let shared = AppIconManager()

    private var defaultDockIcon: NSImage?
    private let dockIconCanvasSize: CGFloat = 1024
    private let dockIconMinPixels: CGFloat = 256
    private let dockIconMaxPixels: CGFloat = 4096
    private let menuBarMinPixels: CGFloat = 12
    private let menuBarMaxPixels: CGFloat = 256

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
        _ = ensureDefaultDockIcon()
        do {
            dockIconImage = IconCustomizationStore.loadImage(from: url)
            if dockIconImage == nil {
                AppLogger.log(.warning, "Dock 图标读取失败: \(url.path)", category: "appearance")
                showAlert(title: "Dock 图标读取失败", message: "无法读取所选图片，请更换后重试。")
                return
            }
            if let image = dockIconImage, !validateDockImageSize(image, url: url) {
                dockIconImage = nil
                return
            }
            if let image = dockIconImage {
                dockIconImage = renderDockIcon(from: image)
            }
            guard dockIconImage != nil else {
                AppLogger.log(.warning, "Dock 图标处理失败: \(url.path)", category: "appearance")
                showAlert(title: "Dock 图标处理失败", message: "无法生成符合规范的 Dock 图标，请更换图片。")
                return
            }
            dockIconImage?.isTemplate = false
            try IconCustomizationStore.saveDockIcon(url: url)
            dockIconPath = url.path
            applyDockIcon()
        } catch {
            AppLogger.log(.error, "保存 Dock 图标失败: \(error.localizedDescription)", category: "appearance")
            showAlert(title: "保存 Dock 图标失败", message: error.localizedDescription)
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
        let icon = dockIconImage ?? fallback
        icon?.isTemplate = false
        NSApp.applicationIconImage = icon
    }

    private func ensureDefaultDockIcon() -> NSImage? {
        if defaultDockIcon == nil {
            // Use bundle app icon as the stable default instead of current NSApp icon.
            defaultDockIcon = NSImage(named: NSImage.applicationIconName)
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

    private func validateDockImageSize(_ image: NSImage, url: URL) -> Bool {
        let size = imagePixelSize(image)
        guard size.width > 0, size.height > 0 else {
            AppLogger.log(.warning, "Dock 图标尺寸无效: \(url.path)", category: "appearance")
            showAlert(title: "Dock 图标尺寸无效", message: "请选择有效的图片文件。")
            return false
        }
        let maxSide = max(size.width, size.height)
        let minSide = min(size.width, size.height)
        if maxSide > dockIconMaxPixels || minSide < dockIconMinPixels {
            AppLogger.log(
                .warning,
                "Dock 图标尺寸不符合要求: \(Int(size.width))x\(Int(size.height))，允许范围 \(Int(dockIconMinPixels))~\(Int(dockIconMaxPixels)) 像素",
                category: "appearance"
            )
            showAlert(
                title: "Dock 图标尺寸不符合要求",
                message: "当前尺寸为 \(Int(size.width))x\(Int(size.height))，允许范围 \(Int(dockIconMinPixels))~\(Int(dockIconMaxPixels)) 像素。"
            )
            return false
        }
        return true
    }

    private func renderDockIcon(from image: NSImage) -> NSImage? {
        let size = NSSize(width: dockIconCanvasSize, height: dockIconCanvasSize)
        let output = NSImage(size: size)
        output.lockFocus()
        NSColor.clear.set()
        NSRect(origin: .zero, size: size).fill()

        let inset = dockIconCanvasSize * 0.08
        let bounds = NSRect(x: inset, y: inset, width: dockIconCanvasSize - inset * 2, height: dockIconCanvasSize - inset * 2)
        let mask = NSBezierPath(ovalIn: bounds)
        mask.addClip()

        let sourceSize = imagePixelSize(image)
        let drawRect = aspectFillRect(imageSize: sourceSize, bounds: bounds)
        image.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0, respectFlipped: true, hints: nil)
        output.unlockFocus()
        output.isTemplate = false
        return output
    }

    private func aspectFillRect(imageSize: CGSize, bounds: NSRect) -> NSRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return bounds }
        let imageRatio = imageSize.width / imageSize.height
        let boundsRatio = bounds.width / bounds.height
        var drawRect = bounds
        if imageRatio > boundsRatio {
            let width = bounds.height * imageRatio
            drawRect.origin.x = bounds.midX - width / 2
            drawRect.size.width = width
        } else {
            let height = bounds.width / imageRatio
            drawRect.origin.y = bounds.midY - height / 2
            drawRect.size.height = height
        }
        return drawRect
    }

    private func imagePixelSize(_ image: NSImage) -> CGSize {
        let reps = image.representations
        guard !reps.isEmpty else { return .zero }
        let best = reps.max { ($0.pixelsWide * $0.pixelsHigh) < ($1.pixelsWide * $1.pixelsHigh) }
        guard let rep = best, rep.pixelsWide > 0, rep.pixelsHigh > 0 else {
            return .zero
        }
        return CGSize(width: rep.pixelsWide, height: rep.pixelsHigh)
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "确定")
        alert.runModal()
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
