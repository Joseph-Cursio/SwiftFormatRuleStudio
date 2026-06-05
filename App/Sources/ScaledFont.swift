//
//  ScaledFont.swift
//  SwiftFormatRuleStudio
//

import SwiftUI

/// A multiplier applied to text in the Rules panel (driven by ⌘+ / ⌘- / ⌘0).
/// macOS ignores `dynamicTypeSize` for font rendering, so we scale font point
/// sizes explicitly via this environment value instead. Defaults to 1.0, so any
/// view that doesn't opt in (or lives outside the Rules panel) is unaffected.
extension EnvironmentValues {
    @Entry var uiTextScale: CGFloat = 1.0
}

extension CGFloat {
    /// Maps a text-size step (0 = 100%) to a clamped scale multiplier. Each step
    /// is ±12%; shared by the menu commands and the views that apply the scale.
    static func uiTextScale(forStep step: Int) -> CGFloat {
        Swift.min(Swift.max(1.0 + CGFloat(step) * 0.12, 0.6), 2.0)
    }
}

extension View {
    /// Applies a semantic-style font whose point size is multiplied by the
    /// environment's `uiTextScale`. Use instead of `.font(.caption)` etc. on text
    /// that should respond to the Rules panel's text-size controls.
    func scaledFont(
        _ style: Font.TextStyle,
        weight: Font.Weight? = nil,
        design: Font.Design = .default
    ) -> some View {
        modifier(ScaledFont(style: style, weight: weight, design: design))
    }
}

struct ScaledFont: ViewModifier {
    @Environment(\.uiTextScale) private var scale
    let style: Font.TextStyle
    let weight: Font.Weight?
    let design: Font.Design

    /// macOS default point sizes for the semantic text styles.
    private static let baseSizes: [Font.TextStyle: CGFloat] = [
        .largeTitle: 26, .title: 22, .title2: 17, .title3: 15, .headline: 13,
        .body: 13, .callout: 12, .subheadline: 11, .footnote: 10, .caption: 10, .caption2: 10
    ]

    func body(content: Content) -> some View {
        let size = (Self.baseSizes[style] ?? 13) * scale
        return content.font(.system(size: size, weight: weight, design: design))
    }
}
