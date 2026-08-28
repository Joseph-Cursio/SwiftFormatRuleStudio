//
//  SwiftFormatBackendParityTests.swift
//  SwiftFormatRuleStudioCoreTests
//

import Foundation
@testable import SwiftFormatRuleStudioCore
import Testing

/// The in-process backend standing on its own: every surface the app's parsers
/// consume, driven through the linked SwiftFormat library with no binary present.
@Suite("SwiftFormatInProcessActor")
struct SwiftFormatInProcessActorTests {
    private static let messy = "class Foo {\n  func bar() {\n    self.baz()\n  }\n}\n"

    @Test("Reports the linked SwiftFormat version")
    func reportsVersion() async throws {
        let version = try await SwiftFormatInProcessActor().version()
        #expect(version.isEmpty == false)
        // A bare version string, not a banner or a wrapped run summary.
        #expect(version.contains("\n") == false)
        #expect(version.first?.isNumber == true)
    }

    @Test("detectPath resolves without a binary installed")
    func detectPathNeverThrows() async {
        // The formatter is linked in, so there is nothing to find and no
        // `.notFound` path — the opposite of the CLI backend's contract.
        let path = await SwiftFormatInProcessActor().detectPath()
        #expect(path.path.isEmpty == false)
    }

    @Test("RuleListParser reads the in-process rule list")
    func parsesRules() async throws {
        let rules = RuleListParser.parse(try await SwiftFormatInProcessActor().rulesOutput())
        #expect(rules.count > 100)
        #expect(rules.contains { $0.name == "redundantSelf" && !$0.isOptIn })
        #expect(rules.contains { $0.name == "acronyms" && $0.isOptIn })
        #expect(rules.contains { $0.name == "sortedImports" && $0.isDeprecated })
    }

    @Test("OptionsParser reads the in-process option list")
    func parsesOptions() async throws {
        let options = OptionsParser.parse(try await SwiftFormatInProcessActor().optionsOutput())
        #expect(options.count > 50)
        let indent = try #require(options.first { $0.name == "--indent" })
        #expect(indent.summary.contains("Number of spaces to indent"))
        let maxWidth = try #require(options.first { $0.name == "--max-width" })
        #expect(maxWidth.defaultValue == "none")
        let selfOption = try #require(options.first { $0.name == "--self" })
        #expect(selfOption.kind == .enumeration)
        #expect(selfOption.defaultValue == "remove")
        #expect(selfOption.allowedValues.contains("insert"))
    }

    @Test("RuleInfoParser reads a single rule's info")
    func parsesRuleInfo() async throws {
        let output = try await SwiftFormatInProcessActor().ruleInfoOutput(ruleName: "redundantSelf")
        let info = RuleInfoParser.parse(output)
        #expect(info.name == "redundantSelf")
        #expect(info.ruleDescription.isEmpty == false)
        #expect(info.relatedOptions.contains("--self"))
        #expect(info.example?.isEmpty == false)
    }

    @Test("RuleInfoParser reads the bulk description dump")
    func parsesBulkRuleInfo() async throws {
        let cli = SwiftFormatInProcessActor()
        let names = Set(RuleListParser.parse(try await cli.rulesOutput()).map(\.name))
        let descriptions = RuleInfoParser.descriptions(
            from: try await cli.allRuleInfoOutput(),
            knownRuleNames: names
        )
        #expect(descriptions.count > 100)
        #expect(descriptions["redundantSelf"]?.isEmpty == false)
    }

    @Test("Formats a snippet through stdin")
    func formatsViaStdin() async throws {
        let formatted = try await SwiftFormatInProcessActor().format(
            source: Self.messy,
            arguments: ["stdin", "--swift-version", "5.10"]
        )
        #expect(formatted == "class Foo {\n    func bar() {\n        baz()\n    }\n}\n")
    }

    /// The stdin hook feeds the CLI a line at a time; a source whose last line has
    /// no newline must not gain or lose one, or every diff in the live preview
    /// picks up a phantom trailing-line change.
    @Test("Preserves a source with no trailing newline")
    func formatsSourceWithoutTrailingNewline() async throws {
        let formatted = try await SwiftFormatInProcessActor().format(
            source: "let x = 1",
            arguments: ["stdin", "--swift-version", "5.10", "--fragment", "true"]
        )
        #expect(formatted == "let x = 1")
    }

    @Test("LintReportParser reads stdin lint JSON")
    func lintsViaStdin() async throws {
        let json = try await SwiftFormatInProcessActor().format(
            source: Self.messy,
            arguments: ["stdin", "--lint", "--reporter", "json", "--swift-version", "5.10"]
        )
        let findings = LintReportParser.parse(json)
        #expect(findings.isEmpty == false)
        #expect(findings.contains { $0.ruleID == "redundantSelf" })
    }

    /// SwiftFormat writes its "Running SwiftFormat..." banner and run summary to
    /// stderr. If the stream mapping put those on stdout they would land inside the
    /// parsed payload — output that still *looks* like the CLI's but no longer parses.
    @Test("Keeps the run banner out of stdout, on the lint summary")
    func splitsStreams() async throws {
        let directory = try Self.makeFixtureDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let result = try await SwiftFormatInProcessActor().lint(
            path: directory.path,
            arguments: ["--lint", "--reporter", "json", "--rules", "redundantSelf", "--swift-version", "5.10"]
        )
        #expect(result.reporterOutput.contains("Running SwiftFormat") == false)
        #expect(result.reporterOutput.hasPrefix("["))
        #expect(result.summary.contains("Running SwiftFormat"))
        // The `N/M files require formatting` count ImpactModel reads off stderr.
        #expect(result.summary.contains("SwiftFormat completed"))

        let findings = LintReportParser.parse(result.reporterOutput)
        #expect(findings.contains { $0.ruleID == "redundantSelf" })
        #expect(findings.allSatisfy { $0.filePath.isEmpty == false })
    }

    @Test("Surfaces a bad invocation as executionFailed")
    func reportsInvalidArguments() async {
        await #expect(throws: SwiftFormatError.self) {
            _ = try await SwiftFormatInProcessActor().ruleInfoOutput(ruleName: "noSuchRuleExists")
        }
    }

    /// `CLI.print`/`CLI.readLine` are process globals shared by every instance, so
    /// overlapping runs are the failure mode to guard: without the lock they capture
    /// each other's output.
    @Test("Concurrent runs across instances keep their output separate")
    func concurrentRunsDoNotInterleave() async throws {
        // Separate instances, so the guarantee under test is the process-wide lock
        // rather than one actor's isolation. (Built here because the initializer
        // inherits `@MainActor` from the protocol conformance.)
        let clients = (0 ..< 8).map { _ in SwiftFormatInProcessActor() }
        let results = await withTaskGroup(of: String.self) { group in
            for (index, cli) in clients.enumerated() {
                group.addTask {
                    let output = index.isMultiple(of: 2)
                        ? try? await cli.rulesOutput()
                        : try? await cli.optionsOutput()
                    return output ?? ""
                }
            }
            var collected: [String] = []
            for await result in group {
                collected.append(result)
            }
            return collected
        }

        let rules = results.filter { $0.contains("redundantSelf") }
        let options = results.filter { $0.contains("--indent") }
        #expect(rules.count == 4)
        #expect(options.count == 4)
        // Each capture is one command's output, never two concatenated.
        #expect(rules.allSatisfy { !$0.contains("--indent") })
        #expect(options.allSatisfy { !$0.contains("redundantSelf") })
    }

    private static func makeFixtureDirectory() throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("InProcessLint-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try messy.write(
            to: directory.appendingPathComponent("Fixture.swift"),
            atomically: true,
            encoding: .utf8
        )
        return directory
    }
}

/// The claim the migration rests on: driving the linked library's own CLI produces
/// the same bytes the subprocess did, so the parsers written against `swiftformat`
/// output keep working. Skips when SwiftFormat is not installed, or when the
/// installed binary is a different version than the linked one (where a byte
/// difference would be SwiftFormat's own change, not a backend defect).
@Suite("SwiftFormat backend parity")
struct SwiftFormatBackendParityTests {
    private let inProcess = SwiftFormatInProcessActor()
    private let subprocess = SwiftFormatCLIActor()

    /// Both backends' versions, or `nil` when the comparison isn't meaningful here.
    private func matchedVersions() async -> String? {
        guard (try? await subprocess.detectPath()) != nil,
              let installed = try? await subprocess.version(),
              let linked = try? await inProcess.version(),
              installed == linked else {
            return nil
        }
        return linked
    }

    @Test("--rules, --options and --ruleinfo are byte-identical")
    func catalogSurfacesMatch() async throws {
        guard await matchedVersions() != nil else { return }

        #expect(try await inProcess.rulesOutput() == subprocess.rulesOutput())
        #expect(try await inProcess.optionsOutput() == subprocess.optionsOutput())
        #expect(try await inProcess.allRuleInfoOutput() == subprocess.allRuleInfoOutput())
        #expect(
            try await inProcess.ruleInfoOutput(ruleName: "redundantSelf")
                == subprocess.ruleInfoOutput(ruleName: "redundantSelf")
        )
    }

    @Test("stdin formatting and stdin lint JSON are byte-identical")
    func stdinSurfacesMatch() async throws {
        guard await matchedVersions() != nil else { return }

        let source = "class Foo {\n  func bar() {\n    self.baz()\n  }\n}\n"
        let formatArguments = ["stdin", "--swift-version", "5.10"]
        #expect(
            try await inProcess.format(source: source, arguments: formatArguments)
                == subprocess.format(source: source, arguments: formatArguments)
        )

        let lintArguments = formatArguments + ["--lint", "--reporter", "json"]
        #expect(
            try await inProcess.format(source: source, arguments: lintArguments)
                == subprocess.format(source: source, arguments: lintArguments)
        )
    }

    /// Compared as a set of findings rather than as bytes: file enumeration order is
    /// SwiftFormat's business (and cache-sensitive), while the findings are the
    /// contract `ImpactModel` and `TuneModel` actually consume.
    @Test("Directory lint reports the same findings")
    func directoryLintMatches() async throws {
        guard await matchedVersions() != nil else { return }

        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("BackendParity-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try "class Foo {\n  func bar() {\n    self.baz()\n  }\n}\n".write(
            to: directory.appendingPathComponent("Fixture.swift"),
            atomically: true,
            encoding: .utf8
        )

        let arguments = ["--lint", "--reporter", "json", "--swift-version", "5.10"]
        let mine = LintReportParser.parse(
            try await inProcess.lint(path: directory.path, arguments: arguments).reporterOutput
        )
        let theirs = LintReportParser.parse(
            try await subprocess.lint(path: directory.path, arguments: arguments).reporterOutput
        )

        #expect(mine.isEmpty == false)
        let key = { (finding: LintFinding) in "\(finding.filePath):\(finding.line):\(finding.ruleID)" }
        #expect(Set(mine.map(key)) == Set(theirs.map(key)))
    }
}

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
}
