//
//  RuleHistory.swift
//  SwiftFormatRuleStudio
//

import Foundation

/// Which rules each older SwiftFormat shipped, so the app can answer "what arrived
/// since the version I'm on?"
///
/// The data is a generated table (`Scripts/generate_rule_history.py`), not a second
/// formatter. That works because of an asymmetry worth stating: a rule added after the
/// user's version exists **only in the linked engine** — the one this app already runs —
/// so measuring its churn is the isolated lint `TuneModel` already performs. The only
/// thing an old SwiftFormat knows that we don't is *which rules it had*, and that is a
/// list. See `docs/version-upgrade-diff-scope.md` §2.
///
/// What this deliberately cannot answer: whether an *existing* rule changed behavior
/// between versions. That needs both engines running, and is the separate (and far more
/// expensive) dual-version churn diff.
nonisolated public enum RuleHistory {
    /// The versions a user can say they are upgrading from, newest first.
    ///
    /// Deliberately a short, explicit list rather than "any version": each entry costs a
    /// release download at generation time, and offering arbitrary versions would imply
    /// a precision this table doesn't have.
    public static var anchorVersions: [String] {
        generatedCatalogs.keys.sorted { compareVersions($0, $1) == .orderedDescending }
    }

    /// The rule names `version` shipped, or `nil` if it isn't an anchor.
    public static func rules(inVersion version: String) -> Set<String>? {
        generatedCatalogs[version]
    }

    /// Rules in `catalog` that did not exist in `version` — the upgrade digest's
    /// candidate set.
    ///
    /// Deprecated rules are dropped (nothing to gain adopting one on its way out), and
    /// so are rules the config already enables: the question is what the upgrade *makes
    /// newly available*, not what is already on.
    public static func rulesAdded(
        since version: String,
        in catalog: RuleCatalog,
        alreadyEnabled: (FormatRule) -> Bool = { _ in false }
    ) -> [FormatRule] {
        guard let known = rules(inVersion: version) else { return [] }
        return catalog.rules
            .filter { !known.contains($0.name) }
            .filter { !$0.isDeprecated }
            .filter { !alreadyEnabled($0) }
            .sorted { $0.name < $1.name }
    }

    /// Whether `version` is older than the catalog's linked SwiftFormat — the only
    /// direction the digest makes sense in.
    public static func isUpgrade(from version: String, to current: String) -> Bool {
        compareVersions(version, current) == .orderedAscending
    }

    /// Numeric version comparison: `"0.9.0"` sorts *below* `"0.10.0"`, which a string
    /// comparison gets backwards.
    static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let right = rhs.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0 ..< max(left.count, right.count) {
            let leftPart = index < left.count ? left[index] : 0
            let rightPart = index < right.count ? right[index] : 0
            if leftPart != rightPart {
                return leftPart < rightPart ? .orderedAscending : .orderedDescending
            }
        }
        return .orderedSame
    }
}
