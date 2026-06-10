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
            HStack(spacing: 8) {
                sectionHeader("Needs review", "These would reformat code — expand to see what changes.")
                if model.isFindingOpportunities {
                    ProgressView().controlSize(.small)
                    Text("checking option fixes…")
                        .scaledFont(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
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
                    },
                    expandedHeader: optionsPanel(for: impact.ruleID),
                    labelAccessory: opportunityBadge(for: impact.ruleID)
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
                Divider()
            }
        }
    }

    /// The "free win available at …" badge for a churn row, or `nil` until the
    /// background pass finds an option opportunity for the rule.
    private func opportunityBadge(for ruleID: String) -> AnyView? {
        guard let opportunity = model.optionOpportunities[ruleID] else { return nil }
        return AnyView(
            OptionOpportunityBadge(
                opportunity: opportunity,
                adopt: { adoptRule(ruleID, improving: opportunity.sweeps) }
            )
        )
    }

    /// The options-layer panel for a churn rule — `nil` (no panel, no sweep) when
    /// the rule has no boolean/enum options to try.
    private func optionsPanel(for ruleID: String) -> AnyView? {
        guard hasSweepableOptions(ruleID), let path = model.scannedPath else { return nil }
        let options = catalog.options
        let currentValues = config.config.options
        return AnyView(
            RuleOptionsPanel(
                ruleID: ruleID,
                loadSweeps: {
                    await model.sweepOptions(
                        forRule: ruleID,
                        path: path,
                        allOptions: options,
                        currentValues: currentValues
                    )
                },
                measureJoint: { sweeps in
                    await model.ruleImpact(
                        forRule: ruleID,
                        path: path,
                        optionOverrides: bestOverrides(sweeps)
                    )
                },
                adopt: { sweeps in adoptRule(ruleID, improving: sweeps) }
            )
        )
    }

    /// `[--flag: bestValue]` for the given sweeps — the option set adopting the
    /// rule would write.
    private func bestOverrides(_ sweeps: [OptionSweep]) -> [String: String] {
        var overrides: [String: String] = [:]
        for sweep in sweeps {
            if let best = sweep.bestValue { overrides[sweep.optionFlag] = best.value }
        }
        return overrides
    }

    /// Adopts a churn rule at every option's best value at once: sets each option
    /// (clearing it when the best value is the default, to keep the config
    /// minimal), enables the rule, and saves. The rule then leaves the list.
    private func adoptRule(_ ruleID: String, improving sweeps: [OptionSweep]) {
        persistScanSwiftVersion()
        for sweep in sweeps {
            guard let best = sweep.bestValue else { continue }
            if best.value == sweep.defaultValue {
                config.removeOption(key: sweep.optionKey)
            } else {
                config.setOption(key: sweep.optionKey, value: best.value)
            }
        }
        config.setRuleEnabled(ruleID, enabled: true, isOptIn: isOptIn(ruleID))
        config.save()
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

    /// Enables one rule in the config and saves (a timestamped backup is written,
    /// so it's reversible). The row drops off the list once `isRuleEnabled` is true.
    private func enable(_ ruleID: String) {
        persistScanSwiftVersion()
        config.setRuleEnabled(ruleID, enabled: true, isOptIn: isOptIn(ruleID))
        config.save()
    }

    private func enableAll(_ impacts: [RuleImpact]) {
        persistScanSwiftVersion()
        for impact in impacts {
            config.setRuleEnabled(impact.ruleID, enabled: true, isOptIn: isOptIn(impact.ruleID))
        }
        config.save()
    }

    /// Records the Swift version the scan ran under as a `--swift-version` line,
    /// so the rules we just adopted behave identically on the CLI (SwiftFormat
    /// warns, and disables some rules, when it isn't set). Leaves any version the
    /// user already configured untouched.
    private func persistScanSwiftVersion() {
        guard let version = model.swiftVersion, !version.isEmpty else { return }
        guard config.config.options["swift-version"] == nil else { return }
        config.setOption(key: "swift-version", value: version)
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

    /// Whether `ruleID` has at least one boolean/enum option worth sweeping (one
    /// with a finite set of values). Integer/list/string options aren't sweepable.
    private func hasSweepableOptions(_ ruleID: String) -> Bool {
        OptionRuleUsage.optionKeys(forRule: ruleID).contains { key in
            guard let option = catalog.options.first(where: { $0.key == key }) else { return false }
            return option.kind == .boolean || option.kind == .enumeration
        }
    }
}

/// The options layer (docs/audit-redesign.md): inside a Needs-review rule's
/// drill-down, lazily sweep the rule's boolean/enum options and show the churn at
/// each value — so a rule that's churn at the default can be adopted at a zero- or
/// lower-churn value (e.g. `braces` is free once `--allman true` is set). When more
/// than one option helps, a single Adopt sets them all to their best value at
/// once; the joint churn it would actually cause is measured (not summed from the
/// per-option sweeps). The sweep runs on first expand (and is cached by the model).
private struct RuleOptionsPanel: View {
    let ruleID: String
    let loadSweeps: () async -> [OptionSweep]
    let measureJoint: ([OptionSweep]) async -> RuleImpact
    let adopt: ([OptionSweep]) -> Void
    @State private var sweeps: [OptionSweep]?
    @State private var jointImpact: RuleImpact?

    /// The options whose best value beats the current one — the set Adopt writes.
    private var improving: [OptionSweep] { (sweeps ?? []).filter(\.hasImprovement) }

    var body: some View {
        Group {
            if let sweeps {
                if !sweeps.isEmpty {
                    content(sweeps)
                }
            } else {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Checking option values…")
                        .scaledFont(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .task {
            guard sweeps == nil else { return }
            let loaded = await loadSweeps()
            sweeps = loaded
            let improvers = loaded.filter(\.hasImprovement)
            if !improvers.isEmpty {
                jointImpact = await measureJoint(improvers)
            }
        }
    }

    private func content(_ sweeps: [OptionSweep]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(sweeps) { sweep in
                optionBlock(sweep)
            }
            if !improving.isEmpty {
                adoptSection
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
        .padding(.vertical, 4)
    }

    private func optionBlock(_ sweep: OptionSweep) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3")
                    .scaledFont(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(sweep.optionFlag)
                    .scaledFont(.caption, design: .monospaced)
                if sweep.hasImprovement, let best = sweep.bestValue {
                    Text(best.findingCount == 0 ? "free win available" : "less churn available")
                        .scaledFont(.caption2, weight: .semibold)
                        .foregroundStyle(best.findingCount == 0 ? .green : .orange)
                }
            }
            ForEach(sweep.values) { value in
                valueRow(sweep, value)
            }
        }
    }

    private func valueRow(_ sweep: OptionSweep, _ value: OptionValueImpact) -> some View {
        let isCurrent = value.value == sweep.effectiveValue
        let isBest = value.value == sweep.bestValue?.value
        return HStack(spacing: 8) {
            Text(value.value)
                .scaledFont(.caption, design: .monospaced)
                .foregroundStyle(isBest ? .primary : .secondary)
            Text(churnText(value))
                .scaledFont(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            if isCurrent {
                badge("current", .secondary)
            } else if isBest, sweep.hasImprovement {
                // Only flag the best value when it actually beats the current one
                // — not when it merely ties it.
                badge(value.findingCount == 0 ? "free" : "best", value.findingCount == 0 ? .green : .orange)
            }
            Spacer()
        }
    }

    /// A single Adopt that sets every improving option to its best value at once,
    /// labelled with the joint churn that combination actually causes.
    private var adoptSection: some View {
        let changes = improving.compactMap { sweep -> String? in
            guard let best = sweep.bestValue else { return nil }
            return "\(sweep.optionFlag) \(best.value)"
        }
        return VStack(alignment: .leading, spacing: 6) {
            Divider()
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(adoptHeadline)
                        .scaledFont(.caption, weight: .semibold)
                        .foregroundStyle(jointIsFreeWin ? .green : .primary)
                    Text("Sets \(changes.joined(separator: ", "))")
                        .scaledFont(.caption2, design: .monospaced)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button("Adopt") { adopt(improving) }
                    .controlSize(.small)
                    .accessibilityLabel("Adopt \(ruleID) with its best option values")
            }
        }
    }

    private var jointIsFreeWin: Bool { jointImpact?.findingCount == 0 }

    private var adoptHeadline: String {
        guard let joint = jointImpact else { return "Adopt \(ruleID) with its best options" }
        if joint.findingCount == 0 {
            return "Adopt \(ruleID) — free win, 0 changes"
        }
        let changes = "\(joint.findingCount) change\(joint.findingCount == 1 ? "" : "s")"
        let files = "\(joint.fileCount) file\(joint.fileCount == 1 ? "" : "s")"
        return "Adopt \(ruleID) — \(changes) · \(files)"
    }

    private func churnText(_ value: OptionValueImpact) -> String {
        guard value.findingCount > 0 else { return "no changes" }
        let changes = "\(value.findingCount) change\(value.findingCount == 1 ? "" : "s")"
        let files = "\(value.fileCount) file\(value.fileCount == 1 ? "" : "s")"
        return "\(changes) · \(files)"
    }

    private func badge(_ text: String, _ color: Color) -> some View {
        Text(text)
            .scaledFont(.caption2, weight: .medium)
            .foregroundStyle(color)
    }
}

/// The row-level flag the background pass produces: a churn rule that an option
/// change would make cheaper (or free), shown right under the collapsed rule with
/// a one-click Adopt that applies the whole recommended option set at once — so
/// the hidden free win isn't buried in the drill-down.
private struct OptionOpportunityBadge: View {
    let opportunity: OptionOpportunity
    let adopt: () -> Void

    private var tint: Color { opportunity.isFreeWin ? .green : .orange }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .scaledFont(.caption2)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(headline)
                .scaledFont(.caption2, weight: .semibold)
                .foregroundStyle(tint)
            Text(opportunity.optionSummary)
                .scaledFont(.caption2, design: .monospaced)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
            Button("Adopt") { adopt() }
                .controlSize(.small)
                .accessibilityLabel("Adopt \(opportunity.ruleID) with \(opportunity.optionSummary)")
        }
    }

    private var headline: String {
        guard !opportunity.isFreeWin else { return "free win available —" }
        let count = opportunity.jointFindingCount
        return "down to \(count) change\(count == 1 ? "" : "s") —"
    }
}
