//
//  ConfigIsolationTests.swift
//  SwiftFormatRuleStudioCoreTests
//

import Foundation
@testable import SwiftFormatRuleStudioCore
import Testing

@Suite("ConfigIsolation")
@MainActor
struct ConfigIsolationTests {
    private func freshPath() -> String {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SFRSIsolation-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("isolated.swiftformat")
        try? FileManager.default.removeItem(at: url)
        return url.path
    }

    @Test("Names the config file and creates it on first use")
    func createsFileOnDemand() throws {
        let path = freshPath()
        #expect(!FileManager.default.fileExists(atPath: path))

        let isolation = ConfigIsolation(path: path)
        #expect(isolation.arguments == ["--config", path])
        #expect(FileManager.default.fileExists(atPath: path))

        let contents = try String(contentsOfFile: path, encoding: .utf8)
        #expect(contents == ConfigIsolation.fileContents)
    }

    @Test("Recreates the file if it's purged between runs")
    func recreatesPurgedFile() {
        let path = freshPath()
        let isolation = ConfigIsolation(path: path)
        _ = isolation.arguments

        try? FileManager.default.removeItem(atPath: path)
        #expect(!FileManager.default.fileExists(atPath: path))

        #expect(isolation.arguments == ["--config", path])
        #expect(FileManager.default.fileExists(atPath: path))
    }

    @Test("Disabled contributes no arguments")
    func disabledIsEmpty() {
        #expect(ConfigIsolation.disabled.arguments.isEmpty)
    }

    @Test("An unwritable location degrades to discovery rather than failing")
    func unwritableDegrades() {
        // /System is on the read-only system volume, so the write cannot succeed.
        let isolation = ConfigIsolation(path: "/System/SwiftFormatRuleStudio/isolated.swiftformat")
        #expect(isolation.arguments.isEmpty)
    }
}

/// The behavior the isolation exists for, against the linked SwiftFormat rather
/// than a mock: it must set nothing itself, it must make the app's flags beat a
/// project's `.swiftformat`, and it must survive an unreadable ancestor config.
@Suite("ConfigIsolation Integration")
@MainActor
struct ConfigIsolationIntegrationTests {
    private let cli = SwiftFormatInProcessActor()
    private let isolation = ConfigIsolation.shared
    private let source = "struct A {\nlet x = 1\n}\n"

    /// A `parent/proj` tree with `parent/.swiftformat` and one Swift file.
    private struct Tree {
        let parent: URL
        let project: URL
        let file: URL
    }

    private func makeTree(
        parentConfig: String,
        projectConfig: String? = nil
    ) throws -> Tree {
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("SFRSIsolationTree-\(UUID().uuidString)", isDirectory: true)
        let project = parent.appendingPathComponent("proj", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try parentConfig.write(
            to: parent.appendingPathComponent(".swiftformat"),
            atomically: true,
            encoding: .utf8
        )
        if let projectConfig {
            try projectConfig.write(
                to: project.appendingPathComponent(".swiftformat"),
                atomically: true,
                encoding: .utf8
            )
        }
        let file = project.appendingPathComponent("A.swift")
        try source.write(to: file, atomically: true, encoding: .utf8)
        return Tree(parent: parent, project: project, file: file)
    }

    @Test("The isolation file itself sets nothing")
    func isolationFileIsInert() async throws {
        let plain = try await cli.format(source: source, arguments: ["stdin", "--indent", "4"])
        let isolated = try await cli.format(
            source: source,
            arguments: ["stdin"] + isolation.arguments + ["--indent", "4"]
        )
        #expect(isolated == plain)
        #expect(isolated.contains("    let x"))
    }

    @Test("A project .swiftformat no longer overrides an explicit option flag")
    func explicitFlagBeatsProjectConfig() async throws {
        // A tree per leg: SwiftFormat memoizes parsed configs by directory URL in a
        // process global, and in-process that cache outlives a run — a directory read
        // without isolation keeps answering from the cache even once `--config` would
        // otherwise suppress it.
        let discoveredTree = try makeTree(parentConfig: "--indent 2\n", projectConfig: "--indent 2\n")
        let isolatedTree = try makeTree(parentConfig: "--indent 2\n", projectConfig: "--indent 2\n")
        defer {
            try? FileManager.default.removeItem(at: discoveredTree.parent)
            try? FileManager.default.removeItem(at: isolatedTree.parent)
        }

        // Without isolation the discovered file wins — the bug this fixes.
        let discovered = try await cli.format(
            source: source,
            arguments: ["stdin", "--stdin-path", discoveredTree.file.path, "--indent", "4"]
        )
        #expect(discovered.contains("  let x") && !discovered.contains("    let x"))

        // With it, the flag the user is editing wins.
        let isolated = try await cli.format(
            source: source,
            arguments: ["stdin", "--stdin-path", isolatedTree.file.path]
                + isolation.arguments + ["--indent", "4"]
        )
        #expect(isolated.contains("    let x"))
    }

    @Test("An unreadable ancestor config no longer fails the scan")
    func survivesUnreadableAncestorConfig() async throws {
        let tree = try makeTree(parentConfig: "--indent 2\n")
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o644],
                ofItemAtPath: tree.parent.appendingPathComponent(".swiftformat").path
            )
            try? FileManager.default.removeItem(at: tree.parent)
        }

        let ancestorConfig = tree.parent.appendingPathComponent(".swiftformat").path
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: ancestorConfig)
        // Running as root (some CI images) ignores the permission bits entirely.
        try #require(!FileManager.default.isReadableFile(atPath: ancestorConfig))

        // This is what a sandboxed process hits: `fileExists` says yes, the read
        // is denied, and SwiftFormat fails the whole run.
        await #expect(throws: SwiftFormatError.self) {
            try await cli.lint(path: tree.project.path, arguments: ["--lint", "--reporter", "json"])
        }

        let run = try await cli.lint(
            path: tree.project.path,
            arguments: ["--lint", "--reporter", "json"] + isolation.arguments
        )
        #expect(!LintReportParser.parse(run.reporterOutput).isEmpty)
    }
}
