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
    /// The post-scan option-opportunity pass, cancelled when a new scan starts.
    @State private var opportunityTask: Task<Void, Never>?
    /// Which rules to scan: everything disabled, or only what a SwiftFormat upgrade
    /// brought. Both run the same isolated lint — see `TuneScanScope`.
    @State private var scope: TuneScanScope = .allDisabled

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
        .onChange(of: scope) { _, _ in
            // Results belong to the scope they were scanned under; keeping them would
            // show upgrade rules under "all disabled", or vice versa.
            opportunityTask?.cancel()
            model.reset()
        }
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
        ToolbarItem {
            Picker("Scan", selection: $scope) {
                Text(TuneScanScope.allDisabled.title).tag(TuneScanScope.allDisabled)
                if !upgradeScopes.isEmpty {
                    Divider()
                    // "I'm on 0.60.1, what did upgrading give me?"
                    ForEach(upgradeScopes, id: \.self) { scope in
                        Text(scope.title).tag(scope)
                    }
                }
            }
            .pickerStyle(.menu)
            .help("Scan every disabled rule, or only the rules a SwiftFormat upgrade added")
        }
    }

    /// One scope per anchor version older than the SwiftFormat the app links. Versions
    /// at or above it are omitted: there is nothing newer to have arrived.
    private var upgradeScopes: [TuneScanScope] {
        guard let current = catalog.catalog?.swiftFormatVersion else { return [] }
        return RuleHistory.anchorVersions
            .filter { RuleHistory.isUpgrade(from: $0, to: current) }
            .map { .newSince(version: $0) }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .idle:
            ContentUnavailableView {
                Label(
                    scope == .allDisabled ? "Find free wins" : "What the upgrade brought",
                    systemImage: "sparkles"
                )
            } description: {
                Text(scope.explanation)
            } actions: {
                Button(candidateRuleNames.isEmpty
                    ? "Nothing to scan"
                    : "Scan \(candidateRuleNames.count) Rule\(candidateRuleNames.count == 1 ? "" : "s")") {
                    Task { await scan() }
                }
                .disabled(!canScan || candidateRuleNames.isEmpty)
            }
        case let .running(scanned, total):
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
            TuneResultsView(expandedRules: $expandedRules, expandedFiles: $expandedFiles)
        }
    }

    // MARK: - Actions

    /// Whether a scan can run: a project is open, the catalog has loaded, and a
    /// scan isn't already in flight.
    private var canScan: Bool {
        guard workspace.selectedFolder != nil, catalog.catalog != nil else { return false }
        if case .running = model.state { return false }
        return true
    }

    /// The adoption candidates for the selected scope.
    private var candidateRuleNames: [String] {
        guard let loaded = catalog.catalog else { return [] }
        return scope
            .candidateRules(in: loaded) { config.isRuleEnabled($0.name, isOptIn: $0.isOptIn) }
            .map(\.name)
    }

    private func scan() async {
        guard let folder = workspace.selectedFolder else { return }
        expandedRules.removeAll()
        expandedFiles.removeAll()
        opportunityTask?.cancel()
        model.extraArguments = config.commandLineArguments
        await model.runScan(path: folder, candidateRuleNames: candidateRuleNames)
        // Then, in the background, sweep the churn rules' options so rows can flag
        // a hidden free win. Cancellable so a re-scan doesn't leave a stale pass.
        let options = catalog.options
        let currentValues = config.config.options
        opportunityTask = Task {
            await model.findOptionOpportunities(allOptions: options, currentValues: currentValues)
        }
    }
}
