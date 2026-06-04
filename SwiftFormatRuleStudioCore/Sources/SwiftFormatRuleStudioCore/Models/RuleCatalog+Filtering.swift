//
//  RuleCatalog+Filtering.swift
//  SwiftFormatRuleStudio
//

import Foundation

extension RuleCatalog {
    /// Rules matching the filter, in catalog order. Search matches the rule
    /// name and description, case-insensitively.
    public func filteredRules(_ filter: RuleFilter) -> [FormatRule] {
        let query = filter.searchText
            .trimmingCharacters(in: .whitespaces)
            .lowercased()

        return rules.filter { rule in
            if !filter.includeDeprecated, rule.isDeprecated {
                return false
            }
            if let category = filter.category, rule.category != category {
                return false
            }
            switch filter.availability {
            case .all:
                break
            case .defaultOn where rule.isOptIn:
                return false
            case .optIn where !rule.isOptIn:
                return false
            case .defaultOn, .optIn:
                break
            }
            if !query.isEmpty {
                let haystack = (rule.name + " " + rule.ruleDescription).lowercased()
                if !haystack.contains(query) {
                    return false
                }
            }
            return true
        }
    }

    /// Filtered rules grouped by category, each group's rules sorted by name,
    /// groups ordered by `FormatRuleCategory.allCases`. Empty groups are omitted.
    public func groupedRules(_ filter: RuleFilter) -> [RuleGroup] {
        let grouped = Dictionary(grouping: filteredRules(filter), by: \.category)
        return FormatRuleCategory.allCases.compactMap { category in
            guard let group = grouped[category], !group.isEmpty else { return nil }
            return RuleGroup(category: category, rules: group.sorted { $0.name < $1.name })
        }
    }
}
