import SwiftUI

struct MenuConfigView: View {
    @State private var config = MenuConfigStore.load()

    var body: some View {
        Form {
            Section("空白区域（Container）") {
                Toggle("新建文件", isOn: binding(\.container.newFileEnabled))
                Toggle("复制当前目录路径", isOn: binding(\.container.copyPathEnabled))
                Toggle("进入终端", isOn: binding(\.container.openTerminalEnabled))
            }

            Section("选中项（Items）") {
                Toggle("复制当前路径", isOn: binding(\.items.copyPathEnabled))
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            config = MenuConfigStore.load()
        }
    }

    private func binding<T>(_ keyPath: WritableKeyPath<MenuConfig, T>) -> Binding<T> {
        Binding(
            get: { config[keyPath: keyPath] },
            set: { newValue in
                config[keyPath: keyPath] = newValue
                MenuConfigStore.save(config)
                // Sync to extension when user changes any toggle.
                DistributedMessenger.shared.sendToExtension(
                    MessagePayload(action: "update-menu-config", menuConfig: config)
                )
            }
        )
    }
}
