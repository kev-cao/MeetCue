import AppKit
import Foundation
import MeetCueCore
import SwiftUI
import Testing
@testable import MeetCue

/// Renders the alert, the pill and the notes card with solid glass, since `ImageRenderer` can't draw Liquid Glass.
/// Set `TEST_RUNNER_MEETCUE_SNAPSHOT_DIR` when running `xcodebuild test` to also write them as PNGs.
@MainActor
struct OverlaySnapshotTests {
    let source = FakeCalendarSource()
    let notes = NoteStore(repository: FlakyNoteRepository())

    func model(at time: Date, events: [EventSnapshot]) -> OverlayModel {
        source.snapshots = events
        let store = MeetingStore(source: source, now: { time }, calendar: AppFixtures.calendar)
        store.refresh()
        let model = OverlayModel(
            store: store,
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

    var teamSync: EventSnapshot {
        AppFixtures.event(start: AppFixtures.at(14, 30), location: "Room 4B; https://meet.google.com/abc-defg-hij")
    }

    @Test func rendersAlert() throws {
        let now = AppFixtures.at(14, 28, second: 18)
        let model = model(at: now, events: [teamSync])
        #expect(model.alertMeetings.count == 1)
        for dark in [false, true] {
            try render(AlertScreenContent(model: model, now: now), dark: dark, named: dark ? "alert-dark" : "alert-light")
        }
    }

    @Test func rendersStackedAndStartedAlerts() throws {
        let review = AppFixtures.event("PITR design review", start: AppFixtures.at(14, 30), series: "series-2", location: "https://acme.zoom.us/j/1")
        let stackedAt = AppFixtures.at(14, 28, second: 18)
        try render(AlertScreenContent(model: model(at: stackedAt, events: [teamSync, review]), now: stackedAt), dark: false, named: "alert-stacked")
        let lateAt = AppFixtures.at(14, 30, second: 42)
        try render(AlertScreenContent(model: model(at: lateAt, events: [teamSync]), now: lateAt), dark: true, named: "alert-started")
    }

    @Test func rendersManySimultaneousMeetings() throws {
        let now = AppFixtures.at(14, 28, second: 18)
        let events = (1...5).map { index in
            AppFixtures.event("Meeting \(index)", start: AppFixtures.at(14, 30), series: "series-\(index)", location: index.isMultiple(of: 2) ? "https://acme.zoom.us/j/\(index)" : "Room \(index)")
        }
        let model = model(at: now, events: events)
        #expect(model.alertMeetings.count == 5)
        try renderHosted(ZStack { Wallpaper(dark: false); AlertScreenContent(model: model, now: now) }, named: "alert-many")
    }

    @Test func rendersPill() throws {
        let now = AppFixtures.at(14, 28, second: 18)
        let model = model(at: now, events: [teamSync])
        model.moveAlertToCorner()
        #expect(model.pillMeetings.count == 1)
        for dark in [false, true] {
            try render(corner(PillStackContent(model: model, now: now)), size: Self.cornerSize, dark: dark, named: dark ? "pill-dark" : "pill-light")
        }
    }

    @Test func rendersCancelNotice() throws {
        let review = AppFixtures.event("PITR design review", start: AppFixtures.at(14, 30), series: "series-2")
        let now = AppFixtures.at(14, 28, second: 18)
        let model = model(at: now, events: [teamSync, review])
        model.moveAlertToCorner()
        source.snapshots = [teamSync]
        model.store.refresh()
        model.refresh()
        #expect(model.notice?.text == "PITR design review is no longer on your calendar")
        try render(corner(PillStackContent(model: model, now: now)), size: Self.cornerSize, dark: false, named: "pill-cancelled")
    }

    /// The corner panel is sized with `PillStackContent.size(rows:)` rather than by measuring the view.
    @Test func pillStackSizeMatchesItsLayout() throws {
        let review = AppFixtures.event("PITR design review", start: AppFixtures.at(14, 30), series: "series-2")
        let now = AppFixtures.at(14, 28, second: 18)
        let model = model(at: now, events: [teamSync, review])
        model.moveAlertToCorner()
        let renderer = ImageRenderer(content: PillStackContent(model: model, now: now).environment(\.solidGlass, true))
        let image = try #require(renderer.cgImage)
        #expect(CGSize(width: image.width, height: image.height) == PillStackContent.size(rows: 2))
    }

    @Test func rendersAlertWithTopics() throws {
        let now = AppFixtures.at(14, 28, second: 18)
        notes.setMarkdown("- [ ] Budget\n- [ ] Hiring plan\n- [x] Offsite", for: MeetingMapper.meeting(from: teamSync))
        let model = model(at: now, events: [teamSync])
        #expect(model.topicCount(for: model.alertMeetings[0]) == 2)
        try render(AlertScreenContent(model: model, now: now), dark: false, named: "alert-topics")
    }

    static let sampleNote = """
    ## Topics
    - [ ] Move staging backups to every 4 hours? <!-- carried:2026-10-28 -->
    - [ ] Share restore throughput from last week's run
    - [x] Who owns the on-call runbook update

    Bring numbers from the [restore benchmark doc](https://example.com/bench). Compare against the **v24.3** baseline.
    """

    @Test func rendersNotesCard() throws {
        let now = AppFixtures.at(14, 40)
        notes.setMarkdown(Self.sampleNote, for: MeetingMapper.meeting(from: teamSync))
        let model = model(at: now, events: [teamSync])
        #expect(model.notesCardMeeting?.title == "Team Sync")
        for dark in [false, true] {
            try renderHosted(
                ZStack { Wallpaper(dark: dark); NotesCardStack(model: model).padding(.top, 24) },
                size: Self.cardSize,
                dark: dark,
                named: dark ? "notes-card-dark" : "notes-card-light"
            )
        }
    }

    @Test func rendersCompactNotesCard() throws {
        let now = AppFixtures.at(14, 40)
        notes.setMarkdown(Self.sampleNote, for: MeetingMapper.meeting(from: teamSync))
        let model = model(at: now, events: [teamSync])
        let layout = NotesCardLayout()
        layout.isCompact = true
        for dark in [false, true] {
            try renderHosted(
                ZStack { Wallpaper(dark: dark); NotesCardStack(model: model, layout: layout).padding(.top, 24) },
                size: Self.cornerSize,
                dark: dark,
                named: dark ? "notes-card-compact-dark" : "notes-card-compact-light"
            )
        }
        let compact = NSHostingView(rootView: NotesCardCompact(model: model, meeting: model.notesCardMeeting!, layout: layout).environment(\.solidGlass, true)).fittingSize
        #expect(compact.width == NotesCardCompact.width)
        #expect(compact.height == NotesCardCompact.height)
    }

    /// The panel fits the card: short notes make a short card, and long ones scroll inside a capped height.
    @Test func notesCardHugsShortNotesAndCapsLongOnes() throws {
        let now = AppFixtures.at(14, 40)
        let meeting = MeetingMapper.meeting(from: teamSync)
        notes.setMarkdown("- [ ] Budget", for: meeting)
        let model = model(at: now, events: [teamSync])
        let card = { NotesCardContent(model: model, meeting: meeting).fixedSize(horizontal: false, vertical: true).environment(\.solidGlass, true) }
        let short = NSHostingView(rootView: card()).fittingSize
        notes.setMarkdown((1...40).map { "- [ ] Topic \($0)" }.joined(separator: "\n"), for: meeting)
        let long = NSHostingView(rootView: card()).fittingSize
        notes.setMarkdown((1...80).map { "- [ ] Topic \($0)" }.joined(separator: "\n"), for: meeting)
        let longer = NSHostingView(rootView: card()).fittingSize
        #expect(short.width == NotesCardContent.width)
        #expect(short.height < 200)
        #expect(long.height > short.height + 200)
        #expect(longer.height == long.height)
    }

    @Test func cornerPanelsStackDownFromTheMenuBar() {
        let visible = NSRect(x: 0, y: 0, width: 1440, height: 875)
        let frame = CornerPanel<EmptyView>.cornerFrame(size: CGSize(width: 392, height: 300), below: 80, in: visible)
        #expect(frame == NSRect(x: 1048, y: 495, width: 392, height: 300))
    }

    /// A dragged card stays where it was put, and can't leave the screen except for its transparent margin.
    @Test func draggedCardStaysOnScreen() {
        let visible = NSRect(x: 0, y: 0, width: 1440, height: 875)
        let size = CGSize(width: 392, height: 300)
        let frame = { (point: NSPoint) in CornerPanel<EmptyView>.anchoredFrame(size: size, topRight: point, margin: 16, in: visible) }
        #expect(frame(NSPoint(x: 900, y: 600)) == NSRect(x: 508, y: 300, width: 392, height: 300))
        #expect(frame(NSPoint(x: 100, y: 1200)) == NSRect(x: -16, y: 591, width: 392, height: 300))
        #expect(frame(NSPoint(x: 2000, y: 50)) == NSRect(x: 1064, y: -16, width: 392, height: 300))
        let tall = CornerPanel<EmptyView>.anchoredFrame(size: CGSize(width: 392, height: 1000), topRight: NSPoint(x: 900, y: 400), margin: 16, in: visible)
        #expect(tall.maxY == 891)
    }

    static let cardSize = CGSize(width: 720, height: 520)
    static let cornerSize = CGSize(width: 720, height: 260)

    /// Places a pill stack where the panel puts it: the top-right corner, below the menu bar.
    private func corner(_ pills: some View) -> some View {
        pills
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.top, 24)
    }

    private func render(_ view: some View, size: CGSize = CGSize(width: 1280, height: 800), dark: Bool, named name: String) throws {
        let screen = ZStack {
            Wallpaper(dark: dark)
            view
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .environment(\.solidGlass, true)
        .environment(\.colorScheme, dark ? .dark : .light)
        let renderer = ImageRenderer(content: screen)
        renderer.scale = 2
        let image = try #require(renderer.cgImage)
        #expect(image.width == Int(size.width) * 2)
        guard let directory = ProcessInfo.processInfo.environment["MEETCUE_SNAPSHOT_DIR"] else { return }
        let data = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
        try data.write(to: URL(fileURLWithPath: directory).appendingPathComponent("\(name).png"))
    }
}
