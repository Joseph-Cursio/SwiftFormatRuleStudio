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
///
/// **Every line shape is preserved, whitespace-only ones included.** That was not always true:
/// until 2026-08-12 a line of spaces parsed to a payload-less `.blank` and serialized as the
/// empty string, so `serialized(parse(s)) == s` was false for any input containing one. `.blank`
/// now carries its raw text like every other case.
public struct SwiftFormatConfig: Equatable, Sendable {
    public enum RuleDirectiveKind: String, Sendable, Equatable, CaseIterable {
        case enable
        case disable
        case rules
    }

    public enum Line: Equatable, Sendable {
        /// An empty or whitespace-only line, carrying its raw text.
        ///
        /// The payload exists so a line of spaces survives a round trip. Classification is by
        /// TRIMMED content — `"   "` is blank — but the original text is what serializes, which
        /// is the same rule every other case already followed.
        case blank(String)
        case comment(String)                                   // raw line, incl. leading '#'
        case option(key: String, value: String, raw: String)   // key has no leading '--'
        case ruleDirective(kind: RuleDirectiveKind, rules: [String], raw: String)
        case unknown(String)                                   // unrecognized raw line

        /// The text this line serializes to.
        var rendered: String {
            switch self {
            case .blank(let raw): raw
            case .comment(let raw): raw
            case .option(_, _, let raw): raw
            case .ruleDirective(_, _, let raw): raw
            case .unknown(let raw): raw
            }
        }

        /// Whether the line is visually empty, whatever whitespace it holds.
        ///
        /// Callers that mean "is there content here" must ask this rather than compare against
        /// `.blank`, which no longer denotes a single value. `SwiftFormatConfig+Editing` places a
        /// new directive after the last non-blank line and would otherwise start treating a line
        /// of spaces as content.
        var isBlank: Bool {
            if case .blank = self { return true }
            return false
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
        if trimmed.isEmpty { return .blank(raw) }
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

    /// The `.swiftformat` text.
    ///
    /// **Round-trips unedited content exactly**: `serialized(parse(s)) == s` for every `s`,
    /// including input with whitespace-only lines. Both that and the weaker normal-form law
    /// (`serialized(parse(·))` is a fixed point) are stated over generated input in
    /// `SwiftFormatConfigNormalFormPropertyTests`.
    ///
    /// The unrestricted claim is new. It held only on inputs without a whitespace-only line
    /// until `.blank` gained its raw payload, and the qualified version of this sentence is
    /// what the property suite was originally written against — see that suite's header for
    /// which of its laws changed meaning as a result.
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
            case let .option(key, value, _):
                arguments.append("--\(key)")
                if !value.isEmpty {
                    arguments.append(value)
                }
            case let .ruleDirective(kind, rules, _) where !rules.isEmpty:
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
