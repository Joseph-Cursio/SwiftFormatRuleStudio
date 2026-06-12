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

    func makeNSView(context: Context) -> EditorContainerView {
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

        // A recessed bezel gives the always-on "this is a field" frame.
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.borderType = .bezelBorder
        scrollView.contentView.postsBoundsChangedNotifications = true

        let ruler = LineNumberRulerView(textView: textView)
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true

        // AppKit only auto-draws a focus ring for the first-responder view, and
        // the first responder here is the (scrollable) text view — its ring would
        // wrap the whole document, not the visible frame. So we draw our own ring
        // around the editor's frame via an overlay, toggled on first-responder.
        let overlay = FocusRingOverlay()
        textView.onFocusChange = { [weak overlay] focused in overlay?.isActive = focused }

        context.coordinator.ruler = ruler
        context.coordinator.textView = textView

        // Focus the editor when the pane first appears so the insertion-point
        // caret blinks — an unambiguous cue that the area accepts typing.
        DispatchQueue.main.async { [weak textView] in
            guard let textView, textView.window?.firstResponder !== textView else { return }
            textView.window?.makeFirstResponder(textView)
        }
        return EditorContainerView(scrollView: scrollView, overlay: overlay)
    }

    func updateNSView(_ container: EditorContainerView, context: Context) {
        guard let textView = container.scrollView.documentView as? NSTextView else { return }
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
        weak var textView: NSTextView?

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
    /// Notifies when the view gains/loses first-responder status so the enclosing
    /// editor can show/hide its focus ring.
    var onFocusChange: ((Bool) -> Void)?
    private var outsideClickMonitor: Any?

    override func becomeFirstResponder() -> Bool {
        let didBecome = super.becomeFirstResponder()
        if didBecome {
            onFocusChange?(true)
            startWatchingForOutsideClicks()
        }
        return didBecome
    }

    override func resignFirstResponder() -> Bool {
        let didResign = super.resignFirstResponder()
        if didResign {
            onFocusChange?(false)
            stopWatchingForOutsideClicks()
        }
        return didResign
    }

    deinit { stopWatchingForOutsideClicks() }

    /// A mouse-down on a non-focusable sibling pane (the read-only diff/output)
    /// doesn't move first responder, so the editor would keep its focus ring while
    /// the focusable changes list *does* clear it. Watch for clicks outside the
    /// editor's frame and drop focus, so the ring behaves the same wherever you
    /// click away.
    private func startWatchingForOutsideClicks() {
        stopWatchingForOutsideClicks()
        outsideClickMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            guard let self,
                  let window,
                  event.window === window,
                  let scrollView = enclosingScrollView else { return event }
            let frameInWindow = scrollView.convert(scrollView.bounds, to: nil)
            if !frameInWindow.contains(event.locationInWindow) {
                // Resign after the click is delivered so its own target (if any)
                // settles first; only act if we're still the first responder.
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.window?.firstResponder === self else { return }
                    self.window?.makeFirstResponder(nil)
                }
            }
            return event
        }
    }

    private func stopWatchingForOutsideClicks() {
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }

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

/// Hosts the editor's scroll view and a focus-ring overlay stacked on top, both
/// pinned to fill. The overlay lives here (not inside the scroll view) so its ring
/// isn't clipped by the clip view, scrollers, or ruler.
final class EditorContainerView: NSView {
    let scrollView: NSScrollView
    let overlay: FocusRingOverlay

    init(scrollView: NSScrollView, overlay: FocusRingOverlay) {
        self.scrollView = scrollView
        self.overlay = overlay
        super.init(frame: .zero)
        addSubview(scrollView)
        addSubview(overlay) // on top of the scroll view
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) is not supported") }

    override func layout() {
        super.layout()
        scrollView.frame = bounds
        overlay.frame = bounds
    }
}

/// A click-through overlay that strokes a keyboard focus ring around its edge
/// while `isActive`. Drawing it ourselves is the reliable way to ring a
/// scroll-backed text view's *visible frame* (see `CodeTextEditor.makeNSView`).
final class FocusRingOverlay: NSView {
    var isActive = false {
        didSet { if oldValue != isActive { needsDisplay = true } }
    }

    /// Let clicks fall through to the text view beneath.
    override func hitTest(_: NSPoint) -> NSView? { nil }

    override func draw(_: NSRect) {
        guard isActive else { return }
        let ring = NSBezierPath(roundedRect: bounds.insetBy(dx: 1.5, dy: 1.5), xRadius: 4, yRadius: 4)
        ring.lineWidth = 3
        NSColor.keyboardFocusIndicatorColor.setStroke()
        ring.stroke()
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

    override func drawHashMarksAndLabels(in rect: NSRect) {
        // Gutter divider: a hairline at the gutter's trailing edge, matching the
        // line-number gutters in the other panels.
        NSColor.separatorColor.setStroke()
        let separatorX = ruleThickness - 0.5
        let divider = NSBezierPath()
        divider.move(to: NSPoint(x: separatorX, y: rect.minY))
        divider.line(to: NSPoint(x: separatorX, y: rect.maxY))
        divider.lineWidth = 1
        divider.stroke()

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
