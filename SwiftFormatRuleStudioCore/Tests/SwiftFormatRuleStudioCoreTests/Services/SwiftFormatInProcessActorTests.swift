//
//  SwiftFormatInProcessActorTests.swift
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

    @Test("A bad invocation's message is SwiftFormat's error line, not the empty stdout")
    func invalidArgumentsMessage() async {
        do {
            _ = try await SwiftFormatInProcessActor().ruleInfoOutput(ruleName: "noSuchRuleExists")
            Issue.record("expected executionFailed")
        } catch let SwiftFormatError.executionFailed(message) {
            #expect(message.contains("noSuchRuleExists"), "message: \(message)")
        } catch {
            Issue.record("unexpected error \(error)")
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
