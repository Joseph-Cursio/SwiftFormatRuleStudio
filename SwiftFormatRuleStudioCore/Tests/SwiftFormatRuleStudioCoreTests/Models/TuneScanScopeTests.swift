//
//  TuneScanScopeTests.swift
//  SwiftFormatRuleStudioCoreTests
//

import Foundation
@testable import SwiftFormatRuleStudioCore
import Testing

@Suite("TuneScanScope")
struct TuneScanScopeTests {
    private func rule(_ name: String, deprecated: Bool = false) -> FormatRule {
        FormatRule(
            name: name,
            ruleDescription: "\(name) does a thing.",
            category: .idiomatic,
            isOptIn: true,
            isDeprecated: deprecated
        )
    }

    private var catalog: RuleCatalog {
        // `indent` shipped in every anchor; the other two did not exist in 0.61.1.
        RuleCatalog(
            swiftFormatVersion: "0.62.1",
            rules: [rule("indent"), rule("brandNew"), rule("brandNewButOld", deprecated: true)],
            options: []
        )
    }

    @Test("All-disabled scans everything not enabled")
    func allDisabled() {
        let names = TuneScanScope.allDisabled
            .candidateRules(in: catalog) { $0.name == "indent" }
            .map(\.name)
        #expect(names == ["brandNew"]) // indent enabled, the deprecated one skipped
    }

    @Test("New-since scans only what arrived after that version")
    func newSince() {
        let names = TuneScanScope.newSince(version: "0.61.1")
            .candidateRules(in: catalog) { _ in false }
            .map(\.name)
        // `indent` is old news, the deprecated one isn't worth adopting.
        #expect(names == ["brandNew"])
    }

    @Test("Both scopes describe themselves for the UI")
    func labels() {
        #expect(TuneScanScope.allDisabled.title == "All disabled rules")
        #expect(TuneScanScope.newSince(version: "0.60.1").title == "New since 0.60.1")
        #expect(TuneScanScope.newSince(version: "0.60.1").explanation.contains("0.60.1"))
    }
}
