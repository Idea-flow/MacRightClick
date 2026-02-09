import SwiftUI
import Observation

struct ContentView: View {
    @State private var store = TemplateStore()

    var body: some View {
        NavigationSplitView {
            TemplateListView(store: store)
        } detail: {
            TemplateDetailView(store: store)
        }
        .frame(minWidth: 760, minHeight: 480)
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
        .navigationTitle("右键助手")
        .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
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
                .foregroundStyle(template.isEnabled ? .accent : .secondary)
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
