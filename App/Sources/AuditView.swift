//
//  AuditView.swift
//  SwiftFormatRuleStudio
//

import SwiftFormatRuleStudioCore
import SwiftUI
import UniformTypeIdentifiers

/// The impact audit (M5): pick a folder, run `swiftformat --lint` over it, and
/// see which rules would change the most code. Thin binding over the tested
/// `ImpactAuditModel`; reflects the active config.
struct AuditView: View {
    @Environment(RuleStudioModel.self) private var catalog
    @Environment(ConfigModel.self) private var config
    @State private var model = ImpactAuditModel()
    @State private var folderURL: URL?
    @State private var choosingFolder = false
    @State private var exportDocument: TextExportDocument?
    @State private var exportFormat: AuditExportFormat = .csv
    @State private var showingExporter = false

    var body: some View {
        Group {
            if folderURL == nil {
                content
            } else {
                VStack(spacing: 0) {
                    folderHeader
                    Divider()
                    content
                }
            }
        }
            .navigationTitle("Impact Audit")
            .toolbar { toolbarContent }
            .fileImporter(isPresented: $choosingFolder, allowedContentTypes: [.folder]) { result in
                if case .success(let url) = result {
                    _ = url.startAccessingSecurityScopedResource()
                    folderURL = url
                    Task { await runAudit(url) }
                }
            }
            .fileExporter(
                isPresented: $showingExporter,
                document: exportDocument,
                contentType: exportFormat == .csv ? .commaSeparatedText : .html,
                defaultFilename: "swiftformat-impact"
            ) { _ in }
    }

    private func export(as format: AuditExportFormat) {
        guard let report = model.report else { return }
        let stamp = Date.now.formatted(date: .abbreviated, time: .shortened)
        let text = ImpactReportExporter.export(
            report,
            as: format,
            workspaceName: folderURL?.lastPathComponent ?? "Project",
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
            Text(folderURL?.lastPathComponent ?? "")
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
                Label("Audit a project", systemImage: "chart.bar.doc.horizontal")
            } description: {
                Text("Choose a folder to see how much each rule would change.")
            } actions: {
                Button("Choose Folder…") { choosingFolder = true }
            }
        case .running:
            ProgressView("Auditing…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ContentUnavailableView {
                Label("Audit failed", systemImage: "exclamationmark.triangle")
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
                Label(folderURL?.lastPathComponent ?? "Choose Folder…", systemImage: "folder")
            }
        }
        ToolbarItemGroup {
            Menu {
                ForEach(AuditExportFormat.allCases) { format in
                    Button("Export \(format.displayName)…") { export(as: format) }
                }
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .disabled(model.report?.isClean ?? true)

            Button("Re-run") {
                if let folderURL {
                    Task { await runAudit(folderURL) }
                }
            }
            .disabled(folderURL == nil || model.state == .running)
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
                List(report.ruleImpacts) { impact in
                    ImpactRow(
                        impact: impact,
                        maxFileCount: report.ruleImpacts.first?.fileCount ?? 1,
                        rule: rule(for: impact)
                    )
                }
            }
        }
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

    private func runAudit(_ url: URL) async {
        model.extraArguments = config.commandLineArguments
        await model.runAudit(path: url)
    }
}

/// One rule's impact row: name, category, an impact bar, and counts.
struct ImpactRow: View {
    let impact: RuleImpact
    let maxFileCount: Int
    let rule: FormatRule?

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
