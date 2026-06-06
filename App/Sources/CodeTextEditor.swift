//
//  CodeTextEditor.swift
//  SwiftFormatRuleStudio
//

import AppKit
import SwiftUI

/// A monospaced, non-wrapping code editor with a line-number gutter — SwiftUI's
/// `TextEditor` offers neither. Wraps `NSTextView` in a scroll view and draws
/// line numbers via an `NSRulerView`, so the numbers line up with the Changes
/// panel.
struct CodeTextEditor: NSViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat
    /// Greyed-out prompt drawn when the editor is empty (Apple's "you can type
    /// here" convention). Disappears on the first keystroke.
    var placeholder = "Type or paste Swift here…"

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let big = CGFloat.greatestFiniteMagnitude
        let textView = PlaceholderTextView()
        textView.placeholder = placeholder
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.allowsUndo = true
        textView.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.string = text
        textView.textContainerInset = NSSize(width: 4, height: 6)

        // Look like an editable field, not a static label: a real text-field
        // background distinguishes this pane from the read-only result panes.
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor

        // Don't wrap — let long lines scroll horizontally so line numbers map 1:1.
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        textView.maxSize = NSSize(width: big, height: big)
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: big, height: big)

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true

        // The recessed bezel + focus ring are macOS's standard "this is where you
        // type" affordance for a scroll-backed text area.
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.borderType = .bezelBorder
        scrollView.focusRingType = .exterior
        scrollView.contentView.postsBoundsChangedNotifications = true

        let ruler = LineNumberRulerView(textView: textView)
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true

        context.coordinator.ruler = ruler

        // Focus the editor when the pane first appears so the insertion-point
        // caret blinks — an unambiguous cue that the area accepts typing.
        DispatchQueue.main.async { [weak textView] in
            guard let textView, textView.window?.firstResponder !== textView else { return }
            textView.window?.makeFirstResponder(textView)
        }
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
            textView.needsDisplay = true
        }
        if textView.font?.pointSize != fontSize {
            textView.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
            context.coordinator.ruler?.needsDisplay = true
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        let parent: CodeTextEditor
        weak var ruler: LineNumberRulerView?

        init(_ parent: CodeTextEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            // Repaint so the placeholder appears/clears as the editor empties/fills.
            textView.needsDisplay = true
            ruler?.needsDisplay = true
        }
    }
}

/// An `NSTextView` that draws greyed-out placeholder text while it's empty.
/// `NSTextView` has no native `placeholderString` (unlike `NSTextField`), so we
/// render it ourselves in the text container's top-left.
final class PlaceholderTextView: NSTextView {
    var placeholder = ""

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty, !placeholder.isEmpty else { return }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font ?? .monospacedSystemFont(ofSize: 13, weight: .regular),
            .foregroundColor: NSColor.placeholderTextColor
        ]
        let origin = NSPoint(
            x: textContainerInset.width + (textContainer?.lineFragmentPadding ?? 0),
            y: textContainerInset.height
        )
        placeholder.draw(at: origin, withAttributes: attributes)
    }
}

/// Draws 1-based line numbers in a scroll view's vertical ruler. With wrapping
/// disabled, each line fragment is exactly one logical line, so numbers run
/// sequentially from the first visible line.
final class LineNumberRulerView: NSRulerView {
    init(textView: NSTextView) {
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 40
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(invalidate),
            name: NSView.boundsDidChangeNotification,
            object: textView.enclosingScrollView?.contentView
        )
        center.addObserver(
            self,
            selector: #selector(invalidate),
            name: NSText.didChangeNotification,
            object: textView
        )
    }

    @available(*, unavailable)
    required init(coder _: NSCoder) { fatalError("init(coder:) is not supported") }

    @objc private func invalidate() { needsDisplay = true }

    override func drawHashMarksAndLabels(in _: NSRect) {
        guard let textView = clientView as? NSTextView,
              let layoutManager = textView.layoutManager,
              let container = textView.textContainer else { return }

        let text = textView.string
        let font = textView.font ?? .monospacedSystemFont(ofSize: 11, weight: .regular)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: font.pointSize * 0.85, weight: .regular),
            .foregroundColor: NSColor.tertiaryLabelColor
        ]
        let originY = convert(NSPoint.zero, from: textView).y + textView.textContainerInset.height

        let visibleGlyphs = layoutManager.glyphRange(forBoundingRect: textView.visibleRect, in: container)
        let firstChar = layoutManager.characterIndexForGlyph(at: visibleGlyphs.location)
        var lineNumber = startLineNumber(forUTF16Offset: firstChar, in: text)

        layoutManager.enumerateLineFragments(forGlyphRange: visibleGlyphs) { fragmentRect, _, _, _, _ in
            let label = NSAttributedString(string: "\(lineNumber)", attributes: attributes)
            let xPos = self.ruleThickness - 4 - label.size().width
            label.draw(at: NSPoint(x: xPos, y: originY + fragmentRect.minY))
            lineNumber += 1
        }
    }

    /// 1-based line number for a UTF-16 offset (newlines before it, plus one).
    private func startLineNumber(forUTF16Offset offset: Int, in text: String) -> Int {
        let utf16 = text.utf16
        guard offset > 0,
              let utf16Index = utf16.index(utf16.startIndex, offsetBy: offset, limitedBy: utf16.endIndex),
              let stringIndex = utf16Index.samePosition(in: text) else { return 1 }
        return 1 + text[text.startIndex..<stringIndex].reduce(into: 0) { count, character in
            if character == "\n" { count += 1 }
        }
    }
}
