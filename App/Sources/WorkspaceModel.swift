//
//  WorkspaceModel.swift
//  SwiftFormatRuleStudio
//

import Foundation
import Observation

/// The project folder shared across tabs. Picking a folder in Config or Audit
/// updates this one source of truth, so both tabs operate on the same project
/// (each reacts to a change: Config loads its `.swiftformat`, Audit re-runs).
@MainActor
@Observable
final class WorkspaceModel {
    /// The selected project folder, or `nil` until one is chosen.
    var selectedFolder: URL?
}
