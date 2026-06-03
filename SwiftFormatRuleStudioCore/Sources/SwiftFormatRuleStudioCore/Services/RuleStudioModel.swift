//
//  RuleStudioModel.swift
//  SwiftFormatRuleStudio
//

import Foundation
import Observation

/// The observable view model for the rule browser + detail surface (M2).
///
/// Lives in Core (not the App target) so its behavior is fully unit-testable;
/// the SwiftUI views bind to it and stay thin. Loads the catalog via a
/// `CatalogLoading`, exposes the current `RuleFilter` and derived rule lists,
/// and lazily enriches the selected rule with its `--ruleinfo` detail.
@MainActor
@Observable
public final class RuleStudioModel {
    /// Lifecycle of the catalog load. Carries the error message (not the Error)
    /// so the type stays `Equatable`/`Sendable` for view diffing.
    public enum LoadState: Equatable, Sendable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    public private(set) var loadState: LoadState = .idle
    public private(set) var catalog: RuleCatalog?

    /// The active browser filter. Mutating it re-derives the rule lists.
    public var filter = RuleFilter()

    public private(set) var selectedRuleName: String?
    public private(set) var selectedRuleDetail: FormatRule?
    public private(set) var isLoadingDetail = false

    private let loader: any CatalogLoading

    public init(loader: any CatalogLoading = CatalogLoader()) {
        self.loader = loader
    }

    // MARK: - Loading

    /// Loads (or refreshes) the catalog, updating `loadState`.
    public func load(forceRefresh: Bool = false) async {
        loadState = .loading
        do {
            catalog = try await loader.loadCatalog(forceRefresh: forceRefresh)
            loadState = .loaded
        } catch {
            catalog = nil
            loadState = .failed(error.localizedDescription)
        }
    }

    // MARK: - Derived rule lists

    /// Rules matching the current filter, in catalog order.
    public var filteredRules: [FormatRule] {
        catalog?.filteredRules(filter) ?? []
    }

    /// Filtered rules grouped by category for sectioned display.
    public var groupedRules: [RuleGroup] {
        catalog?.groupedRules(filter) ?? []
    }

    /// All global options (for the Options panel; M4).
    public var options: [FormatOption] {
        catalog?.options ?? []
    }

    /// Whether a catalog is loaded but the current filter hides every rule.
    public var hasNoMatches: Bool {
        loadState == .loaded && filteredRules.isEmpty
    }

    // MARK: - Selection / detail

    /// Selects a rule and lazily loads its `--ruleinfo` detail (description,
    /// related options, example). Passing `nil` clears the selection.
    public func select(_ ruleName: String?) async {
        selectedRuleName = ruleName
        selectedRuleDetail = nil

        guard let ruleName else { return }

        isLoadingDetail = true
        defer { isLoadingDetail = false }
        selectedRuleDetail = try? await loader.enrichedRule(named: ruleName)
    }
}
