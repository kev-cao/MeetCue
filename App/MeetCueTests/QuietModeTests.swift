import Foundation
import Testing
@testable import MeetCue

@MainActor
struct QuietModeTests {
    let testDefaults = TestDefaults()

    @Test func durations() {
        let quiet = QuietMode(defaults: testDefaults.defaults)
        quiet.turnOn(.oneHour, now: AppFixtures.at(13, 0), calendar: AppFixtures.calendar)
        #expect(quiet.until == AppFixtures.at(14, 0))
        quiet.turnOn(.endOfToday, now: AppFixtures.at(13, 0), calendar: AppFixtures.calendar)
        #expect(quiet.until == AppFixtures.at(0, 0, day: 5))
        quiet.turnOn(.untilTurnedOff, now: AppFixtures.at(13, 0), calendar: AppFixtures.calendar)
        #expect(quiet.until == .distantFuture)
    }

    @Test func expires() {
        let quiet = QuietMode(defaults: testDefaults.defaults)
        quiet.turnOn(.oneHour, now: AppFixtures.at(13, 0), calendar: AppFixtures.calendar)
        #expect(quiet.isOn(at: AppFixtures.at(13, 59)))
        #expect(!quiet.isOn(at: AppFixtures.at(14, 0)))
    }

    @Test func persistsAcrossLaunchesUntilTurnedOff() {
        QuietMode(defaults: testDefaults.defaults).turnOn(.untilTurnedOff, now: AppFixtures.at(13, 0), calendar: AppFixtures.calendar)
        let relaunched = QuietMode(defaults: testDefaults.defaults)
        #expect(relaunched.until == .distantFuture)
        #expect(relaunched.preset == .untilTurnedOff)
        relaunched.turnOff()
        let afterOff = QuietMode(defaults: testDefaults.defaults)
        #expect(afterOff.until == nil)
        #expect(afterOff.preset == nil)
    }
}
