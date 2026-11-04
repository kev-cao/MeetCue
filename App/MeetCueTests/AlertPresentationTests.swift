import Foundation
import MeetCueCore
import Testing
@testable import MeetCue

@MainActor
struct AlertPresentationTests {
    @Test func mainDisplayOnlyKeepsTheScreenWithTheMenuBar() {
        #expect(OverlayController.alertScreens([1, 2, 3], displays: .all) == [1, 2, 3])
        #expect(OverlayController.alertScreens([1, 2, 3], displays: .main) == [1])
        #expect(OverlayController.alertScreens([Int](), displays: .main).isEmpty)
    }

    @Test func soundPlaysOnlyWhenTheAlertGainsAMeeting() {
        let a = OccurrenceID(seriesKey: "a", originalDate: nil)
        let b = OccurrenceID(seriesKey: "b", originalDate: nil)
        #expect(OverlayController.alertGainedMeetings(from: [], to: [a]))
        #expect(OverlayController.alertGainedMeetings(from: [a], to: [a, b]))
        #expect(!OverlayController.alertGainedMeetings(from: [a], to: [a]))
        #expect(!OverlayController.alertGainedMeetings(from: [a, b], to: [a]))
        #expect(!OverlayController.alertGainedMeetings(from: [a], to: []))
    }

    @Test func glassTintGoesFromTheSurfaceToOpaque() {
        #expect(GlassTint.opacity(base: 0, glassOpacity: 0, reduceTransparency: false) == 0)
        #expect(GlassTint.opacity(base: 0, glassOpacity: 0.4, reduceTransparency: false) == 0.4)
        #expect(GlassTint.opacity(base: 0.75, glassOpacity: 0.5, reduceTransparency: false) == 0.875)
        #expect(GlassTint.opacity(base: 0.75, glassOpacity: 1, reduceTransparency: false) == 1)
        #expect(GlassTint.opacity(base: 0, glassOpacity: 0, reduceTransparency: true) == 1)
    }
}
