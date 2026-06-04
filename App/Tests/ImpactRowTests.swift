//
//  ImpactRowTests.swift
//  SwiftFormatRuleStudioTests
//

@testable import SwiftFormatRuleStudio
import SwiftFormatRuleStudioCore
import SwiftUI
import Testing
import ViewInspector

@Suite("ImpactRow")
@MainActor
struct ImpactRowTests {
    @Test("Shows the rule name, category and counts")
    func rendersImpact() throws {
        let rule = FormatRule(name: "indent", ruleDescription: "Indent.", category: .spacing)
        let view = ImpactRow(
            impact: RuleImpact(ruleID: "indent", fileCount: 3, findingCount: 7),
            maxFileCount: 3,
            rule: rule
        )

        let texts = try view.inspect().findAll(ViewType.Text.self).compactMap { try? $0.string() }
        #expect(texts.contains("indent"))
        #expect(texts.contains("Spacing"))
        #expect(texts.contains("3 files · 7 findings"))
    }

    @Test("Singular file/finding wording")
    func singularWording() throws {
        let view = ImpactRow(
            impact: RuleImpact(ruleID: "braces", fileCount: 1, findingCount: 1),
            maxFileCount: 1,
            rule: nil
        )
        let texts = try view.inspect().findAll(ViewType.Text.self).compactMap { try? $0.string() }
        #expect(texts.contains("1 file · 1 finding"))
    }
}
