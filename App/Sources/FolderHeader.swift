//
//  FolderHeader.swift
//  SwiftFormatRuleStudio
//

import SwiftUI

/// The chosen project's name, kept visible at the top of a scanning pane.
///
/// Mirrors the Config tab: once a project is chosen the toolbar button alone is easy to miss.
///
/// Its own `View` rather than a computed property on each pane, for two reasons. `ImpactView` and
/// `TuneView` had the same header written out twice, differing only in how each model spells
/// "running". And both panes re-render on a dozen pieces of their own `@State` — expanded rows,
/// export sheets, scan scope — none of which change either of the two values here.
struct FolderHeader: View {
    let folderName: String
    let isScanning: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.fill")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(folderName)
                .scaledFont(.headline, weight: .semibold)
            if isScanning {
                ProgressView().controlSize(.small)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}
