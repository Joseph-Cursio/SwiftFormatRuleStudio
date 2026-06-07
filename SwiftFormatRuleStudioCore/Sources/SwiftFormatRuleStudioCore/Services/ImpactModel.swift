//
//  ImpactModel.swift
//  SwiftFormatRuleStudio
//

import Foundation
import LintStudioCore
import Observation

/// Observable model for the impact scan (M5): run `swiftformat --lint` over a
/// workspace and rank rules by how much code each would change.
///
/// In Core so the orchestration is unit-testable; the SwiftFormat heavy lifting
/// is offloaded to the `SwiftFormatCLIActor`.
@MainActor
@Observable
public final class ImpactModel {
    /// Lifecycle of a scan run.
    public enum ScanState: Equatable, Sendable {
        case idle
        case running
        case completed
        case failed(String)
    }

    /// The current scan state.
    public private(set) var state: ScanState = .idle
    /// The most recent report, or `nil` until a scan completes.
    public private(set) var report: ImpactReport?
    /// The folder the report was produced from.
    public private(set) var scannedPath: URL?

    /// Swift version passed as `--swift-version` (rules vary by version).
    public var swiftVersion: String?
    /// Extra arguments — typically the active config's `commandLineArguments`.
    public var extraArguments: [String] = []

    private let cli: any SwiftFormatCLIProtocol

    /// Memoized drill-down diffs, keyed by rule + file, so re-expanding a row in
    /// the report doesn't re-run SwiftFormat. Cleared on each new scan.
    private var diffCache: [String: [PreviewDiffLine]] = [:]

    /// The config flags that pick *which* rules run. We strip these when isolating
    /// a single rule for the drill-down, keeping only the option flags.
    private static let ruleSelectionFlags: Set<String> = ["--enable", "--disable", "--rules"]

    /// Creates an impact model backed by the given CLI.
    public init(cli: any SwiftFormatCLIProtocol = SwiftFormatCLIActor(), swiftVersion: String? = "5.10") {
        self.cli = cli
        self.swiftVersion = swiftVersion
    }

    /// The arguments passed to `swiftformat <path>` for the scan.
    ///
    /// No `--quiet`: we want SwiftFormat's `N/M files require formatting` summary
    /// on stderr (for the files-checked count). The JSON reporter still writes the
    /// findings to stdout, so dropping `--quiet` doesn't affect parsing.
    var scanArguments: [String] {
        var arguments = ["--lint", "--reporter", "json"]
        if let swiftVersion, !swiftVersion.isEmpty {
            arguments += ["--swift-version", swiftVersion]
        }
        arguments += extraArguments
        return arguments
    }

    /// Runs the scan over `path`, populating `report` and `state`.
    public func runScan(path: URL) async {
        state = .running
        scannedPath = path
        diffCache.removeAll()
        do {
            let result = try await cli.lint(path: path.path, arguments: scanArguments)
            let findings = LintReportParser.parse(result.reporterOutput)
            report = ImpactReport.from(
                findings: findings,
                filesChecked: Self.filesChecked(inSummary: result.summary)
            )
            state = .completed
        } catch {
            report = nil
            state = .failed(error.localizedDescription)
        }
    }

    /// The before/after diff for a single rule applied to a single file, for the
    /// report drill-down: the file as it is on disk vs. SwiftFormat run with *only*
    /// `ruleID` enabled (under the active config's options). This is the rule's
    /// standalone effect, so it can differ slightly from its marginal effect inside
    /// the full config when rules interact — but it answers "what does this rule do
    /// here?" directly. Empty if the file can't be read or formatting fails.
    /// Results are cached for the lifetime of the current report.
    public func ruleDiff(ruleID: String, filePath: String) async -> [PreviewDiffLine] {
        let key = "\(ruleID)\u{0}\(filePath)"
        if let cached = diffCache[key] { return cached }
        guard let source = try? String(contentsOfFile: filePath, encoding: .utf8) else { return [] }

        var arguments = ["stdin", "--stdin-path", filePath]
        if let swiftVersion, !swiftVersion.isEmpty, !extraArguments.contains("--swift-version") {
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
    /// `--rules`) and their values dropped, leaving only the option flags. Used to
    /// isolate one rule without the config's own enable/disable set fighting
    /// `--rules`.
    private var optionArguments: [String] {
        var result: [String] = []
        var index = 0
        while index < extraArguments.count {
            if Self.ruleSelectionFlags.contains(extraArguments[index]) {
                index += 2 // skip the flag and its comma-joined value
            } else {
                result.append(extraArguments[index])
                index += 1
            }
        }
        return result
    }

    /// Pulls the files-checked count from SwiftFormat's run summary, e.g.
    /// `"26/26 files require formatting, 3 files skipped."` → 26 (the denominator),
    /// or `"0/1 files require formatting."` → 1. `nil` when the line is absent.
    static func filesChecked(inSummary summary: String) -> Int? {
        guard let match = summary.firstMatch(of: /(\d+)\/(\d+) files? require/) else {
            return nil
        }
        return Int(match.output.2)
    }
}
