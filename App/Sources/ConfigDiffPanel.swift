//
//  ConfigDiffPanel.swift
//  SwiftFormatRuleStudio
//
//  The before / diff / after panel of the .swiftformat file, extracted from
//  ConfigView.
//

import SwiftFormatRuleStudioCore
import SwiftUI

/// Shows the saved `.swiftformat`, the pending diff, and what the file will look
/// like after saving — the right-hand panel of the Config tab.
struct ConfigDiffPanel: View {
    @Environment(ConfigModel.self) private var config

    var body: some View {
        VSplitView {
            configPane("Saved .swiftformat", systemImage: "doc") {
                configListing(config.originalText, emptyMessage: "No .swiftformat saved yet.")
            }
            pendingChangesPane
            configPane("After saving", systemImage: "doc.badge.gearshape") {
                configListing(config.editedText, emptyMessage: "Empty — everything is at its default.")
            }
        }
        .frame(minWidth: 320, maxHeight: .infinity)
    }

    /// The middle pane of the diff panel: pending-changes header plus the live diff.
    private var pendingChangesPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Pending changes", systemImage: "plusminus")
                    .scaledFont(.headline, weight: .semibold)
                Spacer()
                if let error = config.lastError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .scaledFont(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(8)
            Divider()
            Group {
                if config.isDirty {
                    PreviewDiffView(lines: config.diff, showsLineNumbers: true)
                } else {
                    ContentUnavailableView(
                        "No pending changes",
                        systemImage: "checkmark.seal",
                        description: Text("Edit a rule or option to see the .swiftformat diff here.")
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minHeight: 90)
    }

    /// A labeled before/after pane wrapping read-only config text.
    private func configPane(_ title: String, systemImage: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Label(title, systemImage: systemImage)
                .scaledFont(.headline, weight: .semibold)
                .padding(8)
            Divider()
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minHeight: 90)
    }

    /// Read-only, line-numbered rendering of `.swiftformat` text (plain — config
    /// files aren't Swift). Empty text shows a placeholder.
    @ViewBuilder
    private func configListing(_ text: String, emptyMessage: String) -> some View {
        let lines = text.isEmpty ? [] : text.components(separatedBy: "\n")
        if lines.isEmpty {
            Text(emptyMessage)
                .scaledFont(.caption)
                .foregroundStyle(.tertiary)
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            let width = diffGutterWidth(forMaxNumber: lines.count)
            GeometryReader { geometry in
                ScrollView([.vertical, .horizontal]) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                            HStack(alignment: .top, spacing: 8) {
                                lineNumberGutter(index + 1, width: width)
                                Divider()
                                Text(line.isEmpty ? " " : line)
                            }
                            .scaledFont(.body, design: .monospaced)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 1)
                        }
                    }
                    .padding(.vertical, 4)
                    .frame(minWidth: geometry.size.width, minHeight: geometry.size.height, alignment: .topLeading)
                }
            }
            .textSelection(.enabled)
        }
    }
}
