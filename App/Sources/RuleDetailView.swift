//
//  RuleDetailView.swift
//  SwiftFormatRuleStudio
//

import SwiftFormatRuleStudioCore
import SwiftUI

/// Shows the selected rule's description, related options, and before/after
/// example. Reads `model.selectedRuleDetail`, which the model lazily enriches.
struct RuleDetailView: View {
    let model: RuleStudioModel
    @Environment(ConfigModel.self) private var config

    var body: some View {
        if let rule = model.selectedRuleDetail {
            detail(for: rule)
        } else if model.isLoadingDetail {
            ProgressView()
        } else {
            ContentUnavailableView(
                "Select a rule",
                systemImage: "sidebar.left",
                description: Text("Choose a rule to see what it does and how it rewrites code.")
            )
        }
    }

    private func enabledBinding(for rule: FormatRule) -> Binding<Bool> {
        Binding(
            get: { config.isRuleEnabled(rule.name, isOptIn: rule.isOptIn) },
            set: { config.setRuleEnabled(rule.name, enabled: $0, isOptIn: rule.isOptIn) }
        )
    }

    /// Whether the rule's enabled state differs from its SwiftFormat default
    /// (opt-in rules default off; the rest default on).
    private func isRuleOverridden(_ rule: FormatRule) -> Bool {
        config.isRuleEnabled(rule.name, isOptIn: rule.isOptIn) != !rule.isOptIn
    }

    /// Title color: green when enabled away from a default-off, red when disabled
    /// away from a default-on, primary when at the default.
    private func ruleStatusColor(for rule: FormatRule) -> Color {
        guard isRuleOverridden(rule) else { return .primary }
        return config.isRuleEnabled(rule.name, isOptIn: rule.isOptIn) ? .green : .red
    }

    private func detail(for rule: FormatRule) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(for: rule)

                enabledRow(for: rule)

                if !rule.ruleDescription.isEmpty {
                    Text(rule.ruleDescription)
                        .scaledFont(.title3)
                        .foregroundStyle(.secondary)
                }

                RuleOptionsSection(rule: rule, options: matchedOptions(for: rule), config: config)
                    .id(rule.name)

                RuleLiveExampleView(rule: rule, options: matchedOptions(for: rule))
                    .id(rule.name)

                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled) // select/copy the rule name, summaries, code
        }
        .navigationTitle(rule.name)
    }

    /// The "Enabled in config" switch plus a reset-to-default button shown when
    /// the rule's enabled state is overridden.
    private func enabledRow(for rule: FormatRule) -> some View {
        HStack(spacing: 10) {
            Toggle("Enabled in config", isOn: enabledBinding(for: rule))
                .toggleStyle(.switch)
            if isRuleOverridden(rule) {
                Button {
                    config.setRuleEnabled(rule.name, enabled: !rule.isOptIn, isOptIn: rule.isOptIn)
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .accessibilityLabel("Reset to default")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .help("Reset to default (\(rule.isOptIn ? "off" : "on"))")
            }
        }
    }

    private func header(for rule: FormatRule) -> some View {
        HStack(spacing: 10) {
            Text(rule.name)
                .font(.largeTitle.bold()) // pinned — the title stays a fixed size
                .foregroundStyle(ruleStatusColor(for: rule))
            badge(rule.category.displayName, color: .blue)
            if rule.isOptIn {
                badge("Opt-in", color: .orange)
            }
            if rule.isDeprecated {
                badge("Deprecated", color: .red)
            }
        }
    }

    /// Resolve the rule's `relatedOptions` flags (e.g. `["--self"]`) to the
    /// catalog's `FormatOption` values so we can render editable controls.
    private func matchedOptions(for rule: FormatRule) -> [FormatOption] {
        let keys = Set(rule.relatedOptions.map { flag in
            String(flag.drop { $0 == "-" })
        })
        return model.options.filter { keys.contains($0.key) }
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .scaledFont(.caption, weight: .semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }
}
