//
//  StartupView.swift
//  SwiftFormatRuleStudio
//

import SwiftUI
import UniformTypeIdentifiers

/// The launch gate: pick a project (so the whole app reflects its `.swiftformat`)
/// or browse the rule catalog with SwiftFormat's defaults. Sets the shared
/// `WorkspaceModel`, which RootView then loads config + runs the scan from.
struct StartupView: View {
    @Environment(WorkspaceModel.self) private var workspace
    @State private var choosingFolder = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "wand.and.stars")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text("SwiftFormat Rule Studio")
                    .font(.largeTitle.bold())
                Text("Open a project to browse and tune its formatting rules.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            actionButtons

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .fileImporter(isPresented: $choosingFolder, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result {
                _ = url.startAccessingSecurityScopedResource()
                workspace.open(url)
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                choosingFolder = true
            } label: {
                Label("Open Project Folder…", systemImage: "folder")
                    .frame(maxWidth: 280)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)

            if let recent = workspace.lastFolder {
                Button {
                    workspace.open(recent)
                } label: {
                    Label("Reopen “\(recent.lastPathComponent)”", systemImage: "clock.arrow.circlepath")
                        .frame(maxWidth: 280)
                }
                .controlSize(.large)
            }

            Button("Browse rules without a project") {
                workspace.browseWithoutProject()
            }
            .buttonStyle(.link)
            .padding(.top, 4)
        }
    }
}
