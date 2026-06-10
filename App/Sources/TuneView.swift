//
//  TuneView.swift
//  SwiftFormatRuleStudio
//

import SwiftFormatRuleStudioCore
import SwiftUI

/// The disabled-rule adoption scan (docs/audit-redesign.md, layer C — first slice).
/// Runs every currently-disabled rule over the project in isolation and splits the
/// results: **free wins** (rules that would change nothing — adopt them with one
/// click) and **needs review** (rules that would cause churn — each drills down to
/// the affected files and their before/after diffs). Thin binding over `TuneModel`.
struct TuneView: View {
    @Environment(RuleStudioModel.self) private var catalog
    @Environment(ConfigModel.self) private var config
    @Environment(WorkspaceModel.self) private var workspace
    @Environment(TuneModel.self) private var model
    /// Which churn rule rows are expanded.
    @State private var expandedRules: Set<String> = []
    /// Which file rows are expanded, keyed by `fileKey(rule, path)`.
    @State private var expandedFiles: Set<String> = []

    var body: some View {
        Group {
            if workspace.selectedFolder == nil {
                noProject
            } else {
                VStack(spacing: 0) {
                    folderHeader
                    Divider()
                    content
                }
            }
        }
        .navigationTitle("Tune")
        .toolbar { toolbarContent }
    }

    private var noProject: some View {
        ContentUnavailableView {
            Label("Tune your config", systemImage: "sparkles")
        } description: {
            Text("Open a project, then scan to find rules you can adopt with zero churn.")
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
            if case .running = model.state {
                ProgressView().controlSize(.small)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button {
                Task { await scan() }
            } label: {
                Label(model.state == .idle ? "Scan" : "Re-scan", systemImage: "sparkles")
            }
            .disabled(!canScan)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .idle:
            ContentUnavailableView {
                Label("Find free wins", systemImage: "sparkles")
            } description: {
                Text("Scan every disabled rule against this project to see which "
                    + "you could enable without changing a single line.")
            } actions: {
                Button("Scan for Free Wins") { Task { await scan() } }
                    .disabled(!canScan)
            }
        case .running(let scanned, let total):
            ProgressView(value: Double(scanned), total: Double(max(total, 1))) {
                Text("Scanning rule \(scanned) of \(total)…")
            }
            .padding(40)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        case .failed(let message):
            ContentUnavailableView {
                Label("Scan failed", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            }
        case .completed:
            results
        }
    }

    // MARK: - Results

    /// Free wins still worth showing — those not already enabled (so they drop off
    /// the list the moment they're adopted, no re-scan needed).
    private var pendingFreeWins: [RuleImpact] {
        model.freeWins.filter { !config.isRuleEnabled($0.ruleID, isOptIn: isOptIn($0.ruleID)) }
    }

    /// Churn candidates still disabled, ranked by impact.
    private var pendingChurn: [RuleImpact] {
        model.churn.filter { !config.isRuleEnabled($0.ruleID, isOptIn: isOptIn($0.ruleID)) }
    }

    @ViewBuilder
    private var results: some View {
        if pendingFreeWins.isEmpty, pendingChurn.isEmpty {
            ContentUnavailableView(
                "Nothing left to adopt",
                systemImage: "checkmark.seal",
                description: Text("Every disabled rule either changes code you'd rather "
                    + "keep, or is already enabled.")
            )
        } else {
            VStack(alignment: .leading, spacing: 0) {
                summary
                Divider()
                // Plain ScrollView + LazyVStack (not a List) so the nested horizontal
                // diff ScrollView in the drill-down still takes the wheel.
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        freeWinsSection
                        churnSection
                    }
                }
            }
        }
    }

    private var summary: some View {
        HStack(spacing: 24) {
            stat("\(pendingFreeWins.count)", "free wins")
            stat("\(pendingChurn.count)", "need review")
            stat("\(model.results.count)", "rules scanned")
            Spacer()
        }
        .padding(12)
    }

    @ViewBuilder
    private var freeWinsSection: some View {
        if !pendingFreeWins.isEmpty {
            HStack {
                sectionHeader("Free wins", "Enabling these changes nothing on this project today.")
                Spacer()
                Button {
                    enableAll(pendingFreeWins)
                } label: {
                    Label("Enable All", systemImage: "checkmark.circle")
                }
                .help("Enable every free win and save the config")
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 4)

            ForEach(pendingFreeWins) { impact in
                freeWinRow(impact)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                Divider()
            }
        }
    }

    @ViewBuilder
    private var churnSection: some View {
        if !pendingChurn.isEmpty {
            sectionHeader("Needs review", "These would reformat code — expand to see what changes.")
                .padding(.horizontal, 14)
                .padding(.top, 16)
                .padding(.bottom, 4)

            ForEach(pendingChurn) { impact in
                RuleImpactRow(
                    impact: impact,
                    maxFileCount: pendingChurn.first?.fileCount ?? 1,
                    rule: rule(named: impact.ruleID),
                    optionLines: optionLines(for: impact),
                    scanRoot: model.scannedPath,
                    isExpanded: ruleExpansion(impact.ruleID),
                    fileExpansion: { fileExpansion(impact.ruleID, $0) },
                    loadDiff: { ruleID, filePath in
                        await model.ruleDiff(ruleID: ruleID, filePath: filePath)
                    }
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
                Divider()
            }
        }
    }

    private func freeWinRow(_ impact: RuleImpact) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(impact.ruleID)
                    .scaledFont(.body, design: .monospaced)
                if let rule = rule(named: impact.ruleID) {
                    Text(rule.ruleDescription)
                        .scaledFont(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            Spacer()
            Button("Enable") { enable(impact.ruleID) }
                .accessibilityLabel("Enable \(impact.ruleID)")
        }
    }

    private func sectionHeader(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).scaledFont(.headline, weight: .semibold)
            Text(subtitle).scaledFont(.caption).foregroundStyle(.secondary)
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).scaledFont(.title2, weight: .bold)
            Text(label).scaledFont(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: - Expansion bindings

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

    // MARK: - Actions

    /// Whether a scan can run: a project is open, the catalog has loaded, and a
    /// scan isn't already in flight.
    private var canScan: Bool {
        guard workspace.selectedFolder != nil, catalog.catalog != nil else { return false }
        if case .running = model.state { return false }
        return true
    }

    /// Every rule not currently enabled — the adoption candidates. Deprecated rules
    /// are skipped (no point adopting something on its way out).
    private var candidateRuleNames: [String] {
        guard let rules = catalog.catalog?.rules else { return [] }
        return rules
            .filter { !$0.isDeprecated && !config.isRuleEnabled($0.name, isOptIn: $0.isOptIn) }
            .map(\.name)
    }

    private func scan() async {
        guard let folder = workspace.selectedFolder else { return }
        expandedRules.removeAll()
        expandedFiles.removeAll()
        model.extraArguments = config.commandLineArguments
        await model.runScan(path: folder, candidateRuleNames: candidateRuleNames)
    }

    /// Enables one rule in the config and saves (a timestamped backup is written,
    /// so it's reversible). The row drops off the list once `isRuleEnabled` is true.
    private func enable(_ ruleID: String) {
        config.setRuleEnabled(ruleID, enabled: true, isOptIn: isOptIn(ruleID))
        config.save()
    }

    private func enableAll(_ impacts: [RuleImpact]) {
        for impact in impacts {
            config.setRuleEnabled(impact.ruleID, enabled: true, isOptIn: isOptIn(impact.ruleID))
        }
        config.save()
    }

    // MARK: - Catalog lookups

    private func rule(named name: String) -> FormatRule? {
        catalog.catalog?.rule(named: name)
    }

    private func isOptIn(_ name: String) -> Bool {
        rule(named: name)?.isOptIn ?? true
    }

    private func optionLines(for impact: RuleImpact) -> [String] {
        ruleOptionLines(forRule: impact.ruleID, catalog: catalog, config: config)
    }
}
