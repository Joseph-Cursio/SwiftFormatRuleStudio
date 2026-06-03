//
//  RuleDetailView.swift
//  SwiftFormatRuleStudio
//

import SwiftUI
import SwiftFormatRuleStudioCore

/// Shows the selected rule's description, related options, and before/after
/// example. Reads `model.selectedRuleDetail`, which the model lazily enriches.
struct RuleDetailView: View {
    let model: RuleStudioModel

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

    private func detail(for rule: FormatRule) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(for: rule)

                if !rule.ruleDescription.isEmpty {
                    Text(rule.ruleDescription)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                if !rule.relatedOptions.isEmpty {
                    relatedOptions(rule.relatedOptions)
                }

                if let example = rule.example {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Example")
                            .font(.headline)
                        DiffExampleView(example: example)
                    }
                }

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

    private func relatedOptions(_ options: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Related options")
                .font(.headline)
            ForEach(options, id: \.self) { option in
                Text(option)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.tint)
            }
        }
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
                Text(line.isEmpty ? " " : line)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(foreground(for: line))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 1)
                    .background(background(for: line))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8).strokeBorder(.separator)
        )
    }

    private func foreground(for line: String) -> Color {
        if line.hasPrefix("+") { return .green }
        if line.hasPrefix("-") { return .red }
        return .primary
    }

    private func background(for line: String) -> Color {
        if line.hasPrefix("+") { return Color.green.opacity(0.12) }
        if line.hasPrefix("-") { return Color.red.opacity(0.12) }
        return .clear
    }
}
