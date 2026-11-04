import Foundation
import MeetCueCore
import Testing
@testable import MeetCue

@MainActor
struct AlertSchedulerTests {
    let source = FakeCalendarSource()

    func makeModel(
        notes: NoteStore = NoteStore(repository: FlakyNoteRepository()),
        settings: AppSettings = AppSettings(storage: InMemorySettingsStorage()),
        clock: @escaping () -> Date
    ) -> (MeetingStore, OverlayModel) {
        let store = MeetingStore(source: source, now: clock, calendar: AppFixtures.calendar)
        let model = OverlayModel(
            store: store,
            quiet: QuietMode(storage: InMemoryQuietStorage()),
            notes: notes,
            dismissed: DismissedAlerts(storage: InMemoryDismissedAlertStorage()),
            settings: settings,
            clock: clock,
            calendar: AppFixtures.calendar,
            openURL: { _ in }
        )
        return (store, model)
    }

    func eventually(timeout: Duration = .seconds(2.5), _ condition: () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return condition()
    }

    @Test func settlesWhenTheMeetingsChange() async {
        let (store, model) = makeModel { AppFixtures.at(14, 28) }
        let scheduler = AlertScheduler(model: model)
        scheduler.start()
        #expect(model.alertMeetings.isEmpty)
        source.snapshots = [AppFixtures.event(start: AppFixtures.at(14, 30))]
        store.refresh()
        #expect(await eventually { model.alertMeetings.count == 1 })
    }

    @Test func runsTheRefreshHookBeforeEveryRefresh() {
        let (_, model) = makeModel { AppFixtures.at(14, 0) }
        let scheduler = AlertScheduler(model: model)
        var refreshes = 0
        scheduler.beforeRefresh = { refreshes += 1 }
        scheduler.start()
        scheduler.refresh()
        #expect(refreshes == 2)
    }

    @Test func topicsCarriedIntoAMeetingInProgressShowOnItsCardAtOnce() {
        let clock = { AppFixtures.at(14, 40, day: 11) }
        func weekly(day: Int) -> EventSnapshot {
            AppFixtures.event(start: AppFixtures.at(14, 30, day: day), series: "weekly", recurring: true)
        }
        let notes = NoteStore(repository: FlakyNoteRepository(), saveDelay: .seconds(60))
        notes.setMarkdown("- [ ] Budget", for: MeetingMapper.meeting(from: weekly(day: 4)))
        source.snapshots = [weekly(day: 4), weekly(day: 11)]
        let (store, model) = makeModel(notes: notes, clock: clock)
        store.refresh()
        let carrier = NoteCarrier(notes: notes, store: store, calendar: AppFixtures.calendar)
        let scheduler = AlertScheduler(model: model)
        scheduler.beforeRefresh = { carrier.run(now: clock()) }
        scheduler.start()
        #expect(model.notesCardMeeting?.start == AppFixtures.at(14, 30, day: 11))
    }

    @Test func settlesWhenTheSettingsChange() async {
        let settings = AppSettings(storage: InMemorySettingsStorage())
        source.snapshots = [AppFixtures.event(start: AppFixtures.at(14, 30))]
        let (store, model) = makeModel(settings: settings) { AppFixtures.at(14, 24) }
        store.refresh()
        let scheduler = AlertScheduler(model: model)
        scheduler.start()
        #expect(model.alertMeetings.isEmpty)
        settings.leadTime = 10
        #expect(await eventually { model.alertMeetings.count == 1 })
    }

    @Test func settlesWhenTheTimerFires() async {
        let (store, model) = makeModel(clock: Date.init)
        source.snapshots = [AppFixtures.event(start: Date().addingTimeInterval(AlertTiming.standard.leadTime + 1.5))]
        store.refresh()
        let scheduler = AlertScheduler(model: model)
        scheduler.start()
        #expect(model.alertMeetings.isEmpty)
        #expect(await eventually(timeout: .seconds(10)) { model.alertMeetings.count == 1 })
    }
}
