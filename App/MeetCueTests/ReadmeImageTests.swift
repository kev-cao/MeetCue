import AppKit
import Foundation
import MeetCueCore
import SwiftUI
import Testing
@testable import MeetCue

/// Renders the README screenshots into `MEETCUE_README_DIR`; skipped unless it's set. Pass it to
/// `xcodebuild test` as `TEST_RUNNER_MEETCUE_README_DIR`.
@MainActor
@Suite(.enabled(if: ProcessInfo.processInfo.environment["MEETCUE_README_DIR"] != nil))
struct ReadmeImageTests {
    let source = FakeCalendarSource()
    let notes = NoteStore(repository: FlakyNoteRepository())

    func stores(at time: Date) -> MeetingStore {
        source.calendarList = SampleWeek.calendars
        source.snapshots = SampleWeek.events
        let store = MeetingStore(source: source, now: { time }, calendar: AppFixtures.calendar)
        store.refresh()
        return store
    }

    func overlays(at time: Date) -> OverlayModel {
        let model = OverlayModel(
            store: stores(at: time),
            quiet: QuietMode(storage: InMemoryQuietStorage()),
            notes: notes,
            dismissed: DismissedAlerts(storage: InMemoryDismissedAlertStorage()),
            settings: AppSettings(storage: InMemorySettingsStorage()),
            clock: { time },
            calendar: AppFixtures.calendar,
            locale: Locale(identifier: "en_US"),
            openURL: { _ in }
        )
        model.refresh()
        return model
    }

    var teamSync: Meeting {
        MeetingMapper.meeting(from: SampleWeek.events.first { $0.title == "Team Sync" }!)
    }

    @Test func alert() throws {
        let now = AppFixtures.at(14, 28, second: 18)
        notes.setMarkdown(SampleWeek.note, for: teamSync)
        let model = overlays(at: now)
        #expect(model.alertMeetings.map(\.title) == ["Team Sync"])
        try render(ZStack { Wallpaper(dark: false); AlertScreenContent(model: model, now: now) }, size: CGSize(width: 1280, height: 800), named: "alert")
    }

    @Test func notesCard() throws {
        notes.setMarkdown(SampleWeek.note, for: teamSync)
        let model = overlays(at: AppFixtures.at(14, 36))
        #expect(model.notesCardMeeting?.title == "Team Sync")
        let scene = ZStack(alignment: .topTrailing) {
            Wallpaper(dark: false)
            NotesCardStack(model: model, open: { _ in }).padding(.top, 20).padding(.trailing, 8)
        }
        try render(scene, size: CGSize(width: 820, height: 560), named: "notes-card")
    }

    @Test func calendarWindow() throws {
        let store = stores(at: SampleWeek.now)
        let model = CalendarWindowModel(
            store: store,
            notes: notes,
            visibility: CalendarVisibility(store: store, storage: InMemoryHiddenCalendarStorage()),
            clock: { SampleWeek.now },
            calendar: AppFixtures.calendar,
            locale: Locale(identifier: "en_US")
        )
        model.reload()
        notes.setMarkdown(SampleWeek.note, for: teamSync)
        notes.setMarkdown("- [ ] Ask about the offsite", for: model.meetings.first { $0.title == "1:1" }!)
        model.select(model.meetings.first { $0.id == teamSync.id })
        let window = CalendarWindowView(model: model)
            .frame(width: 1360, height: 820)
            .overlay(alignment: .topLeading) { TrafficLights().padding(EdgeInsets(top: 22, leading: 24, bottom: 0, trailing: 0)) }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 30, y: 16)
        try render(ZStack { WallpaperGradient(); window }, size: CGSize(width: 1480, height: 940), named: "calendar")
    }

    private func render(_ view: some View, size: CGSize, named name: String) throws {
        try renderHosted(view, size: size, named: name, directoryVariable: "MEETCUE_README_DIR")
    }
}

/// The window's close, minimize and zoom buttons, which belong to the window frame and so aren't in a render of its content.
private struct TrafficLights: View {
    var body: some View {
        HStack(spacing: 8) {
            ForEach([Color(red: 1, green: 0.37, blue: 0.34), Color(red: 1, green: 0.74, blue: 0.18), Color(red: 0.16, green: 0.78, blue: 0.25)], id: \.self) { color in
                Circle().fill(color).frame(width: 12, height: 12)
            }
        }
    }
}

private struct WallpaperGradient: View {
    var body: some View {
        LinearGradient(
            colors: [Color(red: 0.62, green: 0.76, blue: 1.0), Color(red: 0.99, green: 0.80, blue: 0.70)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
