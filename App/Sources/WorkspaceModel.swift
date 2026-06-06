//
//  WorkspaceModel.swift
//  SwiftFormatRuleStudio
//

import Foundation
import Observation

/// The project folder shared across tabs, plus the startup-screen state.
///
/// Picking a folder in the startup screen, Config, or Audit updates this one
/// source of truth, so the whole app operates on the same project (RootView
/// reacts to a change: load that folder's `.swiftformat`, run its audit).
@MainActor
@Observable
final class WorkspaceModel {
    /// The selected project folder, or `nil` when browsing without a project.
    var selectedFolder: URL?

    /// Whether the user has made their initial choice (opened a folder or chose
    /// to browse without one). While `false`, RootView shows the startup screen.
    var hasCompletedStartup = false

    /// Absolute path of the most recently opened project, persisted across
    /// launches so the startup screen can offer to reopen it.
    var lastFolderPath: String? {
        didSet { UserDefaults.standard.set(lastFolderPath, forKey: Self.lastFolderKey) }
    }

    private static let lastFolderKey = "lastProjectFolderPath"

    init() {
        lastFolderPath = UserDefaults.standard.string(forKey: Self.lastFolderKey)
    }

    /// The remembered project as a URL, but only if it still exists on disk.
    var lastFolder: URL? {
        guard let path = lastFolderPath,
              FileManager.default.fileExists(atPath: path) else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    /// Opens a project folder: makes it the selection, remembers it, and leaves
    /// the startup screen.
    func open(_ url: URL) {
        selectedFolder = url
        lastFolderPath = url.path
        hasCompletedStartup = true
    }

    /// Enters the app with no project (SwiftFormat's default config).
    func browseWithoutProject() {
        hasCompletedStartup = true
    }
}
