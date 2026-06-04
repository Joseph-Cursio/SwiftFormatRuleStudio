//
//  ConfigModelTests.swift
//  SwiftFormatRuleStudioCoreTests
//

import Foundation
@testable import SwiftFormatRuleStudioCore
import Testing

@Suite("ConfigModel")
@MainActor
struct ConfigModelTests {
    /// A unique temp directory for isolated file I/O.
    private func makeTempDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SFRSConfigTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func writeConfig(_ text: String, in directory: URL) throws -> URL {
        let url = directory.appendingPathComponent(".swiftformat")
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    @Test("Loading parses the file and starts clean")
    func loadsCleanly() throws {
        let directory = try makeTempDirectory()
        let url = try writeConfig("--indent 4\n--disable redundantSelf", in: directory)

        let model = ConfigModel()
        model.load(from: url)

        #expect(model.config.options["indent"] == "4")
        #expect(model.isDirty == false)
        #expect(model.diff.allSatisfy { $0.change == .unchanged })
    }

    @Test("Loading a missing file yields an empty config rooted at the path")
    func loadsMissing() throws {
        let directory = try makeTempDirectory()
        let url = directory.appendingPathComponent(".swiftformat")

        let model = ConfigModel()
        model.load(from: url)

        #expect(model.configPath == url)
        #expect(model.config.lines.isEmpty)
        #expect(model.canSave == false) // nothing to save yet
    }

    @Test("Editing marks the model dirty and produces a diff")
    func editingIsDirty() throws {
        let directory = try makeTempDirectory()
        let url = try writeConfig("--indent 4", in: directory)
        let model = ConfigModel()
        model.load(from: url)

        model.setOption(key: "indent", value: "2")

        #expect(model.isDirty)
        #expect(model.canSave)
        #expect(model.diff.contains { $0.change == .added })
        #expect(model.diff.contains { $0.change == .removed })
    }

    @Test("Saving writes the file, backs up the old one, and resets the baseline")
    func savesWithBackup() throws {
        let directory = try makeTempDirectory()
        let url = try writeConfig("--indent 4", in: directory)
        let model = ConfigModel()
        model.load(from: url)
        model.setOption(key: "indent", value: "2")

        #expect(model.save())
        #expect(model.isDirty == false)

        let onDisk = try String(contentsOf: url, encoding: .utf8)
        #expect(onDisk == "--indent 2")

        // A timestamped .backup of the original was created.
        let backups = try FileManager.default
            .contentsOfDirectory(atPath: directory.path)
            .filter { $0.contains(".backup") }
        #expect(backups.isEmpty == false)
    }

    @Test("revert discards edits")
    func reverts() throws {
        let directory = try makeTempDirectory()
        let url = try writeConfig("--indent 4", in: directory)
        let model = ConfigModel()
        model.load(from: url)

        model.setOption(key: "indent", value: "2")
        model.revert()

        #expect(model.isDirty == false)
        #expect(model.config.options["indent"] == "4")
    }

    @Test("setRuleEnabled keeps the config minimal")
    func ruleEnablementMinimal() {
        let model = ConfigModel()
        model.load(from: nil)

        // Disable a default-on rule → recorded in --disable.
        model.setRuleEnabled("redundantSelf", enabled: false, isOptIn: false)
        #expect(model.config.disabledRules.contains("redundantSelf"))
        #expect(model.isRuleEnabled("redundantSelf", isOptIn: false) == false)

        // Re-enable it (back to default) → override cleared, nothing written.
        model.setRuleEnabled("redundantSelf", enabled: true, isOptIn: false)
        #expect(model.config.disabledRules.isEmpty)
        #expect(model.config.serialized().isEmpty)

        // Enable an opt-in rule → recorded in --enable.
        model.setRuleEnabled("isEmpty", enabled: true, isOptIn: true)
        #expect(model.config.enabledRules.contains("isEmpty"))
        #expect(model.isRuleEnabled("isEmpty", isOptIn: true))
    }

    @Test("commandLineArguments reflect edits")
    func argumentsReflectEdits() {
        let model = ConfigModel()
        model.load(from: nil)
        model.setOption(key: "indent", value: "4")
        model.setRuleEnabled("redundantSelf", enabled: false, isOptIn: false)

        #expect(model.commandLineArguments == ["--indent", "4", "--disable", "redundantSelf"])
    }
}
