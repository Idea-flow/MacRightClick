import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Settings UI for custom dock and menu bar icons.
struct IconSettingsSection: View {
    @Environment(AppIconManager.self) private var iconManager
    @State private var showDockPicker = false
    @State private var showMenuBarPicker = false

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
                    pickAction: { showDockPicker = true },
                    resetAction: iconManager.clearDockIcon
                )

                Divider()

                iconRow(
                    title: "菜单栏图标",
                    previewImage: iconManager.menuBarPreviewImage(),
                    path: iconManager.menuBarIconPath,
                    previewSize: 24,
                    pickAction: { showMenuBarPicker = true },
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

                Text("支持常见图片格式（PNG/JPG/ICNS）。Dock 图标建议 512×512 或 1024×1024。菜单栏图标建议 18×18 或 36×36。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .fileImporter(
            isPresented: $showDockPicker,
            allowedContentTypes: allowedTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                iconManager.setDockIcon(from: url)
            case .failure(let error):
                AppLogger.log(.warning, "选择 Dock 图标失败: \(error.localizedDescription)", category: "appearance")
                break
            }
        }
        .fileImporter(
            isPresented: $showMenuBarPicker,
            allowedContentTypes: allowedTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                iconManager.setMenuBarIcon(from: url)
            case .failure(let error):
                AppLogger.log(.warning, "选择菜单栏图标失败: \(error.localizedDescription)", category: "appearance")
                break
            }
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
}
