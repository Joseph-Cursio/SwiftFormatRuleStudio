//
//  TuneModelTests+RankingAndCancellation.swift
//  SwiftFormatRuleStudioCoreTests
//

import Foundation
@testable import SwiftFormatRuleStudioCore
import SwiftFormatRuleStudioCoreTestSupport
import Testing

/// Orderings whose keys only disagree with several churn rules in play, and the opportunity
/// pass's cancellation checks, which need a cancel to land at a chosen point in the pass.
extension TuneModelTests {
    // MARK: - Ranking

    /// A lint report with one finding per entry of `files` — a file listed twice has two findings.
    private static func report(_ files: [String]) -> String {
        let entries = files.enumerated().map { index, file in
            #"{ "file": "\#(file)", "line": \#(index + 1), "reason": "", "rule_id": "x" }"#
        }
        return "[" + entries.joined(separator: ",") + "]"
    }

    @Test("Churn ranks by files, then findings, then name")
    func churnRanking() async {
        // Name order disagrees with both keys, so only the full ranking puts them in this order.
        let reports = [
            "mid": Self.report(["/ws/A.swift", "/ws/B.swift"]), // 2 files, 2 findings
            "zeta": Self.report(Array(repeating: "/ws/A.swift", count: 4)), // 1 file, 4 findings
            "alpha": Self.report(["/ws/A.swift", "/ws/A.swift"]), // 1 file, 2 findings
            "beta": Self.report(["/ws/B.swift", "/ws/B.swift"]) // 1 file, 2 findings
        ]
        let cli = MockSwiftFormatCLI { args in
            reports.first { args.contains($0.key) }?.value ?? "[]"
        }
        let model = TuneModel(cli: cli)
        await model.runScan(path: URL(fileURLWithPath: "/ws"), candidateRuleNames: ["beta", "alpha", "zeta", "mid"])

        #expect(model.churn.map(\.ruleID) == ["mid", "zeta", "alpha", "beta"])
    }

    @Test("A rule's files rank by finding count before path")
    func filesRankByFindingsBeforePath() async throws {
        let cli = MockSwiftFormatCLI(lintOutput: Self.report(["/ws/A.swift", "/ws/Z.swift", "/ws/Z.swift"]))
        let model = TuneModel(cli: cli)
        await model.runScan(path: URL(fileURLWithPath: "/ws"), candidateRuleNames: ["wrapEnumCases"])

        let impact = try #require(model.churn.first)
        #expect(impact.files.map(\.filePath) == ["/ws/Z.swift", "/ws/A.swift"])
    }

    // MARK: - Opportunity pass: cancellation and order

    /// Watches lint calls from inside the mock, which runs on its own actor: records each
    /// call's rule and can cancel a task on a chosen call. Inert until `arm`ed, so the scan
    /// that precedes the pass under test is not counted.
    nonisolated private final class LintProbe: @unchecked Sendable {
        private let lock = NSLock()
        private let cancelOnCall: Int?
        private var task: Task<Void, Never>?
        private var armed = false
        private var loggedRules: [String] = []

        init(cancelOnCall: Int? = nil) { self.cancelOnCall = cancelOnCall }

        var rules: [String] { lock.withLock { loggedRules } }

        func arm(cancelling task: Task<Void, Never>? = nil) {
            lock.withLock { armed = true; self.task = task }
        }

        func record(_ args: [String]) {
            lock.withLock {
                guard armed else { return }
                if let index = args.firstIndex(of: "--rules"), index + 1 < args.count {
                    loggedRules.append(args[index + 1])
                }
                if loggedRules.count == cancelOnCall { task?.cancel() }
            }
        }
    }

    @Test("A pass cancelled before it starts measures nothing")
    func cancelledPassMeasuresNothing() async {
        let cli = allmanAwareCLI()
        let model = TuneModel(cli: cli)
        await model.runScan(path: URL(fileURLWithPath: "/ws"), candidateRuleNames: ["braces"])
        let scanLints = await cli.lintCallCount

        // Cancelled before it runs: the task cannot start until this test suspends.
        let pass = Task { await model.findOptionOpportunities(allOptions: [Self.allmanOption], currentValues: [:]) }
        pass.cancel()
        await pass.value

        #expect(await cli.lintCallCount == scanLints)
        #expect(model.optionOpportunities.isEmpty)
    }

    @Test("A pass cancelled during a rule's joint measurement records no opportunity for it")
    func cancelledMidPassRecordsNothing() async {
        // Calls in the pass: sweep --allman true, sweep --allman false, then the joint run.
        let probe = LintProbe(cancelOnCall: 3)
        let churn = Self.allmanFalseChurn
        let cli = MockSwiftFormatCLI { args in
            probe.record(args)
            return args.contains("true") ? "[]" : churn
        }
        let model = TuneModel(cli: cli)
        await model.runScan(path: URL(fileURLWithPath: "/ws"), candidateRuleNames: ["braces"])

        let pass = Task { await model.findOptionOpportunities(allOptions: [Self.allmanOption], currentValues: [:]) }
        probe.arm(cancelling: pass)
        await pass.value

        #expect(probe.rules.count == 3) // the joint run happened, and then the result was dropped
        #expect(model.optionOpportunities.isEmpty)
    }

    @Test("The pass visits the rule with fewer sweepable options first, whatever the churn order")
    func passVisitsFewestOptionsFirst() async {
        // wrapArguments out-churns braces, so it leads `churn`; braces has one sweepable option to its two.
        let reports = [
            "wrapArguments": Self.report(["/ws/A.swift", "/ws/B.swift"]),
            "braces": Self.report(["/ws/A.swift"])
        ]
        let probe = LintProbe()
        let cli = MockSwiftFormatCLI { args in
            probe.record(args)
            return reports.first { args.contains($0.key) }?.value ?? "[]"
        }
        let model = TuneModel(cli: cli)
        await model.runScan(path: URL(fileURLWithPath: "/ws"), candidateRuleNames: ["braces", "wrapArguments"])
        #expect(model.churn.map(\.ruleID) == ["wrapArguments", "braces"])

        let options = [
            Self.allmanOption,
            FormatOption(
                name: "--wrap-arguments",
                summary: "",
                kind: .enumeration,
                allowedValues: ["before-first", "after-first"],
                defaultValue: "preserve"
            ),
            FormatOption(
                name: "--closing-paren",
                summary: "",
                kind: .boolean,
                allowedValues: ["true", "false"],
                defaultValue: "true"
            )
        ]
        probe.arm()
        await model.findOptionOpportunities(allOptions: options, currentValues: [:])

        #expect(probe.rules.first == "braces")
    }
}
