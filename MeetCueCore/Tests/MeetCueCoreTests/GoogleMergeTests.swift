import Foundation
import Testing
@testable import MeetCueCore

struct GoogleMergeTests {
    let meet = JoinLink(url: URL(string: "https://meet.google.com/abc-defg-hij")!, service: .meet)
    let zoom = JoinLink(url: URL(string: "https://acme.zoom.us/j/1")!, service: .zoom)

    @Test func matchedMeetingTakesGooglesLinkAndReplyAndAppearsOnce() {
        let start = Fixtures.at(14, 30)
        let local = [
            Fixtures.meeting("Team Sync", start: start, calendarID: "mac-work", status: .unknown),
            Fixtures.meeting("Team Sync", start: start, calendarID: "mac-shared", status: .unknown),
        ]
        let google = [Fixtures.meeting("Team Sync (Google)", start: start, calendarID: "google", status: .tentative, joinLink: meet)]
        let merged = GoogleMerge.merge(local: local, google: google)
        #expect(merged.map(\.calendarID) == ["mac-work", "mac-shared"])
        #expect(merged.allSatisfy { $0.joinLink == meet && $0.myStatus == .tentative && $0.title == "Team Sync" })
    }

    @Test func unknownReplyAndMissingLinkKeepTheMacs() {
        let start = Fixtures.at(14, 30)
        let local = [Fixtures.meeting(start: start, status: .declined, joinLink: zoom)]
        let google = [Fixtures.meeting(start: start, calendarID: "google", status: .unknown)]
        let merged = GoogleMerge.merge(local: local, google: google)
        #expect(merged == local)
    }

    @Test func unmatchedGoogleMeetingsAreKept() {
        let local = [Fixtures.meeting("Mac only", start: Fixtures.at(9, 0), series: "m")]
        let google = [
            Fixtures.meeting("Google only", start: Fixtures.at(10, 0), series: "g", calendarID: "google"),
            Fixtures.meeting("Mac only", start: Fixtures.at(9, 0), series: "m", calendarID: "google"),
        ]
        let merged = GoogleMerge.merge(local: local, google: google)
        #expect(merged.map(\.title) == ["Mac only", "Google only"])
        #expect(merged.map(\.calendarID) == ["work", "google"])
    }

    @Test func differentOccurrencesOfOneSeriesDontMatch() {
        let local = [Fixtures.meeting(start: Fixtures.at(9, 0), recurring: true)]
        let google = [Fixtures.meeting(start: Fixtures.at(9, 0, day: 5), recurring: true, calendarID: "google")]
        #expect(GoogleMerge.merge(local: local, google: google).count == 2)
    }
}
