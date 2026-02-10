# 图标更换功能开发文档

## 目标
- 在 Settings 窗口提供 Dock 图标与菜单栏图标的自定义能力。
- 使用安全范围书签（security-scoped bookmark）持久化用户选择的文件。
- App 启动时自动恢复图标设置。

## 功能范围
- Dock 图标：运行时替换，随 App 启动恢复。
- 菜单栏图标：运行时替换，可选择是否模板渲染。
- 支持常见图片格式：PNG/JPG/ICNS。

## 关键限制
- App 开启沙盒时，必须使用 security-scoped bookmark 才能持久访问用户选择的图标文件。
- 菜单栏图标若非模板图，在深浅色菜单栏上可能可读性不一致。

## 模块说明

### 1) 持久化与解析
文件：`Shared/IconCustomizationStore.swift`
- 保存/读取 Dock 与菜单栏图标的书签数据和路径。
- 处理书签过期（stale）并自动刷新。
- 通过 `AuthorizedFolderStore.withSecurityScopedAccess` 读取图像数据。

### 2) 运行时管理
文件：`MacRightClick/IconCustomization/AppIconManager.swift`
- 负责加载已保存的图标、应用到 Dock、提供菜单栏 Label。
- 管理模板渲染开关。
- 提供 Settings 页面所需的预览与控制方法。

### 3) 设置界面
文件：`MacRightClick/IconCustomization/IconSettingsSection.swift`
- Settings 中的图标设置区。
- 文件选择器 `fileImporter` 选择图片。
- 提供预览、路径显示、恢复默认。

## 数据键
- `DockIconBookmark`
- `DockIconPath`
- `MenuBarIconBookmark`
- `MenuBarIconPath`
- `MenuBarIconIsTemplate`

## 启动流程
- `MacRightClickApp` 启动后异步调用 `AppIconManager.shared.applyStoredIcons()`。
- 恢复 Dock 图标。
- 恢复菜单栏图标数据（用于 MenuBarExtra label）。

## 图标建议
- Dock 图标：512x512 或 1024x1024，正方形，透明 PNG/ICNS。
- 菜单栏图标：18x18 或 36x36，模板图更适配浅/深色。

## 扩展点
- 加入尺寸/透明度校验，并在 UI 中提示。
- 为菜单栏提供一键切换“模板/彩色”的推荐配置。
