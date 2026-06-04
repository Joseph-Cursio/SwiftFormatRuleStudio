//
//  RuleListParserTests.swift
//  SwiftFormatRuleStudioCoreTests
//

@testable import SwiftFormatRuleStudioCore
import Testing

@Suite("RuleListParser")
struct RuleListParserTests {
    // Captured from `swiftformat --rules` (0.61.1), abridged. Includes a
    // (deprecated) entry, which must still be parsed.
    static let fixture = """


     acronyms (disabled)
     andOperator
     anyObjectProtocol
     blankLineAfterImports
     blankLineAfterSwitchCase (disabled)
     redundantProperty (deprecated)
     redundantSelf
    """

    @Test("Parses names and markers")
    func parsesEntries() {
        let entries = RuleListParser.parse(Self.fixture)

        #expect(entries.count == 7)
        #expect(entries.map(\.name) == [
            "acronyms", "andOperator", "anyObjectProtocol",
            "blankLineAfterImports", "blankLineAfterSwitchCase",
            "redundantProperty", "redundantSelf"
        ])
    }

    @Test("Disabled rules are opt-in, others are not")
    func optInDetection() {
        let entries = RuleListParser.parse(Self.fixture)
        let byName = Dictionary(uniqueKeysWithValues: entries.map { ($0.name, $0.isOptIn) })

        #expect(byName["acronyms"] == true)
        #expect(byName["blankLineAfterSwitchCase"] == true)
        #expect(byName["andOperator"] == false)
        #expect(byName["redundantSelf"] == false)
    }

    @Test("Deprecated rules are flagged")
    func deprecatedDetection() {
        let entries = RuleListParser.parse(Self.fixture)
        let byName = Dictionary(uniqueKeysWithValues: entries.map { ($0.name, $0.isDeprecated) })

        #expect(byName["redundantProperty"] == true)
        #expect(byName["andOperator"] == false)
    }

    @Test("Empty output yields no entries")
    func emptyOutput() {
        #expect(RuleListParser.parse("\n\n").isEmpty)
    }
}
