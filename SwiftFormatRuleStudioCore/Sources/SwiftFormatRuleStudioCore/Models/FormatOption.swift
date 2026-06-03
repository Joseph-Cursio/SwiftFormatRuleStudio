//
//  FormatOption.swift
//  SwiftFormatRuleStudio
//

import Foundation

/// The value shape of a SwiftFormat global option, inferred from its
/// `--options` blurb. Drives which editor control the Options panel renders.
public enum FormatOptionKind: String, Codable, Sendable, CaseIterable {
    /// A fixed set of named choices, e.g. `--self`: "insert", "remove", "init-only".
    case enumeration
    /// A boolean toggle, e.g. `--allman`: "true" or "false".
    case boolean
    /// A whole number, e.g. `--class-threshold`: "Defaults to 0".
    case integer
    /// A comma-delimited list, e.g. `--acronyms`: "ID,URL,UUID".
    case list
    /// A free-form string when no tighter shape can be inferred.
    case string
}

/// A global SwiftFormat option, as surfaced by `swiftformat --options`.
///
/// Options are distinct from rules: rules toggle on/off, options are global
/// formatting knobs (`--indent`, `--self`, …) consumed by specific rules. This
/// is a NEW model with no SwiftLint analogue — SwiftLint folds parameters into
/// each rule, whereas SwiftFormat keeps a flat global option set.
public struct FormatOption: Codable, Identifiable, Sendable, Hashable {
    /// The option flag including leading dashes, e.g. `"--self"`.
    public let name: String

    /// The human-readable blurb from `--options`.
    public let summary: String

    /// Best-effort inferred value shape. See `FormatOptionKind`.
    public let kind: FormatOptionKind

    /// Allowed named values for enumeration/boolean options, in listed order.
    public let allowedValues: [String]

    /// The default value, if one is stated (the choice marked `(default)`, or
    /// the value after "Defaults to").
    public let defaultValue: String?

    public init(
        name: String,
        summary: String,
        kind: FormatOptionKind = .string,
        allowedValues: [String] = [],
        defaultValue: String? = nil
    ) {
        self.name = name
        self.summary = summary
        self.kind = kind
        self.allowedValues = allowedValues
        self.defaultValue = defaultValue
    }

    /// The option name without its leading dashes, e.g. `"self"`.
    public var key: String {
        var trimmed = Substring(name)
        while trimmed.first == "-" {
            trimmed = trimmed.dropFirst()
        }
        return String(trimmed)
    }

    // MARK: - Identifiable

    public var id: String { name }
}
