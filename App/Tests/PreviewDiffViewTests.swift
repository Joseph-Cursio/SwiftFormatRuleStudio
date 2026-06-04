//
//  PreviewDiffViewTests.swift
//  SwiftFormatRuleStudioTests
//

@testable import SwiftFormatRuleStudio
import SwiftFormatRuleStudioCore
import SwiftUI
import Testing
import ViewInspector

@Suite("PreviewDiffView")
@MainActor
struct PreviewDiffViewTests {
    @Test("Renders each diff line with its +/- symbol")
    func rendersDiffLines() throws {
        let lines = [
            PreviewDiffLine(id: 0, text: "let x=1", change: .removed),
            PreviewDiffLine(id: 1, text: "let x = 1", change: .added),
            PreviewDiffLine(id: 2, text: "}", change: .unchanged)
        ]
        let view = PreviewDiffView(lines: lines)

        let texts = try view.inspect().findAll(ViewType.Text.self).compactMap { try? $0.string() }
        #expect(texts.contains("let x=1"))
        #expect(texts.contains("let x = 1"))
        #expect(texts.contains("+"))
        #expect(texts.contains("-"))
    }
}
