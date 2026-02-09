import SwiftUI

@main
struct MacRightClickApp: App {
    init() {
        AppLogger.log(.info, "App 启动", category: "app")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
