import SwiftUI
import AppKit

struct FavoriteFoldersView: View {
    @State private var folders: [FavoriteFolder] = FavoriteFolderStore.load()
    @State private var selection: Set<UUID> = []

    var body: some View {
        List(selection: $selection) {
            ForEach($folders) { $folder in
                HStack(spacing: 12) {
                    Toggle("", isOn: $folder.isEnabled)
                        .labelsHidden()
                    VStack(alignment: .leading, spacing: 4) {
                        Text(folder.name)
                        Text(folder.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tag(folder.id)
            }
        }
        .navigationTitle("常用目录")
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
        .onChange(of: folders) { _, _ in
            // Persist changes when toggling enabled states or editing list.
            FavoriteFolderStore.save(folders)
            syncToExtension()
        }
    }

    private func reload() {
        folders = FavoriteFolderStore.load()
        selection = []
    }

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "添加"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        let path = url.path
        guard !folders.contains(where: { $0.path == path }) else {
            return
        }
        let name = url.lastPathComponent
        folders.append(FavoriteFolder(name: name, path: path, isEnabled: true))
        syncToExtension()
    }

    private func removeSelected() {
        folders.removeAll { selection.contains($0.id) }
        selection.removeAll()
        syncToExtension()
    }

    private func syncToExtension() {
        let enabled = folders.filter { $0.isEnabled }
        DistributedMessenger.shared.sendToExtension(
            MessagePayload(action: "update-favorites", favoriteFolders: enabled, favoriteApps: nil)
        )
    }
}
