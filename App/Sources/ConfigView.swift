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

    var body: some View {
        Group {
            if folderURL == nil {
                chooseFolderPrompt
            } else {
                HSplitView {
                    optionsPanel
                    diffPanel
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
            Button("Revert") { config.revert() }
                .disabled(config.isDirty == false)
            Button("Save") { config.save() }
                .keyboardShortcut("s")
                .disabled(config.canSave == false)
        }
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
        List {
            ForEach(filteredOptions) { option in
                OptionRow(option: option, config: config)
            }
        }
        .searchable(text: $optionSearch, prompt: "Search options")
        .frame(minWidth: 360)
    }

    private var filteredOptions: [FormatOption] {
        let query = optionSearch.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return catalog.options }
        return catalog.options.filter {
            ($0.name + " " + $0.summary).lowercased().contains(query)
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
        .frame(minWidth: 320)
    }
}

/// One option, rendered with the right control for its inferred kind.
private struct OptionRow: View {
    let option: FormatOption
    @Bindable var config: ConfigModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(option.name)
                    .font(.system(.body, design: .monospaced))
                Spacer()
                editor
            }
            Text(option.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 2)
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
            .frame(maxWidth: 160)
        case .integer, .list, .string:
            TextField(option.defaultValue ?? "", text: stringBinding)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 160)
        }
    }

    private var currentValue: String {
        config.config.options[option.key] ?? option.defaultValue ?? ""
    }

    private var stringBinding: Binding<String> {
        Binding(
            get: { currentValue },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty || trimmed == option.defaultValue {
                    config.removeOption(key: option.key) // back to default → keep config minimal
                } else {
                    config.setOption(key: option.key, value: trimmed)
                }
            }
        )
    }

    private var boolBinding: Binding<Bool> {
        Binding(
            get: { currentValue == "true" },
            set: { isOn in
                let value = isOn ? "true" : "false"
                if value == option.defaultValue {
                    config.removeOption(key: option.key)
                } else {
                    config.setOption(key: option.key, value: value)
                }
            }
        )
    }
}
