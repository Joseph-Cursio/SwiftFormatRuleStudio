//
//  RuleImpactRow.swift
//  SwiftFormatRuleStudio
//

import SwiftFormatRuleStudioCore
import SwiftUI

/// One affected file under a rule, expandable to the rule's before/after diff for
/// that file. The diff is loaded lazily (and cached by the caller) on first expand.
struct FileImpactRow: View {
    let ruleID: String
    let file: FileImpact
    let scanRoot: URL?
    @Binding var isExpanded: Bool
    /// Loads the before/after diff for `(ruleID, filePath)`.
    let loadDiff: (String, String) async -> [PreviewDiffLine]
    /// Optional "open in Preview" action; the button is hidden when nil.
    var onOpenInPreview: (() -> Void)?
    @State private var diff: [PreviewDiffLine]?
    @State private var loading = false

    /// File path relative to the scanned folder, for a compact label.
    private var displayPath: String {
        guard let root = scanRoot?.path else { return file.filePath }
        let prefix = root.hasSuffix("/") ? root : root + "/"
        return file.filePath.hasPrefix(prefix) ? String(file.filePath.dropFirst(prefix.count)) : file.filePath
    }

    private var countText: String {
        "\(file.findingCount) finding\(file.findingCount == 1 ? "" : "s")"
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            FileImpactDiff(diff: diff, loading: loading)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "swift").foregroundStyle(.secondary).accessibilityHidden(true)
                Text(displayPath)
                    .scaledFont(.callout, design: .monospaced)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Text(countText)
                    .scaledFont(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                if let onOpenInPreview {
                    Button {
                        onOpenInPreview()
                    } label: {
                        Image(systemName: "wand.and.stars")
                    }
                    .buttonStyle(.borderless)
                    .help("Open in Preview")
                    .accessibilityLabel("Open \(displayPath) in Preview")
                }
            }
        }
        // Load on user expand, and on appear when restored already-expanded (the
        // initial value doesn't fire onChange). load() guards against re-running.
        .onChange(of: isExpanded) { _, open in
            if open { Task { await load() } }
        }
        .task { if isExpanded { await load() } }
    }

    private func load() async {
        guard diff == nil, !loading else { return }
        loading = true
        diff = await loadDiff(ruleID, file.filePath)
        loading = false
    }
}

/// One rule's impact row: name, category, its tuning options, an impact bar, and
/// counts.
struct ImpactRow: View {
    let impact: RuleImpact
    let maxFileCount: Int
    let rule: FormatRule?
    /// `--flag = value` lines for the rule's options, or empty if it has none.
    var optionLines: [String] = []

    private var fraction: Double {
        maxFileCount > 0 ? Double(impact.fileCount) / Double(maxFileCount) : 0
    }

    private var countsText: String {
        let files = "\(impact.fileCount) file\(impact.fileCount == 1 ? "" : "s")"
        let findings = "\(impact.findingCount) finding\(impact.findingCount == 1 ? "" : "s")"
        return "\(files) · \(findings)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(impact.ruleID)
                    .scaledFont(.body, design: .monospaced)
                if let rule {
                    Text(rule.category.displayName)
                        .scaledFont(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(countsText)
                    .scaledFont(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            if !optionLines.isEmpty {
                Text(optionLines.joined(separator: "    "))
                    .scaledFont(.caption, design: .monospaced)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 3)
                    .fill(.tint)
                    .frame(width: max(4, geometry.size.width * fraction), height: 6)
            }
            .frame(height: 6)
        }
        .padding(.vertical, 3)
    }
}

/// The before/after diff a file row reveals when expanded.
///
/// Takes the loaded lines and the loading flag. `FileImpactRow` also holds a `Binding` to the
/// expansion state and two closures the list allocates afresh on every update, so the row itself
/// never compares equal — this does.
private struct FileImpactDiff: View {
    let diff: [PreviewDiffLine]?
    let loading: Bool

    var body: some View {
        if loading {
            ProgressView().controlSize(.small).padding(.vertical, 4)
        } else if let diff, !diff.isEmpty {
            LiveDiffLinesView(lines: diff)
                .padding(.vertical, 4)
        } else if diff != nil {
            Text("This rule makes no isolated change here.")
                .scaledFont(.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 4)
        }
    }
}

/// A rule's row, expandable to the files it would change (each of which expands to
/// its before/after diff). The collapsed label is `ImpactRow`. Decoupled from any
/// one model: the diff loader and optional Preview action are passed in, so both
/// the Impact and Tune tabs reuse it.
struct RuleImpactRow: View {
    let impact: RuleImpact
    let maxFileCount: Int
    let rule: FormatRule?
    let optionLines: [String]
    let scanRoot: URL?
    @Binding var isExpanded: Bool
    /// Supplies the expansion binding for a given file path under this rule.
    let fileExpansion: (String) -> Binding<Bool>
    /// Loads the rule's before/after diff for one file path (cached by the caller).
    let loadDiff: (String, String) async -> [PreviewDiffLine]
    /// Optional "open in Preview" action for an affected file; hidden when nil.
    var onOpenInPreview: ((FileImpact) -> Void)?
    /// Optional content shown at the top of the expanded section, above the files
    /// — the Tune tab puts its option-sweep panel here; Impact leaves it nil.
    var expandedHeader: AnyView?
    /// Optional accessory shown under the collapsed label — the Tune tab puts its
    /// "free win available at …" badge here; Impact leaves it nil.
    var labelAccessory: AnyView?

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            if let expandedHeader {
                expandedHeader
            }
            ForEach(impact.files) { file in
                FileImpactRow(
                    ruleID: impact.ruleID,
                    file: file,
                    scanRoot: scanRoot,
                    isExpanded: fileExpansion(file.filePath),
                    loadDiff: loadDiff,
                    onOpenInPreview: onOpenInPreview.map { action in { action(file) } }
                )
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                ImpactRow(impact: impact, maxFileCount: maxFileCount, rule: rule, optionLines: optionLines)
                if let labelAccessory {
                    labelAccessory
                }
            }
        }
    }
}
