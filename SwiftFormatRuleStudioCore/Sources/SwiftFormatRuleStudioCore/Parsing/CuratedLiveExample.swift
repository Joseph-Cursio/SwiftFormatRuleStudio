//
//  CuratedLiveExample.swift
//  SwiftFormatRuleStudio
//

import Foundation

/// Hand-authored "before" snippets for the live example, used in preference to
/// the auto-reconstructed `FormatRule.exampleBeforeSource`.
///
/// SwiftFormat's `--ruleinfo` examples are great for *reading* but often don't
/// re-format usefully on their own: some are abbreviated (a multi-line case
/// shown as one line), some are aspirational (demonstrate a capability the
/// default option doesn't perform on the bare snippet), and some need
/// surrounding context (a type, a sibling declaration) the diff can't supply.
/// A curated snippet is written so that running *this rule* on it actually
/// changes it at default options — and, where the rule has an option, so that
/// flipping the option visibly changes the result. The `LiveExampleAuditTests`
/// validation test keeps every curated entry honest against the installed
/// SwiftFormat.
public enum CuratedLiveExample {
    /// The curated "before" for `ruleName`, or `nil` if none is curated yet.
    public static func source(forRule ruleName: String) -> String? {
        snippets[ruleName]
    }

    /// Rule name → curated "before" snippet. Built as close to each rule's
    /// static example as possible, adding only the context needed to make the
    /// transformation actually fire.
    static let snippets: [String: String] = [
        // multiline-only (default) blanks only the multi-line case; `always`
        // also blanks the single-line ones — so include both kinds.
        "blankLineAfterSwitchCase": """
        func handle(_ action: Action) {
            switch action {
            case .reset:
                reset()
            case .update:
                validate()
                apply()
            case .done:
                finish()
            }
        }
        """
    ]
}
