//
//  LiveCodePreviewSupport.swift
//  SwiftFormatRuleStudio
//
//  File-tree rows + diff view extracted from LiveCodePreviewView.
//
import SwiftFormatRuleStudioCore
import SwiftUI

struct FileNode: Identifiable, Hashable {
    let url: URL
    let name: String
    let children: [Self]?
    var id: URL { url }
    var isDirectory: Bool { children != nil }
}

/// One outline row, recursive over its children. Directories are `DisclosureGroup`s
/// whose expansion is persisted via `expansion(path)`; files are selectable leaves
/// (tagged by URL for the enclosing `List`'s selection).
struct FileRow: View {
    let node: FileNode
    let expansion: (String) -> Binding<Bool>

    var body: some View {
        if let children = node.children {
            DisclosureGroup(isExpanded: expansion(node.url.path)) {
                ForEach(children) { child in
                    Self(node: child, expansion: expansion)
                }
            } label: {
                Label(node.name, systemImage: "folder")
                    .scaledFont(.callout, design: .monospaced)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        } else {
            Label(node.name, systemImage: "swift")
                .scaledFont(.callout, design: .monospaced)
                .lineLimit(1)
                .truncationMode(.middle)
                .tag(node.url)
        }
    }
}

/// Renders `[PreviewDiffLine]` as a colored unified diff. With `showsLineNumbers`,
/// a two-column gutter shows old and new line numbers (git/GitHub style) so moves
/// are legible: a removed line numbers the old side, an added line the new side.
struct PreviewDiffView: View {
    let lines: [PreviewDiffLine]
    var showsLineNumbers = false

    var body: some View {
        let rows = lines.numbered()
        let oldWidth = diffGutterWidth(forMaxNumber: rows.compactMap(\.oldNumber).max() ?? 0)
        let newWidth = diffGutterWidth(forMaxNumber: rows.compactMap(\.newNumber).max() ?? 0)
        // GeometryReader + minWidth/minHeight pins content to the top-left: a 2D
        // ScrollView otherwise centers content smaller than its viewport.
        GeometryReader { geometry in
            ScrollView([.vertical, .horizontal]) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(rows) { row in
                        HStack(alignment: .top, spacing: 8) {
                            if showsLineNumbers {
                                lineNumberGutter(row.oldNumber, width: oldWidth)
                                lineNumberGutter(row.newNumber, width: newWidth)
                                Divider()
                            }
                            HStack(alignment: .top, spacing: 8) {
                                Text(symbol(for: row.line.change))
                                    .frame(width: 10, alignment: .leading)
                                Text(row.line.text.isEmpty ? " " : row.line.text)
                            }
                            .foregroundStyle(foreground(for: row.line.change))
                        }
                        .scaledFont(.body, design: .monospaced)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 1)
                        .background(background(for: row.line.change))
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
