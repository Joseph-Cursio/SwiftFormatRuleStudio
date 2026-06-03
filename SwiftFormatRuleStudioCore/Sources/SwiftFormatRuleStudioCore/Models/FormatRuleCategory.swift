//
//  FormatRuleCategory.swift
//  SwiftFormatRuleStudio
//

import Foundation
import LintStudioCore

/// A coarse grouping for SwiftFormat rules.
///
/// SwiftFormat does not expose rule categories natively (unlike SwiftLint), so
/// these buckets are an app-side convenience used purely for sidebar grouping
/// and filtering. Every rule defaults to `.formatting`; richer classification
/// is layered on as the rule catalog is parsed from `--ruleinfo`.
///
/// Mirrors SwiftLintRuleStudio's `RuleCategory`: a `String` raw enum (so its
/// `rawValue` is the synthesized, nonisolated `RawRepresentable` witness) with
/// `nonisolated` computed members, satisfying the nonisolated `LintCategory`
/// requirements under the package's MainActor default isolation.
public enum FormatRuleCategory: String, Codable, CaseIterable, Identifiable, Sendable, LintCategory {
    case formatting
    case redundancy
    case organization
    case spacing
    case convention

    nonisolated public var id: String { rawValue }

    nonisolated public var displayName: String {
        rawValue.capitalized
    }
}
