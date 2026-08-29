//
//  RuleHistoryTests.swift
//  SwiftFormatRuleStudioCoreTests
//

import Foundation
@testable import SwiftFormatRuleStudioCore
import Testing

@Suite("RuleHistory")
struct RuleHistoryTests {
    private func rule(
        _ name: String,
        optIn: Bool = true,
        deprecated: Bool = false
    ) -> FormatRule {
        FormatRule(
            name: name,
            ruleDescription: "\(name) does a thing.",
            category: .idiomatic,
            isOptIn: optIn,
            isDeprecated: deprecated
        )
    }

    private func catalog(_ rules: [FormatRule], version: String = "0.62.1") -> RuleCatalog {
        RuleCatalog(swiftFormatVersion: version, rules: rules, options: [])
    }

    @Test("Anchors are ordered newest first, numerically")
    func anchorsAreOrdered() {
        let anchors = RuleHistory.anchorVersions
        #expect(!anchors.isEmpty)
        #expect(anchors == anchors.sorted {
            RuleHistory.compareVersions($0, $1) == .orderedDescending
        })
        #expect(anchors.first == "0.61.1")
    }

    @Test("Version comparison is numeric, not lexical")
    func comparesNumerically() {
        // The case a string comparison gets backwards.
        #expect(RuleHistory.compareVersions("0.9.0", "0.10.0") == .orderedAscending)
        #expect(RuleHistory.compareVersions("0.61.1", "0.62.1") == .orderedAscending)
        #expect(RuleHistory.compareVersions("0.62.1", "0.62.1") == .orderedSame)
        #expect(RuleHistory.compareVersions("0.62", "0.62.0") == .orderedSame)
    }

    @Test("The generated catalogs grow with each release")
    func catalogsGrow() throws {
        let anchors = RuleHistory.anchorVersions.reversed()
        var previous = 0
        for version in anchors {
            let count = try #require(RuleHistory.rules(inVersion: version)).count
            #expect(count > previous, "\(version) should ship more rules than its predecessor")
            previous = count
        }
        // And the oldest anchor is smaller than what the app links today.
        #expect(previous < 153)
    }

    @Test("Added rules are the ones the older version didn't have")
    func findsAddedRules() throws {
        let known = try #require(RuleHistory.rules(inVersion: "0.61.1"))
        let old = try #require(known.first)
        let added = RuleHistory.rulesAdded(since: "0.61.1", in: catalog([rule(old), rule("brandNewRule")]))
        #expect(added.map(\.name) == ["brandNewRule"])
    }

    @Test("Deprecated and already-enabled rules are not offered")
    func filtersDeprecatedAndEnabled() {
        let rules = [
            rule("freshRule"),
            rule("freshButDeprecated", deprecated: true),
            rule("freshButAlreadyOn")
        ]
        let added = RuleHistory.rulesAdded(since: "0.61.1", in: catalog(rules)) {
            $0.name == "freshButAlreadyOn"
        }
        // Nothing to gain adopting a rule on its way out, or one already on.
        #expect(added.map(\.name) == ["freshRule"])
    }

    @Test("An unknown version yields no candidates rather than every rule")
    func unknownVersionIsEmpty() {
        #expect(RuleHistory.rules(inVersion: "0.1.0") == nil)
        #expect(RuleHistory.rulesAdded(since: "0.1.0", in: catalog([rule("anything")])).isEmpty)
    }

    @Test("The digest only runs in the upgrade direction")
    func upgradeDirection() {
        #expect(RuleHistory.isUpgrade(from: "0.55.6", to: "0.62.1"))
        #expect(RuleHistory.isUpgrade(from: "0.62.1", to: "0.62.1") == false)
        #expect(RuleHistory.isUpgrade(from: "0.63.0", to: "0.62.1") == false)
    }

    @Test("Against the real catalog, 0.55.6 → today adds a known rule")
    func realDelta() throws {
        let known = try #require(RuleHistory.rules(inVersion: "0.55.6"))
        // `preferCountWhere` arrived after 0.55; `indent` has been there throughout.
        #expect(!known.contains("preferCountWhere"))
        #expect(known.contains("indent"))
    }
}

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
