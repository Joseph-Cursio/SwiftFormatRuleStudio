//
//  RuleCatalogFilteringTests.swift
//  SwiftFormatRuleStudioCoreTests
//

import Testing
@testable import SwiftFormatRuleStudioCore

@Suite("RuleCatalog filtering")
struct RuleCatalogFilteringTests {
    private func makeCatalog() -> RuleCatalog {
        RuleCatalog(
            swiftFormatVersion: "0.61.1",
            rules: [
                FormatRule(name: "redundantSelf", ruleDescription: "Insert/remove explicit self.", category: .redundancy),
                FormatRule(name: "redundantParens", ruleDescription: "Remove redundant parentheses.", category: .redundancy),
                FormatRule(name: "indent", ruleDescription: "Indent code by scope.", category: .spacing),
                FormatRule(name: "acronyms", ruleDescription: "Capitalize acronyms.", category: .convention, isOptIn: true),
                FormatRule(name: "sortedImports", ruleDescription: "Sort import statements.", category: .organization, isDeprecated: true)
            ],
            options: []
        )
    }

    @Test("Empty filter returns all non-deprecated rules")
    func emptyFilterHidesDeprecated() {
        let result = makeCatalog().filteredRules(RuleFilter())
        #expect(result.map(\.name) == ["redundantSelf", "redundantParens", "indent", "acronyms"])
    }

    @Test("includeDeprecated surfaces deprecated rules")
    func includeDeprecated() {
        let result = makeCatalog().filteredRules(RuleFilter(includeDeprecated: true))
        #expect(result.contains { $0.name == "sortedImports" })
    }

    @Test("Search matches name and description, case-insensitively")
    func searchMatches() {
        let byName = makeCatalog().filteredRules(RuleFilter(searchText: "REDUNDANT"))
        #expect(byName.map(\.name) == ["redundantSelf", "redundantParens"])

        let byDescription = makeCatalog().filteredRules(RuleFilter(searchText: "capitalize"))
        #expect(byDescription.map(\.name) == ["acronyms"])
    }

    @Test("Category filter narrows to one category")
    func categoryFilter() {
        let result = makeCatalog().filteredRules(RuleFilter(category: .redundancy))
        #expect(result.map(\.name) == ["redundantSelf", "redundantParens"])
    }

    @Test("Availability facet splits opt-in from default")
    func availabilityFilter() {
        let optIn = makeCatalog().filteredRules(RuleFilter(availability: .optIn))
        #expect(optIn.map(\.name) == ["acronyms"])

        let defaultOn = makeCatalog().filteredRules(RuleFilter(availability: .defaultOn))
        #expect(defaultOn.contains { $0.name == "acronyms" } == false)
        #expect(defaultOn.contains { $0.name == "indent" })
    }

    @Test("Facets combine (search + category)")
    func combinedFacets() {
        let result = makeCatalog().filteredRules(RuleFilter(searchText: "self", category: .redundancy))
        #expect(result.map(\.name) == ["redundantSelf"])
    }

    @Test("groupedRules sorts within group and orders by category, omitting empties")
    func grouping() {
        let groups = makeCatalog().groupedRules(RuleFilter())

        // allCases order is formatting, redundancy, organization, spacing,
        // convention. .formatting has no rules and .organization's only rule is
        // deprecated (hidden by default), so both are omitted.
        #expect(groups.map(\.category) == [.redundancy, .spacing, .convention])

        let redundancy = groups.first { $0.category == .redundancy }
        #expect(redundancy?.rules.map(\.name) == ["redundantParens", "redundantSelf"]) // sorted
    }

    @Test("RuleFilter.isActive reflects non-default facets")
    func isActive() {
        #expect(RuleFilter().isActive == false)
        #expect(RuleFilter(searchText: "x").isActive)
        #expect(RuleFilter(category: .spacing).isActive)
        #expect(RuleFilter(availability: .optIn).isActive)
        #expect(RuleFilter(includeDeprecated: true).isActive)
    }
}
