import MeetCueCore
import SwiftUI

/// The selected meeting's details and its notes editor.
struct EventInspector: View {
    let model: CalendarWindowModel

    var body: some View {
        if let meeting = model.selected {
            EventDetails(model: model, meeting: meeting)
                .id(meeting.id)
        } else {
            Text("Select an event to see its details and notes.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct EventDetails: View {
    let model: CalendarWindowModel
    let meeting: Meeting

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(meeting.title)
                    .font(.system(size: 22, weight: .bold))
                    .lineLimit(3)
                    .textSelection(.enabled)
                    .accessibilityAddTraits(.isHeader)
                Text(model.dateLine(for: meeting))
                    .font(.system(size: 13))
                    .monospacedDigit()
                if meeting.isRecurring {
                    Label("Repeats", systemImage: "repeat")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                if let link = meeting.joinLink {
                    DetailRow(systemImage: "video") {
                        Text(link.service.displayName)
                        Spacer(minLength: 8)
                        Button("Join") { model.join(meeting) }
                            .buttonStyle(JoinButtonStyle())
                            .accessibilityLabel("Join \(meeting.title)")
                    }
                }
                if let location = meeting.location, !location.isEmpty {
                    DetailRow(systemImage: "mappin.and.ellipse") { Text(location).lineLimit(2) }
                }
                if let attendees = model.attendeeLine(for: meeting) {
                    DetailRow(systemImage: "person.2") { Text(attendees) }
                }
                if let calendarLine = model.calendarLine(for: meeting) {
                    DetailRow(color: Color(model.color(for: meeting))) { Text(calendarLine) }
                }
            }
            Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 1)
            NotesEditor(model: model, meeting: meeting)
        }
        .padding(EdgeInsets(top: 24, leading: 22, bottom: 18, trailing: 22))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct DetailRow<Content: View>: View {
    var systemImage: String?
    var color: Color?
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let systemImage {
                    Image(systemName: systemImage)
                } else if let color {
                    Circle().fill(color).frame(width: 9, height: 9)
                }
            }
            .frame(width: 18)
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
            content
        }
        .font(.system(size: 13))
        .frame(minHeight: 28)
    }
}

private struct JoinButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(height: 28)
            .background(Capsule().fill(Color.accentColor))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// Preview renders the note with live checkboxes; Markdown edits the text, with carried markers dimmed.
private struct NotesEditor: View {
    let model: CalendarWindowModel
    let meeting: Meeting
    @State private var topic = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Notes")
                    .font(.system(size: 15, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                SegmentedCapsule(options: CalendarWindowModel.EditorMode.allCases, selection: model.editorMode, label: \.title, compact: true) {
                    model.editorMode = $0
                }
            }
            Group {
                switch model.editorMode {
                case .preview:
                    let markdown = model.markdown(for: meeting)
                    if markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("No notes yet. Add a topic below, or switch to Markdown to write.")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    } else {
                        ScrollView {
                            NoteView(markdown: markdown) { model.toggleTask(line: $0, for: meeting) }
                                .padding(.trailing, 4)
                        }
                    }
                case .markdown:
                    MarkdownTextEditor(text: model.markdown(for: meeting)) { model.setMarkdown($0, for: meeting) }
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.04)))
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField("Add a topic", text: $topic)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .onSubmit {
                        model.addTopic(topic, to: meeting)
                        topic = ""
                    }
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.05)))
            if !model.notes.isStorageAvailable {
                Label("Notes can't be saved right now.", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.orange)
            } else if model.notes.saveFailed {
                Label("Couldn't save. Retrying.", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.orange)
            } else {
                Text("Notes appear in the corner when the meeting starts.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
