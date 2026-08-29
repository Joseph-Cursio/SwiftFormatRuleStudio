//
//  WorkspaceModelTests.swift
//  SwiftFormatRuleStudioTests
//

import Foundation
@testable import SwiftFormatRuleStudio
import Testing

/// Covers the navigation/state wiring behind the Rules-tab example toggle:
/// `currentPreviewFile`, the sticky `rulesShowsProjectFile` preference, and how
/// `openInRules` flips it depending on where the jump came from.
@Suite("WorkspaceModel")
@MainActor
struct WorkspaceModelTests {
    private let fileURL = URL(fileURLWithPath: "/proj/Sources/File.swift")

    /// A workspace with an in-memory bookmark store and a throwaway defaults suite,
    /// so no test reads or writes the real app's remembered project.
    private func makeWorkspace(
        store: MockBookmarkStore = MockBookmarkStore(),
        defaults: UserDefaults? = nil
    ) -> WorkspaceModel {
        WorkspaceModel(bookmarks: store, defaults: defaults ?? Self.scratchDefaults())
    }

    static func scratchDefaults() -> UserDefaults {
        guard let defaults = UserDefaults(suiteName: "SFRSTests-\(UUID().uuidString)") else {
            Issue.record("Could not open a scratch defaults suite")
            return .standard
        }
        return defaults
    }

    @Test("The example toggle and its target file default off")
    func defaultsOff() {
        let workspace = makeWorkspace()
        #expect(workspace.currentPreviewFile == nil)
        #expect(workspace.rulesShowsProjectFile == false)
    }

    @Test("Opening a rule from a Preview file flips the example to that file")
    func openFromPreviewFileFlipsToggle() {
        let workspace = makeWorkspace()
        workspace.openInRules("redundantSelf", from: .preview(file: fileURL))
        #expect(workspace.rulesShowsProjectFile)
        #expect(workspace.selectedTab == .rules)
        #expect(workspace.ruleRequest == "redundantSelf")
        #expect(workspace.canGoBack)
    }

    @Test("Opening a rule from the Preview scratchpad (no file) leaves the toggle off")
    func openFromScratchpadKeepsExample() {
        let workspace = makeWorkspace()
        workspace.openInRules("redundantSelf", from: .preview(file: nil))
        #expect(workspace.rulesShowsProjectFile == false)
        #expect(workspace.selectedTab == .rules)
        #expect(workspace.ruleRequest == "redundantSelf")
    }

    @Test("Opening a rule from the Impact tab leaves the toggle off")
    func openFromImpactKeepsExample() {
        let workspace = makeWorkspace()
        workspace.openInRules("sortImports", from: .impact(ruleID: "sortImports", filePath: fileURL.path))
        #expect(workspace.rulesShowsProjectFile == false)
    }

    @Test("The project-file preference is sticky — a later non-Preview jump doesn't reset it")
    func preferenceIsSticky() {
        let workspace = makeWorkspace()
        workspace.openInRules("first", from: .preview(file: fileURL))
        workspace.openInRules("second", from: .impact(ruleID: "second", filePath: nil))
        #expect(workspace.rulesShowsProjectFile)
    }

    @Test("Back from a Preview-file jump returns to Preview and reloads that file")
    func backReturnsToPreviewFile() {
        let workspace = makeWorkspace()
        workspace.openInRules("redundantSelf", from: .preview(file: fileURL))
        workspace.goBack()
        #expect(workspace.selectedTab == .preview)
        #expect(workspace.previewRequest == fileURL)
        #expect(workspace.canGoBack == false)
    }
}
