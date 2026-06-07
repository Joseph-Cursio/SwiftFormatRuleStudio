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
    @State private var workspace = WorkspaceModel()
    @State private var audit = ImpactAuditModel()
    @AppStorage("rulesTextSizeStep") private var textSizeStep = 0

    var body: some View {
        Group {
            if workspace.hasCompletedStartup {
                mainUI
            } else {
                StartupView()
            }
        }
        .environment(\.uiTextScale, .uiTextScale(forStep: textSizeStep))
        .environment(catalog)
        .environment(config)
        .environment(workspace)
        .environment(audit)
        .task {
            await catalog.load()
        }
        // One source of truth for the project: when the shared folder changes,
        // load its config and run its audit so both tabs reflect it. Driven from
        // RootView (always alive) so it fires once per change, not on tab switches.
        .onChange(of: workspace.selectedFolder) { _, folder in
            guard let folder else { return }
            config.load(from: folder.appendingPathComponent(".swiftformat"))
            audit.extraArguments = config.commandLineArguments
            Task { await audit.runAudit(path: folder) }
        }
    }

    /// Binds the TabView to the shared selection so cross-links and Back can switch
    /// tabs centrally. A bound selection also keeps the active tab stable when a
    /// `.fileImporter` is presented from Config or Audit.
    private var tabSelection: Binding<WorkspaceModel.Tab> {
        Binding(get: { workspace.selectedTab }, set: { workspace.selectedTab = $0 })
    }

    private var mainUI: some View {
        VStack(spacing: 0) {
            TabView(selection: tabSelection) {
                ContentView()
                    .modifier(backToolbar)
                    .tabItem {
                        Label("Rules", systemImage: "list.bullet.rectangle")
                    }
                    .tag(WorkspaceModel.Tab.rules)
                ConfigView()
                    .modifier(backToolbar)
                    .tabItem {
                        Label("Config", systemImage: "slider.horizontal.3")
                    }
                    .tag(WorkspaceModel.Tab.config)
                LiveCodePreviewView()
                    .modifier(backToolbar)
                    .tabItem {
                        Label("Preview", systemImage: "wand.and.stars")
                    }
                    .tag(WorkspaceModel.Tab.preview)
                AuditView()
                    .modifier(backToolbar)
                    .tabItem {
                        Label("Impact", systemImage: "chart.bar.doc.horizontal")
                    }
                    .tag(WorkspaceModel.Tab.audit)
            }
            Divider()
            StatusBar(catalog: catalog)
        }
    }

    /// A leading "Back" toolbar item, added to every tab so the control sits in
    /// the standard top-left spot whichever tab is showing (⌘[ triggers it too).
    /// Reads RootView's own `workspace` directly — not the environment — so it
    /// doesn't trap when a view is inspected/previewed without the shared models.
    private var backToolbar: BackToolbar {
        BackToolbar(workspace: workspace)
    }
}

/// See `RootView.backToolbar`.
private struct BackToolbar: ViewModifier {
    let workspace: WorkspaceModel

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    workspace.goBack()
                } label: {
                    Label("Back", systemImage: "chevron.backward")
                }
                .disabled(!workspace.canGoBack)
                .keyboardShortcut("[", modifiers: .command)
                .help("Back to where you jumped from")
            }
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
