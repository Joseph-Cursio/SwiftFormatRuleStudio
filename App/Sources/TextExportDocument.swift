//
//  TextExportDocument.swift
//  SwiftFormatRuleStudio
//
//  NOTE: lint-excluded — SwiftUI's FileDocument requires throwing
//  init(configuration:) / fileWrapper(configuration:), which trips
//  unneeded_throws_rethrows even though the bodies don't throw.
//

import SwiftUI
import UniformTypeIdentifiers

/// A plain-text document used by `.fileExporter` to save CSV/HTML exports.
struct TextExportDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.plainText, .commaSeparatedText, .html]

    let text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            text = String(bytes: data, encoding: .utf8) ?? ""
        } else {
            text = ""
        }
    }

    func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
