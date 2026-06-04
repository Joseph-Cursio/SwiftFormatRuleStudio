//
//  SwiftFormatCLIActorTests.swift
//  SwiftFormatRuleStudioCoreTests
//

import Foundation
@testable import SwiftFormatRuleStudioCore
import Testing

@Suite("SwiftFormatCLIActor")
struct SwiftFormatCLIActorTests {
    /// A runner that echoes the joined arguments back as stdout, so tests can
    /// assert exactly which arguments each method forwards.
    private static func echoRunner() -> SwiftFormatCommandRunner {
        { args in (Data(args.joined(separator: " ").utf8), Data()) }
    }

    @Test("detectPath returns the first existing candidate")
    func detectsPath() async throws {
        let actor = SwiftFormatCLIActor(fileExists: { $0 == "/usr/local/bin/swiftformat" })
        let url = try await actor.detectPath()
        #expect(url.path == "/usr/local/bin/swiftformat")
    }

    @Test("detectPath throws notFound when no binary exists")
    func notFound() async {
        let actor = SwiftFormatCLIActor(fileExists: { _ in false })
        await #expect(throws: SwiftFormatError.notFound) {
            try await actor.detectPath()
        }
    }

    @Test("rulesOutput forwards --rules")
    func rulesArguments() async throws {
        let actor = SwiftFormatCLIActor(commandRunner: Self.echoRunner())
        #expect(try await actor.rulesOutput() == "--rules")
    }

    @Test("ruleInfoOutput forwards the rule name")
    func ruleInfoArguments() async throws {
        let actor = SwiftFormatCLIActor(commandRunner: Self.echoRunner())
        #expect(try await actor.ruleInfoOutput(ruleName: "redundantSelf") == "--ruleinfo redundantSelf")
    }

    @Test("optionsOutput forwards --options")
    func optionsArguments() async throws {
        let actor = SwiftFormatCLIActor(commandRunner: Self.echoRunner())
        #expect(try await actor.optionsOutput() == "--options")
    }

    @Test("version trims surrounding whitespace")
    func versionTrims() async throws {
        let actor = SwiftFormatCLIActor(commandRunner: { _ in (Data("0.61.1\n".utf8), Data()) })
        #expect(try await actor.version() == "0.61.1")
    }
}

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
