import Foundation
import CoreGraphics

enum FileCreator {
    static func createFile(template: FileTemplate, in directoryURL: URL) throws -> URL {
        let sanitizedBaseName = sanitizeBaseName(template.defaultBaseName)
        let baseName = sanitizedBaseName.isEmpty ? "未命名" : sanitizedBaseName
        let fileURL = uniqueFileURL(in: directoryURL, baseName: baseName, fileExtension: template.fileExtension)
        try writeFile(for: template, to: fileURL)
        return fileURL
    }

    private static func sanitizeBaseName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let invalidCharacters = CharacterSet(charactersIn: "/:")
        let sanitized = trimmed.components(separatedBy: invalidCharacters).joined(separator: "-")
        return sanitized.replacingOccurrences(of: "  ", with: " ")
    }

    private static func uniqueFileURL(in directoryURL: URL, baseName: String, fileExtension: String) -> URL {
        var candidate = directoryURL.appendingPathComponent("\(baseName).\(fileExtension)")
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directoryURL.appendingPathComponent("\(baseName) \(counter).\(fileExtension)")
            counter += 1
        }
        return candidate
    }

    private static func writeFile(for template: FileTemplate, to url: URL) throws {
        switch template.kind {
        case .text, .markdown, .json, .custom:
            let data = template.defaultBody.data(using: .utf8) ?? Data()
            try data.write(to: url, options: .atomic)
        case .pdf:
            let data = PDFBuilder.makeBlankPDF(title: template.defaultBaseName)
            try data.write(to: url, options: .atomic)
        }
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
