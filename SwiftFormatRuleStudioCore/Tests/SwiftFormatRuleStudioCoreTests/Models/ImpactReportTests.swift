//
//  ImpactReportTests.swift
//  SwiftFormatRuleStudioCoreTests
//

@testable import SwiftFormatRuleStudioCore
import Testing

@Suite("ImpactReport")
struct ImpactReportTests {
    private static let findings = [
        LintFinding(filePath: "/ws/A.swift", line: 1, ruleID: "indent", reason: ""),
        LintFinding(filePath: "/ws/A.swift", line: 2, ruleID: "indent", reason: ""),
        LintFinding(filePath: "/ws/B.swift", line: 1, ruleID: "indent", reason: ""),
        LintFinding(filePath: "/ws/A.swift", line: 1, ruleID: "consecutiveSpaces", reason: ""),
        LintFinding(filePath: "/ws/C.swift", line: 5, ruleID: "consecutiveSpaces", reason: "")
    ]

    @Test("Aggregates per-rule file and finding counts")
    func aggregates() {
        let report = ImpactReport.from(findings: Self.findings)

        #expect(report.totalFindings == 5)
        #expect(report.filesAffected == 3) // A, B, C

        let indent = report.ruleImpacts.first { $0.ruleID == "indent" }
        #expect(indent?.fileCount == 2)    // A, B
        #expect(indent?.findingCount == 3)

        let spaces = report.ruleImpacts.first { $0.ruleID == "consecutiveSpaces" }
        #expect(spaces?.fileCount == 2)    // A, C
        #expect(spaces?.findingCount == 2)
    }

    @Test("Ranks rules by file count, then finding count")
    func ranking() {
        let report = ImpactReport.from(findings: Self.findings)
        // Both touch 2 files; indent has more findings (3 vs 2) → ranked first.
        #expect(report.ruleImpacts.map(\.ruleID) == ["indent", "consecutiveSpaces"])
    }

    @Test("Per-rule affected files carry finding counts and lines, ranked")
    func affectedFiles() {
        let report = ImpactReport.from(findings: Self.findings)

        let indent = report.ruleImpacts.first { $0.ruleID == "indent" }
        // A has 2 findings, B has 1 → A ranks first.
        #expect(indent?.files.map(\.filePath) == ["/ws/A.swift", "/ws/B.swift"])
        #expect(indent?.files.first?.findingCount == 2)
        #expect(indent?.files.first?.lines == [1, 2]) // sorted line numbers
        #expect(indent?.files.last?.lines == [1])

        let spaces = report.ruleImpacts.first { $0.ruleID == "consecutiveSpaces" }
        // Tie on count (1 each) → sorted by path: A before C.
        #expect(spaces?.files.map(\.filePath) == ["/ws/A.swift", "/ws/C.swift"])
    }

    @Test("An empty audit is clean")
    func emptyIsClean() {
        let report = ImpactReport.from(findings: [])
        #expect(report.isClean)
        #expect(report.filesAffected == 0)
        #expect(report.ruleImpacts.isEmpty)
    }
}
