//
//  CatalogLoader.swift
//  SwiftFormatRuleStudio
//

import Foundation
import LintStudioCore

/// Loads the SwiftFormat rule/option catalog and enriches individual rules.
public protocol CatalogLoading: Sendable {
    /// Returns the catalog, served from the on-disk cache when the cached
    /// version matches the installed binary, otherwise re-fetched and re-cached.
    func loadCatalog(forceRefresh: Bool) async throws -> RuleCatalog

    /// Parses `--ruleinfo` for a single rule (description, related options,
    /// example). Loaded on demand because fetching all 145 up front is slow.
    func ruleInfo(for ruleName: String) async throws -> ParsedRuleInfo

    /// Returns a fully-populated rule by merging its catalog entry with its
    /// `--ruleinfo` details.
    func enrichedRule(named ruleName: String) async throws -> FormatRule?
}

/// Default `CatalogLoading` implementation backed by `SwiftFormatCLIActor` and
/// the shared `FileCache` from `LintStudioCore`.
///
/// MainActor-isolated (the package default): the subprocess work is offloaded to
/// the `SwiftFormatCLIActor`, while the light parsing and small-JSON disk cache
/// run on the main actor. Keeping it on the main actor means it can construct
/// MainActor model values, call the parsers, and encode the catalog without
/// cross-isolation friction.
public final class CatalogLoader: CatalogLoading {
    private let cli: any SwiftFormatCLIProtocol
    private let cache: FileCache?
    /// Bump when the parser's output shape changes (e.g. how option values are
    /// extracted) so stale on-disk caches from an older build are ignored even
    /// when the SwiftFormat version is unchanged.
    private static let catalogSchemaVersion = 2
    private let catalogFileName = "rule_catalog_v\(catalogSchemaVersion).json"

    /// In-memory copy to avoid re-reading the disk cache within a session.
    private var memoryCache: RuleCatalog?

    public init(
        cli: any SwiftFormatCLIProtocol = SwiftFormatCLIActor(),
        cache: FileCache? = FileCache(appIdentifier: "SwiftFormatRuleStudio")
    ) {
        self.cli = cli
        self.cache = cache
    }

    public func loadCatalog(forceRefresh: Bool) async throws -> RuleCatalog {
        let version = try await cli.version()

        if !forceRefresh, let catalog = validCachedCatalog(matching: version) {
            return catalog
        }

        let entries = RuleListParser.parse(try await cli.rulesOutput())
        let rules = entries.map { entry in
            FormatRule(
                name: entry.name,
                ruleDescription: "",
                category: FormatRuleClassifier.category(for: entry.name),
                isOptIn: entry.isOptIn,
                isDeprecated: entry.isDeprecated
            )
        }
        let options = OptionsParser.parse(try await cli.optionsOutput())
        let catalog = RuleCatalog(swiftFormatVersion: version, rules: rules, options: options)

        store(catalog)
        return catalog
    }

    public func ruleInfo(for ruleName: String) async throws -> ParsedRuleInfo {
        RuleInfoParser.parse(try await cli.ruleInfoOutput(ruleName: ruleName))
    }

    public func enrichedRule(named ruleName: String) async throws -> FormatRule? {
        let catalog = try await loadCatalog()
        guard let base = catalog.rule(named: ruleName) else { return nil }

        let info = try await ruleInfo(for: ruleName)
        return FormatRule(
            name: base.name,
            ruleDescription: info.ruleDescription,
            category: base.category,
            isOptIn: base.isOptIn,
            isEnabled: base.isEnabled,
            isDeprecated: base.isDeprecated,
            relatedOptions: info.relatedOptions,
            example: info.example
        )
    }

    // MARK: - Caching

    private func validCachedCatalog(matching version: String) -> RuleCatalog? {
        if let memoryCache, memoryCache.swiftFormatVersion == version {
            return memoryCache
        }
        guard let cache,
              let disk = try? cache.loadCodable(RuleCatalog.self, from: catalogFileName),
              disk.swiftFormatVersion == version else {
            return nil
        }
        memoryCache = disk
        return disk
    }

    private func store(_ catalog: RuleCatalog) {
        memoryCache = catalog
        try? cache?.saveCodable(catalog, to: catalogFileName)
    }
}

extension CatalogLoading {
    /// Loads the catalog from cache when valid, otherwise re-fetches.
    public func loadCatalog() async throws -> RuleCatalog {
        try await loadCatalog(forceRefresh: false)
    }
}
