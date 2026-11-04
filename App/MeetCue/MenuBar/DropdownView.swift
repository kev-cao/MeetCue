import AppKit
import MeetCueCore
import SwiftUI

struct DropdownView: View {
    let model: MenuBarModel
    let dismiss: @MainActor () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.needsAccess {
                AccessPrompt(store: model.store, dismiss: dismiss)
            } else if let meeting = model.featured {
                MeetingCard(meeting: meeting, isLive: model.isLive(meeting), detail: model.detail(for: meeting), dismiss: dismiss)
            } else {
                Text("No more meetings today")
                    .foregroundStyle(.secondary)
            }
            Divider()
            QuietModeMenu(model: model, dismiss: dismiss)
            Divider()
            Button {
                NSApp.terminate(nil)
            } label: {
                Text("Quit MeetCue")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
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
                .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
    }
}
