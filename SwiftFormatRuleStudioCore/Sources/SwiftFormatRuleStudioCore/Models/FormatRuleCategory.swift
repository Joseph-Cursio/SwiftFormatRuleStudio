//
//  FormatRuleCategory.swift
//  SwiftFormatRuleStudio
//

import Foundation
import LintStudioCore

/// A grouping for SwiftFormat rules, used for sidebar sectioning and filtering.
///
/// SwiftFormat does not expose rule categories natively, so these buckets are an
/// app-side convenience. Rules are assigned by `FormatRuleClassifier`.
///
/// Mirrors SwiftLintRuleStudio's `RuleCategory`: a `String` raw enum (so its
/// `rawValue` is the synthesized, nonisolated `RawRepresentable` witness) with
/// `nonisolated` computed members, satisfying the nonisolated `LintCategory`
/// requirements under the package's MainActor default isolation.
public enum FormatRuleCategory: String, Codable, CaseIterable, Identifiable, Sendable, LintCategory {
    /// Whitespace, blank lines, and indentation.
    case spacing
    /// Line wrapping and brace placement.
    case wrapping
    /// Removing redundant, unused, or unnecessary code.
    case redundancy
    /// Sorting, marks, declaration order, access-control placement, hoisting.
    case organization
    /// Import statements.
    case imports
    /// Comments, doc comments, file headers, and TODOs.
    case comments
    /// Test-specific rules.
    case testing
    /// Idiomatic syntax preferences that don't fit the buckets above.
    case idiomatic

    nonisolated public var id: String { rawValue }

    nonisolated public var displayName: String {
        switch self {
        case .spacing: "Spacing"
        case .wrapping: "Wrapping"
        case .redundancy: "Redundancy"
        case .organization: "Organization"
        case .imports: "Imports"
        case .comments: "Comments"
        case .testing: "Testing"
        case .idiomatic: "Idiomatic"
        }
    }
}
