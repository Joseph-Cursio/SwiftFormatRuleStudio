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
    @State private var folderURL: URL?
    @State private var optionSearch = ""
    @State private var choosingFolder = false
    @State private var showOnlySet = false

    var body: some View {
        Group {
            if folderURL == nil {
                chooseFolderPrompt
            } else {
                VStack(spacing: 0) {
                    folderHeader
                    Divider()
                    HSplitView {
                        optionsPanel
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
                folderURL = url
                config.load(from: url.appendingPathComponent(".swiftformat"))
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
                Label(folderURL?.lastPathComponent ?? "Choose Folder…", systemImage: "folder")
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
            .disabled(folderURL == nil)

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
            Text(folderURL?.lastPathComponent ?? "")
                .font(.headline)
            Text(".swiftformat")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
            if config.isDirty {
                Text("• Unsaved")
                    .font(.caption.weight(.semibold))
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

    // MARK: - Options panel

    private var optionsPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("Options")
                    .font(.headline)
                Text("\(setCount) set · \(catalog.options.count) total")
                    .font(.caption)
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
        .frame(minWidth: 360, maxHeight: .infinity)
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
                    .font(.headline)
                Spacer()
                if let error = config.lastError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.caption)
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
                    .font(.system(.body, design: .monospaced))
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
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            if let usedByText {
                Text(usedByText)
                    .font(.caption2)
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
            Toggle("", isOn: boolBinding).labelsHidden()
        case .enumeration:
            Picker("", selection: stringBinding) {
                ForEach(option.allowedValues, id: \.self) { value in
                    Text(value).tag(value)
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

    /// Effective value (set value, else default) — used by controls that always
    /// show a value (toggle, picker).
    private var effectiveValue: String {
        config.config.options[option.key] ?? option.defaultValue ?? ""
    }

    /// Text-field binding: shows the set value, or empty (so the default shows
    /// as placeholder). Writing the default or empty clears the override.
    private var textBinding: Binding<String> {
        Binding(
            get: { config.config.options[option.key] ?? "" },
            set: { writeValue($0) }
        )
    }

    private var stringBinding: Binding<String> {
        Binding(
            get: { effectiveValue },
            set: { writeValue($0) }
        )
    }

    private func writeValue(_ newValue: String) {
        let trimmed = newValue.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed == option.defaultValue {
            config.removeOption(key: option.key) // back to default → keep config minimal
        } else {
            config.setOption(key: option.key, value: trimmed)
        }
    }

    private var boolBinding: Binding<Bool> {
        Binding(
            get: { effectiveValue == "true" },
            set: { writeValue($0 ? "true" : "false") }
        )
    }
}
