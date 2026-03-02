import SwiftUI
import Observation
import FinderSync
import AppKit
import UniformTypeIdentifiers

enum AppNotifications {
    static let openAuthorizedFolders = Notification.Name("OpenAuthorizedFolders")
}

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
            case .myWallpapers:
                WallpaperGalleryWorkspaceView()
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
        .onReceive(NotificationCenter.default.publisher(for: AppNotifications.openAuthorizedFolders)) { _ in
            selection = .authorizedFolders
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
    case myWallpapers
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
                Label("我的壁纸", systemImage: "photo.stack")
                    .tag(SidebarItem.myWallpapers)
                Label("授权目录", systemImage: "folder.badge.plus")
                     .tag(SidebarItem.authorizedFolders)
                Label("文件模板", systemImage: "doc.text")
                    .tag(SidebarItem.templates)
                Label("菜单配置", systemImage: "slider.horizontal.3")
                    .tag(SidebarItem.menuConfig)
                Label("常用目录", systemImage: "folder")
                    .tag(SidebarItem.favoriteFolders)
                Label("常用 App", systemImage: "app")
                    .tag(SidebarItem.favoriteApps)
                Label("日志", systemImage: "text.justify")
                    .tag(SidebarItem.logs)
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
            Image(nsImage: iconForTemplate(template))
                .resizable()
                .frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 4) {
                Text(template.displayName)
                Text(".\(template.fileExtension)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .tag(template.id)
    }

    private func iconForTemplate(_ template: FileTemplate) -> NSImage {
        let ext = template.fileExtension.lowercased()
        if let utType = UTType(filenameExtension: ext) {
            return NSWorkspace.shared.icon(forFileType: utType.identifier)
        }
        return NSWorkspace.shared.icon(forFileType: ext)
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

private struct WallpaperGalleryWorkspaceView: View {
    @State private var wallpapers: [WallpaperItem] = WallpaperItem.samples
    @State private var selectedID: WallpaperItem.ID = WallpaperItem.samples[0].id
    @State private var showMetadata = true
    @State private var appliedToast = false

    private var selectedIndex: Int {
        wallpapers.firstIndex(where: { $0.id == selectedID }) ?? 0
    }

    private var selected: WallpaperItem {
        wallpapers[selectedIndex]
    }

    var body: some View {
        VStack(spacing: 12) {
            immersiveHero
            filmStrip
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [.black.opacity(0.18), .indigo.opacity(0.08), .black.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .animation(.easeInOut(duration: 0.22), value: selectedID)
    }

    private var immersiveHero: some View {
        ZStack(alignment: .bottomLeading) {
            wallpaperCanvas(for: selected)
                .frame(maxWidth: .infinity, minHeight: 360)
                .clipShape(.rect(cornerRadius: 18))
                .overlay(alignment: .topTrailing) {
                    if appliedToast {
                        Text("已应用到桌面")
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.thinMaterial, in: Capsule())
                            .padding(12)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }

            LinearGradient(
                colors: [.clear, .black.opacity(0.42)],
                startPoint: .center,
                endPoint: .bottom
            )
            .clipShape(.rect(cornerRadius: 18))

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(selected.title)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    if showMetadata {
                        Text("\(selected.sizeLabel) · \(selected.tags.joined(separator: " · "))")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.88))
                    }
                }
                Spacer()
                HStack(spacing: 8) {
                    galleryActionButton("shuffle", label: "随机", action: selectRandom)
                    galleryActionButton(selected.isFavorite ? "heart.fill" : "heart", label: "收藏") {
                        toggleFavorite()
                    }
                    galleryActionButton("display.2", label: "设为桌面", action: applyCurrentWallpaper)
                }
            }
            .padding(16)
        }
    }

    private var filmStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("胶片轨道")
                    .font(.headline)
                Spacer()
                Toggle("显示信息", isOn: $showMetadata)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(wallpapers) { item in
                            Button {
                                selectedID = item.id
                            } label: {
                                wallpaperCanvas(for: item)
                                    .frame(width: 164, height: 92)
                                    .clipShape(.rect(cornerRadius: 10))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(item.id == selectedID ? .white : .white.opacity(0.2), lineWidth: item.id == selectedID ? 2 : 1)
                                    }
                                    .overlay(alignment: .topLeading) {
                                        if item.isFavorite {
                                            Image(systemName: "heart.fill")
                                                .font(.caption2)
                                                .foregroundStyle(.white)
                                                .padding(6)
                                                .background(.black.opacity(0.35), in: Circle())
                                                .padding(6)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .id(item.id)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .onChange(of: selectedID) { _, newValue in
                    withAnimation(.easeInOut(duration: 0.22)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func wallpaperCanvas(for item: WallpaperItem) -> some View {
        ZStack {
            LinearGradient(colors: item.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle()
                .fill(.white.opacity(0.14))
                .frame(width: 190, height: 190)
                .offset(x: 90, y: -60)
            RoundedRectangle(cornerRadius: 80)
                .fill(.white.opacity(0.08))
                .frame(width: 280, height: 100)
                .rotationEffect(.degrees(-12))
                .offset(x: -100, y: 80)
            Image(systemName: item.symbol)
                .font(.system(size: 76, weight: .thin))
                .foregroundStyle(.white.opacity(0.72))
        }
    }

    private func galleryActionButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .tint(.black.opacity(0.35))
    }

    private func selectRandom() {
        guard wallpapers.count > 1 else { return }
        let current = selectedID
        var next = current
        while next == current {
            next = wallpapers.randomElement()?.id ?? current
        }
        selectedID = next
    }

    private func toggleFavorite() {
        guard let index = wallpapers.firstIndex(where: { $0.id == selectedID }) else { return }
        wallpapers[index].isFavorite.toggle()
    }

    private func applyCurrentWallpaper() {
        withAnimation(.easeInOut(duration: 0.2)) {
            appliedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.2)) {
                appliedToast = false
            }
        }
    }
}

private struct WallpaperItem: Identifiable, Hashable {
    let id: UUID
    var title: String
    var tags: [String]
    var sizeLabel: String
    var symbol: String
    var colors: [Color]
    var isFavorite: Bool

    init(
        id: UUID = UUID(),
        title: String,
        tags: [String],
        sizeLabel: String,
        symbol: String,
        colors: [Color],
        isFavorite: Bool = false
    ) {
        self.id = id
        self.title = title
        self.tags = tags
        self.sizeLabel = sizeLabel
        self.symbol = symbol
        self.colors = colors
        self.isFavorite = isFavorite
    }

    static let samples: [WallpaperItem] = [
        WallpaperItem(title: "极光海岸", tags: ["风景", "冷色"], sizeLabel: "6K", symbol: "mountain.2", colors: [.blue, .cyan, .mint]),
        WallpaperItem(title: "霓虹都市", tags: ["赛博", "夜景"], sizeLabel: "5K", symbol: "building.2.crop.circle", colors: [.pink, .purple, .indigo]),
        WallpaperItem(title: "赤道日落", tags: ["日落", "暖色"], sizeLabel: "4K", symbol: "sun.max", colors: [.orange, .red, .pink]),
        WallpaperItem(title: "森林薄雾", tags: ["自然", "静谧"], sizeLabel: "4K", symbol: "leaf", colors: [.green, .mint, .teal]),
        WallpaperItem(title: "深空轨道", tags: ["太空", "暗色"], sizeLabel: "8K", symbol: "sparkles", colors: [.black, .indigo, .blue])
    ]
}
