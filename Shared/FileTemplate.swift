import Foundation

enum TemplateKind: String, Codable, CaseIterable, Identifiable {
    case text
    case markdown
    case pdf
    case json
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .text:
            return "纯文本"
        case .markdown:
            return "Markdown"
        case .pdf:
            return "PDF"
        case .json:
            return "JSON"
        case .custom:
            return "自定义"
        }
    }

    var fileExtension: String {
        switch self {
        case .text:
            return "txt"
        case .markdown:
            return "md"
        case .pdf:
            return "pdf"
        case .json:
            return "json"
        case .custom:
            return "txt"
        }
    }

    var supportsBody: Bool {
        switch self {
        case .text, .markdown, .json, .custom:
            return true
        case .pdf:
            return false
        }
    }

    var defaultBaseName: String {
        switch self {
        case .text:
            return "新建文本"
        case .markdown:
            return "新建文档"
        case .pdf:
            return "新建PDF"
        case .json:
            return "新建JSON"
        case .custom:
            return "新建文件"
        }
    }

    var defaultBody: String {
        switch self {
        case .text:
            return ""
        case .markdown:
            return "# 标题\n\n从这里开始写内容。"
        case .pdf:
            return ""
        case .json:
            return "{\n  \n}"
        case .custom:
            return ""
        }
    }
}

struct FileTemplate: Identifiable, Hashable, Codable {
    let id: UUID
    var kind: TemplateKind
    var displayName: String
    var fileExtension: String
    var isEnabled: Bool
    var defaultBaseName: String
    var defaultBody: String

    init(
        id: UUID = UUID(),
        kind: TemplateKind,
        displayName: String,
        fileExtension: String,
        isEnabled: Bool,
        defaultBaseName: String,
        defaultBody: String
    ) {
        self.id = id
        self.kind = kind
        self.displayName = displayName
        self.fileExtension = fileExtension
        self.isEnabled = isEnabled
        self.defaultBaseName = defaultBaseName
        self.defaultBody = defaultBody
    }

    static var defaults: [FileTemplate] {
        let kinds: [TemplateKind] = [.text, .markdown, .pdf, .json]
        return kinds.map { kind in
            FileTemplate(
                kind: kind,
                displayName: kind.displayName,
                fileExtension: kind.fileExtension,
                isEnabled: true,
                defaultBaseName: kind.defaultBaseName,
                defaultBody: kind.defaultBody
            )
        }
    }
}
