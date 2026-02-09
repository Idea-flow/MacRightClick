import SwiftUI
import FinderSync

struct SettingsView: View {
    @AppStorage("ShowDockIcon", store: .appGroup) private var showDockIcon = true
    @AppStorage("ShowMenuBar", store: .appGroup) private var showMenuBar = true
    @AppStorage("CopyPathsMenuEnabled", store: .appGroup) private var copyPathsMenuEnabled = true
    @State private var extensionEnabled = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Form {
            Section("Finder 扩展") {
                HStack {
                    Text("启用扩展")
                    Spacer()
                    Button(action: openExtensionSettings) {
                        Label("打开设置", systemImage: extensionEnabled ? "checkmark.circle.fill" : "checkmark.circle")
                    }
                }
                Text("必须在系统设置里启用 Finder 扩展，右键菜单才能生效。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("外观") {
                Toggle("Dock 显示图标", isOn: $showDockIcon)
                    .onChange(of: showDockIcon) { _, newValue in
                        if !newValue && !showMenuBar {
                            showMenuBar = true
                        }
                        DockVisibility.apply(showDockIcon: showDockIcon)
                    }
                Toggle("菜单栏显示图标", isOn: $showMenuBar)
                    .onChange(of: showMenuBar) { _, _ in
                        if !showMenuBar && !showDockIcon {
                            showDockIcon = true
                            DockVisibility.apply(showDockIcon: showDockIcon)
                        }
                    }
            }

            Section("Finder 菜单") {
                Toggle("启用路径复制菜单", isOn: $copyPathsMenuEnabled)
                    .onChange(of: copyPathsMenuEnabled) { _, newValue in
                        DistributedMessenger.shared.sendToExtension(
                            MessagePayload(action: "update-menu-settings", copyPathsEnabled: newValue)
                        )
                    }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(minWidth: 420, minHeight: 240)
        .onAppear {
            updateExtensionState()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            updateExtensionState()
        }
    }

    private func updateExtensionState() {
        extensionEnabled = FIFinderSyncController.isExtensionEnabled
    }

    private func openExtensionSettings() {
        FIFinderSyncController.showExtensionManagementInterface()
    }

    private func updateDockVisibility(_ show: Bool) {
        DockVisibility.apply(showDockIcon: show)
        if !show {
            for window in NSApp.windows {
                window.close()
            }
        }
    }
}
