import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Settings UI for custom dock and menu bar icons.
struct IconSettingsSection: View {
    @Environment(AppIconManager.self) private var iconManager

    private var allowedTypes: [UTType] {
        var types: [UTType] = [.image]
        if let icns = UTType(filenameExtension: "icns") {
            types.append(icns)
        }
        return types
    }

    var body: some View {
        Section("图标") {
            VStack(alignment: .leading, spacing: 12) {
                iconRow(
                    title: "Dock 图标",
                    previewImage: iconManager.dockPreviewImage(),
                    path: iconManager.dockIconPath,
                    previewSize: 48,
                    pickAction: { presentOpenPanel(for: .dock) },
                    resetAction: iconManager.clearDockIcon
                )

                Divider()

                iconRow(
                    title: "菜单栏图标",
                    previewImage: iconManager.menuBarPreviewImage(),
                    path: iconManager.menuBarIconPath,
                    previewSize: 24,
                    pickAction: { presentOpenPanel(for: .menuBar) },
                    resetAction: iconManager.clearMenuBarIcon
                )

                Toggle(
                    "菜单栏图标使用模板渲染",
                    isOn: Binding(
                        get: { iconManager.menuBarIconIsTemplate },
                        set: { iconManager.setMenuBarTemplate($0) }
                    )
                )
                .help("模板图会自动适配浅色/深色菜单栏")
                .disabled(iconManager.menuBarIconPath == nil)

                Text("支持常见图片格式（PNG/JPG/ICNS）。Dock 图标建议 512×512 或 1024×1024，系统会裁剪为椭圆并限制在 256~4096 像素范围内。菜单栏图标建议 18×18 或 36×36，系统将限制在 12~256 像素范围内。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func iconRow(
        title: String,
        previewImage: NSImage?,
        path: String?,
        previewSize: CGFloat,
        pickAction: @escaping () -> Void,
        resetAction: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            if let previewImage {
                Image(nsImage: previewImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: previewSize, height: previewSize)
                    .clipShape(.rect(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.quaternary)
                    .frame(width: previewSize, height: previewSize)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                Text(path ?? "默认图标")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button("选择") {
                AppLogger.log(.info, "点击选择: \(title)", category: "appearance")
                pickAction()
            }

            Button("恢复默认") {
                resetAction()
            }
            .disabled(path == nil)
        }
    }

    private enum IconTarget {
        case dock
        case menuBar
    }

    private func presentOpenPanel(for target: IconTarget) {
        AppLogger.log(.info, "打开文件选择器: \(target == .dock ? "Dock" : "MenuBar")", category: "appearance")
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = allowedTypes
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.prompt = "选择"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            switch target {
            case .dock:
                iconManager.setDockIcon(from: url)
            case .menuBar:
                iconManager.setMenuBarIcon(from: url)
            }
        }
    }
}
