import Foundation
import MeetCueCore
import Testing
@testable import MeetCue

@MainActor
final class OverlayModelTests {
    let source = FakeCalendarSource()
    let dismissedStorage = InMemoryDismissedAlertStorage()
    let quiet = QuietMode(storage: InMemoryQuietStorage())
    let notes = NoteStore(repository: FlakyNoteRepository(), saveDelay: .seconds(60))
    let settings = AppSettings(storage: InMemorySettingsStorage())
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
            notes: notes,
            dismissed: DismissedAlerts(storage: dismissedStorage),
            settings: settings,
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

    @Test func moveToCornerLeavesStartedMeetingsInTheAlert() {
        source.snapshots.append(AppFixtures.event("Standup", start: AppFixtures.at(14, 26), series: "series-2"))
        now = AppFixtures.at(14, 28)
        let model = makeModel()
        #expect(model.alertMeetings.map(\.title) == ["Standup", "Team Sync"])
        model.moveAlertToCorner()
        #expect(model.pillMeetings.map(\.title) == ["Team Sync"])
        #expect(model.alertMeetings.map(\.title) == ["Standup"])
    }

    @Test func noticeShortensLongTitles() {
        let longTitle = String(repeating: "A", count: 50)
        source.snapshots = [AppFixtures.event(longTitle, start: AppFixtures.at(14, 30))]
        let model = makeModel()
        at(AppFixtures.at(14, 28), model)
        source.snapshots = []
        store.refresh()
        model.refresh()
        #expect(model.notice?.text == String(repeating: "A", count: 29) + "… is no longer on your calendar")
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
        #expect(model.notice == CancelNotice(text: "Team Sync is no longer on your calendar", until: AppFixtures.at(14, 28, second: 5)))
        #expect(model.schedule.wake == AppFixtures.at(14, 28, second: 5))
        at(AppFixtures.at(14, 28, second: 5), model)
        #expect(model.notice == nil)
    }

    @Test func noNoticeForAMeetingThatAlreadyEnded() {
        let model = makeModel()
        at(AppFixtures.at(14, 28), model)
        #expect(model.alertMeetings.count == 1)
        source.snapshots = []
        store.refresh()
        at(AppFixtures.at(15, 1), model)
        #expect(model.notice == nil)
    }

    @Test func secondDisappearanceWithinFiveSecondsMergesTheNotice() {
        source.snapshots.append(AppFixtures.event("Standup", start: AppFixtures.at(14, 30), series: "series-2"))
        let model = makeModel()
        at(AppFixtures.at(14, 28), model)
        #expect(model.alertMeetings.count == 2)

        source.snapshots = [AppFixtures.event(start: AppFixtures.at(14, 30))]
        store.refresh()
        model.refresh()
        #expect(model.notice == CancelNotice(text: "Standup is no longer on your calendar", until: AppFixtures.at(14, 28, second: 5)))

        source.snapshots = []
        store.refresh()
        at(AppFixtures.at(14, 28, second: 2), model)
        #expect(model.notice == CancelNotice(text: "Standup and Team Sync are no longer on your calendar", until: AppFixtures.at(14, 28, second: 7)))
    }

    @Test func threeTitlesInOneNoticeAreListedWithCommasAndAnd() {
        source.snapshots.append(AppFixtures.event("Standup", start: AppFixtures.at(14, 30), series: "series-2"))
        source.snapshots.append(AppFixtures.event("Design review", start: AppFixtures.at(14, 30), series: "series-3"))
        let model = makeModel()
        at(AppFixtures.at(14, 28), model)
        #expect(model.alertMeetings.count == 3)

        source.snapshots = []
        store.refresh()
        model.refresh()
        #expect(model.notice?.text == "Design review, Standup and Team Sync are no longer on your calendar")
    }

    @Test func aTitleThatDisappearsTwiceWithinFiveSecondsIsListedOnce() {
        let model = makeModel()
        at(AppFixtures.at(14, 28), model)
        source.snapshots = []
        store.refresh()
        model.refresh()

        source.snapshots = [AppFixtures.event(start: AppFixtures.at(14, 30))]
        store.refresh()
        at(AppFixtures.at(14, 28, second: 1), model)
        #expect(model.alertMeetings.count == 1)

        source.snapshots = []
        store.refresh()
        at(AppFixtures.at(14, 28, second: 2), model)
        #expect(model.notice?.text == "Team Sync is no longer on your calendar")
    }

    @Test func aMeetingThatDisappearsAndReturnsAlertsAgain() {
        let model = makeModel()
        at(AppFixtures.at(14, 28), model)
        source.snapshots = []
        store.refresh()
        model.refresh()
        #expect(model.notice != nil)
        #expect(model.alertMeetings.isEmpty)

        source.snapshots = [AppFixtures.event(start: AppFixtures.at(14, 30), location: "https://acme.zoom.us/j/1")]
        store.refresh()
        at(AppFixtures.at(14, 29), model)
        #expect(model.alertMeetings.map(\.title) == ["Team Sync"])
    }

    @Test func joiningOneOfTwoClearsTheCard() {
        source.snapshots.append(AppFixtures.event("Design review", start: AppFixtures.at(14, 30), series: "series-2"))
        let model = makeModel()
        at(AppFixtures.at(14, 28), model)
        #expect(model.alertMeetings.count == 2)
        model.join(syncID)
        #expect(model.alertMeetings.isEmpty)
        let other = model.entries.values.first { $0.meeting.title == "Design review" }
        #expect(other?.state == .dismissed)
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

    @Test func movedWhileClosedThenMovedBackStillAlerts() {
        let model = makeModel()
        at(AppFixtures.at(14, 28), model)
        model.dismissAlert()

        source.snapshots = [AppFixtures.event(start: AppFixtures.at(14, 31))]
        now = AppFixtures.at(14, 29)
        _ = makeModel()

        source.snapshots = [AppFixtures.event(start: AppFixtures.at(14, 30))]
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

    var sync: Meeting { store.meetings.first { $0.title == "Team Sync" }! }

    @Test func notesCardAppearsAtStartForMeetingsWithNotes() {
        let model = makeModel()
        notes.setMarkdown("- [ ] Budget\n- [x] Hiring\n- [ ] Offsite", for: sync)
        at(AppFixtures.at(14, 28), model)
        #expect(model.topicCount(for: sync) == 2)
        model.moveAlertToCorner()
        at(AppFixtures.at(14, 30), model)
        #expect(model.pillMeetings.isEmpty)
        #expect(model.notesCardMeeting?.title == "Team Sync")
        at(AppFixtures.at(15, 0), model)
        #expect(model.notesCardMeeting == nil)
        #expect(model.state(of: syncID) == .done)
    }

    @Test func dismissingOrJoiningAfterStartShowsTheCard() {
        now = AppFixtures.at(14, 31)
        let model = makeModel()
        notes.setMarkdown("Agenda", for: sync)
        model.dismissAlert()
        #expect(model.notesCardMeeting?.title == "Team Sync")
    }

    @Test func hideAndShowTheNotesCard() {
        let model = makeModel()
        notes.setMarkdown("Agenda", for: sync)
        at(AppFixtures.at(14, 31), model)
        model.dismissAlert()
        model.hideNotesCard()
        #expect(model.state(of: syncID) == .hidden)
        #expect(model.canShowNotesCard)
        model.showNotesCard()
        #expect(model.notesCardMeeting?.title == "Team Sync")
        #expect(!model.canShowNotesCard)
        model.toggleNotesCard()
        #expect(model.notesCardMeeting == nil)
        model.toggleNotesCard()
        #expect(model.notesCardMeeting?.title == "Team Sync")
    }

    @Test func showBringsBackACardThatWasNeverShownOnceNotesExist() {
        let model = makeModel()
        at(AppFixtures.at(14, 31), model)
        model.dismissAlert()
        #expect(model.state(of: syncID) == .done)
        #expect(!model.canShowNotesCard)
        notes.setMarkdown("Agenda", for: sync)
        #expect(model.canShowNotesCard)
        model.showNotesCard()
        #expect(model.notesCardMeeting?.title == "Team Sync")
    }

    @Test func showPicksTheMeetingThatStartedLast() {
        source.snapshots.append(AppFixtures.event("Standup", start: AppFixtures.at(14, 0), minutes: 60, series: "series-2"))
        for event in source.snapshots { notes.setMarkdown("Agenda", for: MeetingMapper.meeting(from: event)) }
        now = AppFixtures.at(14, 40)
        let model = makeModel()
        #expect(model.notesCardMeeting?.title == "Team Sync")
        model.hideNotesCard()
        model.showNotesCard()
        #expect(model.notesCardMeeting?.title == "Team Sync")
        #expect(model.entries.values.first { $0.meeting.title == "Standup" }?.state == .hidden)
    }

    @Test func alertsOffCalendarsSkipTheAlertButShowTheCard() {
        store.filter = CalendarFilter(alertOffCalendarIDs: ["work"])
        let model = makeModel()
        notes.setMarkdown("Agenda", for: sync)
        #expect(model.schedule == OverlaySchedule(wake: AppFixtures.at(14, 28), holdsActivity: false))
        at(AppFixtures.at(14, 28), model)
        #expect(model.alertMeetings.isEmpty)
        #expect(model.state(of: syncID) == .dismissed)
        at(AppFixtures.at(14, 30), model)
        #expect(model.notesCardMeeting?.title == "Team Sync")
    }

    @Test func turningAlertsOffClosesAnOpenAlertQuietly() {
        let model = makeModel()
        at(AppFixtures.at(14, 28), model)
        #expect(model.alertMeetings.count == 1)
        store.filter = CalendarFilter(alertOffCalendarIDs: ["work"])
        model.refresh()
        #expect(model.alertMeetings.isEmpty)
        #expect(model.notice == nil)
        #expect(model.state(of: syncID) == .dismissed)
    }

    @Test func turningAlertsOffClosesAPillQuietly() {
        let model = makeModel()
        at(AppFixtures.at(14, 28), model)
        model.moveAlertToCorner()
        #expect(model.pillMeetings.count == 1)
        store.filter = CalendarFilter(alertOffCalendarIDs: ["work"])
        model.refresh()
        #expect(model.pillMeetings.isEmpty)
        #expect(model.notice == nil)
        #expect(model.state(of: syncID) == .dismissed)

        store.filter = CalendarFilter()
        at(AppFixtures.at(14, 28), model)
        model.refresh()
        #expect(model.alertMeetings.isEmpty)
        #expect(model.state(of: syncID) == .dismissed)
    }

    @Test func turningAlertsOffClosesASnoozedAlertQuietly() {
        let model = makeModel()
        at(AppFixtures.at(14, 28), model)
        model.snoozeAlert()
        #expect(model.state(of: syncID) == .snoozed(until: AppFixtures.at(14, 29)))
        store.filter = CalendarFilter(alertOffCalendarIDs: ["work"])
        model.refresh()
        #expect(model.notice == nil)
        #expect(model.state(of: syncID) == .dismissed)
        store.filter = CalendarFilter()
        at(AppFixtures.at(14, 29), model)
        #expect(model.alertMeetings.isEmpty)
    }

    @Test func leadTimeFollowsTheSetting() {
        settings.leadTime = 5
        let model = makeModel()
        at(AppFixtures.at(14, 24), model)
        #expect(model.alertMeetings.isEmpty)
        at(AppFixtures.at(14, 25), model)
        #expect(model.alertMeetings.map(\.title) == ["Team Sync"])
    }

    @Test func snoozeLengthFollowsTheSetting() {
        settings.snoozeLength = 5
        let model = makeModel()
        at(AppFixtures.at(14, 28), model)
        model.snoozeAlert()
        #expect(model.state(of: syncID) == .snoozed(until: AppFixtures.at(14, 33)))
    }

    @Test func notesCardFollowsTheSettings() {
        let model = makeModel()
        notes.setMarkdown("Agenda", for: store.meetings[0])
        settings.showNotesAtStart = false
        at(AppFixtures.at(14, 36), model)
        #expect(model.state(of: syncID) == .done)
        model.showNotesCard()
        #expect(model.notesCardMeeting?.title == "Team Sync")
        settings.hideNotesAtEnd = false
        at(AppFixtures.at(15, 0), model)
        #expect(model.notesCardMeeting?.title == "Team Sync")
    }

    @Test func meetingsWithoutNotesGetTheCardWhenOnlyWithNotesIsOff() {
        settings.notesOnlyWithNotes = false
        let model = makeModel()
        at(AppFixtures.at(14, 36), model)
        #expect(model.notesCardMeeting?.title == "Team Sync")
    }

    @Test func allDayEventsStayOutOfTheOverlays() {
        source.snapshots = [EventSnapshot(seriesKey: "holiday", title: "Holiday", start: AppFixtures.at(0, 0), end: AppFixtures.at(0, 0, day: 5), isAllDay: true, calendarID: "work")]
        let model = makeModel()
        #expect(model.entries.isEmpty)
    }
}
