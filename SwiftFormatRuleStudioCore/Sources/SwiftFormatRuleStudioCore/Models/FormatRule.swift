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

    /// Global options that influence this rule, e.g. `["--self"]`.
    public let relatedOptions: [String]

    /// Source snippet before formatting, parsed from the `--ruleinfo` example.
    public let exampleBefore: String?

    /// Source snippet after formatting, parsed from the `--ruleinfo` example.
    public let exampleAfter: String?

    public init(
        name: String,
        ruleDescription: String,
        category: FormatRuleCategory = .formatting,
        isOptIn: Bool = false,
        isEnabled: Bool? = nil,
        relatedOptions: [String] = [],
        exampleBefore: String? = nil,
        exampleAfter: String? = nil
    ) {
        self.name = name
        self.ruleDescription = ruleDescription
        self.category = category
        self.isOptIn = isOptIn
        // Default enablement mirrors SwiftFormat: opt-in rules start off.
        self.isEnabled = isEnabled ?? !isOptIn
        self.relatedOptions = relatedOptions
        self.exampleBefore = exampleBefore
        self.exampleAfter = exampleAfter
    }

    // MARK: - LintRule

    /// `LintRule.identifier` — for SwiftFormat the rule name is its identifier.
    public var identifier: String { name }

    /// SwiftFormat rules are rewriters: they always support autocorrection.
    public var supportsAutocorrection: Bool { true }

    // MARK: - Identifiable

    public var id: String { name }
}
