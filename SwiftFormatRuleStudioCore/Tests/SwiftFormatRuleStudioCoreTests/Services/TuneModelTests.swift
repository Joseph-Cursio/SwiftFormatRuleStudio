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

    // MARK: - Option sweep

    /// The churn `braces` causes at `--allman false` (three findings, two files).
    private static let allmanFalseChurn = """
    [
      { "file": "/ws/A.swift", "line": 1, "reason": "", "rule_id": "braces" },
      { "file": "/ws/B.swift", "line": 1, "reason": "", "rule_id": "braces" },
      { "file": "/ws/A.swift", "line": 2, "reason": "", "rule_id": "braces" }
    ]
    """

    private static let allmanOption = FormatOption(
        name: "--allman",
        summary: "Use Allman indentation style",
        kind: .boolean,
        allowedValues: ["true", "false"],
        defaultValue: "false"
    )

    /// An Allman-styled project: `braces` is churn at the default `false`, free at
    /// `true`.
    private func allmanAwareCLI() -> MockSwiftFormatCLI {
        let churn = Self.allmanFalseChurn // capture the Sendable value, not the isolated static
        return MockSwiftFormatCLI(lintOutputForArguments: { args in
            args.contains("true") ? "[]" : churn
        })
    }

    @Test("Sweeps an option's values and finds the zero-churn value")
    func sweepFindsZeroChurnValue() async {
        let cli = allmanAwareCLI()
        let model = TuneModel(cli: cli)
        let sweeps = await model.sweepOptions(
            forRule: "braces",
            path: URL(fileURLWithPath: "/ws"),
            allOptions: [Self.allmanOption],
            currentValues: [:]
        )
        #expect(sweeps.count == 1)
        let sweep = try! #require(sweeps.first)
        #expect(sweep.optionKey == "allman")
        #expect(sweep.optionFlag == "--allman")
        #expect(sweep.values.map(\.value) == ["true", "false"]) // option's listed order
        #expect(sweep.values.first { $0.value == "true" }?.findingCount == 0)
        let falseImpact = try! #require(sweep.values.first { $0.value == "false" })
        #expect(falseImpact.findingCount == 3)
        #expect(falseImpact.fileCount == 2)
        #expect(sweep.zeroChurnValue?.value == "true")
        #expect(sweep.bestValue?.value == "true")
        #expect(sweep.effectiveValue == "false") // no override → default
        #expect(sweep.currentImpact?.findingCount == 3)
        #expect(sweep.hasImprovement)
    }

    @Test("Skips options with no finite value set (integers, lists)")
    func sweepSkipsNonSweepableOptions() async {
        let cli = MockSwiftFormatCLI(lintOutput: "[]")
        let model = TuneModel(cli: cli)
        let intOption = FormatOption(
            name: "--allman", summary: "", kind: .integer, allowedValues: [], defaultValue: "0"
        )
        let sweeps = await model.sweepOptions(
            forRule: "braces",
            path: URL(fileURLWithPath: "/ws"),
            allOptions: [intOption],
            currentValues: [:]
        )
        #expect(sweeps.isEmpty)
        #expect(await cli.lintCallCount == 0) // nothing measured
    }

    @Test("No improvement when the current value is already the lowest-churn one")
    func sweepNoImprovementAtBestCurrent() async {
        let cli = allmanAwareCLI()
        let model = TuneModel(cli: cli)
        let sweeps = await model.sweepOptions(
            forRule: "braces",
            path: URL(fileURLWithPath: "/ws"),
            allOptions: [Self.allmanOption],
            currentValues: ["allman": "true"] // already Allman in config
        )
        let sweep = try! #require(sweeps.first)
        #expect(sweep.currentValue == "true")
        #expect(sweep.effectiveValue == "true")
        #expect(sweep.currentImpact?.findingCount == 0)
        #expect(!sweep.hasImprovement)
    }

    @Test("Sweep results are cached for the scan")
    func sweepIsCached() async {
        let cli = allmanAwareCLI()
        let model = TuneModel(cli: cli)
        let path = URL(fileURLWithPath: "/ws")
        _ = await model.sweepOptions(forRule: "braces", path: path, allOptions: [Self.allmanOption], currentValues: [:])
        let firstCount = await cli.lintCallCount
        #expect(firstCount == 2) // one lint per candidate value
        _ = await model.sweepOptions(forRule: "braces", path: path, allOptions: [Self.allmanOption], currentValues: [:])
        #expect(await cli.lintCallCount == firstCount) // served from cache
    }

    @Test("The swept value is appended as an option override on the lint args")
    func sweepAppendsOptionOverride() async {
        let cli = MockSwiftFormatCLI(lintOutput: "[]")
        let model = TuneModel(cli: cli)
        _ = await model.sweepOptions(
            forRule: "braces",
            path: URL(fileURLWithPath: "/ws"),
            allOptions: [Self.allmanOption],
            currentValues: [:]
        )
        let args = await cli.lastLintArguments
        #expect(args.contains("--rules"))
        #expect(args.contains("braces"))
        #expect(args.contains("--allman"))
    }

    @Test("Joint impact applies the given option overrides together")
    func ruleImpactAppliesOverrides() async {
        let cli = allmanAwareCLI()
        let model = TuneModel(cli: cli)
        let path = URL(fileURLWithPath: "/ws")

        let free = await model.ruleImpact(forRule: "braces", path: path, optionOverrides: ["--allman": "true"])
        #expect(free.findingCount == 0)

        let churn = await model.ruleImpact(forRule: "braces", path: path, optionOverrides: ["--allman": "false"])
        #expect(churn.findingCount == 3)
        #expect(churn.fileCount == 2)

        let args = await cli.lastLintArguments
        #expect(args.contains("braces"))
        #expect(args.contains("--allman"))
    }

    // MARK: - Option opportunities (post-scan background pass)

    @Test("The background pass flags a churn rule's hidden free-win option")
    func findsOptionOpportunity() async {
        let cli = allmanAwareCLI()
        let model = TuneModel(cli: cli)
        let path = URL(fileURLWithPath: "/ws")
        await model.runScan(path: path, candidateRuleNames: ["braces"])
        #expect(model.churn.map(\.ruleID) == ["braces"]) // churn at the default --allman false

        await model.findOptionOpportunities(allOptions: [Self.allmanOption], currentValues: [:])
        let opportunity = try! #require(model.optionOpportunities["braces"])
        #expect(opportunity.isFreeWin)
        #expect(opportunity.jointFindingCount == 0)
        #expect(opportunity.optionSummary == "--allman true")
        #expect(!model.isFindingOpportunities) // settled after awaiting
    }

    @Test("No opportunity is recorded when no option value helps")
    func noOpportunityWhenNoOptionHelps() async {
        // Every value lints the same — the option doesn't move the churn.
        let cli = MockSwiftFormatCLI(lintOutput: Self.allmanFalseChurn)
        let model = TuneModel(cli: cli)
        let path = URL(fileURLWithPath: "/ws")
        await model.runScan(path: path, candidateRuleNames: ["braces"])
        await model.findOptionOpportunities(allOptions: [Self.allmanOption], currentValues: [:])
        #expect(model.optionOpportunities.isEmpty)
    }
}
