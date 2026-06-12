//
//  TuneResultsView.swift
//  SwiftFormatRuleStudio
//
//  The completed-scan results (free wins + needs-review) extracted from TuneView.
//

import SwiftFormatRuleStudioCore
import SwiftUI

struct TuneResultsView: View {
    @Binding var expandedRules: Set<String>
    @Binding var expandedFiles: Set<String>
    @Environment(RuleStudioModel.self) private var catalog
    @Environment(ConfigModel.self) private var config
    @Environment(TuneModel.self) private var model

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
    var body: some View {
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
            OptionOpportunityBadge(opportunity: opportunity) {
                adoptRule(ruleID, improving: opportunity.sweeps)
            }
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
