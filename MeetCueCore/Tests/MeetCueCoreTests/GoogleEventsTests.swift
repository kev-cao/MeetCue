import Foundation
import Testing
@testable import MeetCueCore

struct GoogleEventsTests {
    private func decode(_ json: String) throws -> GoogleEventList {
        try JSONDecoder().decode(GoogleEventList.self, from: Data(json.utf8))
    }

    private func snapshots(_ items: String) throws -> [EventSnapshot] {
        let list = try decode(#"{"summary": "me@example.com", "items": [\#(items)]}"#)
        return GoogleEventMapper.snapshots(from: list.items ?? [], calendarID: "google", calendar: Fixtures.calendar)
    }

    @Test func mapsATimedEvent() throws {
        let events = try snapshots("""
        {
          "id": "evt1", "status": "confirmed", "iCalUID": "abc@google.com",
          "summary": "Team Sync", "location": "Room 4B", "description": "Agenda",
          "start": {"dateTime": "2026-11-04T14:30:00-05:00"},
          "end": {"dateTime": "2026-11-04T15:00:00-05:00"},
          "hangoutLink": "https://meet.google.com/abc-defg-hij",
          "attendees": [{"email": "a@example.com", "responseStatus": "accepted"},
                        {"email": "me@example.com", "self": true, "responseStatus": "tentative"},
                        {"email": "room@resource.calendar.google.com", "resource": true, "responseStatus": "accepted"}]
        }
        """)
        let event = try #require(events.first)
        #expect(events.count == 1)
        #expect(event.seriesKey == "abc@google.com")
        #expect(!event.isRecurring)
        #expect(event.title == "Team Sync")
        #expect(event.start == Fixtures.at(14, 30))
        #expect(event.end == Fixtures.at(15, 0))
        #expect(event.occurrenceDate == Fixtures.at(14, 30))
        #expect(event.location == "Room 4B")
        #expect(event.notes == "Agenda")
        #expect(event.url == URL(string: "https://meet.google.com/abc-defg-hij"))
        #expect(event.calendarID == "google")
        #expect(event.myStatus == .tentative)
        #expect(event.attendeeCount == 2)
        #expect(!event.isAllDay)
    }

    @Test func prefersTheConferenceVideoEntryPoint() throws {
        let events = try snapshots("""
        {
          "id": "evt1", "iCalUID": "abc", "summary": "Zoom call",
          "start": {"dateTime": "2026-11-04T14:30:00Z"}, "end": {"dateTime": "2026-11-04T15:00:00Z"},
          "hangoutLink": "https://meet.google.com/abc-defg-hij",
          "conferenceData": {"entryPoints": [{"entryPointType": "phone", "uri": "tel:+1-555"},
                                             {"entryPointType": "video", "uri": "https://acme.zoom.us/j/123"}]}
        }
        """)
        #expect(events.first?.url == URL(string: "https://acme.zoom.us/j/123"))
        #expect(MeetingMapper.meeting(from: events[0]).joinLink?.service == .zoom)
    }

    @Test func readsFractionalSecondsAndUTC() throws {
        let events = try snapshots("""
        {"id": "e", "iCalUID": "u", "summary": "x",
         "start": {"dateTime": "2026-11-04T19:30:00.000Z"}, "end": {"dateTime": "2026-11-04T20:00:00Z"}}
        """)
        #expect(events.first?.start == Fixtures.at(14, 30))
    }

    @Test func recurringInstanceKeepsItsOriginalStart() throws {
        let events = try snapshots("""
        {
          "id": "evt1_20261104T193000Z", "iCalUID": "series@google.com", "recurringEventId": "evt1", "summary": "Standup",
          "start": {"dateTime": "2026-11-04T15:00:00-05:00"}, "end": {"dateTime": "2026-11-04T15:15:00-05:00"},
          "originalStartTime": {"dateTime": "2026-11-04T14:30:00-05:00"}
        }
        """)
        let event = try #require(events.first)
        #expect(event.isRecurring)
        #expect(event.occurrenceDate == Fixtures.at(14, 30))
        #expect(event.start == Fixtures.at(15, 0))
    }

    @Test func allDayDatesStartAtLocalMidnight() throws {
        let events = try snapshots("""
        {"id": "e", "iCalUID": "u", "summary": "Offsite",
         "start": {"date": "2026-11-04"}, "end": {"date": "2026-11-05"}}
        """)
        let event = try #require(events.first)
        #expect(event.isAllDay)
        #expect(event.start == Fixtures.at(0, 0))
        #expect(event.end == Fixtures.at(0, 0, day: 5))
    }

    @Test(arguments: [
        ("needsAction", RSVP.pending),
        ("declined", RSVP.declined),
        ("accepted", RSVP.accepted),
        ("tentative", RSVP.tentative),
    ])
    func readsMyReply(status: String, expected: RSVP) throws {
        let events = try snapshots("""
        {"id": "e", "iCalUID": "u", "summary": "x",
         "start": {"dateTime": "2026-11-04T14:30:00-05:00"}, "end": {"dateTime": "2026-11-04T15:00:00-05:00"},
         "attendees": [{"email": "me@example.com", "self": true, "responseStatus": "\(status)"}, {"email": "b@example.com"}]}
        """)
        #expect(events.first?.myStatus == expected)
    }

    @Test func organizerWithoutAnAttendeeEntryCountsAsAccepted() throws {
        let events = try snapshots("""
        {"id": "e", "iCalUID": "u", "summary": "x", "organizer": {"email": "me@example.com", "self": true},
         "start": {"dateTime": "2026-11-04T14:30:00-05:00"}, "end": {"dateTime": "2026-11-04T15:00:00-05:00"},
         "attendees": [{"email": "b@example.com", "responseStatus": "accepted"}]}
        """)
        #expect(events.first?.myStatus == .accepted)
    }

    @Test func someoneElsesEventWithoutMeIsUnknown() throws {
        let events = try snapshots("""
        {"id": "e", "iCalUID": "u", "summary": "x", "organizer": {"email": "b@example.com"},
         "start": {"dateTime": "2026-11-04T14:30:00-05:00"}, "end": {"dateTime": "2026-11-04T15:00:00-05:00"},
         "attendees": [{"email": "b@example.com", "responseStatus": "accepted"}]}
        """)
        #expect(events.first?.myStatus == .unknown)
    }

    @Test func eventWithoutAttendeesIsMyOwn() throws {
        let events = try snapshots("""
        {"id": "e", "iCalUID": "u", "summary": "Focus",
         "start": {"dateTime": "2026-11-04T14:30:00-05:00"}, "end": {"dateTime": "2026-11-04T15:00:00-05:00"}}
        """)
        #expect(events.first?.myStatus == .accepted)
        #expect(events.first?.attendeeCount == 0)
    }

    @Test func skipsCancelledAndWorkingLocationEvents() throws {
        let events = try snapshots("""
        {"id": "a", "iCalUID": "a", "status": "cancelled", "summary": "Gone",
         "start": {"dateTime": "2026-11-04T14:30:00-05:00"}, "end": {"dateTime": "2026-11-04T15:00:00-05:00"}},
        {"id": "b", "iCalUID": "b", "eventType": "workingLocation", "summary": "Home",
         "start": {"date": "2026-11-04"}, "end": {"date": "2026-11-05"}},
        {"id": "c", "iCalUID": "c", "summary": "Kept",
         "start": {"dateTime": "2026-11-04T14:30:00-05:00"}, "end": {"dateTime": "2026-11-04T15:00:00-05:00"}}
        """)
        #expect(events.map(\.title) == ["Kept"])
    }

    @Test func skipsEventsWithoutTimes() throws {
        let events = try snapshots(#"{"id": "a", "iCalUID": "a", "summary": "Broken"}"#)
        #expect(events.isEmpty)
    }

    @Test func missingTitleAndICalUIDFallBack() throws {
        let events = try snapshots("""
        {"id": "evt9", "start": {"dateTime": "2026-11-04T14:30:00-05:00"}, "end": {"dateTime": "2026-11-04T15:00:00-05:00"}}
        """)
        #expect(events.first?.title == "")
        #expect(events.first?.seriesKey == "evt9")
    }

    @Test func decodesPagingAndCalendarName() throws {
        let list = try decode(#"{"summary": "me@example.com", "nextPageToken": "p2", "items": []}"#)
        #expect(list.summary == "me@example.com")
        #expect(list.nextPageToken == "p2")
    }
}
