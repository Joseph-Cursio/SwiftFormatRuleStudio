//
//  RuleCatalog.swift
//  SwiftFormatRuleStudio
//

import Foundation

/// The full set of SwiftFormat rules and global options for a given binary
/// version. Cached on disk and invalidated when the version changes.
public struct RuleCatalog: Codable, Sendable, Equatable {
    /// The SwiftFormat version this catalog was loaded from, e.g. `"0.61.1"`.
    public let swiftFormatVersion: String

    /// All rules from `swiftformat --rules`. Descriptions and examples are
    /// loaded lazily per rule (see `CatalogLoader.ruleInfo(for:)`).
    public let rules: [FormatRule]

    /// All global options from `swiftformat --options`.
    public let options: [FormatOption]

    public init(swiftFormatVersion: String, rules: [FormatRule], options: [FormatOption]) {
        self.swiftFormatVersion = swiftFormatVersion
        self.rules = rules
        self.options = options
    }

    /// Rules excluding any marked `(deprecated)`.
    public var activeRules: [FormatRule] {
        rules.filter { !$0.isDeprecated }
    }

    /// Looks up a rule by name.
    public func rule(named name: String) -> FormatRule? {
        rules.first { $0.name == name }
    }

    /// Looks up an option by its flag, e.g. `"--self"`.
    public func option(named name: String) -> FormatOption? {
        options.first { $0.name == name }
    }
}
