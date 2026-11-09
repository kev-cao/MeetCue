import AppKit
import MeetCueCore
import SwiftUI

struct DropdownView: View {
    let model: MenuBarModel
    let dismiss: @MainActor () -> Void
    /// Shows "Show notes card" when set.
    var overlays: OverlayModel?
    /// Shows "Open MeetCue" when set.
    var openMeetCue: (@MainActor () -> Void)?
    /// Shows "Settings…" when set.
    var openSettings: (@MainActor () -> Void)?
    var simulateMeeting: (@MainActor () -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.needsAccess {
                AccessPrompt(store: model.store, dismiss: dismiss)
            } else if let meeting = model.featured {
                MeetingCard(meeting: meeting, isLive: model.isLive(meeting), detail: model.detail(for: meeting), dismiss: dismiss)
                AddTopicField(model: model, meeting: meeting, dismiss: dismiss)
                    .id(meeting.id)
            } else {
                Text("No more meetings today")
                    .foregroundStyle(.secondary)
            }
            Divider()
            QuietModeMenu(model: model, dismiss: dismiss)
            if let overlays {
                MenuRow(title: "Show notes card", systemImage: "note.text", shortcut: "⌥⌘N") {
                    overlays.showNotesCard()
                    dismiss()
                }
                .keyboardShortcut("n", modifiers: [.command, .option])
                .disabled(!overlays.canShowNotesCard)
            }
            if model.showsSimulateItem, let simulateMeeting {
                Button {
                    simulateMeeting()
                    dismiss()
                } label: {
                    Label("Simulate meeting in 2 minutes", systemImage: "bell.badge")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .menuItemHighlight()
                }
                .buttonStyle(.plain)
            }
            Divider()
            if let openMeetCue {
                MenuRow(title: "Open MeetCue", systemImage: "calendar", shortcut: "⌥⌘O") {
                    openMeetCue()
                    dismiss()
                }
                .keyboardShortcut("o", modifiers: [.command, .option])
            }
            if let openSettings {
                MenuRow(title: "Settings…", systemImage: "gearshape", shortcut: "⌘,") {
                    dismiss()
                    openSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            Button {
                NSApp.terminate(nil)
            } label: {
                Text("Quit")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .menuItemHighlight()
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q")
        }
        .padding(16)
        .frame(width: 300, alignment: .leading)
    }
}

private struct MeetingCard: View {
    let meeting: Meeting
    let isLive: Bool
    let detail: String
    let dismiss: @MainActor () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(isLive ? "Now" : "Next up")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Text(meeting.title)
                .font(.headline)
                .lineLimit(2)
                .help(meeting.title)
                .accessibilityAddTraits(.isHeader)
            Text(detail)
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            if let place = meeting.placeLine {
                Label(place, systemImage: meeting.joinLink == nil ? "mappin.and.ellipse" : "video")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if let link = meeting.joinLink {
                Button {
                    NSWorkspace.shared.open(link.url)
                    dismiss()
                } label: {
                    Label("Join meeting", systemImage: "video.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityLabel("Join \(meeting.title)")
                .padding(.top, 4)
            }
        }
    }
}

/// "Add a topic to Team Sync…", with the count of topics already noted.
private struct AddTopicField: View {
    let model: MenuBarModel
    let meeting: Meeting
    let dismiss: @MainActor () -> Void
    @State private var topic = ""
    @FocusState private var isFocused: Bool

    private var canAdd: Bool { !topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                TextField("Add a topic to \(meeting.title)…", text: $topic)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($isFocused)
                    .onSubmit(add)
                    .accessibilityLabel("Add a topic to \(meeting.title)")
                Button("Add topic", systemImage: "plus", action: add)
                    .labelStyle(.iconOnly)
                    .buttonStyle(CircleButtonStyle(diameter: 24))
                    .disabled(!canAdd)
            }
            .padding(.leading, 12)
            .padding(.trailing, 6)
            .frame(height: 34)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5))
            let count = model.topicCount(for: meeting)
            if count > 0 {
                Text(count == 1 ? "1 topic already noted" : "\(count) topics already noted")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
        }
        .padding(.top, 4)
        .onAppear { isFocused = true }
        .onDisappear { topic = "" }
    }

    private func add() {
        guard canAdd else { return }
        model.addTopic(topic, to: meeting)
        topic = ""
        dismiss()
    }
}

/// A full-width menu item with an icon and a shortcut hint.
private struct MenuRow: View {
    let title: String
    let systemImage: String
    let shortcut: String
    let action: @MainActor () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                Text(shortcut)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .menuItemHighlight()
        }
        .buttonStyle(.plain)
    }
}

private struct AccessPrompt: View {
    let store: MeetingStore
    let dismiss: @MainActor () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MeetCue needs access to your calendars")
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            Text("It reads your meetings to show what's next and alert you before they start.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if store.access == .notDetermined {
                Button("Allow Access") {
                    Task { await store.requestAccess() }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Open Privacy Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                        NSWorkspace.shared.open(url)
                    }
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

private struct QuietModeMenu: View {
    let model: MenuBarModel
    let dismiss: @MainActor () -> Void

    var body: some View {
        Menu {
            ForEach(QuietMode.Preset.allCases) { preset in
                Button(preset.title) {
                    model.setQuiet(preset)
                    dismiss()
                }
            }
            if model.quiet.isOn(at: model.now) {
                Divider()
                Button("Turn Off") {
                    model.setQuiet(nil)
                    dismiss()
                }
            }
        } label: {
            Label(model.quietStatus, systemImage: "moon")
                .frame(maxWidth: .infinity, alignment: .leading)
                .menuItemHighlight()
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
    }
}

extension View {
    /// The accent-colored highlight of a menu item under the pointer. It reaches past the item's
    /// text into the dropdown's padding, as a system menu's does.
    func menuItemHighlight() -> some View {
        modifier(MenuItemHighlight())
    }
}

private struct MenuItemHighlight: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    private static let overhang: CGFloat = 8

    func body(content: Content) -> some View {
        let highlighted = isHovered && isEnabled
        content
            .padding(.horizontal, Self.overhang)
            .padding(.vertical, 3)
            .foregroundStyle(highlighted ? AnyShapeStyle(Color.white) : AnyShapeStyle(.primary))
            .background {
                if highlighted {
                    RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
            .padding(.horizontal, -Self.overhang)
            .padding(.vertical, -3)
            .onHover { isHovered = $0 }
    }
}
