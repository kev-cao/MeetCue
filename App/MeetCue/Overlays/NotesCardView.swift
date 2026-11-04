import MeetCueCore
import SwiftUI

/// The corner panel's content: the notes card for `model.notesCardMeeting`, at the top right.
/// Reports its size so the panel can fit it.
struct NotesCardStack: View {
    let model: OverlayModel
    let open: (Meeting) -> Void
    var sizeChanged: (CGSize) -> Void = { _ in }

    var body: some View {
        Group {
            if let meeting = model.notesCardMeeting {
                NotesCardContent(model: model, meeting: meeting, open: open)
                    .padding(NotesCardContent.margin)
                    .fixedSize(horizontal: false, vertical: true)
                    .onGeometryChange(for: CGSize.self) { $0.size } action: { sizeChanged($0) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }
}

/// The meeting's title, time and place, and its notes with live checkboxes.
struct NotesCardContent: View {
    static let width: CGFloat = 360
    /// Longer notes scroll.
    static let maxNotesHeight: CGFloat = 380
    /// Room around the card for its shadow, which the panel would otherwise clip.
    static let margin: CGFloat = 16

    let model: OverlayModel
    let meeting: Meeting
    let open: (Meeting) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1)
            ScrollView {
                NoteView(markdown: model.notes.markdown(for: meeting.id)) { line in
                    model.notes.toggleTask(line: line, for: meeting)
                }
                .padding(.trailing, 4)
            }
            .scrollIndicators(.automatic)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxHeight: Self.maxNotesHeight)
            Text("⌥⌘N to show again")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
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
            Spacer(minLength: 0)
            Button("Open in MeetCue", systemImage: "arrow.up.right") { open(meeting) }
                .buttonStyle(CircleButtonStyle(diameter: 28))
                .help("Open in MeetCue")
            Button("Hide notes", systemImage: "xmark") { model.hideNotesCard() }
                .buttonStyle(CircleButtonStyle(diameter: 28))
                .help("Hide notes")
        }
    }
}
