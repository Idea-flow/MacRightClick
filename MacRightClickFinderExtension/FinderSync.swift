import Cocoa
import FinderSync
import CoreGraphics

final class FinderSync: FIFinderSync {
    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [FileManager.default.homeDirectoryForCurrentUser]
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForContainer || menuKind == .contextualMenuForItems else {
            return nil
        }

        let templates = TemplateStore.enabledTemplates()
        guard !templates.isEmpty else {
            return nil
        }

        let menu = NSMenu(title: "新建文件")
        let parentItem = NSMenuItem(title: "新建文件", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "新建文件")

        for template in templates {
            let item = NSMenuItem(title: template.displayName, action: #selector(createFile(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = template
            submenu.addItem(item)
        }

        parentItem.submenu = submenu
        menu.addItem(parentItem)
        return menu
    }

    @objc private func createFile(_ sender: NSMenuItem) {
        guard let template = sender.representedObject as? FileTemplate else {
            return
        }

        let controller = FIFinderSyncController.default()
        let targetURL = controller.targetedURL() ?? controller.selectedItemURLs()?.first
        guard let targetURL else {
            return
        }

        let directoryURL = targetURL.hasDirectoryPath ? targetURL : targetURL.deletingLastPathComponent()
        let sanitizedBaseName = sanitizeBaseName(template.defaultBaseName)
        let baseName = sanitizedBaseName.isEmpty ? "未命名" : sanitizedBaseName
        let fileURL = uniqueFileURL(in: directoryURL, baseName: baseName, fileExtension: template.fileExtension)

        do {
            try writeFile(for: template, to: fileURL)
        } catch {
            NSSound.beep()
        }
    }
}

private func sanitizeBaseName(_ name: String) -> String {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let invalidCharacters = CharacterSet(charactersIn: "/:")
    let sanitized = trimmed.components(separatedBy: invalidCharacters).joined(separator: "-")
    return sanitized.replacingOccurrences(of: "  ", with: " ")
}

private func uniqueFileURL(in directoryURL: URL, baseName: String, fileExtension: String) -> URL {
    var candidate = directoryURL.appendingPathComponent("\(baseName).\(fileExtension)")
    var counter = 2
    while FileManager.default.fileExists(atPath: candidate.path) {
        candidate = directoryURL.appendingPathComponent("\(baseName) \(counter).\(fileExtension)")
        counter += 1
    }
    return candidate
}

private func writeFile(for template: FileTemplate, to url: URL) throws {
    switch template.kind {
    case .text, .markdown:
        let data = template.defaultBody.data(using: .utf8) ?? Data()
        try data.write(to: url, options: .atomic)
    case .pdf:
        let data = PDFBuilder.makeBlankPDF(title: template.defaultBaseName)
        try data.write(to: url, options: .atomic)
    }
}

private enum PDFBuilder {
    static func makeBlankPDF(title: String) -> Data {
        let data = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return Data()
        }

        let metadata = [kCGPDFContextTitle as String: title]
        context.beginPDFPage(metadata as CFDictionary)
        context.endPDFPage()
        context.closePDF()
        return data as Data
    }
}
