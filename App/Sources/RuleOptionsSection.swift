//
//  RuleOptionsSection.swift
//  SwiftFormatRuleStudio
//

import SwiftFormatRuleStudioCore
import SwiftUI

/// The options that tune a rule, rendered inline with the same editable
/// controls as the Config tab so you can see (and change) a rule's options
/// without leaving the rule. Collapsed by default for high-fan-out rules
/// (e.g. `organizeDeclarations` has 21) to keep the pane scannable.
struct RuleOptionsSection: View {
    let rule: FormatRule
    let options: [FormatOption]
    @Bindable var config: ConfigModel
    // swiftlint:disable:next unused_declaration - read only through its $binding by the DisclosureGroup
    @State private var isExpanded: Bool
    @State private var showOnlySet = false

    init(rule: FormatRule, options: [FormatOption], config: ConfigModel) {
        self.rule = rule
        self.options = options
        self.config = config
        // Few options → show them; many → start collapsed.
        _isExpanded = State(initialValue: options.count <= 3)
    }

    private func isSet(_ option: FormatOption) -> Bool {
        config.config.options[option.key] != nil
    }

    private var setCount: Int {
        options.count { isSet($0) }
    }

    private var visibleOptions: [FormatOption] {
        showOnlySet ? options.filter(isSet) : options
    }

    var body: some View {
        if options.isEmpty {
            Text("No tunable options.")
                .scaledFont(.callout)
                .foregroundStyle(.tertiary)
        } else {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(spacing: 0) {
                    ForEach(visibleOptions) { option in
                        Divider()
                        OptionRow(
                            option: option,
                            config: config,
                            currentRuleName: rule.name,
                            isActive: config.isRuleEnabled(rule.name, isOptIn: rule.isOptIn)
                        )
                        .padding(.vertical, 2)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text("Options")
                        .scaledFont(.headline, weight: .semibold)
                    Text("\(options.count)")
                        .scaledFont(.caption, weight: .semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(.quaternary, in: Capsule())
                    if setCount > 0 {
                        Text("· \(setCount) set")
                            .scaledFont(.caption)
                            .foregroundStyle(.tint)
                    }
                    Spacer()
                    if options.count > 3 {
                        Toggle("Only set", isOn: $showOnlySet)
                            .toggleStyle(.checkbox)
                            .controlSize(.small)
                    }
                }
            }
        }
    }
}
