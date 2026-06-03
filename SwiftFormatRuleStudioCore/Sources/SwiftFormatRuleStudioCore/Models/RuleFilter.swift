//
//  RuleFilter.swift
//  SwiftFormatRuleStudio
//

import Foundation

/// Which rules to show based on their default enablement.
public enum RuleAvailability: String, CaseIterable, Sendable, Identifiable {
    /// All rules regardless of default state.
    case all
    /// Rules that are on by default (not opt-in).
    case defaultOn
    /// Opt-in rules (SwiftFormat's `(disabled)` marker).
    case optIn

    nonisolated public var id: String { rawValue }

    nonisolated public var displayName: String {
        switch self {
        case .all: "All"
        case .defaultOn: "Default"
        case .optIn: "Opt-in"
        }
    }
}

/// The active filter for the rule browser: free-text search, an optional
/// category, an availability facet, and whether deprecated rules are shown.
public struct RuleFilter: Equatable, Sendable {
    public var searchText: String
    public var category: FormatRuleCategory?
    public var availability: RuleAvailability
    public var includeDeprecated: Bool

    public init(
        searchText: String = "",
        category: FormatRuleCategory? = nil,
        availability: RuleAvailability = .all,
        includeDeprecated: Bool = false
    ) {
        self.searchText = searchText
        self.category = category
        self.availability = availability
        self.includeDeprecated = includeDeprecated
    }

    /// Whether any facet deviates from the default (used to show a "clear" affordance).
    public var isActive: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
            || category != nil
            || availability != .all
            || includeDeprecated
    }
}

/// A category and its rules, for sectioned display in the browser.
public struct RuleGroup: Identifiable, Sendable, Equatable {
    public let category: FormatRuleCategory
    public let rules: [FormatRule]

    public init(category: FormatRuleCategory, rules: [FormatRule]) {
        self.category = category
        self.rules = rules
    }

    public var id: String { category.rawValue }
}
