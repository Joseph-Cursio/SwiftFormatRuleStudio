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
                        ConfigDiffPanel()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .navigationTitle("Config")
        .toolbar { toolbarContent }
        .fileImporter(isPresented: $choosingFolder, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result {
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
                    .foregroundStyle(isRuleEnabled(rule) ? Color.accentColor : Color.primary)
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
                        .italic()
                        .foregroundStyle(.secondary)
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

    private func isRuleEnabled(_ rule: FormatRule) -> Bool {
        config.isRuleEnabled(rule.name, isOptIn: rule.isOptIn)
    }

    /// Whether any rule that consumes this option is currently enabled, so the
    /// option is actually in effect.
    private func isOptionActive(_ option: FormatOption) -> Bool {
        OptionRuleUsage.rules(forOptionKey: option.key).contains { name in
            guard let rule = catalog.catalog?.rule(named: name) else { return false }
            return config.isRuleEnabled(rule.name, isOptIn: rule.isOptIn)
        }
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
                    OptionRow(option: option, config: config, isActive: isOptionActive(option))
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
}
