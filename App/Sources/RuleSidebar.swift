//
//  RuleSidebar.swift
//  SwiftFormatRuleStudio
//

import SwiftFormatRuleStudioCore
import SwiftUI

/// Searchable, filterable rule list, sectioned by category. Binds directly to
/// `model.filter`.
struct RuleSidebar: View {
    @Bindable var model: RuleStudioModel
    @Binding var selection: String?

    var body: some View {
        List(selection: $selection) {
            ForEach(model.groupedRules) { group in
                Section {
                    ForEach(group.rules) { rule in
                        RuleRow(rule: rule)
                            .tag(rule.name)
                    }
                } header: {
                    Text("\(group.category.displayName)  ·  \(group.rules.count)")
                }
            }
        }
        .searchable(text: $model.filter.searchText, prompt: "Search rules")
        .overlay { overlay }
        .safeAreaInset(edge: .top) { filterBar }
        .navigationTitle("Rules")
    }

    @ViewBuilder
    private var filterBar: some View {
        VStack(spacing: 6) {
            Picker("Show", selection: $model.filter.availability) {
                ForEach(RuleAvailability.allCases) { availability in
                    Text(availability.displayName).tag(availability)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Picker("Category", selection: $model.filter.category) {
                Text("All categories").tag(FormatRuleCategory?.none)
                ForEach(FormatRuleCategory.allCases) { category in
                    Text(category.displayName).tag(FormatRuleCategory?.some(category))
                }
            }
            .labelsHidden()
        }
        .padding(8)
        .background(.bar)
    }

    @ViewBuilder
    private var overlay: some View {
        switch model.loadState {
        case .loading:
            ProgressView("Loading rules…")
        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn’t load rules", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            }
        case .idle, .loaded:
            if model.hasNoMatches {
                ContentUnavailableView.search
            }
        }
    }
}

/// A single rule row: name plus opt-in / deprecated markers.
struct RuleRow: View {
    let rule: FormatRule

    var body: some View {
        HStack(spacing: 8) {
            Text(rule.name)
                .font(.body)
            Spacer()
            if rule.isDeprecated {
                Text("deprecated")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if rule.isOptIn {
                Image(systemName: "circle.dashed")
                    .foregroundStyle(.secondary)
                    .help("Opt-in (off by default)")
                    .accessibilityLabel("Opt-in, off by default")
            }
        }
    }
}
