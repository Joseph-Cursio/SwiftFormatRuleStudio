//
//  SwiftFormatBackendTests.swift
//  SwiftFormatRuleStudioCoreTests
//

import Foundation
@testable import SwiftFormatRuleStudioCore
import Testing

@Suite("SwiftFormatBackend selection")
struct SwiftFormatBackendTests {
    @Test("Defaults to the in-process backend")
    func defaultsToInProcess() throws {
        let defaults = try #require(UserDefaults(suiteName: "SwiftFormatBackendTests-default"))
        defer { defaults.removePersistentDomain(forName: "SwiftFormatBackendTests-default") }

        #expect(SwiftFormatBackend.preferred(defaults: defaults) == .inProcess)
        #expect(SwiftFormatBackend.makePreferred(defaults: defaults) is SwiftFormatInProcessActor)
    }

    @Test("Honors a stored override, ignoring an unrecognized one")
    func honorsOverride() throws {
        let name = "SwiftFormatBackendTests-override"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }

        defaults.set(SwiftFormatBackend.commandLine.rawValue, forKey: SwiftFormatBackend.defaultsKey)
        #expect(SwiftFormatBackend.preferred(defaults: defaults) == .commandLine)
        #expect(SwiftFormatBackend.makePreferred(defaults: defaults) is SwiftFormatCLIActor)

        defaults.set("nonsense", forKey: SwiftFormatBackend.defaultsKey)
        #expect(SwiftFormatBackend.preferred(defaults: defaults) == .inProcess)
    }

    /// A sandboxed process, as the environment presents it.
    private static let sandboxed = ["APP_SANDBOX_CONTAINER_ID": "com.josephcursio.SwiftFormatRuleStudio"]

    @Test("Sandboxed, the command-line override is ignored rather than honored into failure")
    func sandboxIgnoresCommandLineOverride() throws {
        let name = "SwiftFormatBackendTests-sandboxed"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(SwiftFormatBackend.commandLine.rawValue, forKey: SwiftFormatBackend.defaultsKey)

        // Unsandboxed the override stands; sandboxed it cannot work, and honoring it
        // would surface as "SwiftFormat not found — brew install swiftformat" for a
        // tool the user already has.
        #expect(SwiftFormatBackend.preferred(defaults: defaults, environment: [:]) == .commandLine)
        #expect(SwiftFormatBackend.preferred(defaults: defaults, environment: Self.sandboxed) == .inProcess)
        #expect(SwiftFormatBackend.makePreferred(defaults: defaults, environment: Self.sandboxed)
            is SwiftFormatInProcessActor)
    }

    @Test("Only the command-line backend is gated by the sandbox")
    func usabilityByEnvironment() {
        #expect(SwiftFormatBackend.inProcess.isUsable(environment: Self.sandboxed))
        #expect(SwiftFormatBackend.inProcess.isUsable(environment: [:]))
        #expect(SwiftFormatBackend.commandLine.isUsable(environment: [:]))
        #expect(SwiftFormatBackend.commandLine.isUsable(environment: Self.sandboxed) == false)
    }

    @Test("The sandbox is detected by the container variable, not guessed")
    func detectsSandbox() {
        #expect(SwiftFormatBackend.isSandboxed(environment: Self.sandboxed))
        #expect(SwiftFormatBackend.isSandboxed(environment: [:]) == false)
        #expect(SwiftFormatBackend.isSandboxed(environment: ["HOME": "/Users/someone"]) == false)
    }
}
