//
//  RootView.swift
//  SwiftFormatRuleStudio
//

import SwiftUI

/// Top-level navigation: the rule browser and the live code preview.
struct RootView: View {
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
        }
    }
}
