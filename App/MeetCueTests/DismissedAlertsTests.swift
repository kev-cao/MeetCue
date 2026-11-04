import Foundation
import MeetCueCore
import Testing
@testable import MeetCue

@MainActor
struct DismissedAlertsTests {
    let storage = InMemoryDismissedAlertStorage()
    let sync = MeetingMapper.meeting(from: AppFixtures.event(start: AppFixtures.at(14, 30)))

    @Test func remembersAMeetingAcrossLaunches() {
        DismissedAlerts(storage: storage).insert(sync)
        #expect(DismissedAlerts(storage: storage).contains(sync))
    }

    @Test func aMovedMeetingIsNoLongerDismissed() {
        let dismissed = DismissedAlerts(storage: storage)
        dismissed.insert(sync)
        var moved = sync
        moved.start = AppFixtures.at(15, 0)
        #expect(!dismissed.contains(moved))
    }

    @Test func removeForgetsTheMeeting() {
        let dismissed = DismissedAlerts(storage: storage)
        dismissed.insert(sync)
        dismissed.remove(sync.id)
        #expect(!DismissedAlerts(storage: storage).contains(sync))
    }

    @Test func pruneDropsMeetingsThatStartedBeforeTheCutoff() {
        let yesterday = MeetingMapper.meeting(from: AppFixtures.event(start: AppFixtures.at(14, 30, day: 3), series: "old"))
        let dismissed = DismissedAlerts(storage: storage)
        dismissed.insert(yesterday)
        dismissed.insert(sync)
        dismissed.prune(before: AppFixtures.at(0, 0))
        #expect(storage.records.keys.sorted() == [sync.id.storageKey])
    }
}
