import AppKit
import MeetCueCore
import SwiftUI

struct DropdownView: View {
    let model: MenuBarModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.needsAccess {
                AccessPrompt(store: model.store)
            } else if let meeting = model.featured {
                MeetingCard(meeting: meeting, isLive: meeting.start <= model.now, detail: model.detail(for: meeting))
            } else {
                Text("No more meetings today")
                    .foregroundStyle(.secondary)
            }
            Divider()
            QuietModeMenu(model: model)
            Divider()
            Button("Quit MeetCue") { NSApp.terminate(nil) }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(isLive ? "Now" : "Next up")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Text(meeting.title)
                .font(.headline)
            Text(detail)
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            if let place = meeting.placeLine {
                Label(place, systemImage: meeting.joinLink == nil ? "mappin.and.ellipse" : "video")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let link = meeting.joinLink {
                Button {
                    NSWorkspace.shared.open(link.url)
                } label: {
                    Label("Join meeting", systemImage: "video.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 4)
            }
        }
    }
}

private struct AccessPrompt: View {
    let store: MeetingStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MeetCue needs access to your calendars")
                .font(.headline)
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
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

private struct QuietModeMenu: View {
    let model: MenuBarModel

    var body: some View {
        Menu {
            ForEach(QuietMode.Preset.allCases) { preset in
                Button(preset.title) { model.setQuiet(preset) }
            }
            if model.quiet.isOn(at: model.now) {
                Divider()
                Button("Turn Off") { model.setQuiet(nil) }
            }
        } label: {
            Label(model.quietStatus, systemImage: "moon")
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .fixedSize()
    }
}
