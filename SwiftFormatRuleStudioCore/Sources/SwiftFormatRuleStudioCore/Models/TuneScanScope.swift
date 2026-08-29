//
//  TuneScanScope.swift
//  SwiftFormatRuleStudio
//

import Foundation

/// Which rules a Tune scan considers.
///
/// Both scopes feed the same engine — `TuneModel.runScan(path:candidateRuleNames:)`
/// lints each candidate in isolation — so the difference between "find me free wins"
/// and "what did upgrading bring me" is only which names go in. That is the whole
/// reason the upgrade digest needs no second SwiftFormat
/// (`docs/version-upgrade-diff-scope.md` §2).
nonisolated public enum TuneScanScope: Hashable, Sendable {
    /// Every disabled rule — the adoption scan.
    case allDisabled
    /// Only rules that arrived after `version` — the upgrade digest.
    case newSince(version: String)

    /// The rules to scan, given the loaded catalog and what the config already enables.
    ///
    /// Deprecated and already-enabled rules are excluded from both scopes: the question
    /// is always "what could I turn on that isn't on", not "what exists".
    public func candidateRules(
        in catalog: RuleCatalog,
        isEnabled: (FormatRule) -> Bool
    ) -> [FormatRule] {
        switch self {
        case .allDisabled:
            catalog.rules
                .filter { !$0.isDeprecated && !isEnabled($0) }
        case .newSince(let version):
            RuleHistory.rulesAdded(since: version, in: catalog, alreadyEnabled: isEnabled)
        }
    }

    /// A label for the scan control.
    public var title: String {
        switch self {
        case .allDisabled: "All disabled rules"
        case .newSince(let version): "New since \(version)"
        }
    }

    /// What the scan is *for*, in a sentence, for the empty state.
    public var explanation: String {
        switch self {
        case .allDisabled:
            "Scan every disabled rule against this project to see which you could "
                + "enable without changing a single line."
        case .newSince(let version):
            "SwiftFormat added rules since \(version). Scan them against this project "
                + "to see which you could adopt without changing a single line."
        }
    }
}
