import MeetCueCore
import Observation
import SwiftUI

/// How the card and its panel inform each other: the card reports its laid-out `size` and drags,
/// and the panel sets the tallest the notes may grow to fit the screen.
@MainActor
@Observable
final class NotesCardLayout {
    var size: CGSize = .zero
    var maxNotesHeight = NotesCardContent.maxNotesHeight
    var isCompact = false
    /// Called with the drag's translation in view coordinates (y down) while the user drags the
    /// card, and with nil when the drag ends.
    @ObservationIgnored var drag: (CGSize?) -> Void = { _ in }
}

/// The corner panel's content: the notes card for `model.notesCardMeeting`, at the top right,
/// full or compact.
struct NotesCardStack: View {
    let model: OverlayModel
    var layout = NotesCardLayout()

    var body: some View {
        Group {
            if let meeting = model.notesCardMeeting {
                Group {
                    if layout.isCompact {
                        NotesCardCompact(model: model, meeting: meeting, layout: layout)
                    } else {
                        NotesCardContent(model: model, meeting: meeting, layout: layout)
                    }
                }
                .padding(NotesCardContent.margin)
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGSize.self) { $0.size } action: { layout.size = $0 }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .environment(\.glassOpacity, model.settings.glassOpacity)
    }
}

/// The meeting's title, time and place, and its notes with live checkboxes.
struct NotesCardContent: View {
    static let width: CGFloat = 360
    /// Longer notes scroll.
    static let maxNotesHeight: CGFloat = 380
    /// The card's height besides its notes, with a two-line title.
    static let chromeHeight: CGFloat = 180
    /// Room around the card for its shadow, which the panel would otherwise clip.
    static let margin: CGFloat = 16

    let model: OverlayModel
    let meeting: Meeting
    var layout = NotesCardLayout()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1)
            ScrollView {
                NoteView(markdown: model.notes.markdown(for: meeting.id)) { line, text in
                    model.notes.toggleTask(line: line, text: text, for: meeting)
                }
                .padding(.trailing, 4)
            }
            .scrollIndicators(.automatic)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxHeight: layout.maxNotesHeight)
            Text("⌥⌘N to show again")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .contentShape(Rectangle())
                .dragsNotesCard(layout)
        }
        .padding(EdgeInsets(top: 16, leading: 18, bottom: 14, trailing: 18))
        .frame(width: Self.width)
        .glassSurface(.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Notes for \(meeting.title)")
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 7, height: 7)
                    Text("Now")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(0.5)
                        .textCase(.uppercase)
                        .foregroundStyle(colorScheme == .dark ? Color(red: 1, green: 0.45, blue: 0.40) : Color(red: 0.71, green: 0.14, blue: 0.09))
                }
                .accessibilityElement(children: .combine)
                Text(meeting.title)
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(2)
                    .accessibilityAddTraits(.isHeader)
                Text(([model.timeRange(for: meeting)] + [meeting.placeLine].compactMap { $0 }).joined(separator: " · "))
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .dragsNotesCard(layout)
            Button("Collapse notes", systemImage: "arrow.down.right.and.arrow.up.left") { layout.isCompact = true }
                .buttonStyle(CircleButtonStyle(diameter: 28))
                .help("Collapse notes")
            Button("Hide notes", systemImage: "xmark") { model.hideNotesCard() }
                .buttonStyle(CircleButtonStyle(diameter: 28))
                .help("Hide notes")
        }
    }
}

/// The collapsed notes card: the meeting's title and time, with buttons to expand or hide it.
struct NotesCardCompact: View {
    static let width: CGFloat = 280
    static let height: CGFloat = 46

    let model: OverlayModel
    let meeting: Meeting
    let layout: NotesCardLayout

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.red)
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(meeting.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(model.timeRange(for: meeting))
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("Expand notes", systemImage: "arrow.up.left.and.arrow.down.right") { layout.isCompact = false }
                .buttonStyle(CircleButtonStyle(diameter: 24))
                .help("Expand notes")
            Button("Hide notes", systemImage: "xmark") { model.hideNotesCard() }
                .buttonStyle(CircleButtonStyle(diameter: 24))
                .help("Hide notes")
        }
        .padding(.leading, 16)
        .padding(.trailing, 9)
        .frame(width: Self.width, height: Self.height)
        .glassSurface(.card, in: Capsule())
        .contentShape(Capsule())
        .dragsNotesCard(layout)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Notes for \(meeting.title), collapsed")
    }
}

extension View {
    /// Moves the notes card's panel when the user drags this view. The notes themselves don't
    /// drag, so their text stays selectable.
    func dragsNotesCard(_ layout: NotesCardLayout) -> some View {
        gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { layout.drag($0.translation) }
                .onEnded { _ in layout.drag(nil) }
        )
    }
}
