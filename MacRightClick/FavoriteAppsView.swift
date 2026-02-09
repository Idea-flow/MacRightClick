import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct FavoriteAppsView: View {
    @State private var apps: [FavoriteApp] = FavoriteAppStore.load()
    @State private var selection: Set<UUID> = []

    var body: some View {
        List(selection: $selection) {
            ForEach($apps) { $app in
                HStack(spacing: 12) {
                    Toggle("", isOn: $app.isEnabled)
                        .labelsHidden()
                    Image(nsImage: appIcon(at: app.path))
                        .resizable()
                        .frame(width: 24, height: 24)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(app.name)
                        Text(app.bundleIdentifier)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tag(app.id)
            }
        }
        .navigationTitle("常用 App")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("添加", action: addApp)
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
        .onChange(of: apps) { _, _ in
            // Persist changes when toggling enabled states or editing list.
            FavoriteAppStore.save(apps)
            syncToExtension()
        }
    }

    private func reload() {
        apps = FavoriteAppStore.load()
        selection = []
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.prompt = "添加"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        guard let bundle = Bundle(url: url),
              let bundleID = bundle.bundleIdentifier else {
            return
        }
        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        let path = url.path
        guard !apps.contains(where: { $0.bundleIdentifier == bundleID }) else {
            return
        }
        apps.append(FavoriteApp(name: name, bundleIdentifier: bundleID, path: path, isEnabled: true))
        syncToExtension()
    }

    private func removeSelected() {
        apps.removeAll { selection.contains($0.id) }
        selection.removeAll()
        syncToExtension()
    }

    private func appIcon(at path: String) -> NSImage {
        NSWorkspace.shared.icon(forFile: path)
    }

    private func syncToExtension() {
        let enabled = apps.filter { $0.isEnabled }
        DistributedMessenger.shared.sendToExtension(
            MessagePayload(action: "update-favorites", favoriteFolders: nil, favoriteApps: enabled)
        )
    }
}
