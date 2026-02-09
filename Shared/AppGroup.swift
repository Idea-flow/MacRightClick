import Foundation

enum AppGroup {
    // TODO: If you change the bundle identifier, update the app group id as well.
    static let id = "group.com.biliww.MacRightClick"
}

extension UserDefaults {
    static var appGroup: UserDefaults {
        UserDefaults(suiteName: AppGroup.id) ?? .standard
    }
}
