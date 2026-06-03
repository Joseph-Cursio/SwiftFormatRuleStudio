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
/// is layered on in M1 when the rule catalog is parsed from `--ruleinfo`.
public enum FormatRuleCategory: String, Codable, CaseIterable, Sendable, LintCategory {
    case formatting
    case redundancy
    case organization
    case spacing
    case convention

    public var displayName: String {
        rawValue.capitalized
    }
}
