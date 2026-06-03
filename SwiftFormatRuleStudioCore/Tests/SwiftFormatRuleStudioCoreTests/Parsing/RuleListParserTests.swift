//
//  RuleListParserTests.swift
//  SwiftFormatRuleStudioCoreTests
//

import Testing
@testable import SwiftFormatRuleStudioCore

@Suite("RuleListParser")
struct RuleListParserTests {
    // Captured from `swiftformat --rules` (0.61.1), abridged.
    static let fixture = """


     acronyms (disabled)
     andOperator
     anyObjectProtocol
     blankLineAfterImports
     blankLineAfterSwitchCase (disabled)
     redundantSelf
    """

    @Test("Parses names and opt-in markers")
    func parsesEntries() {
        let entries = RuleListParser.parse(Self.fixture)

        #expect(entries.count == 6)
        #expect(entries.map(\.name) == [
            "acronyms", "andOperator", "anyObjectProtocol",
            "blankLineAfterImports", "blankLineAfterSwitchCase", "redundantSelf"
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

    @Test("Empty output yields no entries")
    func emptyOutput() {
        #expect(RuleListParser.parse("\n\n").isEmpty)
    }
}
