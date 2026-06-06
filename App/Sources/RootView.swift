//
//  RootView.swift
//  SwiftFormatRuleStudio
//

import SwiftFormatRuleStudioCore
import SwiftUI

/// Top-level navigation. Owns the shared catalog and config models and injects
/// them into the environment so all tabs work off the same state (e.g. the live
/// preview reflects the edited config).
struct RootView: View {
    /// The tabs, in display order. A bound selection keeps the active tab stable
    /// across re-renders — without it, presenting a `.fileImporter` from Config or
    /// Audit resets an unbound `TabView` back to the first tab.
    private enum Tab: Hashable {
        case rules, scratchpad, config, audit
    }

    @State private var catalog = RuleStudioModel()
    @State private var config = ConfigModel()
    @State private var selectedTab: Tab = .rules
    @AppStorage("rulesTextSizeStep") private var textSizeStep = 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                ContentView()
                    .tabItem {
                        Label("Rules", systemImage: "list.bullet.rectangle")
                    }
                    .tag(Tab.rules)
                LiveCodePreviewView()
                    .tabItem {
                        Label("Scratchpad", systemImage: "wand.and.stars")
                    }
                    .tag(Tab.scratchpad)
                ConfigView()
                    .tabItem {
                        Label("Config", systemImage: "slider.horizontal.3")
                    }
                    .tag(Tab.config)
                AuditView()
                    .tabItem {
                        Label("Audit", systemImage: "chart.bar.doc.horizontal")
                    }
                    .tag(Tab.audit)
            }
            Divider()
            StatusBar(catalog: catalog)
        }
        .environment(\.uiTextScale, .uiTextScale(forStep: textSizeStep))
        .environment(catalog)
        .environment(config)
        .task {
            await catalog.load()
        }
    }
}

/// Bottom status bar: shows the detected SwiftFormat version, or install
/// guidance when the catalog couldn't load (SwiftFormat not found).
private struct StatusBar: View {
    let catalog: RuleStudioModel

    var body: some View {
        HStack(spacing: 6) {
            switch catalog.loadState {
            case .failed:
                Label(
                    "SwiftFormat not found — install with: brew install swiftformat",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .foregroundStyle(.orange)
            case .loaded:
                Label(versionText, systemImage: "checkmark.seal")
                    .foregroundStyle(.secondary)
            case .idle, .loading:
                Label("Loading rules…", systemImage: "hourglass")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .scaledFont(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private var versionText: String {
        if let version = catalog.catalog?.swiftFormatVersion {
            return "SwiftFormat \(version) · \(catalog.catalog?.rules.count ?? 0) rules"
        }
        return "SwiftFormat ready"
    }
}
