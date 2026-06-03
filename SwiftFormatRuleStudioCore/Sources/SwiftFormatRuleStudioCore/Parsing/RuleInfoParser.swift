//
//  RuleInfoParser.swift
//  SwiftFormatRuleStudio
//

import Foundation

/// The structured result of `swiftformat --ruleinfo <name>`.
public struct ParsedRuleInfo: Equatable, Sendable {
    /// The rule name echoed at the top of the output.
    public let name: String
    /// The rule's description blurb.
    public let ruleDescription: String
    /// Global options listed under the rule's `Options:` section, e.g. `["--self"]`.
    public let relatedOptions: [String]
    /// The first before/after example, in raw unified-diff form, or `nil`.
    public let example: String?

    public init(name: String, ruleDescription: String, relatedOptions: [String], example: String?) {
        self.name = name
        self.ruleDescription = ruleDescription
        self.relatedOptions = relatedOptions
        self.example = example
    }
}

/// Parses the output of `swiftformat --ruleinfo <name>`.
///
/// Output shape:
/// ```
///   <rule name>
///
///   <description...>
///
///   Options:           (optional)
///   --flag   blurb
///
///   Examples:
///   <unified-diff lines, possibly several blocks interleaved with prose>
/// ```
/// We capture the description, the option flags under `Options:`, and the
/// **first** contiguous example block (stopping at any following prose, which
/// SwiftFormat emits left-aligned and without diff markers).
public enum RuleInfoParser {
    private static let optionsHeader = "Options:"
    private static let examplesHeader = "Examples:"

    public static func parse(_ output: String) -> ParsedRuleInfo {
        let lines = output.components(separatedBy: "\n")

        guard let nameIndex = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else {
            return ParsedRuleInfo(name: "", ruleDescription: "", relatedOptions: [], example: nil)
        }
        let name = lines[nameIndex].trimmingCharacters(in: .whitespaces)

        var descriptionLines: [String] = []
        var relatedOptions: [String] = []
        var exampleLines: [String] = []

        enum Section { case description, options, examples, done }
        var section: Section = .description
        var exampleStarted = false

        for line in lines[(nameIndex + 1)...] {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed == optionsHeader {
                section = .options
                continue
            }
            if trimmed == examplesHeader {
                section = .examples
                continue
            }

            switch section {
            case .description:
                if !trimmed.isEmpty {
                    descriptionLines.append(trimmed)
                }

            case .options:
                if trimmed.hasPrefix("--"), let flag = trimmed.split(separator: " ").first {
                    relatedOptions.append(String(flag))
                }

            case .examples:
                if exampleEnded(at: line, trimmed: trimmed, started: exampleStarted) {
                    section = .done // stop collecting; ignore trailing prose/blocks
                    continue
                }
                if !trimmed.isEmpty {
                    exampleStarted = true
                }
                if exampleStarted {
                    exampleLines.append(line)
                }

            case .done:
                continue
            }
        }

        let example = trimBlankEdges(exampleLines)

        return ParsedRuleInfo(
            name: name,
            ruleDescription: descriptionLines.joined(separator: " "),
            relatedOptions: relatedOptions,
            example: example.isEmpty ? nil : example
        )
    }

    /// An example block ends at the first non-blank line that is neither a diff
    /// line (`+`/`-`) nor indented code — i.e. left-aligned prose.
    private static func exampleEnded(at line: String, trimmed: String, started: Bool) -> Bool {
        guard started, !trimmed.isEmpty else { return false }
        let isDiff = line.hasPrefix("+") || line.hasPrefix("-")
        let isIndented = line.first == " " || line.first == "\t"
        return !(isDiff || isIndented)
    }

    private static func trimBlankEdges(_ lines: [String]) -> String {
        var slice = lines[...]
        while slice.first?.trimmingCharacters(in: .whitespaces).isEmpty == true {
            slice = slice.dropFirst()
        }
        while slice.last?.trimmingCharacters(in: .whitespaces).isEmpty == true {
            slice = slice.dropLast()
        }
        return slice.joined(separator: "\n")
    }
}
