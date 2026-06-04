//
//  PreviewDiffLine.swift
//  SwiftFormatRuleStudio
//

import Foundation
import LintStudioCore

/// A single line of a before/after diff, in a form the UI can render without
/// importing `LintStudioCore`. Produced by `LivePreviewModel` from the shared
/// `UnifiedDiffEngine`'s `DiffLine` output.
public struct PreviewDiffLine: Identifiable, Sendable, Equatable {
    public enum Change: Sendable, Equatable {
        case added
        case removed
        case unchanged

        /// Maps a shared `DiffLine.Kind` into the app-facing change kind.
        init(_ kind: DiffLine.Kind) {
            switch kind {
            case .added: self = .added
            case .removed: self = .removed
            case .unchanged: self = .unchanged
            }
        }
    }

    public let id: Int
    public let text: String
    public let change: Change

    public init(id: Int, text: String, change: Change) {
        self.id = id
        self.text = text
        self.change = change
    }

    /// Builds preview lines from the shared diff engine's output.
    public static func lines(from diffLines: [DiffLine]) -> [Self] {
        diffLines.enumerated().map { index, line in
            Self(id: index, text: line.text, change: Change(line.kind))
        }
    }
}
