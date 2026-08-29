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
        case rules, config, preview, impact, tune
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
        case let .impact(ruleID, filePath):
            selectedTab = .impact
            impactRestore = ImpactTarget(ruleID: ruleID, filePath: filePath)
        }
    }

    // MARK: - Folder access

    /// The folder the app is currently working in, holding its scoped access.
    private var access: ScopedFolder?

    /// Last launch's project, resolved from its bookmark (which also started its
    /// access). Promoted to `access` if the user reopens it, released if they open
    /// something else.
    private var remembered: ScopedFolder?

    private let bookmarks: any BookmarkStoring
    private let defaults: UserDefaults

    private static let bookmarkKey = "lastProjectFolderBookmark"
    /// Written by pre-sandbox builds. A raw path can't be upgraded into a bookmark —
    /// that needs access we no longer have — so it's dropped rather than left to rot.
    private static let legacyPathKey = "lastProjectFolderPath"

    init(
        bookmarks: any BookmarkStoring = SecurityScopedBookmarkStore(),
        defaults: UserDefaults = .standard
    ) {
        self.bookmarks = bookmarks
        self.defaults = defaults
        defaults.removeObject(forKey: Self.legacyPathKey)
        guard let data = defaults.data(forKey: Self.bookmarkKey) else { return }
        remembered = ScopedFolder(resolving: data, store: bookmarks)
        // A resolve can refresh stale bookmark data; keep what actually works.
        if let refreshed = remembered?.bookmark {
            defaults.set(refreshed, forKey: Self.bookmarkKey)
        }
    }

    /// The remembered project, or `nil` when there isn't one the app can actually
    /// open. Sandboxed, `fileExists` answers `true` for folders it may not read, so
    /// a successful resolve — not a path check — is the only honest test.
    var lastFolder: URL? { remembered?.url }

    /// Opens a project folder: makes it the selection, remembers it for next launch,
    /// and leaves the startup screen.
    ///
    /// Reopening the remembered folder keeps the `ScopedFolder` the bookmark already
    /// produced. Building a fresh one would release that access and replace it with a
    /// grant this launch never received — the folder would go unreadable mid-session.
    func open(_ url: URL) {
        if let remembered, remembered.url == url {
            access?.release()
            access = remembered
            self.remembered = nil
        } else {
            remembered?.release()
            remembered = nil
            access?.release()
            let folder = ScopedFolder(granting: url, store: bookmarks)
            access = folder
            if let bookmark = folder.bookmark {
                defaults.set(bookmark, forKey: Self.bookmarkKey)
            } else {
                // Nothing worth offering next launch: a bookmark we couldn't make is
                // a Reopen button that would fail.
                defaults.removeObject(forKey: Self.bookmarkKey)
            }
        }
        selectedFolder = url
        hasCompletedStartup = true
    }

    /// Enters the app with no project (SwiftFormat's default config).
    func browseWithoutProject() {
        hasCompletedStartup = true
    }
}
