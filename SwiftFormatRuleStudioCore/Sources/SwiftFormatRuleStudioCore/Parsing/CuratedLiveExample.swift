//
//  CuratedLiveExample.swift
//  SwiftFormatRuleStudio
//

import Foundation

/// Hand-authored "before" snippets for the live example, used in preference to
/// the auto-reconstructed `FormatRule.exampleBeforeSource`.
///
/// SwiftFormat's `--ruleinfo` examples are great for *reading* but often don't
/// re-format usefully on their own: some are abbreviated, some are aspirational,
/// and some need surrounding context the bare diff can't supply. A curated
/// snippet is written so that running *this rule* on it actually changes it at
/// default options — and, where the rule has an option, so that flipping the
/// option visibly changes the result. The `LiveExampleAuditTests` validation
/// test keeps every curated entry honest against the installed SwiftFormat.
///
/// The snippet data lives in `CuratedLiveExample+Data*.swift` extensions (split
/// to keep each type body and file within lint limits); this enum merges them.
public enum CuratedLiveExample {
    /// The curated "before" for `ruleName`, or `nil` if none is curated yet.
    public static func source(forRule ruleName: String) -> String? {
        snippets[ruleName]
    }

    /// All curated snippets, merged from the per-batch data extensions.
    static let snippets: [String: String] = dataChunks.reduce(into: [:]) { result, chunk in
        result.merge(chunk) { current, _ in current }
    }

    /// The per-batch data dictionaries, defined in `CuratedLiveExample+Data*`.
    static let dataChunks: [[String: String]] = [dataPart1, dataPart2, dataPart3, dataPart4, dataPart5]
}
