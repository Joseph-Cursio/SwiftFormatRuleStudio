//
//  RuleDiffLoader.swift
//  SwiftFormatRuleStudio
//

import Foundation
import LintStudioCore

/// Runs one rule in isolation over one file and memoizes the resulting diff.
///
/// `ImpactModel` and `TuneModel` both offer a drill-down that answers "what
/// would *this* rule change in *this* file?", and both had a byte-identical
/// `ruleDiff(ruleID:filePath:)` and `optionArguments` to do it — 46 verbatim
/// lines each, down to the `\u{0}` cache-key separator. Two copies of an
/// argument-stripping rule is two chances for a new rule-selection flag to be
/// taught to one of them.
///
/// The cache lives here rather than in the models because it is only ever read
/// and written by this code; each model clears it on its own schedule via
/// ``clearCache()``.
@MainActor
final class RuleDiffLoader {
    /// The config flags that pick *which* rules run. These are stripped when
    /// isolating a single rule, keeping only the option flags — otherwise the
    /// config's own enable/disable set fights the `--rules` we pass.
    private static let ruleSelectionFlags: Set<String> = ["--enable", "--disable", "--rules"]

    private let cli: any SwiftFormatCLIProtocol
    private let reader: any SourceFileReading
    private let configIsolation: ConfigIsolation

    /// Memoized drill-down diffs, keyed by rule + file, so re-expanding a row
    /// doesn't re-run SwiftFormat.
    private var cache: [String: [PreviewDiffLine]] = [:]

    init(
        cli: any SwiftFormatCLIProtocol,
        reader: any SourceFileReading,
        configIsolation: ConfigIsolation
    ) {
        self.cli = cli
        self.reader = reader
        self.configIsolation = configIsolation
    }

    /// Drops the outstanding memoized diffs. Call at the start of a new scan.
    func clearCache() {
        cache.removeAll()
    }

    /// The diff `ruleID` alone would produce in `filePath`, or `[]` when the
    /// file can't be read or SwiftFormat fails.
    func diff(
        ruleID: String,
        filePath: String,
        swiftVersion: String?,
        extraArguments: [String]
    ) async -> [PreviewDiffLine] {
        let key = "\(ruleID)\u{0}\(filePath)"
        if let cached = cache[key] { return cached }
        guard let source = try? reader.readSource(at: filePath) else { return [] }

        var arguments = ["stdin", "--stdin-path", filePath]
        arguments += configIsolation.arguments
        if let swiftVersion, !swiftVersion.isEmpty {
            arguments += ["--swift-version", swiftVersion]
        }
        arguments += Self.optionArguments(from: extraArguments)
        arguments += ["--rules", ruleID]

        guard let output = try? await cli.format(source: source, arguments: arguments) else { return [] }
        let diff = PreviewDiffLine.lines(from: UnifiedDiffEngine.computeDiff(before: source, after: output))
        cache[key] = diff
        return diff
    }

    /// `extraArguments` with the rule-selection flags and their values dropped,
    /// leaving only the option flags.
    static func optionArguments(from extraArguments: [String]) -> [String] {
        var result: [String] = []
        var index = 0
        while index < extraArguments.count {
            if ruleSelectionFlags.contains(extraArguments[index]) {
                index += 2 // skip the flag and its comma-joined value
            } else {
                result.append(extraArguments[index])
                index += 1
            }
        }
        return result
    }
}
