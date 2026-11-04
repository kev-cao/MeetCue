import Foundation
import Testing
@testable import CalpanionCore

struct JoinLinkParserTests {
    @Test func eventURLFieldWinsOverLocationAndNotes() {
        let result = JoinLinkParser.parse(
            url: URL(string: "https://meet.google.com/abc-defg-hij"),
            location: "Room 4B",
            notes: "Backup: https://acme.zoom.us/j/1"
        )
        #expect(result.joinLink?.service == .meet)
        #expect(result.location == "Room 4B")
    }

    @Test func linkInLocationMovesToJoinLink() {
        let result = JoinLinkParser.parse(url: nil, location: "https://acme.zoom.us/j/123?pwd=x", notes: nil)
        #expect(result.joinLink?.url.absoluteString == "https://acme.zoom.us/j/123?pwd=x")
        #expect(result.joinLink?.service == .zoom)
        #expect(result.location == nil)
    }

    @Test func roomAndLinkInLocationSplit() {
        let result = JoinLinkParser.parse(url: nil, location: "Room 4B; https://acme.zoom.us/j/123", notes: nil)
        #expect(result.joinLink?.service == .zoom)
        #expect(result.location == "Room 4B")
    }

    @Test func teamsLinkInNotes() {
        let result = JoinLinkParser.parse(
            url: nil,
            location: nil,
            notes: "Join here: https://teams.microsoft.com/l/meetup-join/abc"
        )
        #expect(result.joinLink?.service == .teams)
        #expect(result.location == nil)
    }

    @Test func plainTextHasNoLink() {
        let result = JoinLinkParser.parse(url: nil, location: "Cafe on 5th", notes: "Bring slides")
        #expect(result.joinLink == nil)
        #expect(result.location == "Cafe on 5th")
    }

    @Test func nonVideoURLFieldIsIgnored() {
        let result = JoinLinkParser.parse(url: URL(string: "https://docs.google.com/document/d/1"), location: nil, notes: nil)
        #expect(result.joinLink == nil)
    }

    @Test func lookalikeHostsAreRejected() {
        #expect(JoinLinkParser.service(for: URL(string: "https://zoom.us.evil.com/j/1")!) == nil)
        #expect(JoinLinkParser.service(for: URL(string: "https://evilzoom.us/j/1")!) == nil)
        #expect(JoinLinkParser.service(for: URL(string: "https://us02web.zoom.us/j/1")!) == .zoom)
    }

    @Test func meetLinkInLocation() {
        let result = JoinLinkParser.parse(url: nil, location: "https://meet.google.com/abc-defg-hij", notes: nil)
        #expect(result.joinLink?.service == .meet)
        #expect(result.location == nil)
    }

    @Test func nonASCIILocationKeepsItsText() {
        let result = JoinLinkParser.parse(url: nil, location: "Café 2F · https://acme.zoom.us/j/1", notes: nil)
        #expect(result.location == "Café 2F")
    }

    @Test func linkInTheMiddleLeavesCleanParts() {
        let result = JoinLinkParser.parse(
            url: nil,
            location: "Room 4B · https://acme.zoom.us/j/123 · Floor 2",
            notes: nil
        )
        #expect(result.location == "Room 4B · Floor 2")
    }

    @Test func bracketedLinkLeavesNoBrackets() {
        let result = JoinLinkParser.parse(url: nil, location: "Room 4B (https://acme.zoom.us/j/1)", notes: nil)
        #expect(result.location == "Room 4B")
    }

    @Test func twoLinksInLocation() {
        let result = JoinLinkParser.parse(
            url: nil,
            location: "Room 4B; https://meet.google.com/abc; https://acme.zoom.us/j/1",
            notes: nil
        )
        #expect(result.joinLink?.service == .meet)
        #expect(result.location == "Room 4B")
    }

    @Test func locationWithoutLinksIsOnlyWhitespaceTrimmed() {
        let result = JoinLinkParser.parse(url: nil, location: "  Wing A-  ", notes: nil)
        #expect(result.location == "Wing A-")
    }
}
