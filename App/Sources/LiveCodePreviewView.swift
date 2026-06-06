//
//  LiveCodePreviewView.swift
//  SwiftFormatRuleStudio
//

import SwiftFormatRuleStudioCore
import SwiftUI

/// The headline feature: edit Swift on the left, watch it reformat (as a colored
/// diff) on the right, live. Thin wrapper over the tested `LivePreviewModel`.
struct LiveCodePreviewView: View {
    @Environment(ConfigModel.self) private var config
    @Environment(RuleStudioModel.self) private var catalog
    @Environment(WorkspaceModel.self) private var workspace
    @Environment(\.uiTextScale) private var uiTextScale
    @State private var model = LivePreviewModel(source: Self.sampleSource)

    /// Swift files discovered under the selected project folder (flat).
    @State private var projectFiles: [URL] = []
    /// The same files arranged as a directory tree for the outline view.
    @State private var fileTree: [FileNode] = []
    /// The outline/list row currently highlighted (a file or a directory).
    @State private var listSelection: URL?
    /// The file currently loaded into the editor, if any (drives the header).
    @State private var selectedFile: URL?
    /// Filter text for the file list.
    @State private var fileFilter = ""
    /// Path of the last file opened in the Scratchpad, persisted across launches
    /// and restored when its project is reopened.
    @AppStorage("scratchpadLastFilePath") private var savedFilePath = ""
    /// Newline-joined paths of expanded directories in the file tree, persisted so
    /// the tree reopens to the same shape.
    @AppStorage("scratchpadExpandedDirs") private var expandedDirsRaw = ""

    var body: some View {
        HSplitView {
            if workspace.selectedFolder != nil {
                fileList
                    .frame(minWidth: 200, idealWidth: 250)
            }
            VSplitView {
                editor
                    .frame(minHeight: 120)
                changesList
                    .frame(minHeight: 100)
            }
            result
        }
        .task {
            model.producesChangeList = true
            model.extraArguments = config.commandLineArguments
            await model.formatNow()
        }
        .onChange(of: config.commandLineArguments) { _, newArguments in
            model.extraArguments = newArguments
            model.scheduleFormat()
        }
        // Rebuild the file list for the selected project, then restore the
        // remembered file (or clear the selection if it isn't in this project).
        .task(id: workspace.selectedFolder) { await loadProjectFiles() }
        .navigationTitle("Scratchpad")
    }

    // MARK: - Project files

    private var fileList: some View {
        VStack(alignment: .leading, spacing: 0) {
            paneHeader("Project files", systemImage: "folder")
            Divider()
            TextField("Filter", text: $fileFilter)
                .textFieldStyle(.roundedBorder)
                .padding(8)
            if projectFiles.isEmpty {
                Text("No Swift files in this folder.")
                    .scaledFont(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else if isFiltering {
                // While filtering, a flat list of matches (with full paths) reads
                // better than a tree of half-expanded directories.
                List(filteredFiles, id: \.self, selection: $listSelection) { url in
                    Label(relativePath(url), systemImage: "swift")
                        .scaledFont(.callout, design: .monospaced)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .listStyle(.sidebar)
            } else {
                List(selection: $listSelection) {
                    ForEach(fileTree) { node in
                        FileRow(node: node) { expansionBinding(for: $0) }
                    }
                }
                .listStyle(.sidebar)
            }
        }
        // Loading only makes sense for file rows; directory rows just expand.
        .onChange(of: listSelection) { _, url in
            guard let url, Set(projectFiles).contains(url) else { return }
            selectedFile = url
            loadFile(url)
        }
    }

    private var isFiltering: Bool {
        !fileFilter.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var filteredFiles: [URL] {
        let query = fileFilter.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return projectFiles }
        return projectFiles.filter { relativePath($0).lowercased().contains(query) }
    }

    /// Path relative to the project folder, e.g. `Sources/App/Foo.swift`.
    private func relativePath(_ url: URL) -> String {
        guard let base = workspace.selectedFolder?.path, url.path.hasPrefix(base + "/") else {
            return url.lastPathComponent
        }
        return String(url.path.dropFirst(base.count + 1))
    }

    /// Loads a file's contents as the editor's "before" source and reformats.
    /// Passing the real path via `--stdin-path` lets path-dependent rules (e.g.
    /// `fileHeader`) behave as they would in place.
    private func loadFile(_ url: URL) {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        model.stdinPath = url.path
        model.source = text
        model.scheduleFormat()
        savedFilePath = url.path // remember across launches
    }

    private func loadProjectFiles() async {
        guard let folder = workspace.selectedFolder else {
            projectFiles = []
            fileTree = []
            clearFileSelection()
            return
        }
        let files = await Self.swiftFiles(in: folder)
        projectFiles = files
        fileTree = Self.tree(from: files, root: folder)

        // Reopen the remembered file if it belongs to this project; otherwise drop
        // any stale selection. Load directly (not via the listSelection onChange,
        // which isn't armed yet at first appearance).
        if let remembered = files.first(where: { $0.path == savedFilePath }) {
            listSelection = remembered
            selectedFile = remembered
            loadFile(remembered)
        } else {
            clearFileSelection()
        }
    }

    /// Returns the editor to the editable, no-file state.
    private func clearFileSelection() {
        listSelection = nil
        selectedFile = nil
        model.stdinPath = nil
    }

    /// The set of expanded directory paths (decoded from the persisted string).
    private var expandedSet: Set<String> {
        Set(expandedDirsRaw.split(separator: "\n").map(String.init))
    }

    /// A persisted expand/collapse binding for one directory's path.
    private func expansionBinding(for path: String) -> Binding<Bool> {
        Binding(
            get: { expandedSet.contains(path) },
            set: { isOpen in
                var set = expandedSet
                if isOpen { set.insert(path) } else { set.remove(path) }
                expandedDirsRaw = set.sorted().joined(separator: "\n")
            }
        )
    }

    /// Enumerates `.swift` files under `folder`, skipping hidden dirs (`.build`,
    /// `.git`) and package bundles — the same set SwiftFormat would scan. Runs off
    /// the main actor since large trees take a moment to walk.
    private static func swiftFiles(in folder: URL) async -> [URL] {
        await Task.detached(priority: .utility) {
            let manager = FileManager.default
            guard let enumerator = manager.enumerator(
                at: folder,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { return [] }
            var found: [URL] = []
            while let url = enumerator.nextObject() as? URL {
                if url.pathExtension == "swift" { found.append(url) }
            }
            return found.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
        }.value
    }

    /// Builds a directory tree from the flat file list. Directory nodes are
    /// synthesized for grouping; leaf nodes keep the file's real URL so loading
    /// reads the exact file SwiftFormat enumerated.
    private static func tree(from files: [URL], root: URL) -> [FileNode] {
        let entries = files.map { url -> (components: [String], url: URL) in
            let path = url.path
            let relative = path.hasPrefix(root.path + "/")
                ? String(path.dropFirst(root.path.count + 1))
                : url.lastPathComponent
            return (relative.split(separator: "/").map(String.init), url)
        }
        return nodes(entries: entries, prefix: root)
    }

    private static func nodes(
        entries: [(components: [String], url: URL)],
        prefix: URL
    ) -> [FileNode] {
        var dirOrder: [String] = []
        var dirGroups: [String: [(components: [String], url: URL)]] = [:]
        var leaves: [(name: String, url: URL)] = []

        for entry in entries {
            guard let first = entry.components.first else { continue }
            if entry.components.count == 1 {
                leaves.append((first, entry.url))
            } else {
                if dirGroups[first] == nil { dirGroups[first] = []; dirOrder.append(first) }
                dirGroups[first]?.append((Array(entry.components.dropFirst()), entry.url))
            }
        }

        // Directories first, then files — each sorted naturally.
        var result: [FileNode] = []
        for name in dirOrder.sorted(by: { $0.localizedStandardCompare($1) == .orderedAscending }) {
            let dirURL = prefix.appendingPathComponent(name, isDirectory: true)
            result.append(FileNode(
                url: dirURL,
                name: name,
                children: nodes(entries: dirGroups[name] ?? [], prefix: dirURL)
            ))
        }
        for leaf in leaves.sorted(by: { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) {
            result.append(FileNode(url: leaf.url, name: leaf.name, children: nil))
        }
        return result
    }

    // MARK: - Editor

    private var editor: some View {
        VStack(alignment: .leading, spacing: 0) {
            paneHeader(
                selectedFile.map(relativePath) ?? "Enter your own source",
                systemImage: selectedFile == nil ? "pencil.line" : "doc.text"
            )
            Divider()
            if selectedFile == nil {
                // No file loaded: an editable scratchpad.
                CodeTextEditor(text: $model.source, fontSize: 13 * uiTextScale)
                    .onChange(of: model.source) {
                        model.scheduleFormat()
                    }
            } else {
                // A loaded project file: read-only, syntax-highlighted, with line
                // numbers like the editable editor (no editable-field background).
                readOnlyCode(model.source, showsLineNumbers: true)
            }
        }
        .frame(minWidth: 300)
    }

    // MARK: - Changes (which rule changed which line)

    private var changesList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                paneHeader("SwiftFormat rules triggered", systemImage: "list.bullet.rectangle")
                Spacer()
                if !model.changes.isEmpty {
                    Text(rulesSummary)
                        .scaledFont(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 10)
                }
            }
            Divider()
            if model.changes.isEmpty {
                Text("No changes — your code already matches the current rules.")
                    .scaledFont(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                List(Array(model.changes.enumerated()), id: \.offset) { _, change in
                    changeRow(change)
                }
                .listStyle(.plain)
            }
        }
        .frame(minWidth: 300)
        .textSelection(.enabled)
    }

    /// e.g. "5 rules · 11 occurrences" — distinct rules vs total occurrences.
    private var rulesSummary: String {
        let occurrences = model.changes.count
        let rules = Set(model.changes.map(\.ruleID)).count
        return "\(rules) rule\(rules == 1 ? "" : "s") · "
            + "\(occurrences) occurrence\(occurrences == 1 ? "" : "s")"
    }

    /// The options that tune a rule, each as `--flag = value` (the value being the
    /// config override or SwiftFormat's default) — shown under each triggered rule
    /// so it's clear which knobs governed the change.
    private func optionLines(for ruleID: String) -> [String] {
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

    private func changeRow(_ change: LintFinding) -> some View {
        // Gutter geometry matches CodeTextEditor's ruler: a 40pt-wide column
        // (number right-aligned with a 4pt trailing margin) then the divider.
        HStack(alignment: .top, spacing: 0) {
            Text("\(change.line)")
                .scaledFont(.subheadline, design: .monospaced)
                .monospacedDigit()
                .foregroundStyle(.tertiary)
                .frame(width: 36, alignment: .trailing)
                .padding(.trailing, 4)
            Divider()
            VStack(alignment: .leading, spacing: 1) {
                Text(change.ruleID)
                    .scaledFont(.body, design: .monospaced)
                let options = optionLines(for: change.ruleID)
                if options.isEmpty {
                    Text("No options")
                        .scaledFont(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(options, id: \.self) { line in
                        Text(line)
                            .scaledFont(.caption, design: .monospaced)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.leading, 8)
        }
        .padding(.vertical, 2)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 8))
        .listRowSeparator(.hidden)
    }

    // MARK: - Result

    private var result: some View {
        VSplitView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    paneHeader("Diff", systemImage: "plusminus")
                    Spacer()
                    statusLabel
                        .padding(.trailing, 10)
                }
                Divider()
                resultBody
            }
            .frame(minHeight: 100)

            VStack(alignment: .leading, spacing: 0) {
                paneHeader("Formatted output", systemImage: "wand.and.stars")
                Divider()
                formattedOutput
            }
            .frame(minHeight: 100)
        }
        .frame(minWidth: 300)
    }

    /// The clean formatted result (no diff markers), syntax-highlighted.
    @ViewBuilder
    private var formattedOutput: some View {
        readOnlyCode(model.formattedSource)
    }

    /// A read-only, syntax-highlighted rendering of Swift source. Used for the
    /// formatted output and for a loaded project file (which shouldn't be edited).
    /// `showsLineNumbers` adds a gutter, matching the editable editor.
    @ViewBuilder
    private func readOnlyCode(_ source: String, showsLineNumbers: Bool = false) -> some View {
        let lines = source.components(separatedBy: "\n")
        let gutterWidth = CGFloat(String(max(lines.count, 1)).count) * 9 + 6
        GeometryReader { geometry in
            ScrollView([.vertical, .horizontal]) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        HStack(alignment: .top, spacing: 8) {
                            if showsLineNumbers {
                                Text("\(index + 1)")
                                    .scaledFont(.body, design: .monospaced)
                                    .monospacedDigit()
                                    .foregroundStyle(.tertiary)
                                    .frame(width: gutterWidth, alignment: .trailing)
                            }
                            Text(SwiftCodeColor.attributed(line))
                                .scaledFont(.body, design: .monospaced)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                    }
                }
                .padding(.vertical, 4)
                .frame(minWidth: geometry.size.width, minHeight: geometry.size.height, alignment: .topLeading)
            }
        }
        .textSelection(.enabled)
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch model.state {
        case .idle:
            EmptyView()
        case .formatting:
            ProgressView().controlSize(.small)
        case .formatted:
            Text(model.hasChanges ? changeSummary : "No changes")
                .scaledFont(.caption)
                .foregroundStyle(.secondary)
        case .failed:
            Label("Error", systemImage: "exclamationmark.triangle")
                .scaledFont(.caption)
                .foregroundStyle(.red)
        }
    }

    private var addedCount: Int { model.diff.filter { $0.change == .added }.count }
    private var removedCount: Int { model.diff.filter { $0.change == .removed }.count }

    /// e.g. "11 line changes: 6 insertions + 5 deletions".
    private var changeSummary: String {
        let total = addedCount + removedCount
        return "\(total) line \(total == 1 ? "change" : "changes"): "
            + "\(addedCount) insertion\(addedCount == 1 ? "" : "s") + "
            + "\(removedCount) deletion\(removedCount == 1 ? "" : "s")"
    }

    @ViewBuilder
    private var resultBody: some View {
        switch model.state {
        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn’t format", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            }
        default:
            if model.hasChanges {
                PreviewDiffView(lines: model.diff)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else if model.state == .formatted {
                ContentUnavailableView(
                    "Already formatted",
                    systemImage: "checkmark.seal",
                    description: Text("This code already matches the current formatting rules.")
                )
            } else {
                Color.clear
            }
        }
    }

    private func paneHeader(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .scaledFont(.headline, weight: .semibold)
            .padding(8)
    }

    static let sampleSource = """
    struct  Foo{
        let x=1
        let y =  2

        func bar( ) ->Int {
            return  x+y
        }
    }
    """
}

/// A node in the project file outline: a directory (with `children`) or a file
/// leaf (`children == nil`). Leaves carry the file's real URL.
private struct FileNode: Identifiable, Hashable {
    let url: URL
    let name: String
    let children: [FileNode]?
    var id: URL { url }
    var isDirectory: Bool { children != nil }
}

/// One outline row, recursive over its children. Directories are `DisclosureGroup`s
/// whose expansion is persisted via `expansion(path)`; files are selectable leaves
/// (tagged by URL for the enclosing `List`'s selection).
private struct FileRow: View {
    let node: FileNode
    let expansion: (String) -> Binding<Bool>

    var body: some View {
        if let children = node.children {
            DisclosureGroup(isExpanded: expansion(node.url.path)) {
                ForEach(children) { child in
                    FileRow(node: child, expansion: expansion)
                }
            } label: {
                Label(node.name, systemImage: "folder")
                    .scaledFont(.callout, design: .monospaced)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        } else {
            Label(node.name, systemImage: "swift")
                .scaledFont(.callout, design: .monospaced)
                .lineLimit(1)
                .truncationMode(.middle)
                .tag(node.url)
        }
    }
}

/// Renders `[PreviewDiffLine]` as a colored unified diff.
struct PreviewDiffView: View {
    let lines: [PreviewDiffLine]

    var body: some View {
        // GeometryReader + minWidth/minHeight pins content to the top-left: a 2D
        // ScrollView otherwise centers content smaller than its viewport.
        GeometryReader { geometry in
            ScrollView([.vertical, .horizontal]) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(lines) { line in
                        HStack(alignment: .top, spacing: 8) {
                            Text(symbol(for: line.change))
                                .frame(width: 10, alignment: .leading)
                            Text(line.text.isEmpty ? " " : line.text)
                        }
                        .scaledFont(.body, design: .monospaced)
                        .foregroundStyle(foreground(for: line.change))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 1)
                        .background(background(for: line.change))
                    }
                }
                .padding(.vertical, 4)
                .frame(minWidth: geometry.size.width, minHeight: geometry.size.height, alignment: .topLeading)
            }
        }
    }

    private func symbol(for change: PreviewDiffLine.Change) -> String {
        switch change {
        case .added: "+"
        case .removed: "-"
        case .unchanged: " "
        }
    }

    private func foreground(for change: PreviewDiffLine.Change) -> Color {
        switch change {
        case .added: .green
        case .removed: .red
        case .unchanged: .primary
        }
    }

    private func background(for change: PreviewDiffLine.Change) -> Color {
        switch change {
        case .added: Color.green.opacity(0.12)
        case .removed: Color.red.opacity(0.12)
        case .unchanged: .clear
        }
    }
}
