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
    @Environment(\.uiTextScale) private var uiTextScale
    @State private var model = LivePreviewModel(source: Self.sampleSource)

    var body: some View {
        HSplitView {
            VSplitView {
                editor
                    .frame(minHeight: 120)
                changesList
                    .frame(minHeight: 100)
            }
            result
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
        .navigationTitle("Live Preview")
    }

    // MARK: - Editor

    private var editor: some View {
        VStack(alignment: .leading, spacing: 0) {
            paneHeader("Enter your own source", systemImage: "pencil.line")
            Divider()
            CodeTextEditor(text: $model.source, fontSize: 13 * uiTextScale)
                .onChange(of: model.source) {
                    model.scheduleFormat()
                }
        }
        .frame(minWidth: 300)
    }

    // MARK: - Changes (which rule changed which line)

    private var changesList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                paneHeader("SwiftFormat rules triggered", systemImage: "list.bullet.rectangle")
                Spacer()
                Text("\(model.changes.count)")
                    .scaledFont(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 10)
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

    private func changeRow(_ change: LintFinding) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(change.line)")
                .scaledFont(.body, design: .monospaced)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)
            VStack(alignment: .leading, spacing: 1) {
                Text(change.ruleID)
                    .scaledFont(.body)
                Text(change.reason)
                    .scaledFont(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .listRowSeparator(.hidden)
    }

    // MARK: - Result

    private var result: some View {
        VSplitView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    paneHeader("Diff", systemImage: "plusminus")
                    Spacer()
                    statusLabel
                        .padding(.trailing, 10)
                }
                Divider()
                resultBody
            }
            .frame(minHeight: 100)

            VStack(alignment: .leading, spacing: 0) {
                paneHeader("Formatted output", systemImage: "wand.and.stars")
                Divider()
                formattedOutput
            }
            .frame(minHeight: 100)
        }
        .frame(minWidth: 300)
    }

    /// The clean formatted result (no diff markers), syntax-highlighted.
    @ViewBuilder
    private var formattedOutput: some View {
        GeometryReader { geometry in
            ScrollView([.vertical, .horizontal]) {
                VStack(alignment: .leading, spacing: 0) {
                    let lines = model.formattedSource.components(separatedBy: "\n")
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        Text(SwiftCodeColor.attributed(line))
                            .scaledFont(.body, design: .monospaced)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                    }
                }
                .padding(.vertical, 4)
                .frame(minWidth: geometry.size.width, minHeight: geometry.size.height, alignment: .topLeading)
            }
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch model.state {
        case .idle:
            EmptyView()
        case .formatting:
            ProgressView().controlSize(.small)
        case .formatted:
            Text(model.hasChanges ? "\(changeCount) change\(changeCount == 1 ? "" : "s")" : "No changes")
                .scaledFont(.caption)
                .foregroundStyle(.secondary)
        case .failed:
            Label("Error", systemImage: "exclamationmark.triangle")
                .scaledFont(.caption)
                .foregroundStyle(.red)
        }
    }

    private var changeCount: Int {
        model.diff.filter { $0.change != .unchanged }.count
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
                PreviewDiffView(lines: model.diff)
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

    private func paneHeader(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .scaledFont(.headline, weight: .semibold)
            .padding(8)
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

/// Renders `[PreviewDiffLine]` as a colored unified diff.
struct PreviewDiffView: View {
    let lines: [PreviewDiffLine]

    var body: some View {
        // GeometryReader + minWidth/minHeight pins content to the top-left: a 2D
        // ScrollView otherwise centers content smaller than its viewport.
        GeometryReader { geometry in
            ScrollView([.vertical, .horizontal]) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(lines) { line in
                        HStack(alignment: .top, spacing: 8) {
                            Text(symbol(for: line.change))
                                .frame(width: 10, alignment: .leading)
                            Text(line.text.isEmpty ? " " : line.text)
                        }
                        .scaledFont(.body, design: .monospaced)
                        .foregroundStyle(foreground(for: line.change))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 1)
                        .background(background(for: line.change))
                    }
                }
                .padding(.vertical, 4)
                .frame(minWidth: geometry.size.width, minHeight: geometry.size.height, alignment: .topLeading)
            }
        }
    }

    private func symbol(for change: PreviewDiffLine.Change) -> String {
        switch change {
        case .added: "+"
        case .removed: "-"
        case .unchanged: " "
        }
    }

    private func foreground(for change: PreviewDiffLine.Change) -> Color {
        switch change {
        case .added: .green
        case .removed: .red
        case .unchanged: .primary
        }
    }

    private func background(for change: PreviewDiffLine.Change) -> Color {
        switch change {
        case .added: Color.green.opacity(0.12)
        case .removed: Color.red.opacity(0.12)
        case .unchanged: .clear
        }
    }
}
