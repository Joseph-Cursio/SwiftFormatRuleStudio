//
//  SourceFileReading.swift
//  SwiftFormatRuleStudio
//

/// Reads the contents of a source file off disk.
///
/// This is the file-access counterpart to `SwiftFormatCLIProtocol`: a narrow
/// seam that lets the orchestration models (`ImpactModel`, `TuneModel`) be
/// unit-tested without staging fixture files. Production code uses
/// `FileSystemSourceReader`; tests inject an in-memory conformer.
public protocol SourceFileReading: Sendable {
    /// Returns the UTF-8 contents of the file at `path`, or throws if it can't
    /// be read.
    func readSource(at path: String) throws -> String
}
