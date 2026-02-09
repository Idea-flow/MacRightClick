摘要

将 SwiftData 模板 UI 替换为用于文件模板（txt/md/pdf）的双列配置 UI，并通过 App Group 默认值实现持久化。
添加了一个 Finder Sync 扩展，该扩展读取配置并通过上下文右键菜单创建文件。
更新了 Xcode 项目以包含新的扩展目标，嵌入它并设置权限。
关键文件

UI 和应用连接：ContentView.swift, MacRightClickApp.swift
共享配置模型/存储：AppGroup.swift, FileTemplate.swift, TemplateStore.swift
Finder 扩展：FinderSync.swift, Info.plist
权限：MacRightClick.entitlements, MacRightClickFinderExtension.entitlements
项目变更：project.pbxproj
注意事项

App Group ID 是 group.com.biliww.MacRightClick。如果您的 bundle ID/团队不同，请在 AppGroup.swift 和两个权限文件中更新它。
Finder Sync 当前作用域限定为用户主目录。要扩展/限制作用域，请编辑 FinderSync.swift 中的 directoryURLs。
我没有运行构建。
意外变更

我发现了一个我没有修改过的文件：xcschememanagement.plist。您希望我如何处理它？
后续步骤

构建并运行应用程序，然后在系统设置 > 隐私与安全性 > 扩展 > Finder 扩展中启用扩展。
如果您希望上下文菜单出现在更多（或更少）位置，请告诉我作用域，我将调整 directoryURLs。