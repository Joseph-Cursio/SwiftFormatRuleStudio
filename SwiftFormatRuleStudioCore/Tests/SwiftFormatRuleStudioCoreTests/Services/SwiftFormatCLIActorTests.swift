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
        let fileExists: SwiftFormatFileExists = { $0 == "/usr/local/bin/swiftformat" }
        let actor = SwiftFormatCLIActor(fileExists: fileExists)
        let url = try await actor.detectPath()
        #expect(url.path == "/usr/local/bin/swiftformat")
    }

    @Test("detectPath throws notFound when no binary exists")
    func notFound() async {
        let fileExists: SwiftFormatFileExists = { _ in false }
        let actor = SwiftFormatCLIActor(fileExists: fileExists)
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
        let runner: SwiftFormatCommandRunner = { _ in (Data("0.61.1\n".utf8), Data()) }
        let actor = SwiftFormatCLIActor(commandRunner: runner)
        #expect(try await actor.version() == "0.61.1")
    }
}
