import Foundation
import MeetCueCore
import Testing
@testable import MeetCue

@MainActor
struct AlertSchedulerTests {
    let source = FakeCalendarSource()

    func makeModel(clock: @escaping () -> Date) -> (MeetingStore, OverlayModel) {
        let store = MeetingStore(source: source, now: clock, calendar: AppFixtures.calendar)
        let model = OverlayModel(
            store: store,
            quiet: QuietMode(storage: InMemoryQuietStorage()),
            dismissed: DismissedAlerts(storage: InMemoryDismissedAlertStorage()),
            clock: clock,
            calendar: AppFixtures.calendar,
            openURL: { _ in }
        )
        return (store, model)
    }

    func eventually(_ condition: () -> Bool) async -> Bool {
        for _ in 0..<125 {
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

    @Test func settlesWhenTheTimerFires() async {
        let (store, model) = makeModel(clock: Date.init)
        source.snapshots = [AppFixtures.event(start: Date().addingTimeInterval(AlertTiming.standard.leadTime + 1.5))]
        store.refresh()
        let scheduler = AlertScheduler(model: model)
        scheduler.start()
        #expect(model.alertMeetings.isEmpty)
        #expect(await eventually { model.alertMeetings.count == 1 })
    }
}
