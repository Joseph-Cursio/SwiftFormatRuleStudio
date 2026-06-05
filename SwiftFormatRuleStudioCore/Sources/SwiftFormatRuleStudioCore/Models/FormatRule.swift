//
//  FormatRule.swift
//  SwiftFormatRuleStudio
//

import Foundation
import LintStudioCore

/// A single SwiftFormat rule, as surfaced by `swiftformat --rules` /
/// `swiftformat --ruleinfo <name>`.
///
/// Conforms to the shared `LintRule` protocol from `LintStudioCore`, which is
/// the seam that lets the shared UI components render SwiftFormat rules without
/// knowing anything tool-specific.
///
/// Differences from SwiftLint's rule model:
/// - **No severity.** SwiftFormat rules either apply or they don't.
/// - **`isOptIn`** mirrors SwiftFormat's `(disabled)` marker: an opt-in rule is
///   off by default and must be explicitly enabled.
/// - **`relatedOptions`** links a rule to the global `--options` that tune it
///   (e.g. `redundantSelf` ⇄ `--self`).
public struct FormatRule: LintRule, Codable, Identifiable, Sendable, Hashable {
    /// The rule's stable name, e.g. `"redundantSelf"`. Also its identifier.
    public let name: String

    /// What the rule does (the blurb from `--ruleinfo`).
    public let ruleDescription: String

    /// Convenience grouping for the UI. See `FormatRuleCategory`.
    public let category: FormatRuleCategory

    /// Whether the rule is on by default. Opt-in rules carry SwiftFormat's
    /// `(disabled)` marker and must be explicitly enabled.
    public let isOptIn: Bool

    /// Whether the rule is currently enabled in the active configuration.
    public let isEnabled: Bool

    /// Whether SwiftFormat marks this rule `(deprecated)`.
    public let isDeprecated: Bool

    /// Global options that influence this rule, e.g. `["--self"]`.
    public let relatedOptions: [String]

    /// The raw before/after example from `--ruleinfo`, in unified-diff form
    /// (lines prefixed with `+`/`-`/space). Rendered directly — no
    /// reconstruction needed, since SwiftFormat already emits diff markers.
    public let example: String?

    public init(
        name: String,
        ruleDescription: String,
        category: FormatRuleCategory = .idiomatic,
        isOptIn: Bool = false,
        isEnabled: Bool? = nil,
        isDeprecated: Bool = false,
        relatedOptions: [String] = [],
        example: String? = nil
    ) {
        self.name = name
        self.ruleDescription = ruleDescription
        self.category = category
        self.isOptIn = isOptIn
        // Default enablement mirrors SwiftFormat: opt-in rules start off.
        self.isEnabled = isEnabled ?? !isOptIn
        self.isDeprecated = isDeprecated
        self.relatedOptions = relatedOptions
        self.example = example
    }

    /// The reconstructed "before" snippet from `example`, suitable for feeding
    /// back through SwiftFormat to build a live, option-driven preview.
    ///
    /// SwiftFormat's `--ruleinfo` examples are unified diffs with a 1-char gutter
    /// (` `/`-`/`+`), but split into blank-line-delimited hunks — and block-form
    /// rules repeat the unchanged context in *both* a "before" hunk (with `-`
    /// lines) and an "after" hunk (with `+` lines). Concatenating the whole thing
    /// would duplicate that context. So we take the **first hunk that contains a
    /// change line**, drop its `+` lines, and strip the 1-char gutter from the
    /// rest. `nil` when there's no example, or no reconstructable change hunk
    /// (e.g. prose-only "examples").
    public var exampleBeforeSource: String? {
        guard let example, !example.isEmpty else { return nil }

        // Group lines into blank-line-delimited hunks.
        var hunks: [[String]] = []
        var current: [String] = []
        for line in example.components(separatedBy: "\n") {
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                if !current.isEmpty { hunks.append(current); current = [] }
            } else {
                current.append(line)
            }
        }
        if !current.isEmpty { hunks.append(current) }

        guard let hunk = hunks.first(where: { lines in
            lines.contains { $0.hasPrefix("+") || $0.hasPrefix("-") }
        }) else { return nil }

        // Drop the result (`+`) lines; strip the 1-char gutter from the rest.
        let before = hunk
            .filter { !$0.hasPrefix("+") }
            .map { $0.isEmpty ? $0 : String($0.dropFirst()) }
            .joined(separator: "\n")
        return before.trimmingCharacters(in: .whitespaces).isEmpty ? nil : before
    }

    /// The snippet to seed the live example: a hand-authored curated snippet if
    /// one exists for this rule, otherwise the auto-reconstructed
    /// `exampleBeforeSource`. `nil` when neither is available.
    public var liveExampleSource: String? {
        CuratedLiveExample.source(forRule: name) ?? exampleBeforeSource
    }

    // MARK: - LintRule

    /// `LintRule.identifier` — for SwiftFormat the rule name is its identifier.
    public var identifier: String { name }

    /// SwiftFormat rules are rewriters: they always support autocorrection.
    public var supportsAutocorrection: Bool { true }

    // MARK: - Identifiable

    public var id: String { name }
}
