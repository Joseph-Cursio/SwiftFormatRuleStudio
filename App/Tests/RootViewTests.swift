//
//  RootViewTests.swift
//  SwiftFormatRuleStudioTests
//

@testable import SwiftFormatRuleStudio
import SwiftFormatRuleStudioCore
import SwiftUI
import Testing
import ViewInspector

@Suite("RootView")
@MainActor
struct RootViewTests {
    @Test("Builds and renders a Group as its top-level shell")
    func bodyIsGroup() throws {
        // RootView gates between StartupView and the main TabView on its own
        // @State, so the rendered tree always begins with a Group. We assert only
        // that: descending further evaluates StartupView (and the tab views),
        // which read @Observable @Environment objects ViewInspector (0.10.3)
        // can't supply — it traps with "No Observable object of type … found".
        // This is a build/structure smoke test; the startup→Rules navigation it
        // would otherwise exercise is covered headlessly by WorkspaceModelTests.
        _ = try RootView().inspect().group()
    }
}
