//
//  ContentView.swift
//  SwiftFormatRuleStudio
//

import SwiftFormatRuleStudioCore
import SwiftUI

/// Top-level browser: a searchable rule sidebar and a detail pane. All state
/// lives in the tested `RuleStudioModel`; these views are thin bindings.
struct ContentView: View {
    @Environment(RuleStudioModel.self) private var model
    @State private var selection: String?

    var body: some View {
        NavigationSplitView {
            RuleSidebar(model: model, selection: $selection)
                .navigationSplitViewColumnWidth(min: 240, ideal: 300)
        } detail: {
            RuleDetailView(model: model)
        }
        .onChange(of: selection) { _, newValue in
            Task { await model.select(newValue) }
        }
    }
}
