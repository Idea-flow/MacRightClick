import Foundation
import Observation

@MainActor
@Observable
final class TemplateStore {
    private let defaults: UserDefaults
    private let storageKey = "FileTemplates"

    var templates: [FileTemplate] {
        didSet {
            persist()
        }
    }

    var selectionID: FileTemplate.ID?

    init(userDefaults: UserDefaults = .appGroup) {
        self.defaults = userDefaults
        self.templates = Self.loadTemplates(from: userDefaults)
        self.selectionID = templates.first?.id
    }

    func restoreDefaults() {
        templates = FileTemplate.defaults
        selectionID = templates.first?.id
    }

    func addTemplate(_ template: FileTemplate) {
        templates.append(template)
        selectionID = template.id
    }

    private func persist() {
        Self.storeTemplates(templates, to: defaults, storageKey: storageKey)
        if !AppRuntime.isExtension {
            let enabled = templates.filter { $0.isEnabled }
            DistributedMessenger.shared.sendToExtension(
                MessagePayload(action: "update-templates", templates: enabled)
            )
        }
    }

    static func loadTemplates(from defaults: UserDefaults = .appGroup, storageKey: String = "FileTemplates") -> [FileTemplate] {
        guard let data = defaults.data(forKey: storageKey) else {
            return FileTemplate.defaults
        }
        do {
            let decoded = try JSONDecoder().decode([FileTemplate].self, from: data)
            if decoded.isEmpty {
                return FileTemplate.defaults
            }
            // Merge newly added default templates into existing stored list.
            let existingKinds = Set(decoded.map { $0.kind })
            let missingDefaults = FileTemplate.defaults.filter { !existingKinds.contains($0.kind) }
            if missingDefaults.isEmpty {
                return decoded
            }
            let merged = decoded + missingDefaults
            storeTemplates(merged, to: defaults, storageKey: storageKey)
            return merged
        } catch {
            return FileTemplate.defaults
        }
    }

    static func enabledTemplates(from defaults: UserDefaults = .appGroup, storageKey: String = "FileTemplates") -> [FileTemplate] {
        loadTemplates(from: defaults, storageKey: storageKey)
            .filter { $0.isEnabled }
    }

    static func storeTemplates(_ templates: [FileTemplate], to defaults: UserDefaults = .appGroup, storageKey: String = "FileTemplates") {
        do {
            let data = try JSONEncoder().encode(templates)
            defaults.set(data, forKey: storageKey)
        } catch {
            defaults.removeObject(forKey: storageKey)
        }
    }
}
