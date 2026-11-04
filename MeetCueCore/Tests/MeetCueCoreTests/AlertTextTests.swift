import Foundation
import Testing
@testable import MeetCueCore

struct AlertTextTests {
    let start = Fixtures.at(14, 30)

    @Test func countsDownToStartRoundingUp() {
        #expect(AlertText.countdown(to: start, now: Fixtures.at(14, 28)) == Countdown(hasStarted: false, clock: "2:00"))
        #expect(AlertText.countdown(to: start, now: Fixtures.at(14, 28, second: 18)) == Countdown(hasStarted: false, clock: "1:42"))
        #expect(AlertText.countdown(to: start, now: Fixtures.at(14, 28, second: 17).addingTimeInterval(0.5)) == Countdown(hasStarted: false, clock: "1:43"))
        #expect(AlertText.countdown(to: start, now: Fixtures.at(14, 29, second: 59).addingTimeInterval(0.5)) == Countdown(hasStarted: false, clock: "0:01"))
    }

    @Test func countsUpAfterStart() {
        #expect(AlertText.countdown(to: start, now: start) == Countdown(hasStarted: true, clock: "0:00"))
        #expect(AlertText.countdown(to: start, now: Fixtures.at(14, 30, second: 42).addingTimeInterval(0.9)) == Countdown(hasStarted: true, clock: "0:42"))
        #expect(AlertText.countdown(to: start, now: Fixtures.at(15, 35, second: 3)) == Countdown(hasStarted: true, clock: "1:05:03"))
    }

    @Test func pillLineAddsThePlace() {
        let zoom = JoinLink(url: URL(string: "https://acme.zoom.us/j/1")!, service: .zoom)
        let both = Fixtures.meeting(start: start, location: "Room 4B", joinLink: zoom)
        let neither = Fixtures.meeting(start: start)
        #expect(AlertText.pillLine(for: both, now: Fixtures.at(14, 28, second: 18)) == "Starts in 1:42 · Room 4B · Zoom")
        #expect(AlertText.pillLine(for: neither, now: Fixtures.at(14, 28, second: 18)) == "Starts in 1:42")
        #expect(AlertText.pillLine(for: neither, now: Fixtures.at(14, 30, second: 42)) == "Started 0:42 ago")
    }

    @Test func progressRunsFromAlertTimeToStart() {
        #expect(AlertText.progress(toward: start, now: Fixtures.at(14, 27), leadTime: 120) == 0)
        #expect(AlertText.progress(toward: start, now: Fixtures.at(14, 28), leadTime: 120) == 0)
        #expect(AlertText.progress(toward: start, now: Fixtures.at(14, 29), leadTime: 120) == 0.5)
        #expect(AlertText.progress(toward: start, now: Fixtures.at(14, 31), leadTime: 120) == 1)
        #expect(AlertText.progress(toward: start, now: Fixtures.at(14, 29), leadTime: 0) == 1)
    }
}
