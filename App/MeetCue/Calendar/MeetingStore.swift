import Foundation
import MeetCueCore
import Observation

@MainActor
@Observable
final class MeetingStore {
    private(set) var access: CalendarAccess
    /// Today's and tomorrow's meetings from `MeetingFilter.relevant`, so the menu bar can look past midnight.
    private(set) var meetings: [Meeting] = []
    var filter = CalendarFilter() {
        didSet { refresh() }
    }

    @ObservationIgnored private let source: CalendarSource
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let calendar: Calendar

    init(source: CalendarSource, now: @escaping () -> Date = Date.init, calendar: Calendar = .autoupdatingCurrent) {
        self.source = source
        self.now = now
        self.calendar = calendar
        access = source.access
        source.onChange = { [weak self] in self?.refresh() }
    }

    func requestAccess() async {
        access = await source.requestAccess()
        refresh()
    }

    func refresh() {
        access = source.access
        guard access == .granted else {
            meetings = []
            return
        }
        let start = calendar.startOfDay(for: now())
        guard let end = calendar.date(byAdding: .day, value: 2, to: start) else { return }
        let all = source.events(from: start, to: end).map(MeetingMapper.meeting(from:))
        meetings = MeetingFilter.relevant(all, filter: filter)
    }
}
