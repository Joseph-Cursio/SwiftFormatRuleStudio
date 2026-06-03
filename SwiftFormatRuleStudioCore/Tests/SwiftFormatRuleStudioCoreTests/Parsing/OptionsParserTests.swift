//
//  OptionsParserTests.swift
//  SwiftFormatRuleStudioCoreTests
//

import Testing
@testable import SwiftFormatRuleStudioCore

@Suite("OptionsParser")
struct OptionsParserTests {
    // Captured from `swiftformat --options` (0.61.1): a representative slice
    // covering each value kind plus a wrapped (name-on-its-own-line) option.
    static let fixture = """


    --acronyms         Acronyms to auto-capitalize. Defaults to "ID,URL,UUID"
    --allman           Use Allman indentation style: "true" or "false" (default)
    --allow-partial-wrapping
                       Allow partial argument wrapping: "true" (default) or "false"
    --self             Explicit self: "insert", "remove" (default) or "init-only"
    --class-threshold  Minimum line count to organize class body. Defaults to 0
    """

    private func option(_ name: String, in options: [FormatOption]) -> FormatOption {
        options.first { $0.name == name }!
    }

    @Test("Parses every option flag in the slice")
    func parsesAllNames() {
        let options = OptionsParser.parse(Self.fixture)
        #expect(options.map(\.name) == [
            "--acronyms", "--allman", "--allow-partial-wrapping",
            "--self", "--class-threshold"
        ])
    }

    @Test("Infers boolean options")
    func booleanOption() {
        let allman = option("--allman", in: OptionsParser.parse(Self.fixture))
        #expect(allman.kind == .boolean)
        #expect(allman.allowedValues == ["true", "false"])
        #expect(allman.defaultValue == "false")
    }

    @Test("Infers enumeration options with their default")
    func enumerationOption() {
        let explicitSelf = option("--self", in: OptionsParser.parse(Self.fixture))
        #expect(explicitSelf.kind == .enumeration)
        #expect(explicitSelf.allowedValues == ["insert", "remove", "init-only"])
        #expect(explicitSelf.defaultValue == "remove")
    }

    @Test("Infers list options from a comma-containing default")
    func listOption() {
        let acronyms = option("--acronyms", in: OptionsParser.parse(Self.fixture))
        #expect(acronyms.kind == .list)
        #expect(acronyms.defaultValue == "ID,URL,UUID")
    }

    @Test("Infers integer options")
    func integerOption() {
        let threshold = option("--class-threshold", in: OptionsParser.parse(Self.fixture))
        #expect(threshold.kind == .integer)
        #expect(threshold.defaultValue == "0")
    }

    @Test("Joins a wrapped option's blurb from its continuation line")
    func wrappedOptionBlurb() {
        let wrapping = option("--allow-partial-wrapping", in: OptionsParser.parse(Self.fixture))
        #expect(wrapping.summary == "Allow partial argument wrapping: \"true\" (default) or \"false\"")
        #expect(wrapping.kind == .boolean)
        #expect(wrapping.defaultValue == "true")
    }
}
