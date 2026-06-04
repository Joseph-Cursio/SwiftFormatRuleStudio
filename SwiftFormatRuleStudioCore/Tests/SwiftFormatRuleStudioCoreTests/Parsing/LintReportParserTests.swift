//
//  LintReportParserTests.swift
//  SwiftFormatRuleStudioCoreTests
//

@testable import SwiftFormatRuleStudioCore
import Testing

@Suite("LintReportParser")
struct LintReportParserTests {
    // Captured from `swiftformat --lint --reporter json` (0.61.1).
    static let json = """
    [
      {
        "file" : "/ws/A.swift",
        "line" : 1,
        "reason" : "Replace consecutive spaces with a single space.",
        "rule_id" : "consecutiveSpaces"
      },
      {
        "file" : "/ws/A.swift",
        "line" : 2,
        "reason" : "Indent code in accordance with the scope level.",
        "rule_id" : "indent"
      }
    ]
    """

    @Test("Parses findings with file, line, rule and reason")
    func parsesFindings() {
        let findings = LintReportParser.parse(Self.json)

        #expect(findings.count == 2)
        #expect(findings[0] == LintFinding(
            filePath: "/ws/A.swift",
            line: 1,
            ruleID: "consecutiveSpaces",
            reason: "Replace consecutive spaces with a single space."
        ))
        #expect(findings[1].ruleID == "indent")
        #expect(findings[1].line == 2)
    }

    @Test("Empty array yields no findings")
    func emptyArray() {
        #expect(LintReportParser.parse("[]").isEmpty)
    }

    @Test("Invalid JSON yields no findings")
    func invalidJSON() {
        #expect(LintReportParser.parse("not json").isEmpty)
        #expect(LintReportParser.parse("").isEmpty)
    }
}
