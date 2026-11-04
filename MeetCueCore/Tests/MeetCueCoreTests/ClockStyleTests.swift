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

    @Test func recognizesOtherLocalesAndQuotedLiterals() {
        #expect(ClockStyle.uses24Hour(Locale(identifier: "ja_JP")) == true)
        #expect(ClockStyle.uses24Hour(Locale(identifier: "de_DE")) == true)
        var zeroToEleven = Locale.Components(locale: Locale(identifier: "en_US"))
        zeroToEleven.hourCycle = .zeroToEleven
        #expect(ClockStyle.uses24Hour(Locale(components: zeroToEleven)) == false)
        var oneToTwentyFour = Locale.Components(locale: Locale(identifier: "en_US"))
        oneToTwentyFour.hourCycle = .oneToTwentyFour
        #expect(ClockStyle.uses24Hour(Locale(components: oneToTwentyFour)) == true)
    }
}
