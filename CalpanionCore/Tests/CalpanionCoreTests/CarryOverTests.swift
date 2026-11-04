import Foundation
import Testing
@testable import CalpanionCore

struct CarryOverTests {
    let oct28 = Fixtures.at(14, 30, month: 10, day: 28)

    func carry(_ source: String, into target: String) -> String {
        CarryOver.carry(from: source, sourceDate: oct28, into: target, calendar: Fixtures.calendar)
    }

    @Test func carriesOnlyUncheckedItems() {
        let source = """
        - [x] Review alert thresholds
        - [ ] Move staging backups
        Context from the incident review
        """
        let result = carry(source, into: "- [ ] Share restore throughput")
        #expect(result == """
        - [ ] Share restore throughput
        - [ ] Move staging backups <!-- carried:2026-10-28 -->
        """)
    }

    @Test func skipsItemsAlreadyInTarget() {
        let result = carry("- [ ] Move staging backups", into: "- [x] move  STAGING backups")
        #expect(result == "- [x] move  STAGING backups")
    }

    @Test func keepsOriginalCarriedDate() {
        let result = carry("- [ ] Old topic <!-- carried:2026-10-14 -->", into: "")
        #expect(result == "- [ ] Old topic <!-- carried:2026-10-14 -->")
    }

    @Test func nothingToCarryLeavesTargetAlone() {
        #expect(carry("- [x] Done", into: "Intro") == "Intro")
    }

    @Test func crlfTargetKeepsCRLF() {
        #expect(carry("- [ ] B", into: "- [ ] A\r\n") == "- [ ] A\r\n- [ ] B <!-- carried:2026-10-28 -->")
        #expect(carry("- [ ] B", into: "- [ ] A\r\n- [ ] C") == "- [ ] A\r\n- [ ] C\r\n- [ ] B <!-- carried:2026-10-28 -->")
    }

    @Test func malformedMarkerIsReplaced() {
        let expected = "- [ ] Topic <!-- carried:2026-10-28 -->"
        #expect(carry("- [ ] Topic <!-- carried:2026-1-4 -->", into: "") == expected)
        #expect(carry("- [ ] Topic <!-- carried:2026-13-45 -->", into: "") == expected)
    }

    @Test func duplicateWithinSourceCarriesOnce() {
        #expect(carry("- [ ] Ship it\n- [ ] ship  IT", into: "") == "- [ ] Ship it <!-- carried:2026-10-28 -->")
    }

    @Test func lateEveningUsesCallersTimeZone() {
        let result = CarryOver.carry(from: "- [ ] A", sourceDate: Fixtures.at(23, 30, month: 10, day: 28), into: "", calendar: Fixtures.calendar)
        #expect(result == "- [ ] A <!-- carried:2026-10-28 -->")
    }

    @Test func nextOccurrenceIsEarliestLaterInSameSeries() {
        let oct28Sync = Fixtures.meeting(start: oct28, series: "sync", recurring: true)
        let nov4 = Fixtures.meeting(start: Fixtures.at(14, 30), series: "sync", recurring: true)
        let nov11 = Fixtures.meeting(start: Fixtures.at(14, 30, day: 11), series: "sync", recurring: true)
        let other = Fixtures.meeting("Standup", start: Fixtures.at(10, 0, month: 10, day: 29), series: "standup", recurring: true)
        #expect(CarryOver.nextOccurrence(after: oct28Sync, in: [nov11, other, nov4, oct28Sync]) == nov4)
    }

    @Test func noNextOccurrenceForOneOffOrEndedSeries() {
        let oneOff = Fixtures.meeting(start: oct28, series: "x")
        let last = Fixtures.meeting(start: oct28, series: "sync", recurring: true)
        #expect(CarryOver.nextOccurrence(after: oneOff, in: [oneOff]) == nil)
        #expect(CarryOver.nextOccurrence(after: last, in: [last]) == nil)
    }
}
