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
        let model = ImpactAuditModel(cli: MockSwiftFormatCLI(lintOutput: Self.json))
        await model.runAudit(path: URL(fileURLWithPath: "/ws"))

        #expect(model.state == .completed)
        #expect(model.report?.filesAffected == 2)
        #expect(model.report?.totalFindings == 3)
        #expect(model.report?.ruleImpacts.first?.ruleID == "indent")
        #expect(model.auditedPath?.path == "/ws")
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

    @Test("auditArguments include the lint flags, swift version and config")
    func auditArguments() async {
        let cli = MockSwiftFormatCLI(lintOutput: "[]")
        let model = ImpactAuditModel(cli: cli, swiftVersion: "5.10")
        model.extraArguments = ["--disable", "redundantSelf"]
        await model.runAudit(path: URL(fileURLWithPath: "/ws"))

        let args = await cli.lastLintArguments
        #expect(args == [
            "--lint", "--reporter", "json", "--quiet",
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
        #expect(report.ruleImpacts.contains { $0.ruleID == "spaceAroundBraces" })
    }
}
