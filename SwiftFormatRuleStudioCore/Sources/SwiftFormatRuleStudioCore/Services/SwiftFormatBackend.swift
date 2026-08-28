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

    /// The backend to use: the override if one is set and valid, else ``inProcess``.
    public static func preferred(defaults: UserDefaults = .standard) -> Self {
        guard let raw = defaults.string(forKey: defaultsKey),
              let backend = Self(rawValue: raw) else {
            return .inProcess
        }
        return backend
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
    public static func makePreferred(defaults: UserDefaults = .standard) -> any SwiftFormatCLIProtocol {
        preferred(defaults: defaults).makeCLI()
    }
}
