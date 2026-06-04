//
//  SwiftFormatPreset.swift
//  SwiftFormatRuleStudio
//

import Foundation

/// A starter `.swiftformat` configuration the user can apply as a baseline.
public struct SwiftFormatPreset: Identifiable, Sendable, Equatable {
    /// Stable identifier.
    public let id: String
    /// Display name.
    public let name: String
    /// One-line description of what the preset does.
    public let summary: String
    /// The `.swiftformat` content the preset installs.
    public let configText: String

    public init(id: String, name: String, summary: String, configText: String) {
        self.id = id
        self.name = name
        self.summary = summary
        self.configText = configText
    }
}

/// Built-in starter presets.
public enum BuiltInPresets {
    /// All presets, in display order.
    public static let all: [SwiftFormatPreset] = [standard, compact, opinionated]

    /// SwiftFormat defaults with 4-space indentation.
    public static let standard = SwiftFormatPreset(
        id: "standard",
        name: "Standard",
        summary: "SwiftFormat's defaults with 4-space indentation.",
        configText: """
        # Standard — SwiftFormat defaults, 4-space indentation
        --swift-version 5.10
        --indent 4
        """
    )

    /// Tighter 2-space indentation.
    public static let compact = SwiftFormatPreset(
        id: "compact",
        name: "Compact",
        summary: "2-space indentation.",
        configText: """
        # Compact — 2-space indentation
        --swift-version 5.10
        --indent 2
        """
    )

    /// Default rules plus several opinionated opt-in rules.
    public static let opinionated = SwiftFormatPreset(
        id: "opinionated",
        name: "Opinionated",
        summary: "Defaults plus opt-in rules (isEmpty, organizeDeclarations, …) and explicit-self removal.",
        configText: """
        # Opinionated — defaults plus selected opt-in rules
        --swift-version 5.10
        --indent 4
        --self remove
        --enable isEmpty,organizeDeclarations,blankLineAfterSwitchCase,wrapEnumCases
        """
    )
}
