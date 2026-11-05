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

    @Test func soundPlaysOncePerAlert() {
        let a = OccurrenceID(seriesKey: "a", originalDate: nil)
        let b = OccurrenceID(seriesKey: "b", originalDate: nil)
        func chimes(_ from: [OccurrenceID: OverlayState], _ to: [OccurrenceID: OverlayState]) -> Bool {
            OverlayController.alertChimes(from: from, to: to)
        }
        #expect(chimes([:], [a: .alert]))
        #expect(chimes([a: .alert], [a: .alert, b: .alert]))
        #expect(!chimes([a: .alert], [a: .alert]))
        #expect(!chimes([a: .alert, b: .alert], [a: .alert]))
        #expect(!chimes([a: .alert], [:]))
        #expect(!chimes([a: .alert], [a: .pill]))
        #expect(!chimes([a: .pill], [a: .alert]))
    }

    @Test func expandingAPillDoesNotChimeAgain() {
        let a = OccurrenceID(seriesKey: "a", originalDate: nil)
        var chimes = 0
        var shown: [OccurrenceID: OverlayState] = [:]
        for next: [OccurrenceID: OverlayState] in [[a: .alert], [a: .pill], [a: .alert], [:], [a: .alert]] {
            if OverlayController.alertChimes(from: shown, to: next) { chimes += 1 }
            shown = next
        }
        #expect(chimes == 2)
    }

    @Test func glassTintGoesFromTheSurfaceToOpaque() {
        #expect(GlassTint.opacity(base: 0, glassOpacity: 0, reduceTransparency: false) == 0)
        #expect(GlassTint.opacity(base: 0, glassOpacity: 0.4, reduceTransparency: false) == 0.4)
        #expect(GlassTint.opacity(base: 0.75, glassOpacity: 0.5, reduceTransparency: false) == 0.875)
        #expect(GlassTint.opacity(base: 0.75, glassOpacity: 1, reduceTransparency: false) == 1)
        #expect(GlassTint.opacity(base: 0, glassOpacity: 0, reduceTransparency: true) == 1)
    }
}
