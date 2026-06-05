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
    // Adjustable via View ▸ Larger/Smaller Text (⌘+ / ⌘- / ⌘0). Shared with the
    // app's menu commands through this AppStorage key.
    @AppStorage("rulesTextSizeStep") private var textSizeStep = 0

    private var textScale: CGFloat { .uiTextScale(forStep: textSizeStep) }

    var body: some View {
        NavigationSplitView {
            RuleSidebar(model: model, selection: $selection)
                .navigationSplitViewColumnWidth(min: 240, ideal: 300)
                .environment(\.uiTextScale, textScale)
        } detail: {
            RuleDetailView(model: model)
                .environment(\.uiTextScale, textScale)
        }
        .onChange(of: selection) { _, newValue in
            Task { await model.select(newValue) }
        }
    }
}
