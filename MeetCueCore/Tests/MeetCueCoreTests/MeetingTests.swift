import Foundation
import Testing
@testable import MeetCueCore

struct MeetingTests {
    @Test func recurringIDIncludesOccurrenceDate() {
        let a = OccurrenceID.make(externalID: "abc", occurrenceDate: Fixtures.at(14, 30), isRecurring: true)
        let b = OccurrenceID.make(externalID: "abc", occurrenceDate: Fixtures.at(14, 30, day: 11), isRecurring: true)
        #expect(a != b)
        #expect(a.seriesKey == b.seriesKey)
        #expect(a.storageKey == "abc|\(Int(Fixtures.at(14, 30).timeIntervalSince1970))")
    }

    @Test func oneOffIDIgnoresDate() {
        let before = OccurrenceID.make(externalID: "abc", occurrenceDate: Fixtures.at(14, 30), isRecurring: false)
        let moved = OccurrenceID.make(externalID: "abc", occurrenceDate: Fixtures.at(16, 0), isRecurring: false)
        #expect(before == moved)
        #expect(before.storageKey == "abc")
    }

    @Test func placeLineShowsLocationAndService() {
        let link = JoinLink(url: URL(string: "https://meet.google.com/abc")!, service: .meet)
        let both = Fixtures.meeting(start: Fixtures.at(14, 30), location: "Room 4B", joinLink: link)
        let roomOnly = Fixtures.meeting(start: Fixtures.at(14, 30), location: "Room 4B")
        let videoOnly = Fixtures.meeting(start: Fixtures.at(14, 30), joinLink: link)
        let neither = Fixtures.meeting(start: Fixtures.at(14, 30))
        #expect(both.placeLine == "Room 4B · Google Meet")
        #expect(roomOnly.placeLine == "Room 4B")
        #expect(videoOnly.placeLine == "Google Meet")
        #expect(neither.placeLine == nil)
    }

    @Test func fractionalSecondsNormalize() {
        let a = OccurrenceID.make(externalID: "abc", occurrenceDate: Fixtures.at(14, 30), isRecurring: true)
        let b = OccurrenceID.make(externalID: "abc", occurrenceDate: Fixtures.at(14, 30).addingTimeInterval(0.4), isRecurring: true)
        #expect(a == b)
        #expect(a.storageKey == b.storageKey)
    }

    @Test func isRecurringFollowsID() {
        #expect(Fixtures.meeting(start: Fixtures.at(14, 30), recurring: true).isRecurring == true)
        #expect(Fixtures.meeting(start: Fixtures.at(14, 30), recurring: false).isRecurring == false)
    }

    @Test func initTruncatesToo() {
        let fractional = OccurrenceID(seriesKey: "s", originalDate: Fixtures.at(14, 30).addingTimeInterval(0.4))
        #expect(fractional == OccurrenceID.make(externalID: "s", occurrenceDate: Fixtures.at(14, 30), isRecurring: true))
    }
}
