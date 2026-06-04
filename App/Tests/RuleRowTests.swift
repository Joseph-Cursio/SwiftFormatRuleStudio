//
//  RuleRowTests.swift
//  SwiftFormatRuleStudioTests
//

@testable import SwiftFormatRuleStudio
import SwiftFormatRuleStudioCore
import SwiftUI
import Testing
import ViewInspector

@Suite("RuleRow")
@MainActor
struct RuleRowTests {
    @Test("Shows the rule name")
    func showsName() throws {
        let view = RuleRow(rule: FormatRule(name: "redundantSelf", ruleDescription: ""))
        let texts = try view.inspect().findAll(ViewType.Text.self).compactMap { try? $0.string() }
        #expect(texts.contains("redundantSelf"))
    }

    @Test("Marks a deprecated rule")
    func marksDeprecated() throws {
        let view = RuleRow(rule: FormatRule(name: "sortedImports", ruleDescription: "", isDeprecated: true))
        let texts = try view.inspect().findAll(ViewType.Text.self).compactMap { try? $0.string() }
        #expect(texts.contains("deprecated"))
    }
}
