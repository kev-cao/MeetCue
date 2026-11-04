import AppKit
import SwiftUI

/// A monospaced plain-text editor for a note, with carried markers dimmed.
struct MarkdownTextEditor: NSViewRepresentable {
    let text: String
    let onChange: @MainActor (String) -> Void

    static let font = NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular)

    func makeCoordinator() -> Coordinator { Coordinator(text: text, onChange: onChange) }

    static func mayHaveMarkers(_ text: String) -> Bool { text.contains("carried:") }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        let textView = scrollView.documentView as! NSTextView
        textView.delegate = context.coordinator
        textView.drawsBackground = false
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = Self.font
        textView.textContainerInset = NSSize(width: 6, height: 8)
        // Markdown needs the characters as typed.
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.string = text
        Self.dimMarkers(in: textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.onChange = onChange
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.hasMarkedText() {
            context.coordinator.hold(text)
        } else {
            context.coordinator.apply(text, to: textView)
        }
    }

    static func dimMarkers(in textView: NSTextView) {
        guard let storage = textView.textStorage else { return }
        let all = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.addAttributes([.font: font, .foregroundColor: NSColor.labelColor], range: all)
        for range in NoteDocument.carriedMarkerRanges(in: storage.string) {
            storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: range)
        }
        storage.endEditing()
        textView.typingAttributes = [.font: font, .foregroundColor: NSColor.labelColor]
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var onChange: @MainActor (String) -> Void
        private var hasMarkers: Bool
        /// The text last applied from outside or written back, which `pending` and the user's edits
        /// are measured against.
        private var base: String
        /// An outside text that arrived during an input-method composition, merged in once it commits.
        private var pending: String?

        init(text: String, onChange: @escaping @MainActor (String) -> Void) {
            self.onChange = onChange
            hasMarkers = MarkdownTextEditor.mayHaveMarkers(text)
            base = text
        }

        func hold(_ text: String) {
            pending = text
        }

        /// Replaces only the part of the text that differs, through the text system, so the
        /// selection, scroll position and undo history stay with what the user was doing.
        func apply(_ text: String, to textView: NSTextView) {
            pending = nil
            defer { base = textView.string }
            guard let change = TextEdit.minimalChange(from: textView.string, to: text) else { return }
            let selection = textView.selectedRange()
            textView.breakUndoCoalescing()
            guard textView.shouldChangeText(in: change.range, replacementString: change.replacement) else { return }
            textView.textStorage?.replaceCharacters(in: change.range, with: change.replacement)
            textView.didChangeText()
            textView.setSelectedRange(TextEdit.selection(selection, through: change, newLength: (textView.string as NSString).length))
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView, !textView.hasMarkedText() else { return }
            if let outside = pending {
                pending = nil
                if let merged = TextEdit.merge(base: base, mine: textView.string, theirs: outside) {
                    apply(merged, to: textView)
                }
            }
            let hadMarkers = hasMarkers
            hasMarkers = MarkdownTextEditor.mayHaveMarkers(textView.string)
            if hadMarkers || hasMarkers { MarkdownTextEditor.dimMarkers(in: textView) }
            base = textView.string
            onChange(textView.string)
        }
    }
}
