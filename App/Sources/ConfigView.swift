//
//  ConfigView.swift
//  SwiftFormatRuleStudio
//

import SwiftFormatRuleStudioCore
import SwiftUI
import UniformTypeIdentifiers

/// The `.swiftformat` editor (M4): pick a project folder, edit options, preview
/// the pending diff, and save (atomic + backup). Thin bindings over the tested
/// `ConfigModel` + the option catalog from `RuleStudioModel`.
struct ConfigView: View {
    @Environment(RuleStudioModel.self) private var catalog
    @Environment(ConfigModel.self) private var config
    @Environment(WorkspaceModel.self) private var workspace
    @State private var optionSearch = ""
    @State private var ruleSearch = ""
    @State private var choosingFolder = false
    @State private var showOnlySet = false

    var body: some View {
        Group {
            if workspace.selectedFolder == nil {
                chooseFolderPrompt
            } else {
                VStack(spacing: 0) {
                    folderHeader
                    Divider()
                    HSplitView {
                        VSplitView {
                            rulesPanel
                            optionsPanel
                        }
                        .frame(minWidth: 360)
                        diffPanel
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .navigationTitle("Config")
        .toolbar { toolbarContent }
        .fileImporter(isPresented: $choosingFolder, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result {
                _ = url.startAccessingSecurityScopedResource()
                workspace.open(url)
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button {
                choosingFolder = true
            } label: {
                Label(workspace.selectedFolder?.lastPathComponent ?? "Choose Folder…", systemImage: "folder")
            }
        }
        ToolbarItemGroup {
            Menu {
                ForEach(BuiltInPresets.all) { preset in
                    Button {
                        config.apply(preset)
                    } label: {
                        Text(preset.name)
                        Text(preset.summary)
                    }
                }
            } label: {
                Label("Presets", systemImage: "wand.and.stars")
            }
            .disabled(workspace.selectedFolder == nil)

            Button("Revert") { config.revert() }
                .disabled(config.isDirty == false)
            Button("Save") { config.save() }
                .keyboardShortcut("s")
                .disabled(config.canSave == false)
        }
    }

    // MARK: - Folder header

    private var folderHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.fill")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(workspace.selectedFolder?.lastPathComponent ?? "")
                .scaledFont(.headline, weight: .semibold)
            Text(".swiftformat")
                .scaledFont(.body, design: .monospaced)
                .foregroundStyle(.secondary)
            if config.isDirty {
                Text("• Unsaved")
                    .scaledFont(.caption, weight: .semibold)
                    .foregroundStyle(.orange)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Empty state

    private var chooseFolderPrompt: some View {
        ContentUnavailableView {
            Label("No project selected", systemImage: "folder.badge.gearshape")
        } description: {
            Text("Choose a folder to edit its .swiftformat configuration.")
        } actions: {
            Button("Choose Folder…") { choosingFolder = true }
        }
    }

    // MARK: - Rules panel

    private var rulesPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("Rules")
                    .scaledFont(.headline, weight: .semibold)
                Text("\(enabledRuleCount) of \(allRules.count) enabled")
                    .scaledFont(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            Divider()
            TextField("Filter rules", text: $ruleSearch)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            List {
                ForEach(filteredRules) { rule in
                    ruleRow(rule)
                }
            }
        }
        .frame(minWidth: 360, minHeight: 160, maxHeight: .infinity)
    }

    private func ruleRow(_ rule: FormatRule) -> some View {
        Toggle(isOn: ruleBinding(rule)) {
            VStack(alignment: .leading, spacing: 1) {
                Text(rule.name)
                    .scaledFont(.body, design: .monospaced)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if !rule.ruleDescription.isEmpty {
                    Text(rule.ruleDescription)
                        .scaledFont(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let usesText = usesText(for: rule) {
                    Text(usesText)
                        .scaledFont(.caption2)
                        .foregroundStyle(.tint)
                        .lineLimit(2)
                }
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
    }

    /// The options a rule consumes, e.g. "Uses --self, --self-required" — the
    /// mirror of the Options panel's "Used by" caption. `nil` when the rule has
    /// no options.
    private func usesText(for rule: FormatRule) -> String? {
        let keys = OptionRuleUsage.optionKeys(forRule: rule.name)
        guard !keys.isEmpty else { return nil }
        return "Uses " + keys.map { "--\($0)" }.joined(separator: ", ")
    }

    private var allRules: [FormatRule] {
        catalog.catalog?.rules ?? []
    }

    private var enabledRuleCount: Int {
        allRules.count { config.isRuleEnabled($0.name, isOptIn: $0.isOptIn) }
    }

    private var filteredRules: [FormatRule] {
        let query = ruleSearch.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return allRules }
        return allRules.filter { $0.name.lowercased().contains(query) }
    }

    private func ruleBinding(_ rule: FormatRule) -> Binding<Bool> {
        Binding(
            get: { config.isRuleEnabled(rule.name, isOptIn: rule.isOptIn) },
            set: { config.setRuleEnabled(rule.name, enabled: $0, isOptIn: rule.isOptIn) }
        )
    }

    // MARK: - Options panel

    private var optionsPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("Options")
                    .scaledFont(.headline, weight: .semibold)
                Text("\(setCount) set · \(catalog.options.count) total")
                    .scaledFont(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle("Only set", isOn: $showOnlySet)
                    .toggleStyle(.checkbox)
                    .controlSize(.small)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            Divider()
            List {
                ForEach(filteredOptions) { option in
                    OptionRow(option: option, config: config)
                }
            }
            .searchable(text: $optionSearch, prompt: "Search options")
        }
        .frame(minWidth: 360, minHeight: 160, maxHeight: .infinity)
    }

    private func isSet(_ option: FormatOption) -> Bool {
        config.config.options[option.key] != nil
    }

    private var setCount: Int {
        catalog.options.count { isSet($0) }
    }

    private var filteredOptions: [FormatOption] {
        let query = optionSearch.trimmingCharacters(in: .whitespaces).lowercased()
        return catalog.options.filter { option in
            if showOnlySet, !isSet(option) { return false }
            guard !query.isEmpty else { return true }
            return (option.name + " " + option.summary).lowercased().contains(query)
        }
    }

    // MARK: - Diff panel

    private var diffPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Pending changes", systemImage: "doc.badge.gearshape")
                    .scaledFont(.headline, weight: .semibold)
                Spacer()
                if let error = config.lastError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .scaledFont(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(8)
            Divider()
            Group {
                if config.isDirty {
                    PreviewDiffView(lines: config.diff)
                } else {
                    ContentUnavailableView(
                        "No pending changes",
                        systemImage: "checkmark.seal",
                        description: Text("Edit an option to see the .swiftformat diff here.")
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 320, maxHeight: .infinity)
    }
}

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

    private var isSet: Bool {
        config.config.options[option.key] != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Circle()
                    .fill(isSet ? Color.accentColor : Color.clear)
                    .frame(width: 6, height: 6)
                Text(option.name)
                    .scaledFont(.body, design: .monospaced)
                    .foregroundStyle(isSet ? Color.accentColor : Color.primary)
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
            Text(option.summary)
                .scaledFont(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            if let usedByText {
                Text(usedByText)
                    .scaledFont(.caption2)
                    .foregroundStyle(.tint)
            }
        }
        .padding(.vertical, 2)
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
            TextField(option.defaultValue ?? "", text: textBinding)
                .textFieldStyle(.roundedBorder)
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
