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
    /// `true` if the rule carries the `(deprecated)` marker.
    public let isDeprecated: Bool

    public init(name: String, isOptIn: Bool, isDeprecated: Bool = false) {
        self.name = name
        self.isOptIn = isOptIn
        self.isDeprecated = isDeprecated
    }
}

/// Parses the output (stdout) of `swiftformat --rules`.
///
/// Each non-blank line is ` name`, ` name (disabled)`, or ` name (deprecated)`.
/// `(disabled)` means the rule is opt-in (off unless explicitly enabled);
/// `(deprecated)` marks a rule kept only for backwards compatibility.
public enum RuleListParser {
    public static func parse(_ output: String) -> [ParsedRuleEntry] {
        output.split(separator: "\n", omittingEmptySubsequences: false).compactMap { rawLine in
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

            // The rule name is the first whitespace-delimited token; markers
            // follow in parentheses. Skip blank lines and any non-rule content.
            guard let token = trimmed.split(separator: " ").first else { return nil }
            let name = String(token)
            guard name.first?.isLetter == true else { return nil }

            return ParsedRuleEntry(
                name: name,
                isOptIn: trimmed.contains("(disabled)"),
                isDeprecated: trimmed.contains("(deprecated)")
            )
        }
    }
}
