//
//  TuneModel.swift
//  SwiftFormatRuleStudio
//

import Foundation
import LintStudioCore
import Observation

/// Observable model for the disabled-rule adoption scan (the marginal-impact
/// scan's first slice — docs/audit-redesign.md, layer C). For each currently
/// disabled opt-in rule, run `swiftformat --lint --rules <rule>` over the
/// workspace in isolation and count what it would change. A rule that changes
/// nothing is a **free win** — adopting it enforces more without any churn.
///
/// In Core so the orchestration is unit-testable; the SwiftFormat passes are
/// offloaded to the `SwiftFormatCLIActor`. One pass per candidate, run serially
/// with progress, since the actor serializes anyway.
@MainActor
@Observable
public final class TuneModel {
    /// Lifecycle of an adoption scan.
    public enum ScanState: Equatable, Sendable {
        case idle
        /// `scanned` of `total` candidate rules measured so far.
        case running(scanned: Int, total: Int)
        case completed
        case failed(String)
    }

    /// The current scan state.
    public private(set) var state: ScanState = .idle
    /// Per-candidate impact (one entry per scanned rule), in the order scanned.
    public private(set) var results: [RuleImpact] = []
    /// The folder the results were produced from.
    public private(set) var scannedPath: URL?

    /// Swift version passed as `--swift-version` (rules vary by version).
    public var swiftVersion: String?
    /// Extra arguments — typically the active config's `commandLineArguments`.
    /// Its rule-selection flags are stripped per candidate (we isolate via
    /// `--rules`); its option values are kept so each rule runs as configured.
    public var extraArguments: [String] = []

    private let cli: any SwiftFormatCLIProtocol
    private var diffCache: [String: [PreviewDiffLine]] = [:]
    private var sweepCache: [String: [OptionSweep]] = [:]
    private static let ruleSelectionFlags: Set<String> = ["--enable", "--disable", "--rules"]

    /// Creates a tune model backed by the given CLI.
    public init(cli: any SwiftFormatCLIProtocol = SwiftFormatCLIActor(), swiftVersion: String? = "5.10") {
        self.cli = cli
        self.swiftVersion = swiftVersion
    }

    /// Zero-churn candidates — enabling any of these changes nothing on this
    /// codebase today. Sorted by name for a stable, scannable list.
    public var freeWins: [RuleImpact] {
        results.filter { $0.findingCount == 0 }.sorted { $0.ruleID < $1.ruleID }
    }

    /// Candidates that would change code, ranked by impact (files, then findings).
    public var churn: [RuleImpact] {
        results.filter { $0.findingCount > 0 }.sorted { lhs, rhs in
            if lhs.fileCount != rhs.fileCount { return lhs.fileCount > rhs.fileCount }
            if lhs.findingCount != rhs.findingCount { return lhs.findingCount > rhs.findingCount }
            return lhs.ruleID < rhs.ruleID
        }
    }

    /// Clears any prior scan, returning to the idle state. Called when the project
    /// folder changes so a stale scan from another project isn't shown.
    public func reset() {
        state = .idle
        results = []
        scannedPath = nil
        diffCache.removeAll()
        sweepCache.removeAll()
    }

    /// Runs an isolated lint pass for each candidate rule over `path`, updating
    /// `results` and `state` (with progress) as it goes.
    public func runScan(path: URL, candidateRuleNames: [String]) async {
        scannedPath = path
        diffCache.removeAll()
        sweepCache.removeAll()
        results = []
        let total = candidateRuleNames.count
        state = .running(scanned: 0, total: total)
        guard total > 0 else { state = .completed; return }

        var collected: [RuleImpact] = []
        for (index, ruleName) in candidateRuleNames.enumerated() {
            collected.append(await scanRule(ruleName: ruleName, path: path))
            results = collected
            state = .running(scanned: index + 1, total: total)
        }
        state = .completed
    }

    /// Measures a single rule's standalone impact: lint the workspace with only
    /// `ruleName` enabled and aggregate the findings into a `RuleImpact`.
    private func scanRule(ruleName: String, path: URL) async -> RuleImpact {
        let findings = (try? await lintIsolated(ruleName: ruleName, path: path)) ?? []
        let byFile = Dictionary(grouping: findings, by: \.filePath)
        let files = byFile.map { filePath, items in
            FileImpact(filePath: filePath, findingCount: items.count, lines: items.map(\.line).sorted())
        }
        .sorted { lhs, rhs in
            if lhs.findingCount != rhs.findingCount { return lhs.findingCount > rhs.findingCount }
            return lhs.filePath < rhs.filePath
        }
        return RuleImpact(ruleID: ruleName, fileCount: byFile.count, findingCount: findings.count, files: files)
    }

    private func lintIsolated(
        ruleName: String,
        path: URL,
        extraOptions: [String] = []
    ) async throws -> [LintFinding] {
        var arguments = ["--lint", "--reporter", "json", "--rules", ruleName]
        if let swiftVersion, !swiftVersion.isEmpty {
            arguments += ["--swift-version", swiftVersion]
        }
        arguments += optionArguments
        // Appended last so a swept option value wins over the config's own.
        arguments += extraOptions
        let result = try await cli.lint(path: path.path, arguments: arguments)
        return LintReportParser.parse(result.reporterOutput)
    }

    /// Sweeps each of `ruleID`'s boolean/enum options across its candidate values,
    /// measuring the churn enabling the rule would cause at each — the options
    /// layer (docs/audit-redesign.md). Surfaces the value (if any) that reformats
    /// nothing, i.e. the option that turns a churn rule into a free win (`braces`
    /// is free on Allman code once `--allman true` is set). Options with no finite
    /// value set (integers, lists) are skipped. Cached for the current scan.
    ///
    /// `allOptions` is the global option catalog; `currentValues` maps an option
    /// key to its active config value (absent = at SwiftFormat's default).
    public func sweepOptions(
        forRule ruleID: String,
        path: URL,
        allOptions: [FormatOption],
        currentValues: [String: String]
    ) async -> [OptionSweep] {
        if let cached = sweepCache[ruleID] { return cached }

        let optionsByKey = Dictionary(allOptions.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
        var sweeps: [OptionSweep] = []
        for key in OptionRuleUsage.optionKeys(forRule: ruleID) {
            guard let option = optionsByKey[key],
                  option.kind == .boolean || option.kind == .enumeration,
                  !option.allowedValues.isEmpty else { continue }

            var impacts: [OptionValueImpact] = []
            for value in option.allowedValues {
                let findings = (try? await lintIsolated(
                    ruleName: ruleID, path: path, extraOptions: [option.name, value]
                )) ?? []
                let fileCount = Set(findings.map(\.filePath)).count
                impacts.append(OptionValueImpact(
                    value: value, findingCount: findings.count, fileCount: fileCount
                ))
            }
            sweeps.append(OptionSweep(
                ruleID: ruleID,
                optionKey: key,
                optionFlag: option.name,
                defaultValue: option.defaultValue,
                currentValue: currentValues[key],
                values: impacts
            ))
        }
        sweepCache[ruleID] = sweeps
        return sweeps
    }

    /// The before/after diff for one candidate rule applied to one file, for the
    /// drill-down — the file on disk vs. SwiftFormat with only that rule enabled
    /// (under the config's options). Cached for the lifetime of the current scan.
    public func ruleDiff(ruleID: String, filePath: String) async -> [PreviewDiffLine] {
        let key = "\(ruleID)\u{0}\(filePath)"
        if let cached = diffCache[key] { return cached }
        guard let source = try? String(contentsOfFile: filePath, encoding: .utf8) else { return [] }

        var arguments = ["stdin", "--stdin-path", filePath]
        if let swiftVersion, !swiftVersion.isEmpty {
            arguments += ["--swift-version", swiftVersion]
        }
        arguments += optionArguments
        arguments += ["--rules", ruleID]

        guard let output = try? await cli.format(source: source, arguments: arguments) else { return [] }
        let diff = PreviewDiffLine.lines(from: UnifiedDiffEngine.computeDiff(before: source, after: output))
        diffCache[key] = diff
        return diff
    }

    /// `extraArguments` with the rule-selection flags (`--enable`/`--disable`/
    /// `--rules`) and their values dropped, leaving only the option flags — so a
    /// candidate is measured in isolation, not fought by the config's own set.
    private var optionArguments: [String] {
        var result: [String] = []
        var index = 0
        while index < extraArguments.count {
            if Self.ruleSelectionFlags.contains(extraArguments[index]) {
                index += 2
            } else {
                result.append(extraArguments[index])
                index += 1
            }
        }
        return result
    }
}
