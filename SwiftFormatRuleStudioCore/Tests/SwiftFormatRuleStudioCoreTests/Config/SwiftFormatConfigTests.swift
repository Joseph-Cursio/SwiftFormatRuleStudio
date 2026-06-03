//
//  SwiftFormatConfigTests.swift
//  SwiftFormatRuleStudioCoreTests
//

import Testing
import Foundation
@testable import SwiftFormatRuleStudioCore

@Suite("SwiftFormatConfig")
struct SwiftFormatConfigTests {
    static let sample = """
    # Formatting options
    --indent 4
    --self remove
    --swift-version 5.10

    # Rules
    --disable redundantSelf,redundantParens
    --enable isEmpty
    """

    // MARK: - Round-trip

    @Test("Parsing then serializing round-trips exactly")
    func roundTrip() {
        #expect(SwiftFormatConfig.parse(Self.sample).serialized() == Self.sample)
    }

    @Test("Round-trips a trailing newline and indented comments")
    func roundTripEdges() {
        let text = "--indent 2\n  # indented comment\n\n"
        #expect(SwiftFormatConfig.parse(text).serialized() == text)
    }

    // MARK: - Semantic view

    @Test("Reads options, disabled, enabled rules")
    func semanticView() {
        let config = SwiftFormatConfig.parse(Self.sample)
        #expect(config.options["indent"] == "4")
        #expect(config.options["self"] == "remove")
        #expect(config.options["swift-version"] == "5.10")
        #expect(config.disabledRules == ["redundantSelf", "redundantParens"])
        #expect(config.enabledRules == ["isEmpty"])
        #expect(config.explicitRules == nil)
    }

    @Test("Reads a --rules allowlist")
    func explicitRules() {
        let config = SwiftFormatConfig.parse("--rules indent,linebreaks,redundantSelf")
        #expect(config.explicitRules == ["indent", "linebreaks", "redundantSelf"])
    }

    // MARK: - Option editing

    @Test("setOption updates in place, preserving position and other lines")
    func setOptionInPlace() {
        var config = SwiftFormatConfig.parse(Self.sample)
        config.setOption(key: "indent", value: "2")

        #expect(config.options["indent"] == "2")
        // Only the indent line changed; everything else identical.
        #expect(config.serialized() == Self.sample.replacingOccurrences(of: "--indent 4", with: "--indent 2"))
    }

    @Test("setOption appends a new option above trailing blanks")
    func setOptionAppend() {
        var config = SwiftFormatConfig.parse("--indent 4\n")
        config.setOption(key: "self", value: "remove")
        #expect(config.serialized() == "--indent 4\n--self remove\n")
    }

    @Test("setOption de-duplicates repeated keys")
    func setOptionDedup() {
        var config = SwiftFormatConfig.parse("--indent 2\n--indent 4")
        config.setOption(key: "indent", value: "8")
        #expect(config.serialized() == "--indent 8")
        #expect(config.options["indent"] == "8")
    }

    @Test("removeOption deletes the line")
    func removeOption() {
        var config = SwiftFormatConfig.parse("--indent 4\n--self remove")
        config.removeOption(key: "self")
        #expect(config.serialized() == "--indent 4")
    }

    // MARK: - Rule editing

    @Test("disableRule adds to --disable and drops from --enable")
    func disableRule() {
        var config = SwiftFormatConfig.parse("--enable isEmpty,redundantSelf")
        config.disableRule("redundantSelf")

        #expect(config.disabledRules.contains("redundantSelf"))
        #expect(config.enabledRules == ["isEmpty"])
    }

    @Test("disableRule creates a directive when none exists")
    func disableRuleCreates() {
        var config = SwiftFormatConfig.parse("--indent 4")
        config.disableRule("redundantSelf")
        #expect(config.serialized() == "--indent 4\n--disable redundantSelf")
    }

    @Test("disableRule appends to an existing --disable directive")
    func disableRuleAppends() {
        var config = SwiftFormatConfig.parse("--disable redundantParens")
        config.disableRule("redundantSelf")
        #expect(config.serialized() == "--disable redundantParens,redundantSelf")
    }

    @Test("enableRule adds to --enable and drops from --disable")
    func enableRule() {
        var config = SwiftFormatConfig.parse("--disable isEmpty")
        config.enableRule("isEmpty")
        #expect(config.disabledRules.isEmpty)
        #expect(config.enabledRules == ["isEmpty"])
    }

    @Test("clearRuleOverride removes both enable and disable entries")
    func clearOverride() {
        var config = SwiftFormatConfig.parse("--disable redundantSelf\n--enable redundantSelf")
        config.clearRuleOverride("redundantSelf")
        #expect(config.disabledRules.isEmpty)
        #expect(config.enabledRules.isEmpty)
        // Both emptied directives are dropped.
        #expect(config.serialized() == "")
    }

    @Test("Disabling is idempotent")
    func disableIdempotent() {
        var config = SwiftFormatConfig.parse("--disable redundantSelf")
        config.disableRule("redundantSelf")
        #expect(config.serialized() == "--disable redundantSelf")
    }
}
