//
//  ImpactView.swift
//  SwiftFormatRuleStudio
//

import SwiftFormatRuleStudioCore
import SwiftUI
import UniformTypeIdentifiers

/// The impact scan (M5): pick a folder, run `swiftformat --lint` over it, and
/// see which rules would change the most code. Thin binding over the tested
/// `ImpactModel`; reflects the active config.
struct ImpactView: View {
    @Environment(RuleStudioModel.self) private var catalog
    @Environment(ConfigModel.self) private var config
    @Environment(WorkspaceModel.self) private var workspace
    @Environment(ImpactModel.self) private var model
    @State private var choosingFolder = false
    @State private var exportDocument: TextExportDocument?
    @State private var exportFormat: ImpactExportFormat = .csv
    @State private var showingExporter = false
    /// Which rule rows are expanded. Owned here (not in the rows) so Back can
    /// re-expand a rule and scroll to it.
    @State private var expandedRules: Set<String> = []
    /// Which file rows are expanded, keyed by `fileKey(rule, path)`.
    @State private var expandedFiles: Set<String> = []

    var body: some View {
        Group {
            if workspace.selectedFolder == nil {
                content
            } else {
                VStack(spacing: 0) {
                    folderHeader
                    Divider()
                    content
                }
            }
        }
            .navigationTitle("Impact")
            .toolbar { toolbarContent }
            .fileImporter(isPresented: $choosingFolder, allowedContentTypes: [.folder]) { result in
                if case .success(let url) = result {
                    _ = url.startAccessingSecurityScopedResource()
                    workspace.open(url)
                }
            }
            .fileExporter(
                isPresented: $showingExporter,
                document: exportDocument,
                contentType: exportFormat == .csv ? .commaSeparatedText : .html,
                defaultFilename: "swiftformat-impact"
            ) { _ in }
    }

    private func export(as format: ImpactExportFormat) {
        guard let report = model.report else { return }
        let stamp = Date.now.formatted(date: .abbreviated, time: .shortened)
        let text = ImpactReportExporter.export(
            report,
            as: format,
            workspaceName: workspace.selectedFolder?.lastPathComponent ?? "Project",
            timestamp: stamp
        )
        exportFormat = format
        exportDocument = TextExportDocument(text: text)
        showingExporter = true
    }

    // MARK: - Folder header

    /// Mirrors the Config tab: once a project is chosen, keep its name visible at
    /// the top of the pane (the toolbar button alone is easy to miss).
    private var folderHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.fill")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(workspace.selectedFolder?.lastPathComponent ?? "")
                .scaledFont(.headline, weight: .semibold)
            if model.state == .running {
                ProgressView().controlSize(.small)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .idle:
            ContentUnavailableView {
                Label("Scan a project", systemImage: "chart.bar.doc.horizontal")
            } description: {
                Text("Choose a folder to see how much each rule would change.")
            } actions: {
                Button("Choose Folder…") { choosingFolder = true }
            }
        case .running:
            ProgressView("Scanning…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ContentUnavailableView {
                Label("Scan failed", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            }
        case .completed:
            if let report = model.report {
                reportView(report)
            }
        }
    }

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
                ForEach(ImpactExportFormat.allCases) { format in
                    Button("Export \(format.displayName)…") { export(as: format) }
                }
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .disabled(model.report?.isClean ?? true)

            Button("Re-run") {
                if let folder = workspace.selectedFolder {
                    Task { await runScan(folder) }
                }
            }
            .disabled(workspace.selectedFolder == nil || model.state == .running)
        }
    }

    private func reportView(_ report: ImpactReport) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            summary(report)
            Divider()
            if report.isClean {
                ContentUnavailableView(
                    "Already formatted",
                    systemImage: "checkmark.seal",
                    description: Text("No rule would change anything in this project.")
                )
            } else {
                // A ScrollView + LazyVStack (not a List): the drill-down diff uses a
                // nested horizontal ScrollView, which a List's NSTableView backing
                // would stop the wheel from scrolling past. This matches the Rules
                // tab, where the same diff view nests in a vertical ScrollView.
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(report.ruleImpacts) { impact in
                                RuleImpactRow(
                                    impact: impact,
                                    maxFileCount: report.ruleImpacts.first?.fileCount ?? 1,
                                    rule: rule(for: impact),
                                    optionLines: optionLines(for: impact),
                                    scanRoot: model.scannedPath,
                                    isExpanded: ruleExpansion(impact.ruleID),
                                    fileExpansion: { fileExpansion(impact.ruleID, $0) }
                                )
                                .id(impact.ruleID)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 4)
                                Divider()
                            }
                        }
                    }
                    // Back lands here: re-expand the rule (and file) and scroll to it.
                    .onChange(of: workspace.impactRestore) { _, target in
                        restore(target, proxy: proxy)
                    }
                    .task { restore(workspace.impactRestore, proxy: proxy) }
                }
            }
        }
    }

    /// Expand/scroll to the rule (and optional file) the Back navigation targeted,
    /// then clear the request.
    private func restore(_ target: WorkspaceModel.ImpactTarget?, proxy: ScrollViewProxy) {
        guard let target else { return }
        expandedRules.insert(target.ruleID)
        if let filePath = target.filePath {
            expandedFiles.insert(fileKey(target.ruleID, filePath))
        }
        proxy.scrollTo(target.ruleID, anchor: .top)
        workspace.impactRestore = nil
    }

    /// Stable key for a file row's expansion within a given rule.
    private func fileKey(_ ruleID: String, _ filePath: String) -> String {
        "\(ruleID)\u{0}\(filePath)"
    }

    private func ruleExpansion(_ ruleID: String) -> Binding<Bool> {
        Binding(
            get: { expandedRules.contains(ruleID) },
            set: { isOpen in
                if isOpen { expandedRules.insert(ruleID) } else { expandedRules.remove(ruleID) }
            }
        )
    }

    private func fileExpansion(_ ruleID: String, _ filePath: String) -> Binding<Bool> {
        let key = fileKey(ruleID, filePath)
        return Binding(
            get: { expandedFiles.contains(key) },
            set: { isOpen in
                if isOpen { expandedFiles.insert(key) } else { expandedFiles.remove(key) }
            }
        )
    }

    private func summary(_ report: ImpactReport) -> some View {
        HStack(spacing: 24) {
            stat("\(report.ruleImpacts.count)", "triggered rules")
            stat("\(enabledRuleCount)", "enabled rules")
            stat("\(disabledRuleCount)", "disabled rules")
            stat("\(report.filesAffected)", "files affected")
            stat("\(report.filesChecked)", "files checked")
            stat("\(report.totalFindings)", "findings")
            Spacer()
        }
        .padding(12)
    }

    /// Rules that would run under the active config (default-on minus disables,
    /// plus any explicitly enabled opt-in rules).
    private var enabledRuleCount: Int {
        guard let rules = catalog.catalog?.rules else { return 0 }
        return rules.count { config.isRuleEnabled($0.name, isOptIn: $0.isOptIn) }
    }

    private var disabledRuleCount: Int {
        guard let rules = catalog.catalog?.rules else { return 0 }
        return rules.count - enabledRuleCount
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).scaledFont(.title2, weight: .bold)
            Text(label).scaledFont(.caption).foregroundStyle(.secondary)
        }
    }

    private func rule(for impact: RuleImpact) -> FormatRule? {
        catalog.catalog?.rule(named: impact.ruleID)
    }

    private func optionLines(for impact: RuleImpact) -> [String] {
        ruleOptionLines(forRule: impact.ruleID, catalog: catalog, config: config)
    }

    private func runScan(_ url: URL) async {
        model.extraArguments = config.commandLineArguments
        await model.runScan(path: url)
    }
}

/// A rule's row in the Impact tab, expandable to the files it would change (each of
/// which expands to its before/after diff). The collapsed label is `ImpactRow`.
struct RuleImpactRow: View {
    let impact: RuleImpact
    let maxFileCount: Int
    let rule: FormatRule?
    let optionLines: [String]
    let scanRoot: URL?
    @Binding var isExpanded: Bool
    /// Supplies the expansion binding for a given file path under this rule.
    let fileExpansion: (String) -> Binding<Bool>

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(impact.files) { file in
                FileImpactRow(
                    ruleID: impact.ruleID,
                    file: file,
                    scanRoot: scanRoot,
                    isExpanded: fileExpansion(file.filePath)
                )
            }
        } label: {
            ImpactRow(impact: impact, maxFileCount: maxFileCount, rule: rule, optionLines: optionLines)
        }
    }
}

/// One affected file under a rule, expandable to the rule's before/after diff for
/// that file. The diff is loaded lazily (and cached by the model) on first expand.
struct FileImpactRow: View {
    @Environment(ImpactModel.self) private var model
    @Environment(WorkspaceModel.self) private var workspace
    let ruleID: String
    let file: FileImpact
    let scanRoot: URL?
    @Binding var isExpanded: Bool
    @State private var diff: [PreviewDiffLine]?
    @State private var loading = false

    /// File path relative to the scanned folder, for a compact label.
    private var displayPath: String {
        guard let root = scanRoot?.path else { return file.filePath }
        let prefix = root.hasSuffix("/") ? root : root + "/"
        return file.filePath.hasPrefix(prefix) ? String(file.filePath.dropFirst(prefix.count)) : file.filePath
    }

    private var countText: String {
        "\(file.findingCount) finding\(file.findingCount == 1 ? "" : "s")"
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            diffContent
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "swift").foregroundStyle(.secondary).accessibilityHidden(true)
                Text(displayPath)
                    .scaledFont(.callout, design: .monospaced)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Text(countText)
                    .scaledFont(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Button {
                    workspace.openInPreview(
                        URL(fileURLWithPath: file.filePath),
                        from: .impact(ruleID: ruleID, filePath: file.filePath)
                    )
                } label: {
                    Image(systemName: "wand.and.stars")
                }
                .buttonStyle(.borderless)
                .help("Open in Preview")
                .accessibilityLabel("Open \(displayPath) in Preview")
            }
        }
        // Load on user expand, and on appear when restored already-expanded (the
        // initial value doesn't fire onChange). load() guards against re-running.
        .onChange(of: isExpanded) { _, open in
            if open { Task { await load() } }
        }
        .task { if isExpanded { await load() } }
    }

    @ViewBuilder
    private var diffContent: some View {
        if loading {
            ProgressView().controlSize(.small).padding(.vertical, 4)
        } else if let diff, !diff.isEmpty {
            LiveDiffLinesView(lines: diff)
                .padding(.vertical, 4)
        } else if diff != nil {
            Text("This rule makes no isolated change here.")
                .scaledFont(.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 4)
        }
    }

    private func load() async {
        guard diff == nil, !loading else { return }
        loading = true
        diff = await model.ruleDiff(ruleID: ruleID, filePath: file.filePath)
        loading = false
    }
}

/// One rule's impact row: name, category, its tuning options, an impact bar, and
/// counts.
struct ImpactRow: View {
    let impact: RuleImpact
    let maxFileCount: Int
    let rule: FormatRule?
    /// `--flag = value` lines for the rule's options, or empty if it has none.
    var optionLines: [String] = []

    private var fraction: Double {
        maxFileCount > 0 ? Double(impact.fileCount) / Double(maxFileCount) : 0
    }

    private var countsText: String {
        let files = "\(impact.fileCount) file\(impact.fileCount == 1 ? "" : "s")"
        let findings = "\(impact.findingCount) finding\(impact.findingCount == 1 ? "" : "s")"
        return "\(files) · \(findings)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(impact.ruleID)
                    .scaledFont(.body, design: .monospaced)
                if let rule {
                    Text(rule.category.displayName)
                        .scaledFont(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(countsText)
                    .scaledFont(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            if !optionLines.isEmpty {
                Text(optionLines.joined(separator: "    "))
                    .scaledFont(.caption, design: .monospaced)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 3)
                    .fill(.tint)
                    .frame(width: max(4, geometry.size.width * fraction), height: 6)
            }
            .frame(height: 6)
        }
        .padding(.vertical, 3)
    }
}
