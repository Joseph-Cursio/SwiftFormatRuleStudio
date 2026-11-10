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
