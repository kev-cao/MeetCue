import Foundation
import Testing
@testable import MeetCueCore

struct ClockStyleTests {
    @Test func followsLocaleAndHourCycleOverride() {
        #expect(ClockStyle.uses24Hour(Locale(identifier: "en_US")) == false)
        #expect(ClockStyle.uses24Hour(Locale(identifier: "en_GB")) == true)
        var components = Locale.Components(locale: Locale(identifier: "en_US"))
        components.hourCycle = .zeroToTwentyThree
        #expect(ClockStyle.uses24Hour(Locale(components: components)) == true)
    }
}
