//
//  MockSourceFileReader.swift
//  SwiftFormatRuleStudioCoreTestSupport
//

import Foundation
import SwiftFormatRuleStudioCore

/// An in-memory `SourceFileReading` for tests: serves preconfigured contents
/// keyed by path, so a model's `ruleDiff` drill-down can be exercised without
/// staging real files on disk. Unknown paths throw, matching a read failure.
public struct MockSourceFileReader: SourceFileReading {
    private let contentsByPath: [String: String]

    public init(contentsByPath: [String: String]) {
        self.contentsByPath = contentsByPath
    }

    /// Convenience for the common single-file case.
    public init(path: String, contents: String) {
        self.contentsByPath = [path: contents]
    }

    public func readSource(at path: String) throws -> String {
        guard let contents = contentsByPath[path] else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        return contents
    }
}
