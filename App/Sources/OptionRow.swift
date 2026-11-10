//
//  OptionRow.swift
//  SwiftFormatRuleStudio
//

import SwiftFormatRuleStudioCore
import SwiftUI
import UniformTypeIdentifiers

/// One option, rendered with the right control for its inferred kind. Options
/// you've explicitly set are marked (accent dot + name) and offer a reset;
/// unset options show their default dimmed (as a placeholder where possible).
struct OptionRow: View {
    let option: FormatOption
    @Bindable var config: ConfigModel
    /// When this row is shown *under a specific rule* (the by-rule view), pass
    /// that rule's name. The caption then reads "Shared — also drives X" listing
    /// only the *other* rules, instead of the redundant "Used by <this rule>".
    var currentRuleName: String?
    /// Whether a rule that consumes this option is enabled, so the option is
    /// actually in effect. Drives the green "active" coloring.
    var isActive = false

    private var isSet: Bool {
        config.config.options[option.key] != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            optionRow
            Text(option.summary)
                .scaledFont(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            if let usedByText {
                Text(usedByText)
                    .scaledFont(.caption2)
                    .italic()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    /// The option's name, set-indicator dot, reset button, and inline editor.
    private var optionRow: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isSet ? Color.accentColor : Color.clear)
                .frame(width: 6, height: 6)
            Text(option.name)
                .scaledFont(.body, design: .monospaced)
                .foregroundStyle(isActive ? Color.accentColor : Color.primary)
            Spacer()
            if isSet {
                Button {
                    config.removeOption(key: option.key)
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .accessibilityLabel("Reset to default")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .help("Reset to default")
            }
            editor
        }
    }

    /// The rules this option tunes (an option is a no-op unless its rule is
    /// enabled). In the by-option view this reads "Used by <rules>"; in the
    /// by-rule view it shows only the *other* rules a shared option also drives.
    private var usedByText: String? {
        let rules = OptionRuleUsage.rules(forOptionKey: option.key)
        guard !rules.isEmpty else { return nil }
        guard let currentRuleName else {
            return "Used by \(rules.joined(separator: ", "))"
        }
        let others = rules.filter { $0 != currentRuleName }
        guard !others.isEmpty else { return nil }
        return "🔗 Shared — also drives \(others.joined(separator: ", "))"
    }

    @ViewBuilder
    private var editor: some View {
        switch option.kind {
        case .boolean:
            Picker("", selection: enumSelection) {
                Text(omittedLabel).tag(String?.none)
                Text("true").tag(String?.some("true"))
                Text("false").tag(String?.some("false"))
            }
            .labelsHidden()
            .frame(maxWidth: 160, alignment: .trailing)

        case .enumeration:
            Picker("", selection: enumSelection) {
                Text(omittedLabel).tag(String?.none)
                ForEach(option.allowedValues, id: \.self) { value in
                    Text(value).tag(String?.some(value))
                }
            }
            .labelsHidden()
            .frame(maxWidth: 160, alignment: .trailing)

        case .integer, .list, .string:
            // Show the set value, or an empty field with the default as a dimmed
            // placeholder — so unset options read as "not set (default: X)".
            // Use a control-face background (like the dropdowns) rather than the
            // editable-field background, which is near-invisible when empty.
            TextField(option.defaultValue ?? "", text: textBinding)
                .textFieldStyle(.plain)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
                .frame(maxWidth: 160)
        }
    }

    /// Text-field binding: shows the set value, or empty (so the default shows
    /// as placeholder). Writing the default or empty clears the override.
    private var textBinding: Binding<String> {
        Binding(
            get: { config.config.options[option.key] ?? "" },
            set: { writeValue($0) }
        )
    }

    /// Enum picker selection. `nil` means the option is *omitted* from the config
    /// (so SwiftFormat's built-in default applies); a value writes it explicitly —
    /// even if it equals the default — so "use the default" and "pin this value"
    /// are distinct, intentional choices.
    private var enumSelection: Binding<String?> {
        Binding(
            get: { config.config.options[option.key] },
            set: { newValue in
                if let newValue {
                    config.setOption(key: option.key, value: newValue)
                } else {
                    config.removeOption(key: option.key)
                }
            }
        )
    }

    /// First entry in the enum dropdown — shows what omitting resolves to.
    private var omittedLabel: String {
        if let defaultValue = option.defaultValue {
            return "(omitted → \(defaultValue))"
        }
        return "(omitted)"
    }

    private func writeValue(_ newValue: String) {
        let trimmed = newValue.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed == option.defaultValue {
            config.removeOption(key: option.key) // back to default → keep config minimal
        } else {
            config.setOption(key: option.key, value: trimmed)
        }
    }
}
