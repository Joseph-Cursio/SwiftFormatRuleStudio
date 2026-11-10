//
//  OptionRuleUsageTests.swift
//  SwiftFormatRuleStudioCoreTests
//

@testable import SwiftFormatRuleStudioCore
import Testing

@Suite("OptionRuleUsage")
struct OptionRuleUsageTests {
    @Test("Known options map to their rule(s)")
    func lookups() {
        #expect(OptionRuleUsage.rules(forOptionKey: "self") == ["redundantSelf"])
        #expect(OptionRuleUsage.rules(forOptionKey: "indent") == ["indent"])
        #expect(OptionRuleUsage.rules(forOptionKey: "property-types") == ["propertyTypes", "redundantType"])
        #expect(OptionRuleUsage.rules(forOptionKey: "does-not-exist").isEmpty)
    }

    @Test("Every entry maps to at least one rule")
    func noEmptyEntries() {
        #expect(OptionRuleUsage.rulesByOptionKey.values.allSatisfy { !$0.isEmpty })
    }

    @Test("Inverse: a rule maps to its options, sorted")
    func optionKeysForRule() {
        #expect(OptionRuleUsage.optionKeys(forRule: "docComments") == ["doc-comments"])
        #expect(OptionRuleUsage.optionKeys(forRule: "sortImports") == ["import-grouping"])
        #expect(OptionRuleUsage.optionKeys(forRule: "redundantSelf") == ["self", "self-required"])
        #expect(OptionRuleUsage.optionKeys(forRule: "linebreaks") == ["linebreaks"])
        #expect(OptionRuleUsage.optionKeys(forRule: "does-not-exist").isEmpty)
    }
}
