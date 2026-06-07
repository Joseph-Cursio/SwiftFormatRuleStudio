//
//  ImpactReport.swift
//  SwiftFormatRuleStudio
//

import Foundation

/// A single finding from `swiftformat --lint --reporter json`: a place where one
/// rule would change the code.
public struct LintFinding: Equatable, Sendable {
    /// Absolute path of the file the finding is in.
    public let filePath: String
    /// 1-based line number.
    public let line: Int
    /// The rule that produced the finding, e.g. `"indent"`.
    public let ruleID: String
    /// SwiftFormat's human-readable reason.
    public let reason: String

    public init(filePath: String, line: Int, ruleID: String, reason: String) {
        self.filePath = filePath
        self.line = line
        self.ruleID = ruleID
        self.reason = reason
    }
}

/// One file a rule would change, with the lines its findings sit on. Backs the
/// impact drill-down: a rule row expands to these, and each expands to a diff.
public struct FileImpact: Identifiable, Equatable, Sendable {
    /// Absolute path of the affected file.
    public let filePath: String
    /// Findings this rule produced in the file.
    public let findingCount: Int
    /// 1-based line numbers of those findings, ascending.
    public let lines: [Int]

    public init(filePath: String, findingCount: Int, lines: [Int]) {
        self.filePath = filePath
        self.findingCount = findingCount
        self.lines = lines
    }

    public var id: String { filePath }
}

/// How much a single rule would change the scanned workspace.
public struct RuleImpact: Identifiable, Equatable, Sendable {
    /// The rule's name, e.g. `"indent"`.
    public let ruleID: String
    /// Number of distinct files this rule would change.
    public let fileCount: Int
    /// Total findings this rule produced across the workspace.
    public let findingCount: Int
    /// The affected files, ranked by finding count (then path). Empty unless the
    /// report was built from findings carrying file paths.
    public let files: [FileImpact]

    public init(ruleID: String, fileCount: Int, findingCount: Int, files: [FileImpact] = []) {
        self.ruleID = ruleID
        self.fileCount = fileCount
        self.findingCount = findingCount
        self.files = files
    }

    public var id: String { ruleID }
}

/// The result of scanning a workspace: which rules would change the most code.
public struct ImpactReport: Equatable, Sendable {
    /// Distinct files with at least one finding.
    public let filesAffected: Int
    /// Total Swift files SwiftFormat actually checked (its `N/M files require
    /// formatting` denominator). Hidden dirs like `.build` are skipped, so this is
    /// the real scan size, not every `.swift` on disk.
    public let filesChecked: Int
    /// Total findings across all rules.
    public let totalFindings: Int
    /// Per-rule impact, ranked by file count (then finding count, then name).
    public let ruleImpacts: [RuleImpact]

    public init(filesAffected: Int, filesChecked: Int, totalFindings: Int, ruleImpacts: [RuleImpact]) {
        self.filesAffected = filesAffected
        self.filesChecked = filesChecked
        self.totalFindings = totalFindings
        self.ruleImpacts = ruleImpacts
    }

    /// Whether the scan found nothing to change.
    public var isClean: Bool {
        totalFindings == 0
    }

    /// Aggregates raw findings into a ranked per-rule report. `filesChecked` comes
    /// from SwiftFormat's run summary; when unknown it falls back to the number of
    /// affected files (a lower bound).
    public static func from(findings: [LintFinding], filesChecked: Int? = nil) -> Self {
        let byRule = Dictionary(grouping: findings, by: \.ruleID)
        let impacts = byRule.map { ruleID, group in
            let byFile = Dictionary(grouping: group, by: \.filePath)
            let files = byFile.map { filePath, items in
                FileImpact(
                    filePath: filePath,
                    findingCount: items.count,
                    lines: items.map(\.line).sorted()
                )
            }
            .sorted { lhs, rhs in
                if lhs.findingCount != rhs.findingCount { return lhs.findingCount > rhs.findingCount }
                return lhs.filePath < rhs.filePath
            }
            return RuleImpact(
                ruleID: ruleID,
                fileCount: byFile.count,
                findingCount: group.count,
                files: files
            )
        }
        .sorted { lhs, rhs in
            if lhs.fileCount != rhs.fileCount { return lhs.fileCount > rhs.fileCount }
            if lhs.findingCount != rhs.findingCount { return lhs.findingCount > rhs.findingCount }
            return lhs.ruleID < rhs.ruleID
        }

        let affected = Set(findings.map(\.filePath)).count
        return Self(
            filesAffected: affected,
            filesChecked: filesChecked ?? affected,
            totalFindings: findings.count,
            ruleImpacts: impacts
        )
    }
}
