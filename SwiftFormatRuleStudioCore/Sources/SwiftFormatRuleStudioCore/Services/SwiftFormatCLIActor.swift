//
//  SwiftFormatCLIActor.swift
//  SwiftFormatRuleStudio
//

import Foundation

/// Runs a `swiftformat` invocation with the given arguments, returning
/// `(stdout, stderr)`. Injected in tests to return canned fixtures.
public typealias SwiftFormatCommandRunner = @Sendable ([String]) async throws -> (Data, Data)

/// Checks whether a file exists at a path. Injected in tests.
public typealias SwiftFormatFileExists = @Sendable (String) async -> Bool

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
/// App-local for now. The generic process-running mechanics (path detection,
/// run + capture + timeout) are a future promotion candidate to
/// `LintStudioCore`'s `CLIToolActor` once the shared shape settles; the
/// SwiftFormat-specific argument building and stream selection stay here.
public actor SwiftFormatCLIActor: SwiftFormatCLIProtocol {
    private var cachedPath: URL?
    private let commandRunner: SwiftFormatCommandRunner?
    private let fileExists: SwiftFormatFileExists
    private let timeoutSeconds: UInt64

    /// Standard install locations, most common first.
    private nonisolated static let candidatePaths = [
        "/opt/homebrew/bin/swiftformat", // Apple Silicon Homebrew
        "/usr/local/bin/swiftformat",    // Intel Homebrew
        "/usr/bin/swiftformat"           // System
    ]

    public init(
        commandRunner: SwiftFormatCommandRunner? = nil,
        fileExists: SwiftFormatFileExists? = nil,
        timeoutSeconds: UInt64 = 30
    ) {
        self.commandRunner = commandRunner
        self.fileExists = fileExists ?? { FileManager.default.fileExists(atPath: $0) }
        self.timeoutSeconds = timeoutSeconds
    }

    // MARK: - SwiftFormatCLIProtocol

    public func detectPath() async throws -> URL {
        if let cachedPath, await fileExists(cachedPath.path) {
            return cachedPath
        }
        cachedPath = nil

        for path in Self.candidatePaths where await fileExists(path) {
            let url = URL(fileURLWithPath: path)
            cachedPath = url
            return url
        }
        throw SwiftFormatError.notFound
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

    // MARK: - Execution

    /// Runs `swiftformat <arguments>` and returns stdout as a UTF-8 string.
    /// `--rules`, `--ruleinfo`, and `--options` all write their payload to
    /// stdout (stderr carries only blank lines / warnings).
    private func run(_ arguments: [String]) async throws -> String {
        let (stdout, _) = try await capture(arguments)
        return String(data: stdout, encoding: .utf8) ?? ""
    }

    private func capture(_ arguments: [String]) async throws -> (Data, Data) {
        if let commandRunner {
            return try await commandRunner(arguments)
        }
        let binary = try await detectPath()
        return try await Self.runProcess(
            executable: binary,
            arguments: arguments,
            timeoutSeconds: timeoutSeconds
        )
    }

    /// Launches a process, capturing stdout/stderr with a timeout. `nonisolated`
    /// static so it does not capture actor state.
    nonisolated static func runProcess(
        executable: URL,
        arguments: [String],
        timeoutSeconds: UInt64
    ) async throws -> (Data, Data) {
        try await withThrowingTaskGroup(of: (Data, Data).self) { group in
            group.addTask {
                try runProcessBlocking(executable: executable, arguments: arguments)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: timeoutSeconds * 1_000_000_000)
                throw SwiftFormatError.timedOut(seconds: timeoutSeconds)
            }
            guard let result = try await group.next() else {
                throw SwiftFormatError.executionFailed(message: "No output produced.")
            }
            group.cancelAll()
            return result
        }
    }

    private nonisolated static func runProcessBlocking(
        executable: URL,
        arguments: [String]
    ) throws -> (Data, Data) {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            throw SwiftFormatError.executionFailed(message: error.localizedDescription)
        }

        // Read both pipes fully before waiting to avoid deadlock on large output.
        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return (stdoutData, stderrData)
    }
}
