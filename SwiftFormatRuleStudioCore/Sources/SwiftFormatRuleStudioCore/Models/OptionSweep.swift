//
//  OptionSweep.swift
//  SwiftFormatRuleStudio
//

import Foundation

/// One candidate value of an option, paired with the churn that enabling the
/// rule *at that value* would cause on the scanned project.
public struct OptionValueImpact: Sendable, Equatable, Identifiable {
    /// The option value, e.g. `"true"` or `"init-only"`.
    public let value: String
    /// How many findings the rule produces at this value (0 = reformats nothing).
    public let findingCount: Int
    /// How many distinct files it would touch.
    public let fileCount: Int

    public init(value: String, findingCount: Int, fileCount: Int) {
        self.value = value
        self.findingCount = findingCount
        self.fileCount = fileCount
    }

    public var id: String { value }
}

/// A rule's option swept across its candidate values, measuring how much each
/// value would reformat. This is the heart of the options layer: a rule's churn
/// is only meaningful relative to its options, so a rule that looks like churn at
/// the default option can be a zero-churn win at another value (e.g. `braces` is
/// free on Allman-styled code once `--allman true` is set).
public struct OptionSweep: Sendable, Equatable, Identifiable {
    /// The rule the option tunes, e.g. `"braces"`.
    public let ruleID: String
    /// The option key without dashes, e.g. `"allman"`.
    public let optionKey: String
    /// The option flag, e.g. `"--allman"`.
    public let optionFlag: String
    /// SwiftFormat's default for the option, if known.
    public let defaultValue: String?
    /// The value set in the active config, or `nil` when it's at the default.
    public let currentValue: String?
    /// Measured churn per candidate value, in the option's listed order.
    public let values: [OptionValueImpact]

    public init(
        ruleID: String,
        optionKey: String,
        optionFlag: String,
        defaultValue: String?,
        currentValue: String?,
        values: [OptionValueImpact]
    ) {
        self.ruleID = ruleID
        self.optionKey = optionKey
        self.optionFlag = optionFlag
        self.defaultValue = defaultValue
        self.currentValue = currentValue
        self.values = values
    }

    public var id: String { optionKey }

    /// The value in effect today — the config override, else the default.
    public var effectiveValue: String? { currentValue ?? defaultValue }

    /// The churn at the value in effect today, if it was measured.
    public var currentImpact: OptionValueImpact? {
        guard let effectiveValue else { return nil }
        return values.first { $0.value == effectiveValue }
    }

    /// The lowest-churn value. Ties keep the option's listed order (so a value
    /// tied with the default isn't presented as a needless change).
    public var bestValue: OptionValueImpact? {
        values.min { $0.findingCount < $1.findingCount }
    }

    /// A value that reformats nothing, if any — the headline "free win" case.
    public var zeroChurnValue: OptionValueImpact? {
        values.first { $0.findingCount == 0 }
    }

    /// Whether some value strictly beats the churn of the value in effect today.
    /// `false` when the current value is already the lowest-churn choice.
    public var hasImprovement: Bool {
        guard let best = bestValue else { return false }
        guard let current = currentImpact else { return best.findingCount >= 0 }
        return best.findingCount < current.findingCount && best.value != effectiveValue
    }
}

/// A churn rule that an option change would make cheaper — the row-level summary
/// the background pass produces, so "Needs review" can flag *"free win available
/// at `--property-types inferred`"* without the user expanding the rule. Bundles
/// the improving option sweeps with the real *joint* churn adopting them all at
/// once would cause.
public struct OptionOpportunity: Sendable, Equatable, Identifiable {
    public let ruleID: String
    /// The options that help, each adoptable at its `bestValue`.
    public let sweeps: [OptionSweep]
    /// Findings remaining once every improving option is at its best value.
    public let jointFindingCount: Int
    /// Files touched at that combination.
    public let jointFileCount: Int

    public init(ruleID: String, sweeps: [OptionSweep], jointFindingCount: Int, jointFileCount: Int) {
        self.ruleID = ruleID
        self.sweeps = sweeps
        self.jointFindingCount = jointFindingCount
        self.jointFileCount = jointFileCount
    }

    public var id: String { ruleID }

    /// The combination reformats nothing — adopting the rule with these options
    /// is a true free win.
    public var isFreeWin: Bool { jointFindingCount == 0 }

    /// The option changes as CLI fragments, e.g. `"--property-types inferred"`.
    public var optionSummary: String {
        sweeps
            .compactMap { sweep in sweep.bestValue.map { "\(sweep.optionFlag) \($0.value)" } }
            .joined(separator: ", ")
    }
}
