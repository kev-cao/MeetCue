import AppKit
import SwiftUI

/// A monospaced plain-text editor for a note, with carried markers dimmed.
struct MarkdownTextEditor: NSViewRepresentable {
    let text: String
    let onChange: @MainActor (String) -> Void

    static let font = NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular)

    func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange) }

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
        guard let textView = scrollView.documentView as? NSTextView, textView.string != text else { return }
        textView.string = text
        Self.dimMarkers(in: textView)
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

    final class Coordinator: NSObject, NSTextViewDelegate {
        var onChange: @MainActor (String) -> Void

        init(onChange: @escaping @MainActor (String) -> Void) {
            self.onChange = onChange
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            MarkdownTextEditor.dimMarkers(in: textView)
            onChange(textView.string)
        }
    }
}
