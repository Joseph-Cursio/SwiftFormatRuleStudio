//
//  RootView.swift
//  SwiftFormatRuleStudio
//

import SwiftUI
import SwiftFormatRuleStudioCore

/// Top-level navigation. Owns the shared catalog and config models and injects
/// them into the environment so all tabs work off the same state (e.g. the live
/// preview reflects the edited config).
struct RootView: View {
    @State private var catalog = RuleStudioModel()
    @State private var config = ConfigModel()

    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("Rules", systemImage: "list.bullet.rectangle")
                }
            LiveCodePreviewView()
                .tabItem {
                    Label("Live Preview", systemImage: "wand.and.stars")
                }
            ConfigView()
                .tabItem {
                    Label("Config", systemImage: "slider.horizontal.3")
                }
        }
        .environment(catalog)
        .environment(config)
        .task {
            await catalog.load()
        }
    }
}
