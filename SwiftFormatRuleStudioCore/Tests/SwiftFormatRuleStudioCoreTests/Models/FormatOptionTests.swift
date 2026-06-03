//
//  FormatOptionTests.swift
//  SwiftFormatRuleStudioCoreTests
//

import Testing
import Foundation
@testable import SwiftFormatRuleStudioCore

@Suite("FormatOption")
struct FormatOptionTests {
    @Test("key strips leading dashes")
    func keyStripsDashes() {
        let option = FormatOption(name: "--self", summary: "Explicit self")
        #expect(option.key == "self")
        #expect(option.id == "--self")
    }

    @Test("key handles single-dash and no-dash names")
    func keyHandlesVariants() {
        #expect(FormatOption(name: "-x", summary: "").key == "x")
        #expect(FormatOption(name: "bare", summary: "").key == "bare")
    }

    @Test("Defaults to a string option with no values")
    func defaultsToString() {
        let option = FormatOption(name: "--header", summary: "File header")
        #expect(option.kind == .string)
        #expect(option.allowedValues.isEmpty)
        #expect(option.defaultValue == nil)
    }

    @Test("FormatOption survives Codable round-trip")
    func codableRoundTrip() throws {
        let option = FormatOption(
            name: "--self",
            summary: "Explicit self: insert, remove or init-only",
            kind: .enumeration,
            allowedValues: ["insert", "remove", "init-only"],
            defaultValue: "remove"
        )
        let data = try JSONEncoder().encode(option)
        let decoded = try JSONDecoder().decode(FormatOption.self, from: data)
        #expect(decoded == option)
    }
}
