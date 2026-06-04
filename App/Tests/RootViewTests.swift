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
    @Test("Hosts a TabView")
    func hasTabView() throws {
        // Locating the TabView doesn't evaluate the (environment-dependent) tab
        // bodies, so this is safe without injecting the shared models.
        _ = try RootView().inspect().find(ViewType.TabView.self)
    }
}
