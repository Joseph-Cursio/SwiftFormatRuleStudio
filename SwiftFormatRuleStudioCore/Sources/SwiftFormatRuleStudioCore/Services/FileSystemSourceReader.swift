//
//  FileSystemSourceReader.swift
//  SwiftFormatRuleStudio
//

import Foundation

/// The production `SourceFileReading` backed by Foundation.
public struct FileSystemSourceReader: SourceFileReading {
    /// Creates a reader. It holds no state; each read goes straight to disk.
    public init() {
        // Nothing to set up.
    }

    public func readSource(at path: String) throws -> String {
        try String(contentsOfFile: path, encoding: .utf8)
    }
}
