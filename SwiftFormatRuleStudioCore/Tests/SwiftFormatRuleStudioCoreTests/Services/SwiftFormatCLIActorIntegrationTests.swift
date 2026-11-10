//
//  SwiftFormatCLIActorIntegrationTests.swift
//  SwiftFormatRuleStudioCoreTests
//

import Foundation
@testable import SwiftFormatRuleStudioCore
import Testing

/// Exercises the real `swiftformat` binary end-to-end through the parsers.
/// Skips cleanly when SwiftFormat is not installed.
@Suite("SwiftFormatCLIActor Integration")
struct SwiftFormatCLIActorIntegrationTests {
    @Test("Loads rules, ruleinfo and options from the installed binary")
    func loadsCatalogFromRealBinary() async throws {
        let actor = SwiftFormatCLIActor()

        let path: URL
        do {
            path = try await actor.detectPath()
        } catch {
            return // SwiftFormat not installed in this environment; skip.
        }
        #expect(FileManager.default.fileExists(atPath: path.path))

        let version = try await actor.version()
        #expect(version.isEmpty == false)

        let rules = RuleListParser.parse(try await actor.rulesOutput())
        #expect(rules.count > 100)
        #expect(rules.contains { $0.name == "redundantSelf" })
        #expect(rules.contains { $0.name == "acronyms" && $0.isOptIn })

        let info = RuleInfoParser.parse(try await actor.ruleInfoOutput(ruleName: "andOperator"))
        #expect(info.name == "andOperator")
        #expect(info.ruleDescription.isEmpty == false)
        #expect(info.example?.isEmpty == false)

        let options = OptionsParser.parse(try await actor.optionsOutput())
        #expect(options.contains { $0.name == "--self" })
        #expect(options.contains { $0.name == "--indent" })
    }
}
