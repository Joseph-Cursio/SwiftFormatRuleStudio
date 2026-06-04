//
//  CatalogLoaderTests.swift
//  SwiftFormatRuleStudioCoreTests
//

import Foundation
import LintStudioCore
@testable import SwiftFormatRuleStudioCore
import SwiftFormatRuleStudioCoreTestSupport
import Testing

@Suite("CatalogLoader")
struct CatalogLoaderTests {
    private static let rulesFixture = """

     acronyms (disabled)
     andOperator
     redundantProperty (deprecated)
     redundantSelf
    """

    private static let optionsFixture = """

    --self             Explicit self: "insert", "remove" (default) or "init-only"
    --indent           Number of spaces to indent. "tab" for tabs. Defaults to 4
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

    private func makeCLI() -> MockSwiftFormatCLI {
        MockSwiftFormatCLI(
            version: "0.61.1",
            rules: Self.rulesFixture,
            options: Self.optionsFixture,
            ruleInfos: ["redundantSelf": Self.redundantSelfInfo]
        )
    }

    /// A FileCache rooted at a unique temp directory, isolated per test.
    private func makeCache() -> FileCache {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SFRSCatalogTests-\(UUID().uuidString)")
        return FileCache(appIdentifier: "SwiftFormatRuleStudioTests", cacheDirectory: directory)
    }

    @Test("Loads rules and options from the CLI")
    func loadsCatalog() async throws {
        let loader = CatalogLoader(cli: makeCLI(), cache: nil)
        let catalog = try await loader.loadCatalog()

        #expect(catalog.swiftFormatVersion == "0.61.1")
        #expect(catalog.rules.map(\.name) == ["acronyms", "andOperator", "redundantProperty", "redundantSelf"])
        #expect(catalog.rule(named: "acronyms")?.isOptIn == true)
        #expect(catalog.rule(named: "redundantProperty")?.isDeprecated == true)
        #expect(catalog.activeRules.contains { $0.name == "redundantProperty" } == false)
        #expect(catalog.options.map(\.name) == ["--self", "--indent"])
    }

    @Test("enrichedRule merges ruleinfo details")
    func enrichesRule() async throws {
        let loader = CatalogLoader(cli: makeCLI(), cache: nil)
        let rule = try await loader.enrichedRule(named: "redundantSelf")

        #expect(rule?.ruleDescription == "Insert/remove explicit self where applicable.")
        #expect(rule?.relatedOptions == ["--self"])
        #expect(rule?.example == "-   self.baz = 42\n+   baz = 42")
        // Base-entry properties are preserved.
        #expect(rule?.isOptIn == false)
    }

    @Test("Second loader with the same cache serves from disk without re-fetching")
    func diskCacheAvoidsRefetch() async throws {
        let cache = makeCache()
        let cli = makeCLI()

        let first = CatalogLoader(cli: cli, cache: cache)
        _ = try await first.loadCatalog()
        let countAfterFirst = await cli.rulesCallCount
        #expect(countAfterFirst == 1)

        // A fresh loader (empty memory cache) sharing the same on-disk cache.
        let second = CatalogLoader(cli: cli, cache: cache)
        let catalog = try await second.loadCatalog()
        let countAfterSecond = await cli.rulesCallCount

        #expect(countAfterSecond == 1) // no second fetch
        #expect(catalog.rules.count == 4)
    }

    @Test("A version change invalidates the cache")
    func versionChangeInvalidates() async throws {
        let cache = makeCache()
        let cli = makeCLI()

        let loader = CatalogLoader(cli: cli, cache: cache)
        _ = try await loader.loadCatalog()
        #expect(await cli.rulesCallCount == 1)

        await cli.setVersion("0.62.0")
        let fresh = CatalogLoader(cli: cli, cache: cache)
        let catalog = try await fresh.loadCatalog()

        #expect(catalog.swiftFormatVersion == "0.62.0")
        #expect(await cli.rulesCallCount == 2) // re-fetched
    }

    @Test("forceRefresh bypasses the cache")
    func forceRefreshRefetches() async throws {
        let cache = makeCache()
        let cli = makeCLI()
        let loader = CatalogLoader(cli: cli, cache: cache)

        _ = try await loader.loadCatalog()
        _ = try await loader.loadCatalog(forceRefresh: true)

        #expect(await cli.rulesCallCount == 2)
    }
}
