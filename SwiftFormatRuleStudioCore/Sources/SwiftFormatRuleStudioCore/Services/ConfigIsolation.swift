//
//  ConfigIsolation.swift
//  SwiftFormatRuleStudio
//

import Foundation

/// The `--config` argument that pins SwiftFormat to the config the app is holding,
/// suppressing its implicit `.swiftformat` discovery.
///
/// Left to itself, SwiftFormat reads a `.swiftformat` from every *ancestor* directory
/// of the target (`gatherOptions`) and from every directory it descends into. Both are
/// wrong for this app, for two independent reasons:
///
/// - **Precedence.** A discovered file *overrides* the options passed on the command
///   line. So an unsaved edit in the Options panel loses to whatever is on disk, and
///   the preview answers a question the user didn't ask — the one thing the live
///   preview exists to get right.
/// - **Sandboxing.** The ancestor walk reads any file `fileExists` reports, and a
///   sandboxed process is told `true` for files it may not read: the read throws and
///   the entire run fails with no results. See `docs/sandbox-scope.md`.
///
/// Passing `--config` at an otherwise-empty file suppresses discovery entirely — with
/// `options.configURLs` set, SwiftFormat logs *"Ignoring config file at …"* instead of
/// reading. The app already passes the whole config as flags
/// (`SwiftFormatConfig.commandLineArguments`), so those flags become the single source
/// of truth. That also fixes the subtler half of the precedence problem: an option the
/// user *removed* in the panel, which a discovered file would otherwise keep applying.
///
/// The trade-off this accepts: `.swiftformat` files in *sub*directories of a scanned
/// workspace no longer apply either. The scan reports what the edited config would do,
/// uniformly, rather than blending in per-directory overrides the panel can't show.
nonisolated public struct ConfigIsolation: Sendable {
    /// Where the empty config lives, or `nil` to leave discovery alone.
    private let path: String?

    /// Creates an isolation backed by the file at `path`; `nil` disables it.
    public init(path: String?) {
        self.path = path
    }

    /// The app's isolation file, under the temporary directory — which the sandbox
    /// redirects into the app container, so this keeps working once sandboxed.
    public static let shared = Self(path: defaultPath)

    /// Leaves SwiftFormat's implicit discovery in place. The fallback when the file
    /// can't be written, and what tests use when asserting the other flags.
    public static let disabled = Self(path: nil)

    /// `["--config", path]`, or `[]` when isolation is off or the file can't be
    /// created — in which case the app degrades to SwiftFormat's own discovery
    /// rather than failing the run.
    public var arguments: [String] {
        guard let path, Self.ensureFileExists(at: path) else { return [] }
        return ["--config", path]
    }

    private static let defaultPath: String = FileManager.default.temporaryDirectory
        .appendingPathComponent("SwiftFormatRuleStudio", isDirectory: true)
        .appendingPathComponent("isolated.swiftformat")
        .path

    /// The file's contents: comments only, so it sets nothing. Written for whoever
    /// finds it on disk and wonders what it is.
    static let fileContents = """
    # SwiftFormat Rule Studio writes this file so it can pass `--config` and stop
    # SwiftFormat from discovering `.swiftformat` files on its own. It is meant to
    # be empty — every setting is passed on the command line instead.

    """

    /// Creates the file when it isn't there. It lives in a directory the system may
    /// purge between runs, so this is checked on every use rather than once.
    private static func ensureFileExists(at path: String) -> Bool {
        let manager = FileManager.default
        if manager.fileExists(atPath: path) { return true }
        let url = URL(fileURLWithPath: path)
        do {
            try manager.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try fileContents.write(to: url, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }
}
