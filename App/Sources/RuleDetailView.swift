//
//  RuleDetailView.swift
//  SwiftFormatRuleStudio
//

import SwiftFormatRuleStudioCore
import SwiftUI

/// Shows the selected rule's description, related options, and before/after
/// example. Reads `model.selectedRuleDetail`, which the model lazily enriches.
struct RuleDetailView: View {
    let model: RuleStudioModel
    @Environment(ConfigModel.self) private var config

    var body: some View {
        if let rule = model.selectedRuleDetail {
            detail(for: rule)
        } else if model.isLoadingDetail {
            ProgressView()
        } else {
            ContentUnavailableView(
                "Select a rule",
                systemImage: "sidebar.left",
                description: Text("Choose a rule to see what it does and how it rewrites code.")
            )
        }
    }

    private func enabledBinding(for rule: FormatRule) -> Binding<Bool> {
        Binding(
            get: { config.isRuleEnabled(rule.name, isOptIn: rule.isOptIn) },
            set: { config.setRuleEnabled(rule.name, enabled: $0, isOptIn: rule.isOptIn) }
        )
    }

    private func detail(for rule: FormatRule) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(for: rule)

                Toggle("Enabled in config", isOn: enabledBinding(for: rule))
                    .toggleStyle(.switch)

                if !rule.ruleDescription.isEmpty {
                    Text(rule.ruleDescription)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                RuleOptionsSection(rule: rule, options: matchedOptions(for: rule), config: config)
                    .id(rule.name)

                RuleLiveExampleView(rule: rule, options: matchedOptions(for: rule))
                    .id(rule.name)

                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(rule.name)
    }

    private func header(for rule: FormatRule) -> some View {
        HStack(spacing: 10) {
            Text(rule.name)
                .font(.largeTitle.bold())
            badge(rule.category.displayName, color: .blue)
            if rule.isOptIn {
                badge("Opt-in", color: .orange)
            }
            if rule.isDeprecated {
                badge("Deprecated", color: .red)
            }
        }
    }

    /// Resolve the rule's `relatedOptions` flags (e.g. `["--self"]`) to the
    /// catalog's `FormatOption` values so we can render editable controls.
    private func matchedOptions(for rule: FormatRule) -> [FormatOption] {
        let keys = Set(rule.relatedOptions.map { flag in
            String(flag.drop { $0 == "-" })
        })
        return model.options.filter { keys.contains($0.key) }
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }
}

/// The options that tune a rule, rendered inline with the same editable
/// controls as the Config tab so you can see (and change) a rule's options
/// without leaving the rule. Collapsed by default for high-fan-out rules
/// (e.g. `organizeDeclarations` has 21) to keep the pane scannable.
struct RuleOptionsSection: View {
    let rule: FormatRule
    let options: [FormatOption]
    @Bindable var config: ConfigModel
    @State private var isExpanded: Bool
    @State private var showOnlySet = false

    init(rule: FormatRule, options: [FormatOption], config: ConfigModel) {
        self.rule = rule
        self.options = options
        self.config = config
        // Few options → show them; many → start collapsed.
        _isExpanded = State(initialValue: options.count <= 3)
    }

    private func isSet(_ option: FormatOption) -> Bool {
        config.config.options[option.key] != nil
    }

    private var setCount: Int {
        options.count { isSet($0) }
    }

    private var visibleOptions: [FormatOption] {
        showOnlySet ? options.filter(isSet) : options
    }

    var body: some View {
        if options.isEmpty {
            Text("No tunable options.")
                .font(.callout)
                .foregroundStyle(.tertiary)
        } else {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(spacing: 0) {
                    ForEach(visibleOptions) { option in
                        Divider()
                        OptionRow(option: option, config: config, currentRuleName: rule.name)
                            .padding(.vertical, 2)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text("Options")
                        .font(.headline)
                    Text("\(options.count)")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(.quaternary, in: Capsule())
                    if setCount > 0 {
                        Text("· \(setCount) set")
                            .font(.caption)
                            .foregroundStyle(.tint)
                    }
                    Spacer()
                    if options.count > 3 {
                        Toggle("Only set", isOn: $showOnlySet)
                            .toggleStyle(.checkbox)
                            .controlSize(.small)
                    }
                }
            }
        }
    }
}

/// A live, option-driven example: reconstructs the rule's "before" snippet,
/// runs it back through SwiftFormat with *only this rule* enabled plus the
/// currently-set options, and shows the resulting before→after diff — updating
/// (debounced) as the options above are edited. So you change `--self` to
/// `remove` and watch the `self.` disappear, instead of guessing.
struct RuleLiveExampleView: View {
    let rule: FormatRule
    let options: [FormatOption]
    @Environment(ConfigModel.self) private var config
    // Swift 6.0 so modern syntax (typed throws, etc.) is recognized in examples.
    @State private var model = LivePreviewModel(source: "", swiftVersion: "6.0")

    private var beforeSource: String? { rule.liveExampleSource }

    /// Isolate this rule and pass only its *set* options — unset ones fall back
    /// to SwiftFormat's defaults, so at no overrides the live diff reproduces the
    /// static example, then diverges as you edit. No `--fragment` here: it
    /// suppresses scope-dependent rules; the model only adds it to rescue an
    /// outright format error (see `fragmentFallback`).
    private var ruleArguments: [String] {
        var arguments = ["--rules", rule.name]
        for option in options {
            if let value = config.config.options[option.key] {
                arguments += ["--\(option.key)", value]
            }
        }
        return arguments
    }

    var body: some View {
        if let before = beforeSource {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("Example")
                        .font(.headline)
                    if model.state == .formatting {
                        ProgressView().controlSize(.small)
                    }
                }
                Text("This rule applied to the sample with your current options — "
                    + "edit the options above to watch it change.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                content(before: before)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .task(id: rule.name) {
                model.fragmentFallback = true
                model.source = before
                model.extraArguments = ruleArguments
                await model.formatNow()
            }
            .onChange(of: ruleArguments) { _, newArguments in
                model.extraArguments = newArguments
                model.scheduleFormat()
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Example")
                    .font(.headline)
                Text("No example available for this rule yet.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func content(before: String) -> some View {
        switch model.state {
        case .failed:
            Text("Couldn’t render a live preview for this example.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        case .idle, .formatting, .formatted:
            VStack(alignment: .leading, spacing: 10) {
                labeledBlock("Before") { DiffExampleView(example: before) }
                if model.hasChanges {
                    labeledBlock("After (changes highlighted)") { LiveDiffLinesView(lines: model.diff) }
                } else {
                    labeledBlock("After (unchanged with these options)") { DiffExampleView(example: before) }
                }
            }
        }
    }

    /// A captioned code block — used for the Before / After panes so it's always
    /// clear which is the original and which is the formatted result.
    @ViewBuilder
    private func labeledBlock(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }
}

/// Maps tokenizer kinds to display colors and builds a syntax-highlighted
/// `Text` from a line of Swift, so example code reads like an editor instead of
/// flat monospace. Colors are chosen to stay legible in light and dark mode.
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
struct LiveDiffLinesView: View {
    let lines: [PreviewDiffLine]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(lines) { line in
                    HStack(alignment: .top, spacing: 8) {
                        Text(symbol(for: line.change))
                            .foregroundStyle(foreground(for: line.change))
                            .frame(width: 10, alignment: .leading)
                        Text(SwiftCodeColor.attributed(line.text))
                    }
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 1)
                    .background(background(for: line.change))
                }
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private var lines: [String] {
        example.components(separatedBy: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                let split = Self.split(line)
                HStack(alignment: .top, spacing: 8) {
                    Text(String(split.gutter))
                        .foregroundStyle(gutterColor(for: line))
                        .frame(width: 8, alignment: .leading)
                    Text(SwiftCodeColor.attributed(split.code))
                }
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 1)
                .background(background(for: line))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8).strokeBorder(.separator)
        )
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
