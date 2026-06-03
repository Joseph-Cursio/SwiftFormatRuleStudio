//
//  RuleStudioModelTests.swift
//  SwiftFormatRuleStudioCoreTests
//

import Testing
import Foundation
@testable import SwiftFormatRuleStudioCore
import SwiftFormatRuleStudioCoreTestSupport

@Suite("RuleStudioModel")
@MainActor
struct RuleStudioModelTests {
    private static let rules = """

     redundantSelf
     redundantParens
     acronyms (disabled)
    """

    private static let options = """

    --self             Explicit self: "insert", "remove" (default) or "init-only"
    """

    private static let redundantSelfInfo = """

    redundantSelf

    Insert/remove explicit self where applicable.

    Options:

    --self             Explicit self: "insert", "remove" (default) or "init-only"

    Examples:

    -   self.baz = 42
    +   baz = 42
    """

    private func makeModel(failWith: SwiftFormatError? = nil) -> RuleStudioModel {
        let cli = MockSwiftFormatCLI(
            rules: Self.rules,
            options: Self.options,
            ruleInfos: ["redundantSelf": Self.redundantSelfInfo],
            failWith: failWith
        )
        let loader = CatalogLoader(cli: cli, cache: nil)
        return RuleStudioModel(loader: loader)
    }

    @Test("Starts idle with empty lists")
    func initialState() {
        let model = makeModel()
        #expect(model.loadState == .idle)
        #expect(model.filteredRules.isEmpty)
        #expect(model.catalog == nil)
    }

    @Test("load() populates the catalog and reaches .loaded")
    func loadSucceeds() async {
        let model = makeModel()
        await model.load()

        #expect(model.loadState == .loaded)
        // Empty filter hides only deprecated rules; opt-in acronyms stays.
        #expect(model.filteredRules.map(\.name) == ["redundantSelf", "redundantParens", "acronyms"])
        #expect(model.options.map(\.name) == ["--self"])
    }

    @Test("load() failure surfaces .failed and clears the catalog")
    func loadFails() async {
        let model = makeModel(failWith: .notFound)
        await model.load()

        guard case .failed = model.loadState else {
            Issue.record("expected .failed, got \(model.loadState)")
            return
        }
        #expect(model.catalog == nil)
        #expect(model.filteredRules.isEmpty)
    }

    @Test("Mutating the filter re-derives the rule list")
    func filterReDerives() async {
        let model = makeModel()
        await model.load()

        model.filter.availability = .optIn
        #expect(model.filteredRules.map(\.name) == ["acronyms"])

        model.filter = RuleFilter(searchText: "parens")
        #expect(model.filteredRules.map(\.name) == ["redundantParens"])
    }

    @Test("hasNoMatches is true only when loaded and the filter hides everything")
    func noMatches() async {
        let model = makeModel()
        #expect(model.hasNoMatches == false) // not loaded yet

        await model.load()
        #expect(model.hasNoMatches == false)

        model.filter = RuleFilter(searchText: "zzz-nonexistent")
        #expect(model.hasNoMatches)
    }

    @Test("select() lazily loads the enriched detail")
    func selectLoadsDetail() async {
        let model = makeModel()
        await model.load()

        await model.select("redundantSelf")
        #expect(model.selectedRuleName == "redundantSelf")
        #expect(model.selectedRuleDetail?.ruleDescription == "Insert/remove explicit self where applicable.")
        #expect(model.selectedRuleDetail?.relatedOptions == ["--self"])
        #expect(model.selectedRuleDetail?.example == "-   self.baz = 42\n+   baz = 42")
        #expect(model.isLoadingDetail == false)
    }

    @Test("select(nil) clears the selection")
    func deselect() async {
        let model = makeModel()
        await model.load()
        await model.select("redundantSelf")

        await model.select(nil)
        #expect(model.selectedRuleName == nil)
        #expect(model.selectedRuleDetail == nil)
    }
}
