//
//  RuleDiffViews.swift
//  SwiftFormatRuleStudio
//
//  Diff rendering + syntax coloring extracted from RuleDetailView.
//
import SwiftFormatRuleStudioCore
import SwiftUI

enum SwiftCodeColor {
    static func color(for kind: SwiftCodeTokenizer.Kind) -> Color {
        switch kind {
        case .keyword: Color(red: 0.79, green: 0.20, blue: 0.55) // magenta/pink
        case .string: Color(red: 0.76, green: 0.30, blue: 0.27) // brick red
        case .comment: .secondary
        case .number: Color(red: 0.20, green: 0.40, blue: 0.85) // blue
        case .type: Color(red: 0.18, green: 0.55, blue: 0.55) // teal
        case .plain: .primary
        }
    }

    /// A syntax-highlighted attributed rendering of one code line. Empty lines
    /// render a single space so the diff row keeps its height.
    static func attributed(_ line: String) -> AttributedString {
        guard !line.isEmpty else { return AttributedString(" ") }
        var result = AttributedString()
        for token in SwiftCodeTokenizer.tokens(inLine: line) {
            var span = AttributedString(token.text)
            span.foregroundColor = color(for: token.kind)
            result += span
        }
        return result
    }
}

/// A non-collapsing diff renderer for the rule detail's live example.
///
/// `PreviewDiffView` wraps a *vertical* `ScrollView`, which collapses to ~zero
/// height when nested inside the detail pane's own vertical `ScrollView` — so the
/// diff would render invisibly. This uses horizontal-only scrolling (safe inside
/// a vertical parent) and lets its height grow naturally with the content.
/// A diff line paired with its old/new line numbers (`nil` where the line doesn't
/// exist on that side) — git/GitHub-style two-column numbering.
struct NumberedDiffLine: Identifiable {
    let line: PreviewDiffLine
    let oldNumber: Int?
    let newNumber: Int?
    var id: Int { line.id }
}

extension [PreviewDiffLine] {
    /// Assigns old/new numbers across the diff: removed → old only, added → new
    /// only, unchanged → both.
    func numbered() -> [NumberedDiffLine] {
        var old = 1
        var new = 1
        return map { line in
            switch line.change {
            case .removed:
                defer { old += 1 }
                return NumberedDiffLine(line: line, oldNumber: old, newNumber: nil)
            case .added:
                defer { new += 1 }
                return NumberedDiffLine(line: line, oldNumber: nil, newNumber: new)
            case .unchanged:
                defer { old += 1; new += 1 }
                return NumberedDiffLine(line: line, oldNumber: old, newNumber: new)
            }
        }
    }
}

/// Gutter width sufficient for the widest line number (monospaced).
func diffGutterWidth(forMaxNumber maxNumber: Int) -> CGFloat {
    CGFloat(max(String(maxNumber).count, 1)) * 9 + 2
}

/// One right-aligned, dimmed line-number cell (blank for a missing number).
@ViewBuilder
func lineNumberGutter(_ number: Int?, width: CGFloat) -> some View {
    Text(number.map(String.init) ?? "")
        .monospacedDigit()
        .foregroundStyle(.tertiary)
        .frame(width: width, alignment: .trailing)
}

/// Reports a view's laid-out height, so a capped block can size to its content
/// (up to the cap) instead of always reserving the full cap height.
private struct BlockHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

extension View {
    func measuringHeight() -> some View {
        background(GeometryReader { geometry in
            Color.clear.preference(key: BlockHeightKey.self, value: geometry.size.height)
        })
    }

    /// Clamps content to `cap`: short content sizes to fit (no leftover space),
    /// long content caps and scrolls. `nil` cap leaves the height unconstrained.
    func cappedHeight(_ measured: CGFloat, _ cap: CGFloat?) -> some View {
        frame(height: cap.map { min(measured == 0 ? $0 : measured, $0) })
    }
}

struct LiveDiffLinesView: View {
    let lines: [PreviewDiffLine]
    /// When set, the diff is capped to this height and scrolls vertically too — so
    /// a long project-file diff stays compact alongside the Before/After panes.
    var maxHeight: CGFloat?
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        let rows = lines.numbered()
        let oldWidth = diffGutterWidth(forMaxNumber: rows.compactMap(\.oldNumber).max() ?? 0)
        let newWidth = diffGutterWidth(forMaxNumber: rows.compactMap(\.newNumber).max() ?? 0)
        ScrollView(maxHeight == nil ? .horizontal : [.horizontal, .vertical], showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(rows) { row in
                    HStack(alignment: .top, spacing: 8) {
                        lineNumberGutter(row.oldNumber, width: oldWidth)
                        lineNumberGutter(row.newNumber, width: newWidth)
                        Divider()
                        Text(symbol(for: row.line.change))
                            .foregroundStyle(foreground(for: row.line.change))
                            .frame(width: 10, alignment: .leading)
                        Text(SwiftCodeColor.attributed(row.line.text))
                    }
                    .scaledFont(.body, design: .monospaced)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 1)
                    .background(background(for: row.line.change))
                }
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .measuringHeight()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cappedHeight(contentHeight, maxHeight)
        .onPreferenceChange(BlockHeightKey.self) { contentHeight = $0 }
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
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

/// Renders a raw unified-diff example (lines prefixed `+`/`-`/space) with
/// per-line coloring. SwiftFormat's `--ruleinfo` already emits diff markers, so
/// no diff computation is needed. (M3 will swap to LintStudioUI's shared diff
/// view for the live `swiftformat stdin` preview.)
struct DiffExampleView: View {
    let example: String
    /// When set, the block is capped to this height and scrolls internally — so a
    /// long project file's Before/After panes stay compact and all three visible.
    var maxHeight: CGFloat?

    @State private var contentHeight: CGFloat = 0

    private var lines: [String] {
        example.components(separatedBy: "\n")
    }

    var body: some View {
        Group {
            if maxHeight != nil {
                ScrollView([.vertical, .horizontal]) { rows.measuringHeight() }
                    .cappedHeight(contentHeight, maxHeight)
                    .onPreferenceChange(BlockHeightKey.self) { contentHeight = $0 }
            } else {
                rows
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8).strokeBorder(.separator)
        )
    }

    private var rows: some View {
        let width = diffGutterWidth(forMaxNumber: lines.count)
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                let split = Self.split(line)
                HStack(alignment: .top, spacing: 8) {
                    lineNumberGutter(index + 1, width: width)
                    Divider()
                    Text(String(split.gutter))
                        .foregroundStyle(gutterColor(for: line))
                        .frame(width: 8, alignment: .leading)
                    Text(SwiftCodeColor.attributed(split.code))
                }
                .scaledFont(.body, design: .monospaced)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 1)
                .background(background(for: line))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Splits a raw diff line into its 1-char gutter (`+`/`-`/space) and the code
    /// after it. Context lines (no marker) keep their full text as code.
    private static func split(_ line: String) -> (gutter: Character, code: String) {
        guard let first = line.first, first == "+" || first == "-" else {
            return (" ", line)
        }
        return (first, String(line.dropFirst()))
    }

    private func gutterColor(for line: String) -> Color {
        if line.hasPrefix("+") { return .green }
        if line.hasPrefix("-") { return .red }
        return .secondary
    }

    private func background(for line: String) -> Color {
        if line.hasPrefix("+") { return Color.green.opacity(0.12) }
        if line.hasPrefix("-") { return Color.red.opacity(0.12) }
        return .clear
    }
}
