//
//  ImpactIntegrationTests.swift
//  SwiftFormatRuleStudioCoreTests
//

import Foundation
@testable import SwiftFormatRuleStudioCore
import Testing

/// Exercises the real `swiftformat --lint --reporter json` end-to-end.
/// Skips cleanly when SwiftFormat is not installed.
@Suite("Impact Integration")
struct ImpactIntegrationTests {
    @MainActor
    @Test("Scans a temp workspace via the real binary")
    func scansRealWorkspace() async throws {
        let actor = SwiftFormatCLIActor()
        do {
            _ = try await actor.detectPath()
        } catch {
            return // not installed; skip
        }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SFRSScan-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try "struct  Foo{\nlet x=1\n}\n".write(
            to: directory.appendingPathComponent("Messy.swift"),
            atomically: true,
            encoding: .utf8
        )

        let model = ImpactModel(cli: actor)
        await model.runScan(path: directory)

        #expect(model.state == .completed)
        let report = try #require(model.report)
        #expect(report.totalFindings > 0)
        #expect(report.filesAffected == 1)
        #expect(report.filesChecked == 1) // parsed from SwiftFormat's run summary
        #expect(report.ruleImpacts.contains { $0.ruleID == "spaceAroundBraces" })
    }
}
