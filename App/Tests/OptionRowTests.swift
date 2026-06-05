//
//  OptionRowTests.swift
//  SwiftFormatRuleStudioTests
//

@testable import SwiftFormatRuleStudio
import SwiftFormatRuleStudioCore
import SwiftUI
import Testing
import ViewInspector

@Suite("OptionRow")
@MainActor
struct OptionRowTests {
    @Test("Shows the option name and summary")
    func showsOptionDetails() throws {
        let option = FormatOption(name: "--indent", summary: "Number of spaces to indent", kind: .integer)
        let view = OptionRow(option: option, config: ConfigModel())

        let texts = try view.inspect().findAll(ViewType.Text.self).compactMap { try? $0.string() }
        #expect(texts.contains("--indent"))
        #expect(texts.contains("Number of spaces to indent"))
    }

    @Test("Renders an (omitted)/true/false picker for a boolean option")
    func booleanEditor() throws {
        let option = FormatOption(
            name: "--allman",
            summary: "Allman braces",
            kind: .boolean,
            allowedValues: ["true", "false"],
            defaultValue: "false"
        )
        let view = OptionRow(option: option, config: ConfigModel())
        // Booleans are a 3-state Picker now (omitted / true / false), not a Toggle.
        _ = try view.inspect().find(ViewType.Picker.self)
    }
}
