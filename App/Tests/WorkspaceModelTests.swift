//
//  WorkspaceModelTests.swift
//  SwiftFormatRuleStudioTests
//

@testable import SwiftFormatRuleStudio
import Foundation
import Testing

/// Covers the navigation/state wiring behind the Rules-tab example toggle:
/// `currentPreviewFile`, the sticky `rulesShowsProjectFile` preference, and how
/// `openInRules` flips it depending on where the jump came from.
@Suite("WorkspaceModel")
@MainActor
struct WorkspaceModelTests {
    private let fileURL = URL(fileURLWithPath: "/proj/Sources/File.swift")

    @Test("The example toggle and its target file default off")
    func defaultsOff() {
        let workspace = WorkspaceModel()
        #expect(workspace.currentPreviewFile == nil)
        #expect(workspace.rulesShowsProjectFile == false)
    }

    @Test("Opening a rule from a Preview file flips the example to that file")
    func openFromPreviewFileFlipsToggle() {
        let workspace = WorkspaceModel()
        workspace.openInRules("redundantSelf", from: .preview(file: fileURL))
        #expect(workspace.rulesShowsProjectFile)
        #expect(workspace.selectedTab == .rules)
        #expect(workspace.ruleRequest == "redundantSelf")
        #expect(workspace.canGoBack)
    }

    @Test("Opening a rule from the Preview scratchpad (no file) leaves the toggle off")
    func openFromScratchpadKeepsExample() {
        let workspace = WorkspaceModel()
        workspace.openInRules("redundantSelf", from: .preview(file: nil))
        #expect(workspace.rulesShowsProjectFile == false)
        #expect(workspace.selectedTab == .rules)
        #expect(workspace.ruleRequest == "redundantSelf")
    }

    @Test("Opening a rule from the Impact tab leaves the toggle off")
    func openFromImpactKeepsExample() {
        let workspace = WorkspaceModel()
        workspace.openInRules("sortImports", from: .impact(ruleID: "sortImports", filePath: fileURL.path))
        #expect(workspace.rulesShowsProjectFile == false)
    }

    @Test("The project-file preference is sticky — a later non-Preview jump doesn't reset it")
    func preferenceIsSticky() {
        let workspace = WorkspaceModel()
        workspace.openInRules("first", from: .preview(file: fileURL))
        workspace.openInRules("second", from: .impact(ruleID: "second", filePath: nil))
        #expect(workspace.rulesShowsProjectFile)
    }

    @Test("Back from a Preview-file jump returns to Preview and reloads that file")
    func backReturnsToPreviewFile() {
        let workspace = WorkspaceModel()
        workspace.openInRules("redundantSelf", from: .preview(file: fileURL))
        workspace.goBack()
        #expect(workspace.selectedTab == .preview)
        #expect(workspace.previewRequest == fileURL)
        #expect(workspace.canGoBack == false)
    }
}
