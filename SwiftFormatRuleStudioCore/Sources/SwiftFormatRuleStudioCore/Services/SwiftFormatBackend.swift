//
//  SwiftFormatBackend.swift
//  SwiftFormatRuleStudio
//

import Foundation

/// Which SwiftFormat implementation the app runs against.
///
/// Both conform to `SwiftFormatCLIProtocol` and produce byte-identical output, so
/// this is purely a deployment choice:
///
/// - ``inProcess`` — the linked SwiftFormat library (default). Sandbox-safe, no
///   Homebrew prerequisite, much faster catalog load, version fixed at link time.
/// - ``commandLine`` — spawns an external `swiftformat` binary. Reports whatever
///   version the user has installed, and supports timeouts; kept because
///   *running a version other than the linked one* is the foundation of the
///   version-upgrade diff in [`docs/config-inference.md`](../../../../docs/config-inference.md).
///
/// Left at the package's default `@MainActor` isolation: both backends' initializers
/// inherit it from their `SwiftFormatCLIProtocol` conformance, and every caller is a
/// `@MainActor` model using this as a default argument — exactly where the literal
/// `SwiftFormatCLIActor()` it replaced was constructed.
public enum SwiftFormatBackend: String, Sendable, CaseIterable {
    case inProcess
    case commandLine

    /// `UserDefaults` key overriding the default backend, so the CLI path stays
    /// reachable for support and A/B checks without a rebuild.
    public static let defaultsKey = "swiftFormatBackend"

    /// Whether this process runs under App Sandbox, where ``commandLine`` cannot
    /// work: the `swiftformat` binary lives outside the container, so the spawn
    /// fails — and fails *misleadingly*, as `NSCocoaErrorDomain` 4 ("no such file"),
    /// which the app reports as `.notFound` and offers to fix with
    /// `brew install swiftformat`. That would send a user to reinstall a tool they
    /// already have, to fix a problem that isn't installation.
    ///
    /// `APP_SANDBOX_CONTAINER_ID` is set to the bundle identifier for a sandboxed
    /// process and absent otherwise (measured both ways; see
    /// `docs/sandbox-scope.md` §1).
    nonisolated public static func isSandboxed(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }

    /// The backend to use: the override if one is set, valid, and *usable*, else
    /// ``inProcess``.
    ///
    /// A `commandLine` override is ignored under sandbox rather than honored into a
    /// guaranteed failure. The override exists for support and A/B checks against a
    /// user-supplied binary — the foundation of the version-upgrade diff in
    /// `docs/config-inference.md` — and that is a non-sandboxed build's feature.
    public static func preferred(
        defaults: UserDefaults = .standard,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Self {
        guard let raw = defaults.string(forKey: defaultsKey),
              let backend = Self(rawValue: raw) else {
            return .inProcess
        }
        guard backend.isUsable(environment: environment) else { return .inProcess }
        return backend
    }

    /// Whether this backend can actually run here.
    nonisolated public func isUsable(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        switch self {
        case .inProcess: true
        case .commandLine: !Self.isSandboxed(environment: environment)
        }
    }

    /// Builds this backend's `SwiftFormatCLIProtocol` implementation.
    public func makeCLI() -> any SwiftFormatCLIProtocol {
        switch self {
        case .inProcess: SwiftFormatInProcessActor()
        case .commandLine: SwiftFormatCLIActor()
        }
    }

    /// The implementation the app should use — the default for every model's
    /// injected `cli`.
    public static func makePreferred(
        defaults: UserDefaults = .standard,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> any SwiftFormatCLIProtocol {
        preferred(defaults: defaults, environment: environment).makeCLI()
    }
}
