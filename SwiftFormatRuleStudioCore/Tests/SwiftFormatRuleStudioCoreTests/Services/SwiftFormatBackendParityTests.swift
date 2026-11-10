//
//  SwiftFormatBackendParityTests.swift
//  SwiftFormatRuleStudioCoreTests
//

import Foundation
@testable import SwiftFormatRuleStudioCore
import Testing

/// The claim the migration rests on: driving the linked library's own CLI produces
/// the same bytes the subprocess did, so the parsers written against `swiftformat`
/// output keep working. Skips when SwiftFormat is not installed, or when the
/// installed binary is a different version than the linked one (where a byte
/// difference would be SwiftFormat's own change, not a backend defect).
@Suite("SwiftFormat backend parity")
struct SwiftFormatBackendParityTests {
    private let inProcess = SwiftFormatInProcessActor()
    private let subprocess = SwiftFormatCLIActor()

    /// Both backends' versions, or `nil` when the comparison isn't meaningful here.
    private func matchedVersions() async -> String? {
        guard (try? await subprocess.detectPath()) != nil,
              let installed = try? await subprocess.version(),
              let linked = try? await inProcess.version(),
              installed == linked else {
            return nil
        }
        return linked
    }

    @Test("--rules, --options and --ruleinfo are byte-identical")
    func catalogSurfacesMatch() async throws {
        guard await matchedVersions() != nil else { return }

        #expect(try await inProcess.rulesOutput() == subprocess.rulesOutput())
        #expect(try await inProcess.optionsOutput() == subprocess.optionsOutput())
        #expect(try await inProcess.allRuleInfoOutput() == subprocess.allRuleInfoOutput())
        #expect(
            try await inProcess.ruleInfoOutput(ruleName: "redundantSelf")
                == subprocess.ruleInfoOutput(ruleName: "redundantSelf")
        )
    }

    @Test("stdin formatting and stdin lint JSON are byte-identical")
    func stdinSurfacesMatch() async throws {
        guard await matchedVersions() != nil else { return }

        let source = "class Foo {\n  func bar() {\n    self.baz()\n  }\n}\n"
        let formatArguments = ["stdin", "--swift-version", "5.10"]
        #expect(
            try await inProcess.format(source: source, arguments: formatArguments)
                == subprocess.format(source: source, arguments: formatArguments)
        )

        let lintArguments = formatArguments + ["--lint", "--reporter", "json"]
        #expect(
            try await inProcess.format(source: source, arguments: lintArguments)
                == subprocess.format(source: source, arguments: lintArguments)
        )
    }

    /// Compared as a set of findings rather than as bytes: file enumeration order is
    /// SwiftFormat's business (and cache-sensitive), while the findings are the
    /// contract `ImpactModel` and `TuneModel` actually consume.
    @Test("Directory lint reports the same findings")
    func directoryLintMatches() async throws {
        guard await matchedVersions() != nil else { return }

        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("BackendParity-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try "class Foo {\n  func bar() {\n    self.baz()\n  }\n}\n".write(
            to: directory.appendingPathComponent("Fixture.swift"),
            atomically: true,
            encoding: .utf8
        )

        let arguments = ["--lint", "--reporter", "json", "--swift-version", "5.10"]
        let mine = LintReportParser.parse(
            try await inProcess.lint(path: directory.path, arguments: arguments).reporterOutput
        )
        let theirs = LintReportParser.parse(
            try await subprocess.lint(path: directory.path, arguments: arguments).reporterOutput
        )

        #expect(mine.isEmpty == false)
        let key = { (finding: LintFinding) in "\(finding.filePath):\(finding.line):\(finding.ruleID)" }
        #expect(Set(mine.map(key)) == Set(theirs.map(key)))
    }
}
