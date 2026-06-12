//
//  TuneRuleOptionsPanel.swift
//  SwiftFormatRuleStudio
//
//  The options-layer panel + opportunity badge, extracted from TuneView.
//
import SwiftFormatRuleStudioCore
import SwiftUI

struct RuleOptionsPanel: View {
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
struct OptionOpportunityBadge: View {
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
