import Foundation
import MeetCueCore
import Testing
@testable import MeetCue

@MainActor
final class OverlayModelTests {
    let source = FakeCalendarSource()
    let dismissedStorage = InMemoryDismissedAlertStorage()
    let quiet = QuietMode(storage: InMemoryQuietStorage())
    var now = AppFixtures.at(14, 0)
    var opened: [URL] = []
    lazy var store = MeetingStore(source: source, now: { [unowned self] in now }, calendar: AppFixtures.calendar)

    init() {
        source.snapshots = [AppFixtures.event(start: AppFixtures.at(14, 30), location: "Room 4B; https://acme.zoom.us/j/1")]
    }

    func makeModel() -> OverlayModel {
        store.refresh()
        let model = OverlayModel(
            store: store,
            quiet: quiet,
            dismissed: DismissedAlerts(storage: dismissedStorage),
            clock: { [unowned self] in now },
            calendar: AppFixtures.calendar,
            locale: Locale(identifier: "en_US"),
            openURL: { [unowned self] in opened.append($0) }
        )
        model.refresh()
        return model
    }

    func at(_ time: Date, _ model: OverlayModel) {
        now = time
        model.refresh()
    }

    var syncID: OccurrenceID { store.meetings.first { $0.title == "Team Sync" }!.id }

    @Test func alertAppearsAtAlertTime() {
        let model = makeModel()
        at(AppFixtures.at(14, 27), model)
        #expect(model.alertMeetings.isEmpty)
        at(AppFixtures.at(14, 28), model)
        #expect(model.alertMeetings.map(\.title) == ["Team Sync"])
        #expect(model.timeRange(for: model.alertMeetings[0]) == "2:30 – 3:00 PM")
    }

    @Test func quietModeSkipsTheAlertForGood() {
        let model = makeModel()
        quiet.turnOn(.oneHour, now: AppFixtures.at(13, 29), calendar: AppFixtures.calendar)
        at(AppFixtures.at(14, 28), model)
        #expect(model.state(of: syncID) == .dismissed)
        at(AppFixtures.at(14, 29), model)
        #expect(model.alertMeetings.isEmpty)
    }

    @Test func snoozeBringsTheAlertBack() {
        let model = makeModel()
        at(AppFixtures.at(14, 28), model)
        model.snoozeAlert()
        #expect(model.state(of: syncID) == .snoozed(until: AppFixtures.at(14, 29)))
        #expect(model.alertMeetings.isEmpty)
        at(AppFixtures.at(14, 29), model)
        #expect(model.alertMeetings.count == 1)
    }

    @Test func moveToCornerAndExpand() {
        let model = makeModel()
        at(AppFixtures.at(14, 28), model)
        model.moveAlertToCorner()
        #expect(model.alertMeetings.isEmpty)
        #expect(model.pillMeetings.map(\.title) == ["Team Sync"])
        model.expandPill()
        #expect(model.pillMeetings.isEmpty)
        #expect(model.alertMeetings.count == 1)
    }

    @Test func pillClosesAtStartWithoutNotes() {
        let model = makeModel()
        at(AppFixtures.at(14, 28), model)
        model.moveAlertToCorner()
        at(AppFixtures.at(14, 30), model)
        #expect(model.pillMeetings.isEmpty)
        #expect(model.state(of: syncID) == .done)
    }

    @Test func dismissBeforeStartWaitsForStartAndAfterStartIsDone() {
        let model = makeModel()
        at(AppFixtures.at(14, 28), model)
        model.dismissAlert()
        #expect(model.state(of: syncID) == .dismissed)
        at(AppFixtures.at(14, 30), model)
        #expect(model.state(of: syncID) == .done)
    }

    @Test func dismissingALateAlertIsDone() {
        now = AppFixtures.at(14, 33)
        let model = makeModel()
        #expect(model.alertMeetings.count == 1)
        model.dismissAlert()
        #expect(model.state(of: syncID) == .done)
    }

    @Test func dismissPillClosesOnlyThatPill() {
        source.snapshots.append(AppFixtures.event("Standup", start: AppFixtures.at(14, 30), series: "series-2"))
        let model = makeModel()
        at(AppFixtures.at(14, 28), model)
        model.moveAlertToCorner()
        model.dismissPill(syncID)
        #expect(model.pillMeetings.map(\.title) == ["Standup"])
    }

    @Test func joinOpensTheLinkAndCloses() {
        let model = makeModel()
        at(AppFixtures.at(14, 28), model)
        model.join(syncID)
        #expect(opened == [URL(string: "https://acme.zoom.us/j/1")!])
        #expect(model.state(of: syncID) == .done)
    }

    @Test func returnJoinsAndEscapeDismisses() {
        let model = makeModel()
        at(AppFixtures.at(14, 28), model)
        model.pressReturn()
        #expect(opened.count == 1)
        #expect(model.alertMeetings.isEmpty)

        source.snapshots = [AppFixtures.event("Standup", start: AppFixtures.at(15, 0), series: "series-2")]
        store.refresh()
        at(AppFixtures.at(14, 58), model)
        model.pressEscape()
        #expect(model.alertMeetings.isEmpty)
        #expect(opened.count == 1)
    }

    @Test func returnDismissesWithoutAVideoLink() {
        source.snapshots = [AppFixtures.event(start: AppFixtures.at(14, 30), location: "Room 4B")]
        let model = makeModel()
        at(AppFixtures.at(14, 28), model)
        model.pressReturn()
        #expect(opened.isEmpty)
        #expect(model.state(of: syncID) == .dismissed)
    }

    @Test func meetingsStartingTogetherShareTheAlert() {
        source.snapshots.append(AppFixtures.event("Design review", start: AppFixtures.at(14, 30), series: "series-2"))
        let model = makeModel()
        at(AppFixtures.at(14, 28), model)
        #expect(model.alertMeetings.map(\.title) == ["Design review", "Team Sync"])
        model.dismissAlert()
        #expect(model.alertMeetings.isEmpty)
    }

    @Test func aMovedMeetingStartsOver() {
        let model = makeModel()
        at(AppFixtures.at(14, 28), model)
        model.dismissAlert()
        source.snapshots = [AppFixtures.event(start: AppFixtures.at(14, 40))]
        store.refresh()
        model.refresh()
        #expect(model.state(of: syncID) == .waiting)
        at(AppFixtures.at(14, 38), model)
        #expect(model.alertMeetings.count == 1)
    }

    @Test func aCancelledMeetingClosesTheAlertWithANotice() {
        let model = makeModel()
        at(AppFixtures.at(14, 28), model)
        source.snapshots = []
        store.refresh()
        model.refresh()
        #expect(model.alertMeetings.isEmpty)
        #expect(model.notice == CancelNotice(text: "Team Sync was cancelled", until: AppFixtures.at(14, 28, second: 5)))
        #expect(model.schedule.wake == AppFixtures.at(14, 28, second: 5))
        at(AppFixtures.at(14, 28, second: 5), model)
        #expect(model.notice == nil)
    }

    @Test func aCancelledMeetingThatWasNotShowingLeavesNoNotice() {
        let model = makeModel()
        source.snapshots = []
        store.refresh()
        model.refresh()
        #expect(model.notice == nil)
        #expect(model.entries.isEmpty)
    }

    @Test func handledAlertsStayHandledAfterARelaunch() {
        let model = makeModel()
        at(AppFixtures.at(14, 28), model)
        model.dismissAlert()

        now = AppFixtures.at(14, 29)
        let relaunched = makeModel()
        #expect(relaunched.alertMeetings.isEmpty)
        #expect(relaunched.state(of: syncID) == .dismissed)
    }

    @Test func aMeetingMovedWhileClosedAlertsAfterARelaunch() {
        let model = makeModel()
        at(AppFixtures.at(14, 28), model)
        model.dismissAlert()

        source.snapshots = [AppFixtures.event(start: AppFixtures.at(14, 31))]
        now = AppFixtures.at(14, 29)
        #expect(makeModel().alertMeetings.count == 1)
    }

    @Test func aSimulatedMeetingAlertsAtOnceEvenWhenQuiet() {
        source.snapshots = []
        quiet.turnOn(.untilTurnedOff, now: now, calendar: AppFixtures.calendar)
        let model = makeModel()
        model.simulateMeeting()
        let simulated = model.alertMeetings
        #expect(simulated.map(\.title) == ["Simulated meeting"])
        #expect(simulated.first?.start == AppFixtures.at(14, 2))
        #expect(store.meetings.isEmpty)
        model.dismissAlert()
        #expect(dismissedStorage.records.isEmpty)
        at(AppFixtures.at(14, 2), model)
        #expect(model.entries.isEmpty)
    }

    @Test func scheduleWakesForEachDeadlineAndHoldsActivityBeforeAnAlert() {
        let model = makeModel()
        #expect(model.schedule == OverlaySchedule(wake: AppFixtures.at(14, 23), holdsActivity: false))
        at(AppFixtures.at(14, 23), model)
        #expect(model.schedule == OverlaySchedule(wake: AppFixtures.at(14, 28), holdsActivity: true))
        at(AppFixtures.at(14, 28), model)
        #expect(model.schedule == OverlaySchedule(wake: AppFixtures.at(15, 0), holdsActivity: false))
        model.snoozeAlert()
        #expect(model.schedule == OverlaySchedule(wake: AppFixtures.at(14, 29), holdsActivity: true))
    }
}
