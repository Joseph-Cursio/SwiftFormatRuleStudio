//
//  SwiftFormatInProcessActor.swift
//  SwiftFormatRuleStudio
//

import Foundation
// SwiftFormat is a Swift 5-language-mode module whose CLI hooks (`CLI.print`,
// `CLI.readLine`) are non-isolated global `var`s, which Swift 6 rejects outright.
// `@preconcurrency` accepts them; `runLocked` below supplies the serialization
// their shared-mutable-state warning is actually about.
@preconcurrency import SwiftFormat

/// Runs SwiftFormat **in-process**, by driving the `SwiftFormat` library's own
/// command-line front end (`CLI.run`) instead of spawning the `swiftformat`
/// binary — see [`docs/in-process-backend-scope.md`](../../../../docs/in-process-backend-scope.md).
///
/// This is not a reimplementation of the CLI: it *is* the CLI, linked in and
/// called directly, with `CLI.print` capturing what would have been stdout/stderr.
/// The output is byte-identical to the subprocess for every surface the app uses,
/// so `RuleListParser`, `OptionsParser`, `RuleInfoParser`, and `LintReportParser`
/// all keep working against it unchanged (`SwiftFormatBackendParityTests`).
///
/// Why it exists: a sandboxed app may not spawn an external executable, so the
/// shell-out path cannot ship on the Mac App Store at all. In-process also drops
/// the "user must `brew install swiftformat`" prerequisite and loads the catalog
/// ~40× faster (three function calls, not three process spawns).
///
/// **Trade-off vs. `SwiftFormatCLIActor`:** `CLI.run` is a synchronous call that
/// cannot be cancelled or timed out — a wedged run has no recovery, where a
/// subprocess could be killed. `SwiftFormatError.timedOut` is therefore never
/// thrown by this backend.
public actor SwiftFormatInProcessActor: SwiftFormatCLIProtocol {
    /// One in-process CLI invocation's result: the text the subprocess would have
    /// written to each stream, plus the exit code it would have returned.
    nonisolated private struct CLIOutput {
        let stdout: String
        let stderr: String
        let code: Int32
    }

    /// `CLI.print` / `CLI.readLine` / SwiftFormat's `quietMode` are *process*
    /// globals, so serialization has to be process-wide: actor isolation alone
    /// would still let two instances interleave their output hooks.
    nonisolated private static let cliLock = NSLock()

    /// The directory `CLI.run` resolves relative paths and implicit `.swiftformat`
    /// discovery against — the process working directory, matching what the
    /// subprocess backend inherited.
    private let workingDirectory: String

    /// SwiftFormat exits `1` when `--lint` finds issues, so that is a success here
    /// exactly as it is for `SwiftFormatCLIActor`.
    nonisolated private static let successExitCodes: Set<Int32> = [0, 1]

    public init(workingDirectory: String = FileManager.default.currentDirectoryPath) {
        self.workingDirectory = workingDirectory
    }

    // MARK: - SwiftFormatCLIProtocol

    /// There is no external binary to find: the formatter is linked into this
    /// executable, so that is the honest answer. Never throws `.notFound`.
    public func detectPath() -> URL {
        Bundle.main.executableURL ?? Bundle.main.bundleURL
    }

    public func version() throws -> String {
        try run(["--version"]).stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func rulesOutput() throws -> String {
        try run(["--rules"]).stdout
    }

    public func ruleInfoOutput(ruleName: String) throws -> String {
        try run(["--ruleinfo", ruleName]).stdout
    }

    public func allRuleInfoOutput() throws -> String {
        try run(["--ruleinfo"]).stdout
    }

    public func optionsOutput() throws -> String {
        try run(["--options"]).stdout
    }

    public func format(source: String, arguments: [String]) throws -> String {
        try run(arguments, stdin: source).stdout
    }

    public func lint(path: String, arguments: [String]) throws -> LintRun {
        let result = try run([path] + arguments)
        return LintRun(reporterOutput: result.stdout, summary: result.stderr)
    }

    // MARK: - Execution

    /// Runs `swiftformat <arguments>` in-process, returning the text the
    /// subprocess would have written to stdout and stderr.
    private func run(
        _ arguments: [String],
        stdin: String? = nil
    ) throws -> (stdout: String, stderr: String) {
        let result = Self.runLocked(
            arguments: ["swiftformat"] + arguments,
            stdin: stdin,
            in: workingDirectory
        )
        guard Self.successExitCodes.contains(result.code) else {
            // stderr carries SwiftFormat's `error:` lines; fall back to stdout so a
            // failure never surfaces as an empty message.
            let message = result.stderr.isEmpty ? result.stdout : result.stderr
            throw SwiftFormatError.executionFailed(
                message: message.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        return (result.stdout, result.stderr)
    }

    /// Installs the output/input hooks and runs the CLI, holding `cliLock` for the
    /// whole call so concurrent runs cannot capture each other's output.
    ///
    /// The stream split mirrors SwiftFormat's own `CommandLineTool/main.swift`
    /// exactly: `.content` prints with a newline and `.raw` without, both to
    /// stdout; `.info` / `.success` / `.error` / `.warning` go to stderr. Getting
    /// this wrong is what makes output *look* like the CLI's while differing —
    /// e.g. the "Running SwiftFormat..." banner landing in the parsed payload.
    nonisolated private static func runLocked(
        arguments: [String],
        stdin: String?,
        in directory: String
    ) -> CLIOutput {
        cliLock.lock()
        defer { cliLock.unlock() }

        var stdout = ""
        var stderr = ""
        CLI.print = { message, type in
            switch type {
            case .content: stdout += message + "\n"
            case .raw: stdout += message
            case .info, .success, .error, .warning: stderr += message + "\n"
            }
        }
        CLI.readLine = stdin.map(makeLineReader) ?? { nil }
        defer {
            // Leave no closure capturing this run's buffers installed globally.
            CLI.print = { _, _ in }
            CLI.readLine = { nil }
        }

        let code = CLI.run(in: directory, with: arguments)
        return CLIOutput(stdout: stdout, stderr: stderr, code: code.rawValue)
    }

    /// Feeds `source` to the CLI a line at a time, each with its terminating
    /// newline — the contract `CLI.readLine` expects. Byte-preserving: a source
    /// with no trailing newline yields a final line with none, so formatting
    /// through stdin round-trips exactly as it does through a pipe.
    nonisolated private static func makeLineReader(_ source: String) -> () -> String? {
        var remaining = Substring(source)
        return {
            guard !remaining.isEmpty else { return nil }
            guard let newline = remaining.firstIndex(of: "\n") else {
                defer { remaining = "" }
                return String(remaining)
            }
            let line = remaining[...newline]
            remaining = remaining[remaining.index(after: newline)...]
            return String(line)
        }
    }
}
