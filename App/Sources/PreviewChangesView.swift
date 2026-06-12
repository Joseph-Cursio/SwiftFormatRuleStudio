//
//  PreviewPanels.swift
//  SwiftFormatRuleStudio
//
//  The Changes + Result panels extracted from LiveCodePreviewView.
//

import SwiftFormatRuleStudioCore
import SwiftUI

/// A labeled pane header, shared across the Preview tab's panels.
func previewPaneHeader(_ title: String, systemImage: String) -> some View {
    Label(title, systemImage: systemImage)
        .scaledFont(.headline, weight: .semibold)
        .padding(8)
}

/// A read-only, syntax-highlighted rendering of Swift source. Used for the
/// formatted output and a loaded (non-editable) project file. `showsLineNumbers`
/// adds a gutter, matching the editable editor.
@ViewBuilder
func previewReadOnlyCode(_ source: String, showsLineNumbers: Bool = false) -> some View {
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
                            Divider()
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

/// The "SwiftFormat rules triggered" panel: one row per change, each linking to
/// the rule in the Rules tab.
struct PreviewChangesView: View {
    let model: LivePreviewModel
    let selectedFile: URL?
    @Environment(RuleStudioModel.self) private var catalog
    @Environment(ConfigModel.self) private var config
    @Environment(WorkspaceModel.self) private var workspace

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                previewPaneHeader("SwiftFormat rules triggered", systemImage: "list.bullet.rectangle")
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
    /// config override or SwiftFormat's default).
    private func optionLines(for ruleID: String) -> [String] {
        ruleOptionLines(forRule: ruleID, catalog: catalog, config: config)
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
            ruleAndOptions(change)
                .padding(.leading, 8)
            Spacer(minLength: 8)
            revealButton(change)
        }
        .padding(.vertical, 2)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 8))
        .listRowSeparator(.hidden)
        .contextMenu {
            Button("Show in Rules Tab") { showRuleInRulesTab(change.ruleID) }
        }
    }

    /// The triggered rule name plus the `--flag = value` lines for its options.
    private func ruleAndOptions(_ change: LintFinding) -> some View {
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
    }

    private func revealButton(_ change: LintFinding) -> some View {
        Button {
            showRuleInRulesTab(change.ruleID)
        } label: {
            Image(systemName: "arrow.up.forward")
        }
        .buttonStyle(.borderless)
        .help("Show “\(change.ruleID)” in the Rules tab")
        .accessibilityLabel("Show \(change.ruleID) in the Rules tab")
    }

    /// Opens `ruleID` in the Rules tab, remembering this Preview location so Back
    /// returns here. Shared by the row's reveal button and its context menu.
    private func showRuleInRulesTab(_ ruleID: String) {
        workspace.openInRules(ruleID, from: .preview(file: selectedFile))
    }
}

/// The Diff + Formatted-output result panel.
struct PreviewResultView: View {
    let model: LivePreviewModel

    var body: some View {
        VSplitView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    previewPaneHeader("Diff", systemImage: "plusminus")
                    Spacer()
                    statusLabel
                        .padding(.trailing, 10)
                }
                Divider()
                resultBody
            }
            .frame(minHeight: 100)

            VStack(alignment: .leading, spacing: 0) {
                previewPaneHeader("Formatted output", systemImage: "wand.and.stars")
                Divider()
                formattedOutput
            }
            .frame(minHeight: 100)
        }
        .frame(minWidth: 300)
    }

    /// The clean formatted result (no diff markers), syntax-highlighted. Its line
    /// numbers line up with the diff's "new" column.
    @ViewBuilder
    private var formattedOutput: some View {
        previewReadOnlyCode(model.formattedSource, showsLineNumbers: true)
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
                PreviewDiffView(lines: model.diff, showsLineNumbers: true)
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
}
