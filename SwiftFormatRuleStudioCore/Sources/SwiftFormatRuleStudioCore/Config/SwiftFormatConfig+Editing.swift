//
//  SwiftFormatConfig+Editing.swift
//  SwiftFormatRuleStudio
//

import Foundation

extension SwiftFormatConfig {
    // MARK: - Options

    /// Sets an option value, updating the existing line in place (preserving its
    /// position) or appending a new one. Removes any duplicate lines for the key.
    public mutating func setOption(key: String, value: String) {
        var didSet = false
        var result: [Line] = []
        for line in lines {
            if case .option(let lineKey, _, _) = line, lineKey == key {
                if !didSet {
                    result.append(.makeOption(key: key, value: value))
                    didSet = true
                }
                // drop duplicates
            } else {
                result.append(line)
            }
        }
        if !didSet {
            result = appendingDirective(.makeOption(key: key, value: value), to: result)
        }
        lines = result
    }

    /// Removes all lines setting the given option.
    public mutating func removeOption(key: String) {
        lines.removeAll { line in
            if case .option(let lineKey, _, _) = line, lineKey == key { return true }
            return false
        }
    }

    // MARK: - Rules

    /// Disables a rule: removes it from any `--enable`, adds it to `--disable`.
    public mutating func disableRule(_ name: String) {
        removeRule(name, from: .enable)
        addRule(name, to: .disable)
    }

    /// Enables an (opt-in) rule: removes it from any `--disable`, adds to `--enable`.
    public mutating func enableRule(_ name: String) {
        removeRule(name, from: .disable)
        addRule(name, to: .enable)
    }

    /// Removes any explicit enable/disable override for a rule (back to default).
    public mutating func clearRuleOverride(_ name: String) {
        removeRule(name, from: .enable)
        removeRule(name, from: .disable)
    }

    // MARK: - Rule directive helpers

    private mutating func addRule(_ name: String, to kind: RuleDirectiveKind) {
        // Already present in a directive of this kind? Nothing to do.
        if rulesAlreadyPresent(name, kind: kind) { return }

        if let index = firstIndex(ofKind: kind) {
            if case .ruleDirective(_, var rules, _) = lines[index] {
                rules.append(name)
                lines[index] = .makeRuleDirective(kind: kind, rules: rules)
            }
        } else {
            lines = appendingDirective(.makeRuleDirective(kind: kind, rules: [name]), to: lines)
        }
    }

    private mutating func removeRule(_ name: String, from kind: RuleDirectiveKind) {
        var result: [Line] = []
        for line in lines {
            if case .ruleDirective(let lineKind, var rules, _) = line, lineKind == kind {
                rules.removeAll { $0 == name }
                if rules.isEmpty {
                    continue // drop an emptied directive line entirely
                }
                result.append(.makeRuleDirective(kind: kind, rules: rules))
            } else {
                result.append(line)
            }
        }
        lines = result
    }

    private func rulesAlreadyPresent(_ name: String, kind: RuleDirectiveKind) -> Bool {
        for case let .ruleDirective(lineKind, rules, _) in lines where lineKind == kind {
            if rules.contains(name) { return true }
        }
        return false
    }

    private func firstIndex(ofKind kind: RuleDirectiveKind) -> Int? {
        lines.firstIndex { line in
            if case .ruleDirective(let lineKind, _, _) = line, lineKind == kind { return true }
            return false
        }
    }

    /// Appends a directive after the last non-blank line, so it doesn't land
    /// below trailing blank lines (which keeps a tidy file).
    private func appendingDirective(_ directive: Line, to lines: [Line]) -> [Line] {
        var result = lines
        if let lastContent = result.lastIndex(where: { $0 != .blank }) {
            result.insert(directive, at: lastContent + 1)
        } else {
            result.append(directive)
        }
        return result
    }
}
