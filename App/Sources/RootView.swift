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
    @State private var catalog = RuleStudioModel()
    @State private var config = ConfigModel()

    var body: some View {
        VStack(spacing: 0) {
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
                AuditView()
                    .tabItem {
                        Label("Audit", systemImage: "chart.bar.doc.horizontal")
                    }
            }
            Divider()
            StatusBar(catalog: catalog)
        }
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
        .font(.caption)
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
