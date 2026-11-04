import Foundation
import Testing
@testable import MeetCueCore

struct MeetingMapperTests {
    @Test func mapsFieldsAndSplitsLocation() {
        let event = EventSnapshot(
            seriesKey: "abc",
            isRecurring: true,
            title: "  Team Sync ",
            start: Fixtures.at(14, 30),
            end: Fixtures.at(15, 0),
            location: "Room 4B; https://acme.zoom.us/j/1",
            calendarID: "work",
            myStatus: .accepted,
            attendeeCount: 6
        )
        let meeting = MeetingMapper.meeting(from: event)
        #expect(meeting.id == .make(externalID: "abc", occurrenceDate: Fixtures.at(14, 30), isRecurring: true))
        #expect(meeting.title == "Team Sync")
        #expect(meeting.placeLine == "Room 4B · Zoom")
        #expect(meeting.calendarID == "work")
        #expect(meeting.myStatus == .accepted)
        #expect(meeting.attendeeCount == 6)
    }

    @Test func rescheduledOccurrenceKeepsItsOriginalDate() {
        let moved = EventSnapshot(
            seriesKey: "abc",
            occurrenceDate: Fixtures.at(14, 30),
            isRecurring: true,
            title: "Team Sync",
            start: Fixtures.at(16, 0),
            end: Fixtures.at(16, 30),
            calendarID: "work"
        )
        let meeting = MeetingMapper.meeting(from: moved)
        #expect(meeting.id == .make(externalID: "abc", occurrenceDate: Fixtures.at(14, 30), isRecurring: true))
        #expect(meeting.start == Fixtures.at(16, 0))
    }

    @Test func blankTitleBecomesUntitled() {
        let event = EventSnapshot(seriesKey: "x", title: "   ", start: Fixtures.at(9, 0), end: Fixtures.at(9, 30), calendarID: "work")
        #expect(MeetingMapper.meeting(from: event).title == "Untitled")
    }

    @Test func videoLinkFromURLOrNotes() {
        let byURL = EventSnapshot(
            seriesKey: "u",
            title: "Standup",
            start: Fixtures.at(9, 0),
            end: Fixtures.at(9, 15),
            url: URL(string: "https://meet.google.com/abc-defg-hij"),
            calendarID: "work"
        )
        #expect(MeetingMapper.meeting(from: byURL).placeLine == "Google Meet")
        let byNotes = EventSnapshot(
            seriesKey: "n",
            title: "Review",
            start: Fixtures.at(10, 0),
            end: Fixtures.at(10, 30),
            location: "Room 4B",
            notes: "Join: https://teams.microsoft.com/l/meetup-join/abc",
            calendarID: "work"
        )
        #expect(MeetingMapper.meeting(from: byNotes).placeLine == "Room 4B · Microsoft Teams")
    }
}
