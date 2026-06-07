//
//  RuleOptionSummary.swift
//  SwiftFormatRuleStudio
//

import SwiftFormatRuleStudioCore

/// `--flag = value` lines for the options that tune `ruleID` — the value being
/// the active config's override or SwiftFormat's default. Empty when the rule has
/// no options. Shared by the Preview tab's triggered-rules list and the Impact
/// tab's rule rows so both describe a rule's knobs identically.
@MainActor
func ruleOptionLines(forRule ruleID: String, catalog: RuleStudioModel, config: ConfigModel) -> [String] {
    OptionRuleUsage.optionKeys(forRule: ruleID).map { key in
        let option = catalog.options.first { $0.key == key }
        let flag = option?.name ?? "--\(key)"
        if let value = config.config.options[key] {
            return "\(flag) = \(value)"
        }
        if let defaultValue = option?.defaultValue {
            return "\(flag) = \(defaultValue)"
        }
        return flag
    }
}
