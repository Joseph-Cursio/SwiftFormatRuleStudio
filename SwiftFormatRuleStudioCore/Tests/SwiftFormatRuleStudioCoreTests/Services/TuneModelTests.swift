//
//  TuneModelTests.swift
//  SwiftFormatRuleStudioCoreTests
//

import Foundation
@testable import SwiftFormatRuleStudioCore
import SwiftFormatRuleStudioCoreTestSupport
import Testing

@Suite("TuneModel")
@MainActor
struct TuneModelTests {
    /// Three findings across two files (the rule_id is ignored — an isolated
    /// `--rules X` run attributes everything to X, which the model labels itself).
    private static let json = """
    [
      { "file": "/ws/A.swift", "line": 1, "reason": "", "rule_id": "x" },
      { "file": "/ws/B.swift", "line": 1, "reason": "", "rule_id": "x" },
      { "file": "/ws/A.swift", "line": 2, "reason": "", "rule_id": "x" }
    ]
    """

    @Test("Starts idle with no results")
    func initialState() {
        let model = TuneModel(cli: MockSwiftFormatCLI())
        #expect(model.state == .idle)
        #expect(model.results.isEmpty)
        #expect(model.freeWins.isEmpty)
        #expect(model.churn.isEmpty)
    }

    @Test("No candidates completes without scanning")
    func noCandidates() async {
        let cli = MockSwiftFormatCLI()
        let model = TuneModel(cli: cli)
        await model.runScan(path: URL(fileURLWithPath: "/ws"), candidateRuleNames: [])
        #expect(model.state == .completed)
        #expect(model.results.isEmpty)
        #expect(await cli.lintCallCount == 0)
    }

    @Test("Rules that change nothing are free wins, one lint pass each, sorted by name")
    func freeWins() async {
        let cli = MockSwiftFormatCLI(lintOutput: "[]")
        let model = TuneModel(cli: cli)
        await model.runScan(path: URL(fileURLWithPath: "/ws"), candidateRuleNames: ["beta", "alpha"])

        #expect(model.state == .completed)
        #expect(await cli.lintCallCount == 2)
        #expect(model.churn.isEmpty)
        #expect(model.freeWins.map(\.ruleID) == ["alpha", "beta"])
        #expect(model.freeWins.allSatisfy { $0.findingCount == 0 && $0.fileCount == 0 })
    }

    @Test("A rule that changes code is churn, aggregated by file and labelled with the candidate")
    func churnAggregation() async {
        let cli = MockSwiftFormatCLI(lintOutput: Self.json)
        let model = TuneModel(cli: cli)
        await model.runScan(path: URL(fileURLWithPath: "/ws"), candidateRuleNames: ["wrapEnumCases"])

        #expect(model.freeWins.isEmpty)
        #expect(model.churn.count == 1)
        let impact = try! #require(model.churn.first)
        #expect(impact.ruleID == "wrapEnumCases") // labelled by candidate, not the JSON rule_id
        #expect(impact.findingCount == 3)
        #expect(impact.fileCount == 2)
        // A.swift has 2 findings, B.swift 1 → A ranks first.
        #expect(impact.files.map(\.filePath) == ["/ws/A.swift", "/ws/B.swift"])
        #expect(impact.files.first?.lines == [1, 2])
    }

    @Test("Each candidate is isolated via --rules; config enable/disable are stripped, options kept")
    func isolatesEachCandidate() async {
        let cli = MockSwiftFormatCLI(lintOutput: "[]")
        let model = TuneModel(cli: cli)
        model.extraArguments = ["--enable", "someRule", "--disable", "other", "--indent", "tabs"]
        await model.runScan(path: URL(fileURLWithPath: "/ws"), candidateRuleNames: ["wrapEnumCases"])

        let args = await cli.lastLintArguments
        #expect(args.contains("--lint"))
        #expect(args.contains("--rules"))
        #expect(args.contains("wrapEnumCases"))
        #expect(args.contains("--indent")) // option flag kept
        #expect(args.contains("tabs"))
        #expect(!args.contains("--enable")) // rule-selection flags stripped
        #expect(!args.contains("--disable"))
    }

    @Test("Completed state reports the full candidate count")
    func scansEveryCandidate() async {
        let cli = MockSwiftFormatCLI(lintOutput: "[]")
        let model = TuneModel(cli: cli)
        await model.runScan(path: URL(fileURLWithPath: "/ws"), candidateRuleNames: ["a", "b", "c"])
        #expect(model.state == .completed)
        #expect(model.results.count == 3)
        #expect(await cli.lintCallCount == 3)
    }
}
