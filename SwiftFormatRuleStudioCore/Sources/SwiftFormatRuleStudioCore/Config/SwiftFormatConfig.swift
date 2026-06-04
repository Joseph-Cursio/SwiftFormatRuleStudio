//
//  SwiftFormatConfig.swift
//  SwiftFormatRuleStudio
//

import Foundation

/// A parsed `.swiftformat` configuration.
///
/// `.swiftformat` is a flat list of CLI arguments (NOT YAML): one directive per
/// line, `#` comments, and `--enable`/`--disable`/`--rules` taking comma lists.
///
/// The model preserves the original line order, comments, blanks, and unknown
/// lines, and keeps each directive's raw text — so unedited lines serialize
/// byte-for-byte and edits produce minimal diffs (the "comment preservation,
/// minimal-override" pattern, without Yams).
public struct SwiftFormatConfig: Equatable, Sendable {
    public enum RuleDirectiveKind: String, Sendable, Equatable, CaseIterable {
        case enable
        case disable
        case rules
    }

    public enum Line: Equatable, Sendable {
        case blank
        case comment(String)                                   // raw line, incl. leading '#'
        case option(key: String, value: String, raw: String)   // key has no leading '--'
        case ruleDirective(kind: RuleDirectiveKind, rules: [String], raw: String)
        case unknown(String)                                   // unrecognized raw line

        /// The text this line serializes to.
        var rendered: String {
            switch self {
            case .blank: ""
            case .comment(let raw): raw
            case .option(_, _, let raw): raw
            case .ruleDirective(_, _, let raw): raw
            case .unknown(let raw): raw
            }
        }

        static func makeOption(key: String, value: String) -> Self {
            let raw = value.isEmpty ? "--\(key)" : "--\(key) \(value)"
            return .option(key: key, value: value, raw: raw)
        }

        static func makeRuleDirective(kind: RuleDirectiveKind, rules: [String]) -> Self {
            let raw = rules.isEmpty ? "--\(kind.rawValue)" : "--\(kind.rawValue) \(rules.joined(separator: ","))"
            return .ruleDirective(kind: kind, rules: rules, raw: raw)
        }
    }

    public var lines: [Line]

    public init(lines: [Line] = []) {
        self.lines = lines
    }

    // MARK: - Parsing

    public static func parse(_ text: String) -> Self {
        let parsed = text.components(separatedBy: "\n").map(parseLine)
        return Self(lines: parsed)
    }

    private static func parseLine(_ raw: String) -> Line {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return .blank }
        if trimmed.hasPrefix("#") { return .comment(raw) }
        guard trimmed.hasPrefix("--") else { return .unknown(raw) }

        let body = trimmed.dropFirst(2)
        let key: String
        let rest: String
        if let spaceIndex = body.firstIndex(where: { $0 == " " || $0 == "\t" }) {
            key = String(body[..<spaceIndex])
            rest = String(body[spaceIndex...]).trimmingCharacters(in: .whitespaces)
        } else {
            key = String(body)
            rest = ""
        }

        if let kind = RuleDirectiveKind(rawValue: key) {
            let rules = rest
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            return .ruleDirective(kind: kind, rules: rules, raw: raw)
        }
        return .option(key: key, value: rest, raw: raw)
    }

    // MARK: - Serializing

    /// The `.swiftformat` text. Round-trips unedited content exactly.
    public func serialized() -> String {
        lines.map(\.rendered).joined(separator: "\n")
    }

    // MARK: - Semantic view

    /// Effective option values (`--indent 4` → `["indent": "4"]`); later lines win.
    public var options: [String: String] {
        var result: [String: String] = [:]
        for case let .option(key, value, _) in lines {
            result[key] = value
        }
        return result
    }

    /// Rules explicitly disabled via `--disable`.
    public var disabledRules: Set<String> {
        rules(for: .disable)
    }

    /// Opt-in rules explicitly enabled via `--enable`.
    public var enabledRules: Set<String> {
        rules(for: .enable)
    }

    /// The `--rules` allowlist (only these run), or `nil` if not used.
    public var explicitRules: [String]? {
        for case let .ruleDirective(.rules, rules, _) in lines.reversed() {
            return rules
        }
        return nil
    }

    /// The config as `swiftformat` CLI arguments, e.g.
    /// `["--indent", "4", "--disable", "redundantSelf"]`. Lets the live preview
    /// run against the edited (unsaved) config without writing a temp file.
    public var commandLineArguments: [String] {
        var arguments: [String] = []
        for line in lines {
            switch line {
            case .option(let key, let value, _):
                arguments.append("--\(key)")
                if !value.isEmpty {
                    arguments.append(value)
                }
            case .ruleDirective(let kind, let rules, _) where !rules.isEmpty:
                arguments.append("--\(kind.rawValue)")
                arguments.append(rules.joined(separator: ","))
            case .blank, .comment, .unknown, .ruleDirective:
                break
            }
        }
        return arguments
    }

    private func rules(for kind: RuleDirectiveKind) -> Set<String> {
        var result: Set<String> = []
        for case let .ruleDirective(lineKind, rules, _) in lines where lineKind == kind {
            result.formUnion(rules)
        }
        return result
    }
}
