import Foundation
import Testing
@testable import MeetCue

@MainActor
struct QuietModeTests {
    let storage = InMemoryQuietStorage()

    @Test func durations() {
        let quiet = QuietMode(storage: storage)
        quiet.turnOn(.oneHour, now: AppFixtures.at(13, 0), calendar: AppFixtures.calendar)
        #expect(quiet.until == AppFixtures.at(14, 0))
        quiet.turnOn(.endOfToday, now: AppFixtures.at(13, 0), calendar: AppFixtures.calendar)
        #expect(quiet.until == AppFixtures.at(0, 0, day: 5))
        quiet.turnOn(.untilTurnedOff, now: AppFixtures.at(13, 0), calendar: AppFixtures.calendar)
        #expect(quiet.until == .distantFuture)
    }

    @Test func expires() {
        let quiet = QuietMode(storage: storage)
        quiet.turnOn(.oneHour, now: AppFixtures.at(13, 0), calendar: AppFixtures.calendar)
        #expect(quiet.isOn(at: AppFixtures.at(13, 59)))
        #expect(!quiet.isOn(at: AppFixtures.at(14, 0)))
    }

    @Test func persistsAcrossLaunchesUntilTurnedOff() {
        QuietMode(storage: storage).turnOn(.untilTurnedOff, now: AppFixtures.at(13, 0), calendar: AppFixtures.calendar)
        let relaunched = QuietMode(storage: storage)
        #expect(relaunched.until == .distantFuture)
        #expect(relaunched.preset == .untilTurnedOff)
        relaunched.turnOff()
        let afterOff = QuietMode(storage: storage)
        #expect(afterOff.until == nil)
        #expect(afterOff.preset == nil)
    }

    @Test func readsAsOffOnceItHasExpired() {
        let quiet = QuietMode(storage: storage)
        quiet.turnOn(.oneHour, now: AppFixtures.at(13, 0), calendar: AppFixtures.calendar)
        quiet.clearIfExpired(at: AppFixtures.at(13, 59))
        #expect(quiet.until == AppFixtures.at(14, 0))
        #expect(quiet.preset == .oneHour)
        quiet.clearIfExpired(at: AppFixtures.at(14, 0))
        #expect(quiet.until == nil)
        #expect(quiet.preset == nil)
        #expect(QuietMode(storage: storage).until == nil)
        quiet.turnOn(.untilTurnedOff, now: AppFixtures.at(13, 0), calendar: AppFixtures.calendar)
        quiet.clearIfExpired(at: AppFixtures.at(23, 0))
        #expect(quiet.until == .distantFuture)
    }
}
