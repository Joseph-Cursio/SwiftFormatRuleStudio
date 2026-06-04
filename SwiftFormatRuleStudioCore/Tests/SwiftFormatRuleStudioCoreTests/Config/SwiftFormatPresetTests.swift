//
//  SwiftFormatPresetTests.swift
//  SwiftFormatRuleStudioCoreTests
//

@testable import SwiftFormatRuleStudioCore
import Testing

@Suite("SwiftFormatPreset")
struct SwiftFormatPresetTests {
    @Test("Built-in presets are distinct and non-empty")
    func presetsWellFormed() {
        let presets = BuiltInPresets.all
        #expect(presets.count == 3)
        #expect(Set(presets.map(\.id)).count == presets.count)
        #expect(presets.allSatisfy { !$0.configText.isEmpty })
    }

    @Test("Standard preset sets 4-space indentation")
    func standardPreset() {
        let config = SwiftFormatConfig.parse(BuiltInPresets.standard.configText)
        #expect(config.options["indent"] == "4")
        #expect(config.options["swift-version"] == "5.10")
    }

    @Test("Compact preset uses 2-space indentation")
    func compactPreset() {
        let config = SwiftFormatConfig.parse(BuiltInPresets.compact.configText)
        #expect(config.options["indent"] == "2")
    }

    @Test("Opinionated preset enables opt-in rules and removes self")
    func opinionatedPreset() {
        let config = SwiftFormatConfig.parse(BuiltInPresets.opinionated.configText)
        #expect(config.options["self"] == "remove")
        #expect(config.enabledRules.contains("isEmpty"))
        #expect(config.enabledRules.contains("organizeDeclarations"))
    }
}
