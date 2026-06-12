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
                PreviewChangesView(model: model, selectedFile: selectedFile)
                    .frame(minHeight: 100)
            }
            PreviewResultView(model: model)
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
        // A cross-link from the Impact tab can request a file; open it once the
        // file list is loaded (consumePreviewRequest no-ops until it matches).
        .onChange(of: workspace.previewRequest) { _, _ in consumePreviewRequest() }
        .navigationTitle("Preview")
    }

    // MARK: - Project files

    private var fileList: some View {
        VStack(alignment: .leading, spacing: 0) {
            previewPaneHeader("Project files", systemImage: "folder")
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
        workspace.currentPreviewFile = url // let the Rules tab target this file
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

        // A pending cross-link from Impact wins over the remembered file. Otherwise
        // reopen the remembered file if it belongs to this project, or drop any
        // stale selection. Load directly (not via the listSelection onChange, which
        // isn't armed yet at first appearance).
        if consumePreviewRequest() {
            return
        }
        if let remembered = files.first(where: { $0.path == savedFilePath }) {
            listSelection = remembered
            selectedFile = remembered
            loadFile(remembered)
        } else {
            clearFileSelection()
        }
    }

    /// Opens the file requested by the Impact cross-link, if one is pending and
    /// present in this project, then clears the request. Returns whether it opened
    /// a file. No-ops (leaving the request intact) until the file list is loaded.
    @discardableResult
    private func consumePreviewRequest() -> Bool {
        guard let requested = workspace.previewRequest,
              let match = projectFiles.first(where: { $0.path == requested.path }) else { return false }
        listSelection = match
        selectedFile = match
        loadFile(match)
        workspace.previewRequest = nil
        return true
    }

    /// Returns the editor to the editable, no-file state.
    private func clearFileSelection() {
        listSelection = nil
        selectedFile = nil
        model.stdinPath = nil
        workspace.currentPreviewFile = nil
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
            previewPaneHeader(
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
                previewReadOnlyCode(model.source, showsLineNumbers: true)
            }
        }
        .frame(minWidth: 300)
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
