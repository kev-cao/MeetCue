import Foundation
import MeetCueCore
import Testing
@testable import MeetCue

@MainActor
struct AppSettingsTests {
    let storage = InMemorySettingsStorage()

    @Test func startsWithTheSpecsDefaults() {
        let settings = AppSettings(storage: storage)
        #expect(settings.menuBarContent == .timeAndTitle)
        #expect(settings.titleLength == 10)
        #expect(settings.titleScroll == .nearMeetings)
        #expect(settings.leadTime == 2)
        #expect(settings.snoozeLength == 1)
        #expect(settings.alertSound == .none)
        #expect(settings.alertDisplays == .all)
        #expect(settings.skipDeclined)
        #expect(settings.alertOffCalendarIDs.isEmpty)
        #expect(settings.showNotesAtStart)
        #expect(settings.notesOnlyWithNotes)
        #expect(settings.hideNotesAtEnd)
        #expect(settings.carryOver)
        #expect(settings.notesEditorMode == .preview)
        #expect(settings.appearance == .system)
        #expect(settings.glassOpacity == 0)
    }

    @Test func keepsChangesAcrossLaunches() {
        let settings = AppSettings(storage: storage)
        settings.menuBarContent = .iconOnly
        settings.titleLength = 16
        settings.titleScroll = .never
        settings.leadTime = 5
        settings.snoozeLength = 2
        settings.alertSound = .glass
        settings.alertDisplays = .main
        settings.skipDeclined = false
        settings.alertOffCalendarIDs = ["work", "home"]
        settings.showNotesAtStart = false
        settings.notesOnlyWithNotes = false
        settings.hideNotesAtEnd = false
        settings.carryOver = false
        settings.notesEditorMode = .markdown
        settings.appearance = .dark
        settings.glassOpacity = 0.4

        let relaunched = AppSettings(storage: storage)
        #expect(relaunched.menuBarContent == .iconOnly)
        #expect(relaunched.titleLength == 16)
        #expect(relaunched.titleScroll == .never)
        #expect(relaunched.leadTime == 5)
        #expect(relaunched.snoozeLength == 2)
        #expect(relaunched.alertSound == .glass)
        #expect(relaunched.alertDisplays == .main)
        #expect(!relaunched.skipDeclined)
        #expect(relaunched.alertOffCalendarIDs == ["work", "home"])
        #expect(!relaunched.showNotesAtStart)
        #expect(!relaunched.notesOnlyWithNotes)
        #expect(!relaunched.hideNotesAtEnd)
        #expect(!relaunched.carryOver)
        #expect(relaunched.notesEditorMode == .markdown)
        #expect(relaunched.appearance == .dark)
        #expect(relaunched.glassOpacity == 0.4)
    }

    @Test func savesUnderStableKeys() {
        let settings = AppSettings(storage: storage)
        settings.menuBarContent = .timeOnly
        settings.alertOffCalendarIDs = ["b", "a"]
        #expect(storage.values["menuBarContent"] as? String == "timeOnly")
        #expect(storage.values["alertOffCalendarIDs"] as? [String] == ["a", "b"])
    }

    @Test func ignoresStoredValuesOutsideTheChoices() {
        storage.values = ["titleLength": 9, "leadTime": 4, "snoozeLength": 0, "menuBarContent": "marquee", "glassOpacity": 3.0]
        let settings = AppSettings(storage: storage)
        #expect(settings.titleLength == 10)
        #expect(settings.leadTime == 2)
        #expect(settings.snoozeLength == 1)
        #expect(settings.menuBarContent == .timeAndTitle)
        #expect(settings.glassOpacity == 1)
    }

    @Test func derivesAlertTimingAndTheNotesPolicy() {
        let settings = AppSettings(storage: storage)
        settings.leadTime = 10
        settings.snoozeLength = 5
        #expect(settings.alertTiming.leadTime == 600)
        #expect(settings.alertTiming.snoozeLength == 300)
        #expect(settings.alertTiming.lateAlertWindow == AlertTiming.standard.lateAlertWindow)
        settings.notesOnlyWithNotes = false
        #expect(settings.notesPolicy(hasNotes: true) == NotesPolicy(showAtStart: true, onlyWithNotes: false, hideAtEnd: true, hasNotes: true))
    }
}
