import Foundation
import Testing
@testable import MeetCueCore

struct NoteExportTests {
    @Test func namesTheFileFromTheDateAndTitle() {
        #expect(NoteExport.baseName(date: Fixtures.at(14, 30), title: "Team Sync", calendar: Fixtures.calendar) == "2026-11-04 Team Sync")
    }

    @Test func usesTheDayInTheCalendarsTimeZone() {
        #expect(NoteExport.baseName(date: Fixtures.at(23, 30), title: nil, calendar: Fixtures.calendar) == "2026-11-04")
    }

    @Test func fallsBackToTheDateAlone() {
        for title in [nil, "", "   ", "\n"] {
            #expect(NoteExport.baseName(date: Fixtures.at(14, 30), title: title, calendar: Fixtures.calendar) == "2026-11-04")
        }
    }

    @Test func replacesCharactersAFileNameCantHold() {
        let name = NoteExport.baseName(date: Fixtures.at(14, 30), title: "Q1/Q2: plan\nreview\t ", calendar: Fixtures.calendar)
        #expect(name == "2026-11-04 Q1-Q2- plan review")
        #expect(NoteExport.baseName(date: Fixtures.at(14, 30), title: ".hidden", calendar: Fixtures.calendar) == "2026-11-04 .hidden")
    }

    @Test func shortensLongTitlesWithoutSplittingCharacters() {
        let name = NoteExport.baseName(date: Fixtures.at(14, 30), title: String(repeating: "🗓️", count: 100), calendar: Fixtures.calendar)
        #expect(name.utf8.count <= 11 + NoteExport.maxTitleBytes)
        #expect(name.hasPrefix("2026-11-04 🗓️"))
        #expect(name.dropFirst(11).allSatisfy { $0 == "🗓️" })
    }

    @Test func numbersRepeatedNamesIgnoringCase() {
        #expect(NoteExport.fileNames(for: ["A", "a", "A 2", "B", "A"]) == ["A.md", "a 2.md", "A 2 2.md", "B.md", "A 3.md"])
    }
}
