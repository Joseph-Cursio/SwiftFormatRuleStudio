//
//  ImpactAuditModelTests.swift
//  SwiftFormatRuleStudioCoreTests
//

import Foundation
@testable import SwiftFormatRuleStudioCore
import SwiftFormatRuleStudioCoreTestSupport
import Testing

@Suite("ImpactAuditModel")
@MainActor
struct ImpactAuditModelTests {
    private static let json = """
    [
      { "file": "/ws/A.swift", "line": 1, "reason": "", "rule_id": "indent" },
      { "file": "/ws/B.swift", "line": 1, "reason": "", "rule_id": "indent" },
      { "file": "/ws/A.swift", "line": 2, "reason": "", "rule_id": "consecutiveSpaces" }
    ]
    """

    @Test("Starts idle")
    func initialState() {
        let model = ImpactAuditModel(cli: MockSwiftFormatCLI())
        #expect(model.state == .idle)
        #expect(model.report == nil)
    }

    @Test("runAudit lints, parses, and aggregates")
    func runsAudit() async {
        let cli = MockSwiftFormatCLI(
            lintOutput: Self.json,
            lintSummary: "2/7 files require formatting, 1 file skipped."
        )
        let model = ImpactAuditModel(cli: cli)
        await model.runAudit(path: URL(fileURLWithPath: "/ws"))

        #expect(model.state == .completed)
        #expect(model.report?.filesAffected == 2)
        #expect(model.report?.filesChecked == 7) // from the run summary denominator
        #expect(model.report?.totalFindings == 3)
        #expect(model.report?.ruleImpacts.first?.ruleID == "indent")
        #expect(model.auditedPath?.path == "/ws")
    }

    @Test("filesChecked falls back to affected files when no summary is present")
    func filesCheckedFallback() async {
        let model = ImpactAuditModel(cli: MockSwiftFormatCLI(lintOutput: Self.json))
        await model.runAudit(path: URL(fileURLWithPath: "/ws"))
        #expect(model.report?.filesChecked == 2) // == filesAffected
    }

    @Test("Audit failure surfaces .failed and clears the report")
    func auditFails() async {
        let model = ImpactAuditModel(cli: MockSwiftFormatCLI(failWith: .notFound))
        await model.runAudit(path: URL(fileURLWithPath: "/ws"))

        guard case .failed = model.state else {
            Issue.record("expected .failed, got \(model.state)")
            return
        }
        #expect(model.report == nil)
    }

    @Test("ruleDiff isolates the rule: keeps options, drops enable/disable, appends --rules")
    func ruleDiffIsolatesRule() async throws {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("SFRSDiff-\(UUID().uuidString).swift")
        try "let x=1\n".write(to: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: file) }

        let cli = MockSwiftFormatCLI(formatOverride: "let x = 1\n")
        let model = ImpactAuditModel(cli: cli, swiftVersion: "5.10")
        model.extraArguments = ["--indent", "4", "--disable", "redundantSelf", "--enable", "isEmpty"]

        let diff = await model.ruleDiff(ruleID: "spaceAroundOperators", filePath: file.path)
        #expect(diff.contains { $0.change != .unchanged }) // before/after differ

        let args = await cli.lastFormatArguments
        #expect(args == [
            "stdin", "--stdin-path", file.path,
            "--swift-version", "5.10",
            "--indent", "4", // option kept
            "--rules", "spaceAroundOperators"
        ])
        // The config's rule-selection flags are stripped so only the one rule runs.
        #expect(!args.contains("redundantSelf"))
        #expect(!args.contains("isEmpty"))
    }

    @Test("ruleDiff caches: a second call doesn't re-run SwiftFormat")
    func ruleDiffCaches() async throws {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("SFRSDiff-\(UUID().uuidString).swift")
        try "let x=1\n".write(to: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: file) }

        let cli = MockSwiftFormatCLI(formatOverride: "let x = 1\n")
        let model = ImpactAuditModel(cli: cli)

        _ = await model.ruleDiff(ruleID: "spaceAroundOperators", filePath: file.path)
        _ = await model.ruleDiff(ruleID: "spaceAroundOperators", filePath: file.path)
        #expect(await cli.formatCallCount == 1)
    }

    @Test("ruleDiff returns empty when the file can't be read")
    func ruleDiffMissingFile() async {
        let model = ImpactAuditModel(cli: MockSwiftFormatCLI(formatOverride: "changed"))
        let diff = await model.ruleDiff(ruleID: "indent", filePath: "/no/such/file.swift")
        #expect(diff.isEmpty)
    }

    @Test("auditArguments include the lint flags, swift version and config")
    func auditArguments() async {
        let cli = MockSwiftFormatCLI(lintOutput: "[]")
        let model = ImpactAuditModel(cli: cli, swiftVersion: "5.10")
        model.extraArguments = ["--disable", "redundantSelf"]
        await model.runAudit(path: URL(fileURLWithPath: "/ws"))

        let args = await cli.lastLintArguments
        #expect(args == [
            "--lint", "--reporter", "json",
            "--swift-version", "5.10", "--disable", "redundantSelf"
        ])
    }
}

/// Exercises the real `swiftformat --lint --reporter json` end-to-end.
/// Skips cleanly when SwiftFormat is not installed.
@Suite("ImpactAudit Integration")
struct ImpactAuditIntegrationTests {
    @MainActor
    @Test("Audits a temp workspace via the real binary")
    func auditsRealWorkspace() async throws {
        let actor = SwiftFormatCLIActor()
        do {
            _ = try await actor.detectPath()
        } catch {
            return // not installed; skip
        }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SFRSAudit-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try "struct  Foo{\nlet x=1\n}\n".write(
            to: directory.appendingPathComponent("Messy.swift"),
            atomically: true,
            encoding: .utf8
        )

        let model = ImpactAuditModel(cli: actor)
        await model.runAudit(path: directory)

        #expect(model.state == .completed)
        let report = try #require(model.report)
        #expect(report.totalFindings > 0)
        #expect(report.filesAffected == 1)
        #expect(report.filesChecked == 1) // parsed from SwiftFormat's run summary
        #expect(report.ruleImpacts.contains { $0.ruleID == "spaceAroundBraces" })
    }
}
