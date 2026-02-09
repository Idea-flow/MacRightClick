import SwiftUI
import Observation
import FinderSync

struct ContentView: View {
    @State private var store = TemplateStore()
    @State private var selection: SidebarItem = .templates
    @AppStorage("HasShownEnableExtensionGuide", store: .appGroup) private var hasShownEnableExtensionGuide = false
    @State private var showEnableExtensionAlert = false
    @AppStorage("ShowDockIcon", store: .appGroup) private var showDockIcon = true

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } detail: {
            switch selection {
            case .templates:
                TemplateWorkspaceView(store: store)
            case .menuConfig:
                MenuConfigView()
            case .favoriteFolders:
                FavoriteFoldersView()
            case .favoriteApps:
                FavoriteAppsView()
            case .logs:
                LogView()
            case .authorizedFolders:
                AuthorizedFoldersView()
            case .settings:
                SettingsView()
            }
        }
        .frame(minWidth: 860, minHeight: 520)
        .onAppear {
            DockVisibility.apply(showDockIcon: true)
        }
        .onDisappear {
            if !showDockIcon {
                DockVisibility.apply(showDockIcon: false)
            }
        }
        .onAppear {
            if !FIFinderSyncController.isExtensionEnabled && !hasShownEnableExtensionGuide {
                showEnableExtensionAlert = true
            }
        }
        .alert("启用 Finder 扩展", isPresented: $showEnableExtensionAlert) {
            Button("打开设置") {
                FIFinderSyncController.showExtensionManagementInterface()
                hasShownEnableExtensionGuide = true
            }
            Button("稍后") {
                hasShownEnableExtensionGuide = true
            }
        } message: {
            Text("需要在系统设置里启用 Finder 扩展，右键菜单才能生效。")
        }
    }
}

private enum SidebarItem: String, Hashable, CaseIterable, Identifiable {
    case templates
    case menuConfig
    case favoriteFolders
    case favoriteApps
    case logs
    case authorizedFolders
    case settings

    var id: String { rawValue }
}

private struct SidebarView: View {
    @Binding var selection: SidebarItem

    var body: some View {
        List(selection: $selection) {
            Section("功能") {
                Label("模板", systemImage: "doc.text")
                    .tag(SidebarItem.templates)
                Label("菜单配置", systemImage: "slider.horizontal.3")
                    .tag(SidebarItem.menuConfig)
                Label("常用目录", systemImage: "folder")
                    .tag(SidebarItem.favoriteFolders)
                Label("常用 App", systemImage: "app")
                    .tag(SidebarItem.favoriteApps)
                Label("日志", systemImage: "text.justify")
                    .tag(SidebarItem.logs)
                Label("授权目录", systemImage: "folder.badge.plus")
                    .tag(SidebarItem.authorizedFolders)
                Label("设置", systemImage: "gearshape")
                    .tag(SidebarItem.settings)
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
    @State private var showingAddTemplate = false

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
            ToolbarItem(placement: .primaryAction) {
                Button("新增模板") { showingAddTemplate = true }
            }
        }
        .sheet(isPresented: $showingAddTemplate) {
            AddTemplateSheet(store: store)
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

    var body: some View {
        Form {
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
    }
}

#Preview {
    ContentView()
}

private struct AddTemplateSheet: View {
    @Bindable var store: TemplateStore
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var fileExtension = ""
    @State private var baseName = ""
    @State private var bodyText = ""

    private var canSave: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !fileExtension.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("新增模板")
                .font(.title3.bold())

            Form {
                TextField("显示名称", text: $displayName)
                TextField("扩展名（不含点）", text: $fileExtension)
                TextField("默认文件名", text: $baseName)
                TextEditor(text: $bodyText)
                    .frame(minHeight: 160)
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("保存") { saveTemplate() }
                    .disabled(!canSave)
            }
        }
        .padding()
        .frame(minWidth: 420, minHeight: 360)
        .onAppear {
            if baseName.isEmpty {
                baseName = "新建文件"
            }
        }
    }

    private func saveTemplate() {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let ext = fileExtension
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let base = baseName.trimmingCharacters(in: .whitespacesAndNewlines)

        let template = FileTemplate(
            kind: .custom,
            displayName: name,
            fileExtension: ext,
            isEnabled: true,
            defaultBaseName: base.isEmpty ? "新建文件" : base,
            defaultBody: bodyText
        )
        store.addTemplate(template)
        dismiss()
    }
}
