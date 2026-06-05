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
/// The snippets are authored as markdown in `CuratedExamples/<rule>.md` (the
/// human source of truth: a ```swift block plus optional rationale prose).
/// `Scripts/generate_curated_examples.py` compiles them into `generatedSnippets`
/// in `CuratedLiveExample+Generated.swift`, which this enum exposes.
public enum CuratedLiveExample {
    /// The curated "before" for `ruleName`, or `nil` if none is curated yet.
    public static func source(forRule ruleName: String) -> String? {
        snippets[ruleName]
    }

    /// For the few rules that act on file-level or invisible aspects a code diff
    /// can't show, a tailored explanation of *why* there's no live example —
    /// authored as a snippet-less `CuratedExamples/<rule>.md`.
    public static func unavailableNote(forRule ruleName: String) -> String? {
        generatedNotes[ruleName]
    }

    /// All curated snippets, compiled from `CuratedExamples/*.md` into
    /// `generatedSnippets` (see `CuratedLiveExample+Generated.swift`).
    static let snippets: [String: String] = generatedSnippets
}
