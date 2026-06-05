//
//  FormatRuleTests.swift
//  SwiftFormatRuleStudioCoreTests
//

import Foundation
import LintStudioCore
@testable import SwiftFormatRuleStudioCore
import Testing

@Suite("FormatRule")
struct FormatRuleTests {
    @Test("A default rule is enabled and its name is its identifier")
    func defaultRuleEnablement() {
        let rule = FormatRule(
            name: "redundantSelf",
            ruleDescription: "Insert/remove explicit self where applicable."
        )

        #expect(rule.identifier == "redundantSelf")
        #expect(rule.name == "redundantSelf")
        #expect(rule.id == "redundantSelf")
        #expect(rule.isEnabled)
        #expect(rule.isOptIn == false)
        #expect(rule.supportsAutocorrection)
        #expect(rule.category == .idiomatic)
    }

    @Test("An opt-in rule defaults to disabled")
    func optInRuleDefaultsDisabled() {
        let rule = FormatRule(
            name: "acronyms",
            ruleDescription: "Capitalize acronyms.",
            isOptIn: true
        )

        #expect(rule.isOptIn)
        #expect(rule.isEnabled == false)
    }

    @Test("Explicit enablement overrides the opt-in default")
    func explicitEnablementOverridesDefault() {
        let rule = FormatRule(
            name: "acronyms",
            ruleDescription: "Capitalize acronyms.",
            isOptIn: true,
            isEnabled: true
        )

        #expect(rule.isEnabled)
    }

    @Test("Related options and example round-trip")
    func relatedOptionsAndExample() {
        let rule = FormatRule(
            name: "redundantSelf",
            ruleDescription: "Insert/remove explicit self where applicable.",
            relatedOptions: ["--self", "--self-required"],
            example: "-   self.baz = 42\n+   baz = 42"
        )

        #expect(rule.relatedOptions == ["--self", "--self-required"])
        #expect(rule.example == "-   self.baz = 42\n+   baz = 42")
    }

    @Test("exampleBeforeSource is nil without an example")
    func exampleBeforeSourceNilWithoutExample() {
        let rule = FormatRule(name: "indent", ruleDescription: "Indent.")
        #expect(rule.exampleBeforeSource == nil)
    }

    @Test("exampleBeforeSource reconstructs an interleaved diff's before")
    func exampleBeforeSourceInterleaved() {
        // Gutter-prefixed pair: `- before` / `+ after`.
        let rule = FormatRule(
            name: "numberFormatting",
            ruleDescription: "Format numbers.",
            example: "- let color = 0xFF77A5\n+ let color = 0xff77a5"
        )
        #expect(rule.exampleBeforeSource == " let color = 0xFF77A5")
    }

    @Test("exampleBeforeSource takes only the first change hunk (no block-form duplication)")
    func exampleBeforeSourceBlockForm() {
        // redundantSelf-style: a "before" block (with `-`) then a separate
        // "after" block (with `+`). Reconstruction must NOT emit the function twice.
        let example = """
          func foobar(foo: Int, bar: Int) {
            self.foo = foo
        -   self.baz = 42
          }

          func foobar(foo: Int, bar: Int) {
            self.foo = foo
        +   baz = 42
          }
        """
        let rule = FormatRule(name: "redundantSelf", ruleDescription: "Self.", example: example)

        let before = rule.exampleBeforeSource
        #expect(before?.contains("self.baz = 42") == true)
        // Only one copy of the function — the after-block must be excluded.
        #expect(before?.components(separatedBy: "func foobar").count == 2)
    }

    @Test("FormatRule conforms to LintRule and is usable through the protocol")
    func conformsToLintRuleProtocol() {
        let rule: any LintRule = FormatRule(
            name: "indent",
            ruleDescription: "Indent code in accordance with the scope level."
        )

        #expect(rule.identifier == "indent")
        #expect(rule.supportsAutocorrection)
    }

    @Test("FormatRule survives Codable round-trip")
    func codableRoundTrip() throws {
        let rule = FormatRule(
            name: "redundantSelf",
            ruleDescription: "Insert/remove explicit self where applicable.",
            category: .redundancy,
            isOptIn: false,
            relatedOptions: ["--self"],
            example: "-   self.baz = 42\n+   baz = 42"
        )

        let data = try JSONEncoder().encode(rule)
        let decoded = try JSONDecoder().decode(FormatRule.self, from: data)

        #expect(decoded == rule)
    }
}

@Suite("FormatRuleCategory")
struct FormatRuleCategoryTests {
    @Test("Every category exposes a capitalized display name")
    func displayNames() {
        for category in FormatRuleCategory.allCases {
            #expect(category.displayName == category.rawValue.capitalized)
        }
    }
}
