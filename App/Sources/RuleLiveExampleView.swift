//
//  RuleLiveExampleView.swift
//  SwiftFormatRuleStudio
//

import SwiftFormatRuleStudioCore
import SwiftUI

/// Maps tokenizer kinds to display colors and builds a syntax-highlighted
/// `Text` from a line of Swift, so example code reads like an editor instead of
/// flat monospace. Colors are chosen to stay legible in light and dark mode.

/// The sentence under the heading explaining what the example below is showing.
///
/// Takes the three facts it reads. `RuleLiveExampleView` re-runs the formatter on every option
/// change and stores the result in `LivePreviewModel`, so it rebuilds constantly — and none of that
/// changes this sentence.
private struct LiveExampleHint: View {
    let ruleName: String
    /// The file being previewed, or `nil` when the curated example is showing.
    let projectFileName: String?
    let hasCuratedSource: Bool

    var body: some View {
        if let projectFileName {
            Text("Running just this rule on \(projectFileName) with your "
                + "current options — edit the options above to see the effect change.")
                .scaledFont(.caption)
                .foregroundStyle(.secondary)
        } else if hasCuratedSource, CuratedLiveExample.unavailableNote(forRule: ruleName) == nil {
            Text(CuratedLiveExample.hint(forRule: ruleName)
                ?? "This rule applied to the sample with your current options — "
                + "edit the options above to watch it change.")
                .scaledFont(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// A live, option-driven example: runs SwiftFormat with *only this rule* enabled
/// plus the currently-set options, and shows the resulting before→after diff —
/// updating (debounced) as the options above are edited. So you change `--self`
/// to `remove` and watch the `self.` disappear, instead of guessing.
///
/// The source is either the rule's curated snippet (the default — always shows
/// the rule's effect, good for learning) or the file currently open in Preview
/// (your real code, good for "does this actually affect me?"). A segmented
/// toggle switches between them; it's offered only when a project file is loaded.
struct RuleLiveExampleView: View {
    let rule: FormatRule
    let options: [FormatOption]
    @Environment(ConfigModel.self) private var config
    @Environment(WorkspaceModel.self) private var workspace
    // Swift 6.0 so modern syntax (typed throws, etc.) is recognized in examples.
    @State private var model = LivePreviewModel(source: "", swiftVersion: "6.0")
    /// Contents of `projectFile` for the current mode, or `nil` in example mode.
    @State private var projectFileSource: String?

    private var curatedSource: String? { rule.liveExampleSource }

    /// The file the Preview tab currently has loaded, offered as a live target.
    private var projectFile: URL? { workspace.currentPreviewFile }

    /// Whether we're showing the project file (toggle on *and* one is loaded).
    private var showingProjectFile: Bool { workspace.rulesShowsProjectFile && projectFile != nil }

    /// The "before" source for the active mode.
    private var beforeSource: String? {
        showingProjectFile ? projectFileSource : curatedSource
    }

    /// Re-run whenever the rule, the mode, or the targeted file changes.
    private var reloadKey: String {
        "\(rule.name)|\(showingProjectFile)|\(projectFile?.path ?? "")"
    }

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
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(showingProjectFile ? "This rule on your file" : "Examples if the Rule is Enabled…")
                    .scaledFont(.headline, weight: .semibold)
                if model.state == .formatting {
                    ProgressView().controlSize(.small)
                }
                Spacer()
                sourcePicker
            }
            LiveExampleHint(
                ruleName: rule.name,
                projectFileName: showingProjectFile ? (projectFile?.lastPathComponent ?? "your file") : nil,
                hasCuratedSource: curatedSource != nil
            )
            contentArea
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: reloadKey) { await reload() }
        .onChange(of: ruleArguments) { _, newArguments in
            model.reformat(with: newArguments)
        }
    }

    /// The `[ Example | MyFile.swift ]` segmented toggle, shown only when Preview
    /// has a file loaded. Bound straight to the (sticky) workspace preference.
    @ViewBuilder
    private var sourcePicker: some View {
        if let file = projectFile {
            Picker("Example source", selection: projectFileBinding) {
                Text("Example").tag(false)
                Text(file.lastPathComponent).tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .help("Switch between the built-in example and the file open in Preview")
        }
    }

    private var projectFileBinding: Binding<Bool> {
        Binding(
            get: { workspace.rulesShowsProjectFile },
            set: { workspace.rulesShowsProjectFile = $0 }
        )
    }

    @ViewBuilder
    private var contentArea: some View {
        // In example mode a rule that acts on an invisible/file-level aspect shows
        // an explanatory note instead of an always-empty diff. The real file can
        // still render a diff, so the note only applies to the curated snippet.
        if !showingProjectFile, let note = CuratedLiveExample.unavailableNote(forRule: rule.name) {
            placeholderText(note)
        } else if let before = beforeSource {
            content(before: before)
        } else if showingProjectFile {
            placeholderText("Couldn’t read \(projectFile?.lastPathComponent ?? "the file").")
        } else {
            placeholderText("No example available for this rule yet.")
        }
    }

    private func placeholderText(_ text: String) -> some View {
        Text(text)
            .scaledFont(.caption)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Loads the source for the current mode and formats it. Reading the file
    /// here (not cached) keeps it fresh when the Preview file or mode changes.
    private func reload() async {
        let before: String?
        if showingProjectFile, let file = projectFile {
            let text = try? String(contentsOf: file, encoding: .utf8)
            projectFileSource = text
            before = text
            model.stdinPath = file.path // path-dependent rules behave as in place
            model.fragmentFallback = false // a real file is complete, not a fragment
        } else {
            projectFileSource = nil
            before = curatedSource
            model.stdinPath = nil
            model.fragmentFallback = true
        }
        guard let before else { return }
        model.source = before
        model.extraArguments = ruleArguments
        await model.formatNow()
    }

    @ViewBuilder
    private func content(before: String) -> some View {
        switch model.state {
        case .failed:
            Text("Couldn’t render a live preview for this example.")
                .scaledFont(.caption)
                .foregroundStyle(.tertiary)

        case .idle, .formatting, .formatted:
            // Before / Diff / After in both modes. For a real file each block is
            // height-capped and scrolls internally, so all three stay visible at
            // once; the curated snippet is small, so it renders at natural height.
            let cap: CGFloat? = showingProjectFile ? 200 : nil
            VStack(alignment: .leading, spacing: 10) {
                labeledBlock("Before") { DiffExampleView(example: before, maxHeight: cap) }
                if model.hasChanges {
                    labeledBlock("Diff (changes highlighted)") { LiveDiffLinesView(lines: model.diff, maxHeight: cap) }
                    labeledBlock("After") { DiffExampleView(example: model.formattedSource, maxHeight: cap) }
                } else {
                    labeledBlock(unchangedLabel) { DiffExampleView(example: before, maxHeight: cap) }
                }
            }
        }
    }

    /// The "After" caption when the rule changes nothing — phrased for whichever
    /// source is showing.
    private var unchangedLabel: String {
        showingProjectFile
            ? "After (\(rule.name) leaves \(projectFile?.lastPathComponent ?? "this file") unchanged)"
            : "After (unchanged with these options)"
    }

    /// A captioned code block — used for the Before / After panes so it's always
    /// clear which is the original and which is the formatted result.
    @ViewBuilder
    private func labeledBlock(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .scaledFont(.caption, weight: .semibold)
                .foregroundStyle(.secondary)
            content()
        }
    }
}
