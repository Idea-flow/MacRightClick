import SwiftUI
import Observation
import FinderSync

struct ContentView: View {
    @State private var store = TemplateStore()
    @State private var selection: SidebarItem = .templates

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } detail: {
            switch selection {
            case .templates:
                TemplateWorkspaceView(store: store)
            case .logs:
                LogView()
            case .authorizedFolders:
                AuthorizedFoldersView()
            }
        }
        .frame(minWidth: 860, minHeight: 520)
    }
}

private enum SidebarItem: String, Hashable, CaseIterable, Identifiable {
    case templates
    case logs
    case authorizedFolders

    var id: String { rawValue }
}

private struct SidebarView: View {
    @Binding var selection: SidebarItem

    var body: some View {
        List(selection: $selection) {
            Section("功能") {
                Label("模板", systemImage: "doc.text")
                    .tag(SidebarItem.templates)
                Label("日志", systemImage: "text.justify")
                    .tag(SidebarItem.logs)
                Label("授权目录", systemImage: "folder.badge.plus")
                    .tag(SidebarItem.authorizedFolders)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("右键助手")
    }
}

private struct TemplateWorkspaceView: View {
    @Bindable var store: TemplateStore

    var body: some View {
        HStack(spacing: 0) {
            TemplateListView(store: store)
                .frame(minWidth: 220, idealWidth: 240, maxWidth: 280)
            Divider()
            TemplateDetailView(store: store)
                .frame(minWidth: 320, maxWidth: .infinity)
        }
    }
}

private struct TemplateListView: View {
    @Bindable var store: TemplateStore

    var body: some View {
        List(selection: $store.selectionID) {
            Section("文件类型") {
                ForEach(store.templates) { template in
                    TemplateListRow(template: template)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("恢复默认", action: store.restoreDefaults)
            }
        }
    }
}

private struct TemplateListRow: View {
    let template: FileTemplate

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: template.isEnabled ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(template.isEnabled ? Color.accentColor : .secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(template.displayName)
                Text(".\(template.fileExtension)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .tag(template.id)
    }
}

private struct TemplateDetailView: View {
    @Bindable var store: TemplateStore

    var body: some View {
        if let selectionID = store.selectionID,
           let index = store.templates.firstIndex(where: { $0.id == selectionID }) {
            TemplateEditorView(template: $store.templates[index])
                .navigationTitle(store.templates[index].displayName)
        } else {
            ContentUnavailableView("选择一个文件类型", systemImage: "doc")
        }
    }
}

private struct TemplateEditorView: View {
    @Binding var template: FileTemplate
    @Environment(\.scenePhase) private var scenePhase
    @State private var extensionEnabled = false

    private var enableIcon: String {
        extensionEnabled ? "checkmark.circle.fill" : "checkmark.circle"
    }

    var body: some View {
        Form {
            Section("Finder 扩展") {
                HStack {
                    Text("启用扩展")
                    Spacer()
                    Button(action: openExtensionSettings) {
                        Label("打开设置", systemImage: enableIcon)
                    }
                }
                Text("必须在系统设置里启用 Finder 扩展，右键菜单才能生效。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("基本设置") {
                Toggle("启用", isOn: $template.isEnabled)
                TextField("显示名称", text: $template.displayName)
                TextField("默认文件名", text: $template.defaultBaseName)
                LabeledContent("扩展名") {
                    Text(".\(template.fileExtension)")
                        .foregroundStyle(.secondary)
                }
            }

            if template.kind.supportsBody {
                Section("默认内容") {
                    TextEditor(text: $template.defaultBody)
                        .frame(minHeight: 160)
                }
            } else {
                Section("默认内容") {
                    Text("PDF 会生成空白页面。")
                        .foregroundStyle(.secondary)
                }
            }

            Section("预览") {
                Text("\(template.defaultBaseName.isEmpty ? "未命名" : template.defaultBaseName).\(template.fileExtension)")
                    .font(.system(.body, design: .monospaced))
            }

            Section("使用提示") {
                Text("在 Finder 中右键空白区域，选择“新建文件”即可看到这些模板。若菜单未出现，请在系统设置 > 隐私与安全性 > 扩展 > Finder 扩展中启用。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: updateEnableState)
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            updateEnableState()
        }
    }

    private func updateEnableState() {
        extensionEnabled = FIFinderSyncController.isExtensionEnabled
    }

    private func openExtensionSettings() {
        FIFinderSyncController.showExtensionManagementInterface()
    }
}

#Preview {
    ContentView()
}
