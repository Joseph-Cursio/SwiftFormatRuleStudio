//
//  ImpactReportPropertyTests.swift
//  SwiftFormatRuleStudioCoreTests
//

@testable import SwiftFormatRuleStudioCore
import Testing

@Suite("ImpactReport properties")
struct ImpactReportPropertyTests {
    /// `ruleImpacts` is ranked by (files desc, findings desc, rule ID asc), and since rule IDs are
    /// unique the report is a function of the findings, not of the order they arrive in.
    ///
    /// Random findings are what make the ranking testable: a fixture whose file-count order and
    /// finding-count order agree cannot tell a ranking by the wrong key from the right one.
    @Test("Rule impacts are ranked by files, then findings, then ID, whatever the input order")
    func ruleImpactsAreRankedAndOrderIndependent() {
        var gen = SplitMix64(seed: 0xC0FFEE)
        for _ in 0..<300 {
            let findings = (0..<gen.int(in: 0...25)).map { _ in
                LintFinding(
                    filePath: "/f\(gen.int(in: 0...5)).swift",
                    line: gen.int(in: 1...30),
                    ruleID: "rule\(gen.int(in: 0...4))",
                    reason: ""
                )
            }
            let report = ImpactReport.from(findings: findings)
            for (lhs, rhs) in zip(report.ruleImpacts, report.ruleImpacts.dropFirst()) {
                #expect(
                    (-lhs.fileCount, -lhs.findingCount, lhs.ruleID) < (-rhs.fileCount, -rhs.findingCount, rhs.ruleID),
                    "\(lhs.ruleID) ranked before \(rhs.ruleID)"
                )
            }
            #expect(ImpactReport.from(findings: findings.reversed()) == report)
        }
    }
}
