//
//  RuleListParser.swift
//  SwiftFormatRuleStudio
//

import Foundation

/// One entry from `swiftformat --rules`.
public struct ParsedRuleEntry: Equatable, Sendable {
    /// The rule's name, e.g. `"redundantSelf"`.
    public let name: String
    /// `true` if the rule carries the `(disabled)` marker (opt-in / off by default).
    public let isOptIn: Bool

    public init(name: String, isOptIn: Bool) {
        self.name = name
        self.isOptIn = isOptIn
    }
}

/// Parses the output of `swiftformat --rules`.
///
/// Each non-blank line is ` name` or ` name (disabled)`. The `(disabled)`
/// marker means the rule is opt-in (off unless explicitly enabled).
public enum RuleListParser {
    public static func parse(_ output: String) -> [ParsedRuleEntry] {
        output.split(separator: "\n", omittingEmptySubsequences: false).compactMap { rawLine in
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }

            let isOptIn = trimmed.contains("(disabled)")
            let name = trimmed
                .replacingOccurrences(of: "(disabled)", with: "")
                .trimmingCharacters(in: .whitespaces)

            // A valid rule name is a single token; skip anything else (headers, prose).
            guard !name.isEmpty, !name.contains(" ") else { return nil }

            return ParsedRuleEntry(name: name, isOptIn: isOptIn)
        }
    }
}
