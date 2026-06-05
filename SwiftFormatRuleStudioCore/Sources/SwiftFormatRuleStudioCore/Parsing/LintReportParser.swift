//
//  LintReportParser.swift
//  SwiftFormatRuleStudio
//

import Foundation

/// Parses the JSON output of `swiftformat --lint --reporter json` into findings.
///
/// Each entry is `{ "file", "line", "reason", "rule_id" }`. Malformed entries are
/// skipped; invalid JSON yields an empty array.
public enum LintReportParser {
    private struct RawFinding: Decodable {
        // `file` is absent when linting stdin (the live preview); present when
        // linting on-disk files (the audit).
        let file: String?
        let line: Int
        let reason: String
        let ruleID: String

        enum CodingKeys: String, CodingKey {
            case file
            case line
            case reason
            case ruleID = "rule_id"
        }
    }

    /// Parses lint reporter JSON into `LintFinding` values.
    public static func parse(_ json: String) -> [LintFinding] {
        guard let data = json.data(using: .utf8),
              let raw = try? JSONDecoder().decode([RawFinding].self, from: data) else {
            return []
        }
        return raw.map {
            LintFinding(filePath: $0.file ?? "", line: $0.line, ruleID: $0.ruleID, reason: $0.reason)
        }
    }
}
