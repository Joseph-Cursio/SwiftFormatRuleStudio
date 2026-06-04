//
//  RuleCatalogTests.swift
//  SwiftFormatRuleStudioCoreTests
//

@testable import SwiftFormatRuleStudioCore
import Testing

@Suite("RuleCatalog")
struct RuleCatalogTests {
    private func makeCatalog() -> RuleCatalog {
        RuleCatalog(
            swiftFormatVersion: "0.61.1",
            rules: [
                FormatRule(name: "indent", ruleDescription: "Indent.", category: .spacing),
                FormatRule(name: "sortedImports", ruleDescription: "", category: .imports, isDeprecated: true)
            ],
            options: [
                FormatOption(name: "--indent", summary: "Indentation", kind: .integer, defaultValue: "4")
            ]
        )
    }

    @Test("rule(named:) finds a rule or returns nil")
    func ruleLookup() {
        let catalog = makeCatalog()
        #expect(catalog.rule(named: "indent")?.category == .spacing)
        #expect(catalog.rule(named: "nonexistent") == nil)
    }

    @Test("option(named:) finds an option or returns nil")
    func optionLookup() {
        let catalog = makeCatalog()
        #expect(catalog.option(named: "--indent")?.defaultValue == "4")
        #expect(catalog.option(named: "--nope") == nil)
    }

    @Test("activeRules excludes deprecated rules")
    func activeRules() {
        let catalog = makeCatalog()
        #expect(catalog.rules.count == 2)
        #expect(catalog.activeRules.map(\.name) == ["indent"])
    }
}
