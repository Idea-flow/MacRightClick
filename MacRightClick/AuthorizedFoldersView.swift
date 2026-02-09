import SwiftUI
import AppKit
import FinderSync

struct AuthorizedFoldersView: View {
    @State private var folders: [AuthorizedFolder] = AuthorizedFolderStore.loadFolders()
    @State private var selection: Set<UUID> = []
    @State private var errorMessage: String?
    @State private var extensionEnabled = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 0) {
            extensionSection
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }

            List(folders, selection: $selection) { folder in
                VStack(alignment: .leading, spacing: 4) {
                    Text(folder.path)
                        .font(.body)
                    Text((folder.path as NSString).lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tag(folder.id)
            }
            .listStyle(.inset)
        }
        .navigationTitle("授权目录")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("添加", action: addFolder)
            }
            ToolbarItem(placement: .primaryAction) {
                Button("移除", action: removeSelected)
                    .disabled(selection.isEmpty)
            }
            ToolbarItem(placement: .primaryAction) {
                Button("刷新", action: reload)
            }
        }
        .onAppear {
            reload()
            updateExtensionState()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            updateExtensionState()
        }
    }

    private var extensionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Finder 扩展")
                    .font(.headline)
                Spacer()
                Button(action: openExtensionSettings) {
                    Label("打开设置", systemImage: extensionEnabled ? "checkmark.circle.fill" : "checkmark.circle")
                }
            }
            Text("必须在系统设置里启用 Finder 扩展，右键菜单才能生效。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding([.horizontal, .top])
    }

    private func reload() {
        folders = AuthorizedFolderStore.loadFolders()
        selection = []
    }

    private func updateExtensionState() {
        extensionEnabled = FIFinderSyncController.isExtensionEnabled
    }

    private func openExtensionSettings() {
        FIFinderSyncController.showExtensionManagementInterface()
    }

    private func addFolder() {
        errorMessage = nil
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "授权"
        panel.message = "请选择要授权的目录"

        if panel.runModal() == .OK, let url = panel.url {
            do {
                _ = try AuthorizedFolderStore.addFolder(url: url)
                AppLogger.log(.info, "新增授权目录: \(url.path)", category: "authorization")
                sendScopeUpdate()
                reload()
            } catch {
                errorMessage = "无法授权该目录：\(error.localizedDescription)"
                AppLogger.log(.error, "授权目录失败: \(error.localizedDescription)", category: "authorization")
            }
        }
    }

    private func removeSelected() {
        errorMessage = nil
        for id in selection {
            AuthorizedFolderStore.removeFolder(id: id)
        }
        AppLogger.log(.info, "移除授权目录: \(selection.count) 个", category: "authorization")
        sendScopeUpdate()
        reload()
    }

    private func sendScopeUpdate() {
        let paths = AuthorizedFolderStore.authorizedPaths()
        DistributedMessenger.shared.sendToExtension(MessagePayload(action: "update-scope", targets: paths))
    }
}
