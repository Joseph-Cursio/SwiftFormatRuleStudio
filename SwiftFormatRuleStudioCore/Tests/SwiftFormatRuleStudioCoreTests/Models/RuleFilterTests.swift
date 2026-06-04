//
//  RuleFilterTests.swift
//  SwiftFormatRuleStudioCoreTests
//

@testable import SwiftFormatRuleStudioCore
import Testing

@Suite("RuleFilter types")
struct RuleFilterTests {
    @Test("RuleAvailability exposes id and display names")
    func availability() {
        #expect(RuleAvailability.allCases.count == 3)
        #expect(RuleAvailability.all.id == "all")
        #expect(RuleAvailability.all.displayName == "All")
        #expect(RuleAvailability.defaultOn.displayName == "Default")
        #expect(RuleAvailability.optIn.displayName == "Opt-in")
    }

    @Test("RuleGroup id is the category rawValue")
    func ruleGroup() {
        let rule = FormatRule(name: "indent", ruleDescription: "", category: .spacing)
        let group = RuleGroup(category: .spacing, rules: [rule])
        #expect(group.id == "spacing")
        #expect(group.rules.count == 1)
    }

    @Test("isActive is false only for the default filter")
    func isActive() {
        #expect(RuleFilter().isActive == false)
        #expect(RuleFilter(searchText: "  ").isActive == false) // whitespace only
        #expect(RuleFilter(searchText: "x").isActive)
        #expect(RuleFilter(category: .imports).isActive)
        #expect(RuleFilter(availability: .defaultOn).isActive)
        #expect(RuleFilter(includeDeprecated: true).isActive)
    }
}
