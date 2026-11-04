import AppKit
import Foundation
import SwiftUI
import Testing
@testable import MeetCue

/// Renders the menu bar label and dropdown. Set `TEST_RUNNER_MEETCUE_SNAPSHOT_DIR` when running
/// `xcodebuild test` to also write them as PNGs for a visual check.
@MainActor
struct SnapshotTests {
    let source = FakeCalendarSource()
    let notes = NoteStore(repository: FlakyNoteRepository())

    func model(at time: Date) -> MenuBarModel {
        source.snapshots = [
            AppFixtures.event("PITR design review", start: AppFixtures.at(14, 30), location: "Room 4B; https://acme.zoom.us/j/1"),
        ]
        let store = MeetingStore(source: source, now: { time }, calendar: AppFixtures.calendar)
        store.refresh()
        return MenuBarModel(store: store, quiet: QuietMode(storage: InMemoryQuietStorage()), notes: notes, clock: { time }, calendar: AppFixtures.calendar, locale: Locale(identifier: "en_US"))
    }

    @Test func rendersLabelAndDropdown() throws {
        let model = model(at: AppFixtures.at(14, 6))
        try render(MenuBarLabel(model: model).background(.white), named: "menubar-label")
        try render(DropdownView(model: model, dismiss: {}).background(.white), named: "dropdown")
    }

    @Test func rendersSimulateItemWithOption() throws {
        let model = model(at: AppFixtures.at(14, 6))
        model.showsSimulateItem = true
        try render(DropdownView(model: model, dismiss: {}, simulateMeeting: {}).background(.white), named: "dropdown-option")
    }

    @Test func rendersTopicsAndNotesItems() throws {
        let model = model(at: AppFixtures.at(14, 6))
        let meeting = try #require(model.featured)
        model.addTopic("Budget", to: meeting)
        model.addTopic("Hiring plan", to: meeting)
        let overlays = OverlayModel(
            store: model.store,
            quiet: model.quiet,
            notes: notes,
            dismissed: DismissedAlerts(storage: InMemoryDismissedAlertStorage()),
            clock: { AppFixtures.at(14, 6) },
            calendar: AppFixtures.calendar
        )
        let dropdown = DropdownView(model: model, dismiss: {}, overlays: overlays, openMeetCue: {})
            .background(Color(white: 0.96))
        try renderHosted(dropdown, size: CGSize(width: 300, height: 440), named: "dropdown-notes")
    }

    @Test func rendersAccessPrompt() throws {
        source.access = .denied
        try render(DropdownView(model: model(at: AppFixtures.at(14, 6)), dismiss: {}).background(.white), named: "dropdown-access")
    }

    private func render(_ view: some View, named name: String) throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = try #require(renderer.cgImage)
        #expect(image.width > 0)
        guard let directory = ProcessInfo.processInfo.environment["MEETCUE_SNAPSHOT_DIR"] else { return }
        let data = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
        try data.write(to: URL(fileURLWithPath: directory).appendingPathComponent("\(name).png"))
    }
}
