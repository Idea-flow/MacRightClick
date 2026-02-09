import SwiftUI
import AppKit

struct AuthorizedFoldersView: View {
    @State private var folders: [AuthorizedFolder] = AuthorizedFolderStore.loadFolders()
    @State private var selection: Set<UUID> = []
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
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
        .onAppear(perform: reload)
    }

    private func reload() {
        folders = AuthorizedFolderStore.loadFolders()
        selection = []
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
