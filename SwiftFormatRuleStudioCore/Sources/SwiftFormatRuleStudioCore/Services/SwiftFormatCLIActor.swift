//
//  SwiftFormatCLIActor.swift
//  SwiftFormatRuleStudio
//

import Foundation
import LintStudioCore

/// Runs a `swiftformat` invocation with the given arguments, returning
/// `(stdout, stderr)`. Injected in tests to return canned fixtures.
public typealias SwiftFormatCommandRunner = @Sendable ([String]) async throws -> (Data, Data)

/// Checks whether a file exists at a path. Injected in tests.
public typealias SwiftFormatFileExists = @Sendable (String) async -> Bool

/// The result of a `swiftformat --lint` run: the machine-readable reporter output
/// (stdout) plus SwiftFormat's human run summary (stderr), which carries the
/// `N/M files require formatting` counts the JSON reporter omits.
public nonisolated struct LintRun: Sendable, Equatable {
    /// stdout — e.g. the `--reporter json` payload.
    public let reporterOutput: String
    /// stderr — the run summary line(s).
    public let summary: String

    public init(reporterOutput: String, summary: String) {
        self.reporterOutput = reporterOutput
        self.summary = summary
    }
}

/// The CLI operations the app needs from `swiftformat`.
public protocol SwiftFormatCLIProtocol: Sendable {
    /// Locates the `swiftformat` binary, throwing `.notFound` if absent.
    func detectPath() async throws -> URL
    /// Returns the installed SwiftFormat version, e.g. `"0.61.1"`.
    func version() async throws -> String
    /// Raw stdout of `swiftformat --rules`.
    func rulesOutput() async throws -> String
    /// Raw stdout of `swiftformat --ruleinfo <ruleName>`.
    func ruleInfoOutput(ruleName: String) async throws -> String
    /// Raw stdout of `swiftformat --options`.
    func optionsOutput() async throws -> String
    /// Formats `source` by piping it through `swiftformat <arguments>` (where
    /// `arguments` should begin with `stdin`), returning the formatted result.
    func format(source: String, arguments: [String]) async throws -> String
    /// Runs `swiftformat <path> <arguments>` (for `--lint --reporter json`),
    /// returning stdout (reporter output) and stderr (run summary).
    func lint(path: String, arguments: [String]) async throws -> LintRun
}

/// Errors surfaced while invoking the SwiftFormat CLI.
public enum SwiftFormatError: LocalizedError, Sendable, Equatable {
    case notFound
    case executionFailed(message: String)
    case timedOut(seconds: UInt64)

    public var errorDescription: String? {
        switch self {
        case .notFound:
            return """
            SwiftFormat not found. Install it with one of:

            • Homebrew: brew install swiftformat
            • Mint: mint install nicklockwood/SwiftFormat
            • Direct download: https://github.com/nicklockwood/SwiftFormat/releases

            After installing, restart SwiftFormat Rule Studio.
            """
        case .executionFailed(let message):
            return "SwiftFormat execution failed: \(message)"
        case .timedOut(let seconds):
            return "SwiftFormat command timed out after \(seconds) seconds."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .notFound:
            return "Install SwiftFormat with Homebrew: brew install swiftformat"
        default:
            return nil
        }
    }
}

/// Executes `swiftformat` CLI commands.
///
/// A thin wrapper over `LintStudioCore.CLIToolActor`: the shared actor owns the
/// path-detection / run / capture / timeout mechanics and the SwiftLint-modeled
/// exit-code policy, while this type keeps the SwiftFormat-specific argument
/// building, stdout selection, and `SwiftFormatError` surface. SwiftFormat's
/// `--lint` mode exits `1` when it finds issues, so `successExitCodes` is
/// `[0, 1]` rather than the SwiftLint default.
public actor SwiftFormatCLIActor: SwiftFormatCLIProtocol {
    private let tool: CLIToolActor

    public init(
        commandRunner: SwiftFormatCommandRunner? = nil,
        fileExists: SwiftFormatFileExists? = nil,
        timeoutSeconds: UInt64 = 30
    ) {
        // Bridge the app-local seams to CLIToolActor's. The injected runner has
        // no stdin/exit-code channel, so treat its output as a successful run.
        var bridgedRunner: CLIToolCommandRunner?
        if let commandRunner {
            bridgedRunner = { arguments, _ in
                let (stdout, stderr) = try await commandRunner(arguments)
                return (stdout, stderr, 0)
            }
        }
        self.tool = CLIToolActor(
            toolName: "swiftformat",
            installMessage: SwiftFormatError.notFound.errorDescription,
            timeoutSeconds: timeoutSeconds,
            successExitCodes: [0, 1],
            fileExists: fileExists,
            commandRunner: bridgedRunner
        )
    }

    // MARK: - SwiftFormatCLIProtocol

    public func detectPath() async throws -> URL {
        try await mapping { try await tool.detectPath() }
    }

    public func version() async throws -> String {
        try await run(["--version"]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func rulesOutput() async throws -> String {
        try await run(["--rules"])
    }

    public func ruleInfoOutput(ruleName: String) async throws -> String {
        try await run(["--ruleinfo", ruleName])
    }

    public func optionsOutput() async throws -> String {
        try await run(["--options"])
    }

    public func format(source: String, arguments: [String]) async throws -> String {
        try await mapping {
            try await tool.run(arguments: arguments, stdin: Data(source.utf8)).stdoutString
        }
    }

    public func lint(path: String, arguments: [String]) async throws -> LintRun {
        try await mapping {
            let result = try await tool.run(arguments: [path] + arguments)
            return LintRun(reporterOutput: result.stdoutString, summary: result.stderrString)
        }
    }

    // MARK: - Execution

    /// Runs `swiftformat <arguments>` and returns stdout. `--rules`,
    /// `--ruleinfo`, and `--options` all write their payload to stdout (stderr
    /// carries only blank lines / warnings).
    private func run(_ arguments: [String]) async throws -> String {
        try await mapping { try await tool.run(arguments: arguments).stdoutString }
    }

    /// Translates `CLIToolError` into the `SwiftFormatError` surface callers
    /// (and existing tests) expect.
    private func mapping<T>(_ body: () async throws -> T) async throws -> T {
        do {
            return try await body()
        } catch let error as CLIToolError {
            switch error {
            case .notFound:
                throw SwiftFormatError.notFound
            case .timedOut(_, let seconds):
                throw SwiftFormatError.timedOut(seconds: seconds)
            case .executionFailed(let message):
                throw SwiftFormatError.executionFailed(message: message)
            }
        }
    }
}
