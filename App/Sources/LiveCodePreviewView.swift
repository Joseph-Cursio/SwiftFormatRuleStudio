//
//  LiveCodePreviewView.swift
//  SwiftFormatRuleStudio
//

import SwiftUI
import SwiftFormatRuleStudioCore

/// The headline feature: edit Swift on the left, watch it reformat (as a colored
/// diff) on the right, live. Thin wrapper over the tested `LivePreviewModel`.
struct LiveCodePreviewView: View {
    @State private var model = LivePreviewModel(source: LiveCodePreviewView.sampleSource)

    var body: some View {
        HSplitView {
            editor
            result
        }
        .task { await model.formatNow() }
        .navigationTitle("Live Preview")
    }

    // MARK: - Editor

    private var editor: some View {
        VStack(alignment: .leading, spacing: 0) {
            paneHeader("Source", systemImage: "pencil.line")
            Divider()
            TextEditor(text: $model.source)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(6)
                .onChange(of: model.source) {
                    model.scheduleFormat()
                }
        }
        .frame(minWidth: 300)
    }

    // MARK: - Result

    private var result: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                paneHeader("Result", systemImage: "wand.and.stars")
                Spacer()
                statusLabel
                    .padding(.trailing, 10)
            }
            Divider()
            resultBody
        }
        .frame(minWidth: 300)
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
                .font(.caption)
                .foregroundStyle(.secondary)
        case .failed:
            Label("Error", systemImage: "exclamationmark.triangle")
                .font(.caption)
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
            .font(.headline)
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
        ScrollView([.vertical, .horizontal]) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(lines) { line in
                    HStack(alignment: .top, spacing: 8) {
                        Text(symbol(for: line.change))
                            .frame(width: 10, alignment: .leading)
                        Text(line.text.isEmpty ? " " : line.text)
                    }
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(foreground(for: line.change))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 1)
                    .background(background(for: line.change))
                }
            }
            .padding(.vertical, 4)
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
