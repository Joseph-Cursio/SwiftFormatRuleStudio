//
//  WorkspaceModel.swift
//  SwiftFormatRuleStudio
//

import Foundation
import Observation

/// The project folder shared across tabs, plus the startup-screen state.
///
/// Picking a folder in the startup screen, Config, or Impact updates this one
/// source of truth, so the whole app operates on the same project (RootView
/// reacts to a change: load that folder's `.swiftformat`, run its scan).
@MainActor
@Observable
final class WorkspaceModel {
    /// The app's top-level tabs. Owned here (not as RootView state) so navigation
    /// — cross-links and Back — can switch tabs centrally.
    enum Tab: Hashable {
        case rules, config, preview, impact
    }

    /// A place a cross-link came from, captured so Back can return and restore it.
    /// Only the two tabs that originate jumps need cases.
    enum Location: Equatable {
        /// The Preview tab with a file loaded (`nil` for the scratchpad).
        case preview(file: URL?)
        /// The Impact tab with a rule row expanded, optionally a file row under it.
        case impact(ruleID: String, filePath: String?)
    }

    /// What the Impact tab should re-expand and scroll to when Back lands on it.
    struct ImpactTarget: Equatable {
        let ruleID: String
        let filePath: String?
    }

    /// The selected project folder, or `nil` when browsing without a project.
    var selectedFolder: URL?

    /// Whether the user has made their initial choice (opened a folder or chose
    /// to browse without one). While `false`, RootView shows the startup screen.
    var hasCompletedStartup = false

    /// The currently selected tab. RootView binds the `TabView` to this.
    var selectedTab: Tab = .rules

    /// A file the user asked to open in the Preview tab — set from the Impact
    /// drill-down's "Open in Preview" (and by Back). The Preview tab loads the
    /// file and clears it.
    var previewRequest: URL?

    /// A rule the user asked to open in the Rules tab — set from the Preview tab's
    /// triggered-rules list (and by Back). The Rules tab selects it and clears it.
    var ruleRequest: String?

    /// The file currently loaded in the Preview tab (`nil` for the scratchpad or
    /// no project). Lets the Rules tab offer "see this rule on my file" using the
    /// exact file the user was just looking at.
    var currentPreviewFile: URL?

    /// Whether the rule detail's live example runs against `currentPreviewFile`
    /// instead of the curated snippet. Sticky across rules (a session preference);
    /// flipped on automatically when the user jumps from Preview to a rule.
    var rulesShowsProjectFile = false

    /// What the Impact tab should restore on Back (expand the rule/file, scroll to
    /// it). The Impact tab consumes and clears it.
    var impactRestore: ImpactTarget?

    /// Locations to return to, most recent last. A cross-link pushes where it came
    /// from; Back pops and restores.
    private var backStack: [Location] = []

    /// Whether there's somewhere to go Back to.
    var canGoBack: Bool { !backStack.isEmpty }

    // MARK: - Navigation

    /// Opens `file` in the Preview tab, remembering `origin` so Back can return.
    func openInPreview(_ file: URL, from origin: Location) {
        backStack.append(origin)
        selectedTab = .preview
        previewRequest = file
    }

    /// Opens `ruleID` in the Rules tab, remembering `origin` so Back can return.
    /// Arriving from a Preview file flips the rule example to that file, so you
    /// land on the rule already showing its effect on the code you were viewing.
    func openInRules(_ ruleID: String, from origin: Location) {
        backStack.append(origin)
        selectedTab = .rules
        ruleRequest = ruleID
        if case .preview(let file) = origin, file != nil {
            rulesShowsProjectFile = true
        }
    }

    /// Returns to the previous location, restoring its context.
    func goBack() {
        guard let location = backStack.popLast() else { return }
        switch location {
        case .preview(let file):
            selectedTab = .preview
            if let file { previewRequest = file }
        case .impact(let ruleID, let filePath):
            selectedTab = .impact
            impactRestore = ImpactTarget(ruleID: ruleID, filePath: filePath)
        }
    }

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
