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
                    FolderHeader(
                        folderName: workspace.selectedFolder?.lastPathComponent ?? "",
                        isScanning: model.state == .running
                    )
                    Divider()
                    content
                }
            }
        }
            .navigationTitle("Impact")
            .toolbar { toolbarContent }
            .fileImporter(isPresented: $choosingFolder, allowedContentTypes: [.folder]) { result in
                if case .success(let url) = result {
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
                ruleList(report)
            }
        }
    }

    private func ruleList(_ report: ImpactReport) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(report.ruleImpacts) { impact in
                        ruleRow(impact, in: report)
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

    private func ruleRow(_ impact: RuleImpact, in report: ImpactReport) -> some View {
        RuleImpactRow(
            impact: impact,
            maxFileCount: report.ruleImpacts.first?.fileCount ?? 1,
            rule: rule(for: impact),
            optionLines: optionLines(for: impact),
            scanRoot: model.scannedPath,
            isExpanded: ruleExpansion(impact.ruleID),
            fileExpansion: { fileExpansion(impact.ruleID, $0) },
            loadDiff: { ruleID, filePath in
                await model.ruleDiff(ruleID: ruleID, filePath: filePath)
            },
            onOpenInPreview: { file in
                workspace.openInPreview(
                    URL(fileURLWithPath: file.filePath),
                    from: .impact(ruleID: impact.ruleID, filePath: file.filePath)
                )
            }
        )
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
