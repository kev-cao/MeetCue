import Foundation
import Testing
@testable import MeetCueCore

struct AlertRulesTests {
    let sync = Fixtures.meeting(start: Fixtures.at(14, 30))
    let config = AlertConfig(leadTime: 120)
    let withNotes = NotesPolicy(hasNotes: true)

    func settle(_ state: OverlayState = .waiting, at now: Date, config: AlertConfig? = nil, notes: NotesPolicy? = nil) -> OverlayState {
        AlertRules.settle(sync, state: state, now: now, config: config ?? self.config, notes: notes ?? withNotes)
    }

    @Test func nothingDueBeforeAlertTime() {
        #expect(AlertRules.dueEvent(for: sync, state: .waiting, now: Fixtures.at(14, 27), config: config) == nil)
    }

    @Test func alertDueAtLeadTime() {
        #expect(AlertRules.dueEvent(for: sync, state: .waiting, now: Fixtures.at(14, 28), config: config) == .alertTime(quiet: false))
    }

    @Test func quietModeMarksTheAlertQuiet() {
        let quiet = AlertConfig(leadTime: 120, quietUntil: Fixtures.at(15, 0))
        let expired = AlertConfig(leadTime: 120, quietUntil: Fixtures.at(14, 0))
        let untilOff = AlertConfig(leadTime: 120, quietUntil: .distantFuture)
        #expect(AlertRules.dueEvent(for: sync, state: .waiting, now: Fixtures.at(14, 28), config: quiet) == .alertTime(quiet: true))
        #expect(AlertRules.dueEvent(for: sync, state: .waiting, now: Fixtures.at(14, 28), config: expired) == .alertTime(quiet: false))
        #expect(AlertRules.dueEvent(for: sync, state: .waiting, now: Fixtures.at(14, 28), config: untilOff) == .alertTime(quiet: true))
    }

    @Test func wakeBeforeStartShowsAlert() {
        #expect(settle(at: Fixtures.at(14, 29, second: 30)) == .alert)
    }

    @Test func wakeShortlyAfterStartShowsLateAlert() {
        #expect(settle(at: Fixtures.at(14, 33)) == .alert)
    }

    @Test func wakeWellAfterStartGoesToNotes() {
        #expect(settle(at: Fixtures.at(14, 40)) == .notesCard)
        #expect(settle(at: Fixtures.at(14, 40), notes: NotesPolicy(hasNotes: false)) == .done)
    }

    @Test func wakeAfterEndIsDone() {
        #expect(settle(at: Fixtures.at(15, 5)) == .done)
    }

    @Test func quietModeStillReachesNotesAtStart() {
        let quiet = AlertConfig(leadTime: 120, quietUntil: .distantFuture)
        #expect(settle(at: Fixtures.at(14, 28), config: quiet) == .dismissed)
        #expect(settle(.dismissed, at: Fixtures.at(14, 30), config: quiet) == .notesCard)
    }

    @Test func snoozeReturnsToAlert() {
        let until = Fixtures.at(14, 29, second: 10)
        #expect(settle(.snoozed(until: until), at: Fixtures.at(14, 29)) == .snoozed(until: until))
        #expect(settle(.snoozed(until: until), at: until) == .alert)
    }

    @Test func alertStaysUpAfterStart() {
        #expect(settle(.alert, at: Fixtures.at(14, 45)) == .alert)
    }

    @Test func pillBecomesNotesAtStart() {
        #expect(settle(.pill, at: Fixtures.at(14, 30)) == .notesCard)
    }

    @Test func nextWakeFollowsState() {
        #expect(AlertRules.nextWake([(sync, .waiting)], now: Fixtures.at(14, 0), config: config) == Fixtures.at(14, 28))
        #expect(AlertRules.nextWake([(sync, .waiting)], now: Fixtures.at(14, 28), config: config) == Fixtures.at(14, 35))
        #expect(AlertRules.nextWake([(sync, .alert)], now: Fixtures.at(14, 28), config: config) == Fixtures.at(15, 0))
        #expect(AlertRules.nextWake([(sync, .done)], now: Fixtures.at(14, 28), config: config) == nil)
    }

    @Test func nextWakeIgnoresQuietExpiry() {
        let timed = AlertConfig(leadTime: 120, quietUntil: Fixtures.at(14, 10))
        let untilOff = AlertConfig(leadTime: 120, quietUntil: .distantFuture)
        #expect(AlertRules.nextWake([(sync, .waiting)], now: Fixtures.at(14, 0), config: timed) == Fixtures.at(14, 28))
        #expect(AlertRules.nextWake([(sync, .waiting)], now: Fixtures.at(14, 0), config: untilOff) == Fixtures.at(14, 28))
    }

    @Test func snoozeAfterStartIsKept() {
        let until = Fixtures.at(14, 40)
        #expect(settle(.snoozed(until: until), at: Fixtures.at(14, 35)) == .snoozed(until: until))
        #expect(settle(.snoozed(until: until), at: until) == .alert)
    }

    @Test func nextWakeForSnoozeIsItsEnd() {
        let wake = AlertRules.nextWake([(sync, .snoozed(until: Fixtures.at(14, 40)))], now: Fixtures.at(14, 35), config: config)
        #expect(wake == Fixtures.at(14, 40))
    }

    @Test func lateWindowBoundary() {
        #expect(settle(at: Fixtures.at(14, 35)) == .notesCard)
        #expect(settle(at: Fixtures.at(14, 34, second: 59)) == .alert)
    }

    @Test func endClosesAnOpenAlert() {
        #expect(settle(.alert, at: Fixtures.at(15, 0)) == .done)
    }

    @Test func zeroLeadTimeAlertsAtStart() {
        let atStart = AlertConfig(leadTime: 0)
        #expect(settle(at: Fixtures.at(14, 29, second: 59), config: atStart) == .waiting)
        #expect(settle(at: Fixtures.at(14, 30), config: atStart) == .alert)
    }

    @Test func quietSkipIsPermanent() {
        let quiet = AlertConfig(leadTime: 120, quietUntil: Fixtures.at(14, 29))
        #expect(settle(at: Fixtures.at(14, 28), config: quiet) == .dismissed)
        #expect(settle(.dismissed, at: Fixtures.at(14, 29, second: 30), config: quiet) == .dismissed)
    }

    @Test func quietWakeAfterStartGoesToNotes() {
        let quiet = AlertConfig(leadTime: 120, quietUntil: .distantFuture)
        #expect(settle(at: Fixtures.at(14, 33), config: quiet) == .notesCard)
    }

    @Test func settleIsIdempotent() {
        for now in [Fixtures.at(14, 27), Fixtures.at(14, 28), Fixtures.at(14, 31), Fixtures.at(14, 36), Fixtures.at(15, 1)] {
            let once = settle(at: now)
            #expect(settle(once, at: now) == once)
        }
    }

    @Test func nextWakeIsEarliestAcrossMeetings() {
        let standup = Fixtures.meeting("Standup", start: Fixtures.at(10, 0), series: "b")
        let wake = AlertRules.nextWake([(sync, .waiting), (standup, .waiting)], now: Fixtures.at(9, 0), config: config)
        #expect(wake == Fixtures.at(9, 58))
    }

    @Test func nextAlertIsTheEarliestPendingAlert() {
        let standup = Fixtures.meeting("Standup", start: Fixtures.at(14, 40), series: "b")
        let snoozed = OverlayState.snoozed(until: Fixtures.at(14, 31))
        #expect(AlertRules.nextAlert([(sync, .waiting), (standup, .waiting)], now: Fixtures.at(14, 0), config: config) == Fixtures.at(14, 28))
        #expect(AlertRules.nextAlert([(sync, snoozed), (standup, .waiting)], now: Fixtures.at(14, 30), config: config) == Fixtures.at(14, 31))
        #expect(AlertRules.nextAlert([(sync, .alert), (standup, .pill)], now: Fixtures.at(14, 30), config: config) == nil)
        #expect(AlertRules.nextAlert([(sync, .dismissed), (standup, .done)], now: Fixtures.at(14, 0), config: config) == nil)
    }
}
