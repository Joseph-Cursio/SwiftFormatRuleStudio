//
//  OptionsParser.swift
//  SwiftFormatRuleStudio
//

import Foundation

/// Parses the output of `swiftformat --options`.
///
/// Each option is a `--flag` followed by a blurb. The blurb is on the same line
/// when the flag is short enough, otherwise on the following indented line(s):
/// ```
/// --self             Explicit self: "insert", "remove" (default) or "init-only"
/// --allow-partial-wrapping
///                    Allow partial argument wrapping: "true" (default) or "false"
/// ```
/// The value `kind`, `allowedValues`, and `defaultValue` are inferred from the
/// blurb on a best-effort basis (refined later in the Options panel work).
public enum OptionsParser {
    public static func parse(_ output: String) -> [FormatOption] {
        var options: [FormatOption] = []
        var currentName: String?
        var blurbParts: [String] = []

        func flush() {
            guard let name = currentName else { return }
            options.append(makeOption(name: name, blurb: blurbParts.joined(separator: " ")))
            currentName = nil
            blurbParts = []
        }

        for line in output.components(separatedBy: "\n") {
            if line.hasPrefix("--") {
                flush()
                let (name, inlineBlurb) = splitNameAndBlurb(line)
                currentName = name
                if !inlineBlurb.isEmpty {
                    blurbParts = [inlineBlurb]
                }
            } else {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty, currentName != nil {
                    blurbParts.append(trimmed)
                }
            }
        }
        flush()

        return options
    }

    // MARK: - Line splitting

    private static func splitNameAndBlurb(_ line: String) -> (name: String, blurb: String) {
        guard let firstSpace = line.firstIndex(where: { $0 == " " || $0 == "\t" }) else {
            return (line, "")
        }
        let name = String(line[..<firstSpace])
        let blurb = line[firstSpace...].trimmingCharacters(in: .whitespaces)
        return (name, blurb)
    }

    // MARK: - Inference

    private static func makeOption(name: String, blurb: String) -> FormatOption {
        let quoted = quotedTokens(in: blurb)
        let defaultValue = inferDefault(blurb: blurb, quoted: quoted)
        let kind = inferKind(blurb: blurb, quoted: quoted, defaultValue: defaultValue)
        let allowedValues = (kind == .enumeration || kind == .boolean) ? quoted : []

        return FormatOption(
            name: name,
            summary: blurb,
            kind: kind,
            allowedValues: allowedValues,
            defaultValue: defaultValue
        )
    }

    private static func inferKind(blurb: String, quoted: [String], defaultValue: String?) -> FormatOptionKind {
        let lowercasedQuoted = Set(quoted.map { $0.lowercased() })
        if lowercasedQuoted == ["true", "false"] {
            return .boolean
        }
        if quoted.count >= 2 {
            return .enumeration
        }
        let lowerBlurb = blurb.lowercased()
        if lowerBlurb.contains("comma-delimited")
            || lowerBlurb.contains("list of")
            || (defaultValue?.contains(",") ?? false) {
            return .list
        }
        if let value = defaultValue, !value.isEmpty, value.allSatisfy(\.isNumber) {
            return .integer
        }
        return .string
    }

    private static func inferDefault(blurb: String, quoted: [String]) -> String? {
        if let marked = firstCapture(in: blurb, pattern: "\"([^\"]*)\"\\s*\\(default\\)") {
            return marked
        }
        if let quotedDefault = firstCapture(in: blurb, pattern: "[Dd]efaults? to \"([^\"]*)\"") {
            return quotedDefault
        }
        if let numericDefault = firstCapture(in: blurb, pattern: "[Dd]efaults? to ([0-9][0-9,]*)") {
            return numericDefault
        }
        if let parenDefault = firstCapture(in: blurb, pattern: "\\(default:\\s*([^)]*)\\)") {
            return parenDefault.trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    // MARK: - Regex helpers

    private static func quotedTokens(in text: String) -> [String] {
        allCaptures(in: text, pattern: "\"([^\"]*)\"")
    }

    private static func firstCapture(in text: String, pattern: String) -> String? {
        allCaptures(in: text, pattern: pattern).first
    }

    private static func allCaptures(in text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard match.numberOfRanges > 1,
                  let captureRange = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[captureRange])
        }
    }
}
