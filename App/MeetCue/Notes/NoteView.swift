import MeetCueCore
import SwiftUI

/// A note rendered from Markdown, with checkboxes that tick task items in place.
struct NoteView: View {
    private let blocks: [NoteBlock]
    private let fontSize: CGFloat
    private let isSelectable: Bool
    private let toggle: (_ line: Int, _ text: String) -> Void

    init(markdown: String, fontSize: CGFloat = 14, isSelectable: Bool = false, toggle: @escaping (_ line: Int, _ text: String) -> Void) {
        blocks = NoteDocument.blocks(from: markdown)
        self.fontSize = fontSize
        self.isSelectable = isSelectable
        self.toggle = toggle
    }

    var body: some View {
        let stack = VStack(alignment: .leading, spacing: 10) {
            ForEach(blocks) { block in
                NoteBlockView(block: block, fontSize: fontSize, toggle: toggle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        if isSelectable {
            stack.textSelection(.enabled)
        } else {
            stack
        }
    }
}

private struct NoteBlockView: View {
    let block: NoteBlock
    let fontSize: CGFloat
    let toggle: (Int, String) -> Void

    var body: some View {
        content
            .padding(.leading, CGFloat(block.depth) * 22 + (block.isQuoted ? 12 : 0))
            .overlay(alignment: .leading) {
                if block.isQuoted {
                    Capsule()
                        .fill(Color.primary.opacity(0.15))
                        .frame(width: 3)
                        .padding(.leading, CGFloat(block.depth) * 22)
                }
            }
    }

    @ViewBuilder private var content: some View {
        switch block.kind {
        case .heading(let level):
            Text(block.text)
                .font(.system(size: level == 1 ? fontSize + 3 : level == 2 ? fontSize + 1 : fontSize, weight: .bold))
                .foregroundStyle(level > 2 ? .secondary : .primary)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 2)
        case .paragraph:
            body(block.text)
        case .task(let line, let source, let isChecked, let carriedFrom):
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Button {
                    toggle(line, source)
                } label: {
                    Checkbox(isChecked: isChecked)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + fontSize * 0.3 }
                VStack(alignment: .leading, spacing: 4) {
                    body(block.text)
                        .strikethrough(isChecked)
                        .foregroundStyle(isChecked ? .secondary : .primary)
                    if let carriedFrom {
                        CarriedTag(text: NoteDocument.carriedLabel(carriedFrom))
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(carriedFrom.map { "\(block.plainText), \(NoteDocument.carriedLabel($0))" } ?? block.plainText)
            .accessibilityValue(isChecked ? "checked" : "unchecked")
            .accessibilityAddTraits([.isButton, .isToggle])
            .accessibilityAction { toggle(line, source) }
        case .inertTask(let isChecked):
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Checkbox(isChecked: isChecked)
                    .opacity(0.45)
                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + fontSize * 0.3 }
                body(block.text)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(block.plainText), not tickable")
            .accessibilityValue(isChecked ? "checked" : "unchecked")
        case .bullet(let marker):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(marker)
                    .font(.system(size: fontSize))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 10, alignment: .trailing)
                body(block.text)
            }
        case .code:
            Text(block.text)
                .font(.system(size: fontSize - 1, design: .monospaced))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.06)))
        case .rule:
            Rectangle()
                .fill(Color.primary.opacity(0.1))
                .frame(height: 1)
        }
    }

    private func body(_ text: AttributedString) -> some View {
        Text(text)
            .font(.system(size: fontSize))
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// A 16 pt rounded checkbox, drawn with shapes so image renders show it.
struct Checkbox: View {
    let isChecked: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                .fill(isChecked ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
            RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                .strokeBorder(isChecked ? Color.accentColor : Color.primary.opacity(0.3), lineWidth: 1)
            if isChecked {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 16, height: 16)
        .contentShape(Rectangle())
    }
}

/// "Carried over from Oct 28".
struct CarriedTag: View {
    let text: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(colorScheme == .dark ? Color(red: 1, green: 0.80, blue: 0.42) : Color(red: 0.42, green: 0.29, blue: 0))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(red: 1, green: 0.70, blue: 0).opacity(0.22)))
    }
}
